"""Test suite for Pi-hole Suite API."""
import pytest
from fastapi.testclient import TestClient
import os
import tempfile
import sqlite3
from pathlib import Path

from api.main import app


@pytest.fixture
def test_db():
    """Create a temporary test database."""
    with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as tmp:
        test_db_path = tmp.name
    
    # Set environment variable for test database
    os.environ['SUITE_DATA_DIR'] = str(Path(test_db_path).parent)
    os.environ['SUITE_API_KEY'] = 'test-api-key'
    
    # Initialize test database
    conn = sqlite3.connect(test_db_path)
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS devices(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ip TEXT,
          mac TEXT,
          hostname TEXT,
          last_seen TEXT
        );
        CREATE TABLE IF NOT EXISTS dns_logs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT,
          client TEXT,
          query TEXT,
          action TEXT
        );
        CREATE TABLE IF NOT EXISTS ip_leases(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ip TEXT,
          mac TEXT,
          hostname TEXT,
          lease_start TEXT,
          lease_end TEXT
        );
    """)
    conn.commit()
    conn.close()
    
    yield test_db_path
    
    # Cleanup
    Path(test_db_path).unlink(missing_ok=True)


@pytest.fixture
def client(test_db):
    """Create test client with temporary database."""
    return TestClient(app)


def test_health_endpoint(client):
    """Test the health endpoint."""
    response = client.get("/health", headers={"X-API-Key": "test-api-key"})
    assert response.status_code == 200
    assert response.json() == {"ok": True}


def test_health_endpoint_no_auth(client):
    """Test health endpoint without authentication."""
    response = client.get("/health")
    assert response.status_code == 422  # Unprocessable Entity due to missing required header


def test_dns_logs_endpoint(client):
    """Test DNS logs endpoint."""
    response = client.get("/dns", headers={"X-API-Key": "test-api-key"})
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_devices_endpoint(client):
    """Test devices endpoint."""
    response = client.get("/devices", headers={"X-API-Key": "test-api-key"})
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_leases_endpoint(client):
    """Test IP leases endpoint."""
    response = client.get("/leases", headers={"X-API-Key": "test-api-key"})
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_root_status():
    """Test basic application status."""
    # This is a placeholder test for basic functionality
    assert True  # Replace with actual status checks


# Example of how to test with the new Pydantic schemas
def test_device_request_validation():
    """Test DeviceRequest model validation."""
    from api.schemas import DeviceRequest
    
    # Valid request
    valid_data = {
        "ip_address": "192.168.1.100",
        "status": True,
        "hostname": "test-device",
        "mac_address": "aa:bb:cc:dd:ee:ff"
    }
    device_req = DeviceRequest(**valid_data)
    assert device_req.ip_address == "192.168.1.100"
    assert device_req.status is True
    
    # Invalid IP address
    with pytest.raises(ValueError):
        DeviceRequest(ip_address="invalid-ip", status=True)
    
    # Invalid MAC address
    with pytest.raises(ValueError):
        DeviceRequest(ip_address="192.168.1.100", status=True, mac_address="invalid-mac")