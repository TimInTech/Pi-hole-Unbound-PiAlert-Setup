"""Test suite for Pi-hole Suite API."""

import os
import tempfile

import pytest
from fastapi.testclient import TestClient

# Set test environment before importing
os.environ['SUITE_API_KEY'] = 'test-api-key'
os.environ['SUITE_DATA_DIR'] = tempfile.mkdtemp()

from api.main import app
from shared.db import init_db


@pytest.fixture(scope="module") 
def setup_database():
    """Initialize test database once for all tests."""
    init_db()
    yield
    # Cleanup would happen here if needed


@pytest.fixture
def client(setup_database):
    """Create test client with initialized database."""
    return TestClient(app)


@pytest.fixture
def api_headers():
    """Return API headers with test key."""
    return {"X-API-Key": "test-api-key"}


def test_health_endpoint(client, api_headers):
    """Test the health endpoint."""
    response = client.get("/health", headers=api_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["ok"] is True
    assert "message" in data


def test_health_endpoint_no_auth(client):
    """Test health endpoint without authentication."""
    response = client.get("/health")
    assert response.status_code == 401  # API key validation returns 401


def test_health_endpoint_bad_auth(client):
    """Test health endpoint with bad authentication."""
    response = client.get("/health", headers={"X-API-Key": "wrong-key"})
    assert response.status_code == 401


def test_dns_logs_endpoint(client, api_headers):
    """Test DNS logs endpoint."""
    response = client.get("/dns", headers=api_headers)
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_dns_logs_with_limit(client, api_headers):
    """Test DNS logs endpoint with limit parameter."""
    response = client.get("/dns?limit=10", headers=api_headers)
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) <= 10


def test_devices_endpoint(client, api_headers):
    """Test devices endpoint."""
    response = client.get("/devices", headers=api_headers)
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_leases_endpoint(client, api_headers):
    """Test IP leases endpoint."""
    response = client.get("/leases", headers=api_headers)
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_stats_endpoint(client, api_headers):
    """Test statistics endpoint."""
    response = client.get("/stats", headers=api_headers)
    assert response.status_code == 200
    data = response.json()
    assert "total_dns_logs" in data
    assert "total_devices" in data
    assert "recent_queries" in data
    assert isinstance(data["total_dns_logs"], int)
    assert isinstance(data["total_devices"], int)
    assert isinstance(data["recent_queries"], int)


def test_root_endpoint(client):
    """Test root endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data