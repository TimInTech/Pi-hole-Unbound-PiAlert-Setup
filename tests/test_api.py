"""Test suite for Pi-hole Suite API."""

import os
import tempfile

import pytest
from fastapi.testclient import TestClient

# Set test environment before importing
os.environ["SUITE_API_KEY"] = "test-api-key"
os.environ["SUITE_DATA_DIR"] = tempfile.mkdtemp()

from api.main import app
from shared.db import init_db


@pytest.fixture(scope="module")
def setup_database():
    init_db()
    yield


@pytest.fixture
def client(setup_database):
    return TestClient(app)


@pytest.fixture
def api_headers():
    return {"X-API-Key": "test-api-key"}


def test_root_endpoint(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert "message" in resp.json()


def test_health_endpoint(client, api_headers):
    resp = client.get("/health", headers=api_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["ok"] is True
    assert "message" in data
    assert "version" in data


def test_health_endpoint_no_auth(client):
    resp = client.get("/health")
    assert resp.status_code == 401


def test_health_endpoint_bad_auth(client):
    resp = client.get("/health", headers={"X-API-Key": "wrong-key"})
    assert resp.status_code == 401


def test_dns_logs_endpoint(client, api_headers):
    resp = client.get("/dns", headers=api_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_dns_logs_with_limit(client, api_headers):
    resp = client.get("/dns?limit=10", headers=api_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) <= 10


def test_devices_endpoint(client, api_headers):
    resp = client.get("/devices", headers=api_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_leases_endpoint(client, api_headers):
    resp = client.get("/leases", headers=api_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_stats_endpoint(client, api_headers):
    resp = client.get("/stats", headers=api_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "total_dns_logs" in data
    assert "total_devices" in data
    assert "recent_queries" in data


def test_device_request_validation():
    from api.schemas import DeviceRequest

    valid_data = {
        "ip_address": "192.168.1.100",
        "status": True,
        "hostname": "test-device",
        "mac_address": "aa:bb:cc:dd:ee:ff",
    }
    device_req = DeviceRequest(**valid_data)
    assert device_req.ip_address == "192.168.1.100"
    assert device_req.status is True

    with pytest.raises(ValueError):
        DeviceRequest(ip_address="invalid-ip", status=True)

    with pytest.raises(ValueError):
        DeviceRequest(ip_address="192.168.1.100", status=True, mac_address="invalid-mac")
