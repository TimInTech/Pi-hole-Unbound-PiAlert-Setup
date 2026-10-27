import os
from unittest.mock import patch

from fastapi.testclient import TestClient

# Set required env vars before importing start_suite
os.environ["SUITE_API_KEY"] = "test-key"
os.environ["SUITE_PORT"] = "8090"
os.environ["SUITE_HOST"] = "127.0.0.1"

from start_suite import app
import start_suite

client = TestClient(app, base_url="https://pi.hole:8443")
HEADERS = {"X-API-Key": "test-key"}
BAD_HEADERS = {"X-API-Key": "wrong-key"}

def test_unknown_device_count_is_not_reported_as_zero():
    assert client.get('/stats', headers=HEADERS).json()['total_devices'] is None
    response = client.get('/devices', headers=HEADERS)
    assert response.status_code == 503

def test_exposed_monitoring_endpoints_require_api_key():
    for path in ('/version', '/dns', '/devices', '/leases'):
        assert client.get(path).status_code == 401

def test_missing_dns_log_is_unavailable_not_zero(monkeypatch):
    monkeypatch.setattr(start_suite, '_read_lines', lambda *args: None)
    response = client.get('/stats', headers=HEADERS)
    assert response.json()['recent_queries'] is None
    assert client.get('/dns', headers=HEADERS).status_code == 503
    assert client.get('/leases', headers=HEADERS).status_code == 503

def test_read_lines_uses_bounded_iteration(tmp_path, monkeypatch):
    import builtins
    path = tmp_path / 'log'
    path.write_text(''.join(f'{i}\n' for i in range(1000)))
    real_open = builtins.open
    class IterOnly:
        def __init__(self, stream): self.stream = stream
        def __enter__(self): return self
        def __exit__(self, *args): self.stream.close()
        def __iter__(self): return iter(self.stream)
        def readlines(self): raise AssertionError('unbounded readlines')
    monkeypatch.setattr(builtins, 'open', lambda *a, **kw: IterOnly(real_open(*a, **kw)))
    assert start_suite._read_lines(str(path), 2) == ['998\n', '999\n']

def test_upstreams_helper_rejects_warning_and_invalid_json(monkeypatch):
    monkeypatch.setattr(start_suite, "_run", lambda *a, **kw: {"ok": True, "returncode": 0, "stdout": '[]', "stderr": "permission denied"})
    assert start_suite._read_pihole_v6_upstreams() is None
    monkeypatch.setattr(start_suite, "_run", lambda *a, **kw: {"ok": True, "returncode": 0, "stdout": '["127.0.0.1#5335"]', "stderr": ""})
    assert start_suite._read_pihole_v6_upstreams() == ["127.0.0.1#5335"]

def test_root_serves_maintenance():
    response = client.get("/", follow_redirects=False)
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]

def test_dashboard_static_files():
    # Only test if dashboard folder is present
    if os.path.isdir(os.path.join(os.path.dirname(__file__), "..", "dashboard")):
        response = client.get("/dashboard/")
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]

def test_auth_success():
    response = client.get("/health", headers=HEADERS)
    assert response.status_code == 200
    assert response.json()["ok"] is True

def test_auth_missing():
    response = client.get("/health")
    assert response.status_code in [401, 422] # missing header error depends on dependency resolution

def test_auth_invalid():
    response = client.get("/health", headers=BAD_HEADERS)
    assert response.status_code == 401
    assert response.json()["detail"] == "Unauthorized"

@patch.object(start_suite, "_run")
@patch.object(start_suite, "_read_pihole_v6_upstreams")
def test_pihole_healthy(mock_upstreams, mock_run):
    def run_side_effect(cmd, **kwargs):
        if cmd == ["pihole", "-v"]:
            return {"ok": True, "stdout": "Pi-hole v5.0"}
        if cmd == ["systemctl", "is-active", "pihole-FTL"]:
            return {"ok": True, "returncode": 0}
        return {"ok": False}

    mock_run.side_effect = run_side_effect
    mock_upstreams.return_value = ["1.1.1.1"]

    response = client.get("/pihole", headers=HEADERS)
    assert response.status_code == 200
    data = response.json()
    assert data["ftl_active"] is True
    assert data["pihole_version"] == "Pi-hole v5.0"
    assert "1.1.1.1" in data["upstreams"]

@patch.object(start_suite, "_run")
@patch.object(start_suite, "_read_pihole_v6_upstreams")
def test_pihole_unavailable(mock_upstreams, mock_run):
    def run_side_effect(cmd, **kwargs):
        if cmd == ["pihole", "-v"]:
            return {"ok": False}
        if cmd == ["systemctl", "is-active", "pihole-FTL"]:
            return {"ok": True, "returncode": 3}
        return {"ok": False}

    mock_run.side_effect = run_side_effect
    mock_upstreams.return_value = []

    response = client.get("/pihole", headers=HEADERS)
    assert response.status_code == 200
    data = response.json()
    assert data["ftl_active"] is False
    assert data["pihole_version"] == "unknown"

@patch.object(start_suite, "_run")
def test_unbound_healthy(mock_run):
    def run_side_effect(cmd, **kwargs):
        if cmd[0:3] == ["systemctl", "is-active", "unbound"]:
            return {"ok": True, "returncode": 0}
        if cmd[0] == "dig":
            return {"ok": True, "stdout": "1.1.1.1"}
        return {"ok": False}

    mock_run.side_effect = run_side_effect
    response = client.get("/unbound", headers=HEADERS)
    assert response.status_code == 200
    data = response.json()
    assert data["service_active"] is True
    assert data["dig_ok"] is True
    assert data["dig_result"] == "1.1.1.1"

@patch.object(start_suite, "_run")
def test_unbound_unavailable(mock_run):
    def run_side_effect(cmd, **kwargs):
        if cmd[0:3] == ["systemctl", "is-active", "unbound"]:
            return {"ok": True, "returncode": 3}
        if cmd[0] == "dig":
            return {"ok": False, "error": "timeout"}
        return {"ok": False}

    mock_run.side_effect = run_side_effect
    response = client.get("/unbound", headers=HEADERS)
    assert response.status_code == 200
    data = response.json()
    assert data["service_active"] is False
    assert data["dig_ok"] is False

@patch.object(start_suite, "_http_ok")
def test_netalertx_healthy(mock_http_ok):
    mock_http_ok.return_value = True
    response = client.get("/netalertx", headers=HEADERS)
    assert response.status_code == 200
    assert response.json()["http_reachable"] is True

@patch.object(start_suite, "_http_ok")
def test_netalertx_unavailable(mock_http_ok):
    mock_http_ok.return_value = False
    response = client.get("/netalertx", headers=HEADERS)
    assert response.status_code == 200
    assert response.json()["http_reachable"] is False

@patch.object(start_suite, "_run")
def test_command_timeout(mock_run):
    def run_side_effect(cmd, **kwargs):
        return {"ok": False, "error": "Command timed out"}

    mock_run.side_effect = run_side_effect
    response = client.get("/pihole", headers=HEADERS)
    assert response.status_code == 200
    data = response.json()
    assert data["ftl_active"] is False
    assert data["pihole_version"] == "unknown"
