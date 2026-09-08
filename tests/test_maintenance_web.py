import asyncio
import importlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from maintenance_web import (
    MaintenanceSettings,
    Session,
    configure_maintenance_security,
    create_maintenance_router,
)


class RecordingDispatcher:
    def __init__(self):
        self.calls: list[list[str]] = []

    def __call__(self, argv: list[str]) -> None:
        self.calls.append(argv)


def state_payload(*, state: str = "succeeded") -> dict[str, object]:
    return {
        "schema_version": 1,
        "job_id": "20260907T120000000000Z-0123456789abcdef",
        "action": "check",
        "state": state,
        "started_at": "2026-09-07T12:00:00Z",
        "finished_at": None if state == "running" else "2026-09-07T12:00:01Z",
        "steps": [{"name": "pihole_ftl", "required": True, "ok": True, "detail": "completed"}],
        "result": {"system": {"host": "pi.hole", "kernel": "6.18", "architecture": "aarch64"}},
        "error": None,
    }


@pytest.fixture
def state_file(tmp_path: Path) -> Path:
    path = tmp_path / "current.json"
    path.write_text(json.dumps(state_payload()), encoding="utf-8")
    return path


@pytest.fixture
def dispatcher() -> RecordingDispatcher:
    return RecordingDispatcher()


@pytest.fixture
def settings(state_file: Path, dispatcher: RecordingDispatcher) -> MaintenanceSettings:
    return MaintenanceSettings(api_key="correct horse battery staple", state_file=state_file, dispatcher=dispatcher)


@pytest.fixture
def client(settings: MaintenanceSettings) -> TestClient:
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    configure_maintenance_security(app, settings)
    app.include_router(create_maintenance_router(settings))
    return TestClient(app, base_url="https://pi.hole:8443")


def login(client: TestClient) -> tuple[dict[str, str], str]:
    response = client.post("/api/session", json={"password": "correct horse battery staple"})
    assert response.status_code == 200
    return {"pihole_maintenance_session": response.cookies["pihole_maintenance_session"]}, response.json()["csrf_token"]


def post_action(client: TestClient, cookies: dict[str, str], csrf_token: str, action: str):
    return client.post(
        f"/api/maintenance/{action}",
        cookies=cookies,
        headers={"Origin": "https://pi.hole:8443", "X-CSRF-Token": csrf_token},
    )


def test_job_status_requires_session(client: TestClient):
    assert client.get("/api/maintenance/status").status_code == 401


def test_login_does_not_return_password_and_sets_secure_cookie(client: TestClient):
    response = client.post("/api/session", json={"password": "correct horse battery staple"})

    assert response.status_code == 200
    assert "correct horse battery staple" not in response.text
    cookie = response.headers["set-cookie"]
    assert "HttpOnly" in cookie
    assert "Secure" in cookie
    assert "samesite=strict" in cookie.lower()


def test_mutation_rejects_missing_or_wrong_csrf(client: TestClient):
    cookies, csrf_token = login(client)

    missing = client.post("/api/maintenance/update", cookies=cookies, headers={"Origin": "https://pi.hole:8443"})
    wrong = post_action(client, cookies, f"{csrf_token}-wrong", "update")

    assert missing.status_code == 403
    assert wrong.status_code == 403


def test_mutation_rejects_wrong_origin(client: TestClient):
    cookies, csrf_token = login(client)

    response = client.post(
        "/api/maintenance/check",
        cookies=cookies,
        headers={"Origin": "https://attacker.invalid", "X-CSRF-Token": csrf_token},
    )

    assert response.status_code == 403


def test_login_rate_limits_five_failures(client: TestClient):
    for _ in range(5):
        assert client.post("/api/session", json={"password": "wrong"}).status_code == 401

    response = client.post("/api/session", json={"password": "correct horse battery staple"})

    assert response.status_code == 429
    assert "correct horse battery staple" not in response.text


def test_parallel_login_failures_cannot_bypass_rate_limit(client: TestClient):
    async def failed_logins() -> list[int]:
        import httpx

        transport = httpx.ASGITransport(app=client.app)
        async with httpx.AsyncClient(transport=transport, base_url="https://pi.hole:8443") as asgi_client:
            responses = await asyncio.gather(*[
                asgi_client.post("/api/session", json={"password": "wrong"})
                for _ in range(7)
            ])
            locked = await asgi_client.post("/api/session", json={"password": "correct horse battery staple"})
        return [response.status_code for response in responses] + [locked.status_code]

    statuses = asyncio.run(failed_logins())
    assert statuses.count(401) == 5
    assert statuses.count(429) == 3


