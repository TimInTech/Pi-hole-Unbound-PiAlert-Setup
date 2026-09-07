"""Authenticated, least-privilege browser API for Pi-hole maintenance jobs."""

from __future__ import annotations

import hmac
import json
import os
import secrets
import stat
import subprocess
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.responses import FileResponse, JSONResponse, PlainTextResponse

SESSION_IDLE_SECONDS = 30 * 60
SESSION_MAX_SECONDS = 8 * 60 * 60
LOGIN_WINDOW_SECONDS = 5 * 60
LOGIN_MAX_FAILURES = 5
START_RESERVATION_SECONDS = 60
MAX_STATE_BYTES = 64 * 1024
COOKIE_NAME = "pihole_maintenance_session"
ALLOWED_HOSTS = frozenset({"pi.hole", "192.168.178.2", "127.0.0.1", "localhost"})
ALLOWED_ORIGINS = frozenset({"https://pi.hole:8443", "https://192.168.178.2:8443"})
WEB_DIRECTORY = Path(__file__).resolve().parent / "web"

Dispatcher = Callable[[list[str]], None]


class StateUnavailable(RuntimeError):
    """The runner state exists but is not safe to expose or act on."""


@dataclass
class Session:
    csrf_token: str
    created_at: float
    last_seen_at: float


@dataclass(frozen=True)
class StartReservation:
    token: str
    baseline_job_id: str | None
    expires_at: float


@dataclass
class MaintenanceSettings:
    """Configuration owned by the local service, never supplied by a request."""

    api_key: str
    state_file: Path = Path("/var/lib/pihole-suite/jobs/current.json")
    dispatcher: Dispatcher | None = None
    allowed_hosts: frozenset[str] = ALLOWED_HOSTS
    allowed_origins: frozenset[str] = ALLOWED_ORIGINS
    sessions: dict[str, Session] = field(default_factory=dict)
    login_failures: dict[str, list[float]] = field(default_factory=dict)
    state_lock: threading.RLock = field(default_factory=threading.RLock, repr=False)
    start_reservation: StartReservation | None = None
    now: Callable[[], float] = time.monotonic

    def __post_init__(self) -> None:
        self.state_file = Path(self.state_file)
        if self.dispatcher is None:
            self.dispatcher = _dispatch

    @classmethod
    def from_environment(cls) -> MaintenanceSettings:
        api_key = os.environ.get("SUITE_API_KEY", "")
        if not api_key:
            raise RuntimeError("Missing required environment variable: SUITE_API_KEY")
        return cls(api_key=api_key)


def _dispatch(argv: list[str]) -> None:
    """Start one predefined unit without a shell or caller-controlled arguments."""
    subprocess.run(argv, check=True, timeout=15, capture_output=True, text=True)


def _security_headers(response: Response) -> None:
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; base-uri 'none'; connect-src 'self'; form-action 'self'; "
        "frame-ancestors 'none'; object-src 'none'; script-src 'self'; style-src 'self'"
    )
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Cache-Control"] = "no-store"


def configure_maintenance_security(app: Any, settings: MaintenanceSettings) -> None:
    """Install the host boundary and response headers once on the FastAPI app."""

    @app.middleware("http")
    async def restrict_host_and_add_security_headers(request: Request, call_next: Any) -> Response:
        host = request.headers.get("host", "").split(":", 1)[0].lower()
        if host not in settings.allowed_hosts:
            response: Response = PlainTextResponse("Invalid host", status_code=400)
        else:
            response = await call_next(request)
        _security_headers(response)
        return response


def _client_key(request: Request) -> str:
    return request.client.host if request.client is not None else "unknown"


def _purge_expired_failures(settings: MaintenanceSettings, client_key: str, now: float) -> list[float]:
    recent = [timestamp for timestamp in settings.login_failures.get(client_key, []) if now - timestamp < LOGIN_WINDOW_SECONDS]
    if recent:
        settings.login_failures[client_key] = recent
    else:
        settings.login_failures.pop(client_key, None)
    return recent


def _purge_expired_sessions(settings: MaintenanceSettings, now: float) -> None:
    expired = [
        session_id
        for session_id, session in settings.sessions.items()
        if now - session.last_seen_at >= SESSION_IDLE_SECONDS or now - session.created_at >= SESSION_MAX_SECONDS
    ]
    for session_id in expired:
        settings.sessions.pop(session_id, None)


def _observe_runner_state(settings: MaintenanceSettings, state: dict[str, Any] | None, now: float) -> None:
    reservation = settings.start_reservation
    if reservation is None:
        return
    if now >= reservation.expires_at:
        settings.start_reservation = None
        return
    if state is not None and state["job_id"] != reservation.baseline_job_id:
        settings.start_reservation = None


