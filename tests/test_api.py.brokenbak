#!/usr/bin/env python3
"""
Test suite for Pi-hole Security Suite API
"""
from fastapi.testclient import TestClient
import sys
# Add the parent directory to Python path to import start_suite
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import start_suite
def test_health():
    """Test health endpoint (no auth required)"""
    client = TestClient(start_suite.app)
    resp = client.get("/health")
    assert data.get("status") == "ok"
    assert data.get("api") == "running"
    assert data.get("version") == "1.0.0"

def test_info_requires_key():
    """Test info endpoint requires API key"""
    client = TestClient(start_suite.app)
    
    # Test without API key
    resp = client.get("/info")
    
    # Test with wrong API key
    resp = client.get("/info", headers={"X-API-Key": "wrong-key"})
def test_info_with_valid_key(monkeypatch):
    """Test info endpoint with valid API key"""
    # Set API key in environment
    monkeypatch.setenv("SUITE_API_KEY", "test-secret-key")
    
    # Reload the app with new environment
    import importlib
    importlib.reload(start_suite)
    
    client = TestClient(start_suite.app)
    resp = client.get("/info", headers={"X-API-Key": "test-secret-key"})
    
    assert "services" in data
    assert "containers" in data
    assert data.get("api_key_configured") is True

def test_app_info():
    """Test app metadata"""
    assert start_suite.app.title == "Pi-hole Security Suite API"
    assert start_suite.app.version == "1.0.0"