def test_invalid_login_body_never_reflects_password(client: TestClient):
    secret = "must-not-be-reflected"

    response = client.post("/api/session", json={"password": [secret]})

    assert response.status_code == 401
    assert secret not in response.text


def test_check_dispatches_only_fixed_unit(client: TestClient, dispatcher: RecordingDispatcher):
    cookies, csrf_token = login(client)

    response = post_action(client, cookies, csrf_token, "check")

    assert response.status_code == 202
    assert dispatcher.calls == [[
        "/usr/bin/sudo", "-n", "/usr/bin/systemctl", "start", "--no-block",
        "pihole-maintenance-check.service",
    ]]


def test_running_job_rejects_second_start(client: TestClient, state_file: Path):
    state_file.write_text(json.dumps(state_payload(state="running")), encoding="utf-8")
    cookies, csrf_token = login(client)

    response = post_action(client, cookies, csrf_token, "backup")

    assert response.status_code == 409


def test_first_job_can_start_without_a_preexisting_state_file(client: TestClient, state_file: Path, dispatcher: RecordingDispatcher):
    state_file.unlink()
    cookies, csrf_token = login(client)

    response = post_action(client, cookies, csrf_token, "check")

    assert response.status_code == 202
    assert dispatcher.calls


def test_immediate_parallel_starts_are_reserved(client: TestClient):
    cookies, csrf_token = login(client)

    async def starts() -> list[int]:
        import httpx

        transport = httpx.ASGITransport(app=client.app)
        async with httpx.AsyncClient(transport=transport, base_url="https://pi.hole:8443") as asgi_client:
            responses = await asyncio.gather(*[
                asgi_client.post(
                    "/api/maintenance/check",
                    cookies=cookies,
                    headers={"Origin": "https://pi.hole:8443", "X-CSRF-Token": csrf_token},
                )
                for _ in range(2)
            ])
        return [response.status_code for response in responses]

    assert sorted(asyncio.run(starts())) == [202, 409]


def test_failed_dispatch_releases_start_reservation(client: TestClient, settings: MaintenanceSettings):
    cookies, csrf_token = login(client)

    def fail_dispatch(_: list[str]) -> None:
        raise OSError("systemctl unavailable")

    settings.dispatcher = fail_dispatch
    assert post_action(client, cookies, csrf_token, "check").status_code == 503
    settings.dispatcher = RecordingDispatcher()
    assert post_action(client, cookies, csrf_token, "check").status_code == 202


def test_new_runner_state_or_timeout_releases_start_reservation(client: TestClient, settings: MaintenanceSettings, state_file: Path):
    clock = [0.0]
    settings.now = lambda: clock[0]
    cookies, csrf_token = login(client)
    assert post_action(client, cookies, csrf_token, "check").status_code == 202

    new_state = state_payload()
    new_state["job_id"] = "20260907T120000000001Z-fedcba9876543210"
    state_file.write_text(json.dumps(new_state), encoding="utf-8")
    assert post_action(client, cookies, csrf_token, "backup").status_code == 202

    clock[0] = 61.0
    assert post_action(client, cookies, csrf_token, "update").status_code == 202


def test_unknown_action_is_not_routable(client: TestClient):
    cookies, csrf_token = login(client)

    assert post_action(client, cookies, csrf_token, "shell").status_code == 404


@pytest.mark.parametrize("contents", ("{}", "{" + "x" * 70_000 + "}"))
def test_status_rejects_malformed_or_oversized_state(client: TestClient, state_file: Path, contents: str):
    state_file.write_text(contents, encoding="utf-8")
    cookies, _ = login(client)

    response = client.get("/api/maintenance/status", cookies=cookies)

    assert response.status_code == 503
    assert "x" * 100 not in response.text


def test_logout_requires_csrf_and_invalidates_session(client: TestClient):
    cookies, csrf_token = login(client)

    missing = client.post("/api/session/logout", cookies=cookies, headers={"Origin": "https://pi.hole:8443"})
    logged_out = client.post(
        "/api/session/logout",
        cookies=cookies,
        headers={"Origin": "https://pi.hole:8443", "X-CSRF-Token": csrf_token},
    )

    assert missing.status_code == 403
    assert logged_out.status_code == 204
    assert client.get("/api/maintenance/status", cookies=cookies).status_code == 401