def _session_from_request(request: Request, settings: MaintenanceSettings) -> tuple[str, Session]:
    session_id = request.cookies.get(COOKIE_NAME)
    if not session_id:
        raise HTTPException(status_code=401, detail="Authentication required")
    now = settings.now()
    with settings.state_lock:
        _purge_expired_sessions(settings, now)
        session = settings.sessions.get(session_id)
        if session is None:
            raise HTTPException(status_code=401, detail="Authentication required")
        session.last_seen_at = now
        return session_id, session


def _require_mutation(request: Request, settings: MaintenanceSettings) -> tuple[str, Session]:
    session_id, session = _session_from_request(request, settings)
    if request.headers.get("origin") not in settings.allowed_origins:
        raise HTTPException(status_code=403, detail="Request rejected")
    csrf_token = request.headers.get("x-csrf-token", "")
    if not csrf_token or not hmac.compare_digest(csrf_token, session.csrf_token):
        raise HTTPException(status_code=403, detail="Request rejected")
    return session_id, session


def _bounded_string(value: object, *, maximum: int = 256) -> bool:
    return isinstance(value, str) and len(value) <= maximum and "\x00" not in value and all(ord(char) >= 32 for char in value)


def _bounded_integer(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _validate_system(system: object) -> bool:
    if not isinstance(system, dict):
        return False
    allowed = {
        "host", "operating_system", "kernel", "architecture", "uptime_seconds", "load_average",
        "memory", "root_filesystem", "temperature_celsius",
    }
    if not set(system) <= allowed:
        return False
    for key in ("host", "operating_system", "kernel", "architecture"):
        if key in system and not _bounded_string(system[key]):
            return False
    if "uptime_seconds" in system and system["uptime_seconds"] is not None and not _bounded_integer(system["uptime_seconds"]):
        return False
    if "load_average" in system and (
        not isinstance(system["load_average"], list)
        or len(system["load_average"]) != 3
        or not all(isinstance(value, (int, float)) and not isinstance(value, bool) for value in system["load_average"])
    ):
        return False
    for key, expected_keys in (("memory", {"total_bytes", "available_bytes"}), ("root_filesystem", {"total_bytes", "used_bytes", "free_bytes"})):
        if key not in system:
            continue
        value = system[key]
        if not isinstance(value, dict) or set(value) != expected_keys:
            return False
        if not all(item is None or _bounded_integer(item) for item in value.values()):
            return False
    return not (
        "temperature_celsius" in system
        and system["temperature_celsius"] is not None
        and not isinstance(system["temperature_celsius"], (int, float))
    )


def _validate_state(payload: object) -> dict[str, Any] | None:
    if not isinstance(payload, dict):
        return None
    required = {"schema_version", "job_id", "action", "state", "started_at", "finished_at", "steps", "result", "error"}
    if set(payload) != required or payload["schema_version"] != 1:
        return None
    if not _bounded_string(payload["job_id"], maximum=128) or not _bounded_string(payload["started_at"]):
        return None
    if payload["action"] not in {"check", "backup", "update"} or payload["state"] not in {"running", "succeeded", "failed"}:
        return None
    if payload["finished_at"] is not None and not _bounded_string(payload["finished_at"]):
        return None
    if not isinstance(payload["steps"], list) or len(payload["steps"]) > 64:
        return None
    for step in payload["steps"]:
        if not isinstance(step, dict) or set(step) != {"name", "required", "ok", "detail"}:
            return None
        if not _bounded_string(step["name"]) or not isinstance(step["required"], bool) or not isinstance(step["ok"], bool) or not _bounded_string(step["detail"]):
            return None
    result = payload["result"]
    if not isinstance(result, dict) or not set(result) <= {"system", "backup_path", "reboot_required"}:
        return None
    if "system" in result and not _validate_system(result["system"]):
        return None
    if "backup_path" in result and not _bounded_string(result["backup_path"], maximum=512):
        return None
    if "reboot_required" in result and not isinstance(result["reboot_required"], bool):
        return None
    error = payload["error"]
    if error is not None and (
        not isinstance(error, dict)
        or set(error) != {"code", "message"}
        or not _bounded_string(error["code"])
        or not _bounded_string(error["message"])
    ):
        return None
    return payload


def _read_current_state(settings: MaintenanceSettings) -> dict[str, Any] | None:
    try:
        metadata = settings.state_file.lstat()
    except FileNotFoundError:
        return None
    except OSError as error:
        raise StateUnavailable from error
    try:
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_size > MAX_STATE_BYTES:
            raise StateUnavailable
        raw = settings.state_file.read_bytes()
        if len(raw) > MAX_STATE_BYTES:
            raise StateUnavailable
        state = _validate_state(json.loads(raw.decode("utf-8")))
        if state is None:
            raise StateUnavailable
        return state
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        raise StateUnavailable from None


def _state_or_error(settings: MaintenanceSettings) -> dict[str, Any]:
    try:
        state = _read_current_state(settings)
    except StateUnavailable:
        raise HTTPException(status_code=503, detail="Job status unavailable")
    with settings.state_lock:
        _observe_runner_state(settings, state, settings.now())
    return state if state is not None else {"state": "idle"}


def _file_response(filename: str, media_type: str) -> FileResponse:
    return FileResponse(WEB_DIRECTORY / filename, media_type=media_type)


def create_maintenance_router(settings: MaintenanceSettings) -> APIRouter:
    """Build routes for one configured maintenance service instance."""
    router = APIRouter()

    def require_session(request: Request) -> tuple[str, Session]:
        return _session_from_request(request, settings)

    def require_mutation(request: Request) -> tuple[str, Session]:
        return _require_mutation(request, settings)

    @router.get("/", include_in_schema=False)
    def dashboard() -> FileResponse:
        return _file_response("maintenance.html", "text/html; charset=utf-8")

    @router.get("/maintenance.css", include_in_schema=False)
    def stylesheet() -> FileResponse:
        return _file_response("maintenance.css", "text/css; charset=utf-8")

    @router.get("/maintenance.js", include_in_schema=False)
    def script() -> FileResponse:
        return _file_response("maintenance.js", "application/javascript; charset=utf-8")

    @router.post("/api/session", include_in_schema=False)
    async def create_session(request: Request, response: Response) -> dict[str, str]:
        try:
            body = await request.body()
            parsed = json.loads(body) if len(body) <= 8192 else {}
            password = parsed.get("password") if isinstance(parsed, dict) and set(parsed) == {"password"} else None
        except (UnicodeDecodeError, json.JSONDecodeError):
            password = None
        now = settings.now()
        client_key = _client_key(request)
        with settings.state_lock:
            _purge_expired_sessions(settings, now)
            if len(_purge_expired_failures(settings, client_key, now)) >= LOGIN_MAX_FAILURES:
                raise HTTPException(status_code=429, detail="Too many login attempts")
            if not isinstance(password, str) or not password or len(password) > 4096 or not hmac.compare_digest(password, settings.api_key):
                settings.login_failures.setdefault(client_key, []).append(now)
                raise HTTPException(status_code=401, detail="Invalid credentials")
            settings.login_failures.pop(client_key, None)
            session_id = secrets.token_urlsafe(32)
            csrf_token = secrets.token_urlsafe(32)
            settings.sessions[session_id] = Session(csrf_token=csrf_token, created_at=now, last_seen_at=now)
        response.set_cookie(
            COOKIE_NAME,
            session_id,
            secure=True,
            httponly=True,
            samesite="strict",
            path="/",
        )
        return {"csrf_token": csrf_token}

    @router.post("/api/session/logout", status_code=204, include_in_schema=False)
    def logout(session: tuple[str, Session] = Depends(require_mutation)) -> Response:
        with settings.state_lock:
            settings.sessions.pop(session[0], None)
        response = Response(status_code=204)
        response.delete_cookie(COOKIE_NAME, path="/", secure=True, httponly=True, samesite="strict")
        return response

    @router.get("/api/maintenance/status", include_in_schema=False)
    def status(_: tuple[str, Session] = Depends(require_session)) -> dict[str, Any]:
        return _state_or_error(settings)

    def start_action(action: str) -> JSONResponse:
        with settings.state_lock:
            try:
                state = _read_current_state(settings)
            except StateUnavailable:
                raise HTTPException(status_code=503, detail="Job status unavailable") from None
            now = settings.now()
            _observe_runner_state(settings, state, now)
            if settings.start_reservation is not None or (state is not None and state["state"] == "running"):
                raise HTTPException(status_code=409, detail="A maintenance job is already running")
            reservation = StartReservation(
                token=secrets.token_urlsafe(16),
                baseline_job_id=state["job_id"] if state is not None else None,
                expires_at=now + START_RESERVATION_SECONDS,
            )
            settings.start_reservation = reservation
        argv = [
            "/usr/bin/sudo", "-n", "/usr/bin/systemctl", "start", "--no-block",
            f"pihole-maintenance-{action}.service",
        ]
        try:
            assert settings.dispatcher is not None
            settings.dispatcher(argv)
        except (OSError, subprocess.SubprocessError):
            with settings.state_lock:
                if settings.start_reservation == reservation:
                    settings.start_reservation = None
            raise HTTPException(status_code=503, detail="Maintenance job could not be started") from None
        return JSONResponse(status_code=202, content={"action": action, "state": "accepted"})

    @router.post("/api/maintenance/check", status_code=202, include_in_schema=False)
    def start_check(_: tuple[str, Session] = Depends(require_mutation)) -> JSONResponse:
        return start_action("check")

    @router.post("/api/maintenance/backup", status_code=202, include_in_schema=False)
    def start_backup(_: tuple[str, Session] = Depends(require_mutation)) -> JSONResponse:
        return start_action("backup")

    @router.post("/api/maintenance/update", status_code=202, include_in_schema=False)
    def start_update(_: tuple[str, Session] = Depends(require_mutation)) -> JSONResponse:
        return start_action("update")

    return router