def test_session_expires_after_idle_or_absolute_lifetime(client: TestClient, settings: MaintenanceSettings):
    clock = [0.0]
    settings.now = lambda: clock[0]
    cookies, _ = login(client)
    clock[0] = 30 * 60
    assert client.get("/api/maintenance/status", cookies=cookies).status_code == 401

    clock[0] = 0.0
    cookies, _ = login(client)
    clock[0] = 30 * 60 - 1
    assert client.get("/api/maintenance/status", cookies=cookies).status_code == 200
    clock[0] = 8 * 60 * 60
    assert client.get("/api/maintenance/status", cookies=cookies).status_code == 401


def test_expired_sessions_are_pruned_during_normal_login(client: TestClient, settings: MaintenanceSettings):
    clock = [10_000.0]
    settings.now = lambda: clock[0]
    settings.sessions["expired"] = Session("csrf", 0.0, 0.0)

    login(client)

    assert "expired" not in settings.sessions


def test_ui_assets_headers_and_docs_are_safe(client: TestClient):
    page = client.get("/")
    css = client.get("/maintenance.css")
    javascript = client.get("/maintenance.js")

    assert page.status_code == 200
    assert "Systemcheck" in page.text
    assert "text/html" in page.headers["content-type"]
    assert "text/css" in css.headers["content-type"]
    assert "javascript" in javascript.headers["content-type"]
    assert client.get("/docs").status_code == 404
    for response in (page, css, javascript):
        assert "frame-ancestors 'none'" in response.headers["content-security-policy"]
        assert response.headers["strict-transport-security"].startswith("max-age=")
        assert response.headers["x-content-type-options"] == "nosniff"


def test_host_allowlist_rejects_unexpected_host(client: TestClient):
    response = client.get("/", headers={"Host": "attacker.invalid"})

    assert response.status_code == 400


def test_browser_ui_uses_confirmation_text_content_and_running_only_polling(client: TestClient):
    page = client.get("/").text
    script = client.get("/maintenance.js").text

    assert "Backup bestätigen" in page
    assert "UPDATE" in page
    assert "textContent" in script
    assert "innerHTML" not in script
    assert 'poll: job.state === "running"' in script
    assert "2000" in script


@pytest.mark.skipif(shutil.which("node") is None, reason="Node.js is only needed for the browser-state regression")
def test_browser_transition_polling_reaches_running_then_terminal_state():
    script_path = Path(__file__).resolve().parents[1] / "web" / "maintenance.js"
    node_program = f"""
const fs = require("fs");
const vm = require("vm");
const element = {{ addEventListener() {{}}, value: "", checked: false, hidden: false, textContent: "" }};
const context = {{
  document: {{ querySelector: () => element }},
  window: {{ clearTimeout() {{}}, setTimeout() {{ return 1; }}, location: {{ origin: "https://pi.hole:8443" }} }},
  Headers,
  fetch: async () => {{ throw new Error("fetch is not expected"); }},
}};
vm.runInNewContext(fs.readFileSync({json.dumps(str(script_path))}, "utf8") + ";globalThis.decision = pollingDecision;", context);
let pending = {{ baselineJobId: "old-job", attempts: 0 }};
let decision = context.decision({{ job_id: "old-job", state: "succeeded" }}, pending);
if (!decision.poll || decision.pending.attempts !== 1) throw new Error("old terminal state did not continue transition polling");
decision = context.decision({{ job_id: "new-job", state: "running" }}, decision.pending);
if (!decision.poll || decision.pending !== null) throw new Error("running new job was not observed");
decision = context.decision({{ job_id: "new-job", state: "succeeded" }}, decision.pending);
if (decision.poll) throw new Error("terminal new job still polls");
"""

    subprocess.run(["node", "-e", node_program], check=True, capture_output=True, text=True)


def test_suite_keeps_the_legacy_monitoring_api(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("SUITE_API_KEY", "correct horse battery staple")
    sys.modules.pop("start_suite", None)
    suite = importlib.import_module("start_suite")
    suite_client = TestClient(suite.app, base_url="https://pi.hole:8443")

    assert {"/health", "/version", "/urls", "/pihole", "/unbound", "/netalertx", "/dns", "/devices", "/leases", "/stats"} <= {
        route.path for route in suite.app.routes if hasattr(route, "path")
    }
    assert suite_client.get("/health", headers={"X-API-Key": "correct horse battery staple"}).status_code == 200


def test_suite_rejects_a_non_loopback_bind_host(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("SUITE_API_KEY", "correct horse battery staple")
    monkeypatch.setenv("SUITE_HOST", "0.0.0.0")
    sys.modules.pop("start_suite", None)
    suite = importlib.import_module("start_suite")

    with pytest.raises(RuntimeError, match="SUITE_HOST must be 127.0.0.1"):
        suite.main()
