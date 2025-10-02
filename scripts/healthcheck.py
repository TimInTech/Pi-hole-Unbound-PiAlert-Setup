#!/usr/bin/env python3
"""Health check script for Pi-hole suite."""

import os
import sqlite3
import sys

import requests


def check_database() -> bool:
    """Check database connectivity."""
    try:
        from shared.shared_config import DB_PATH
        if not DB_PATH.exists():
            print(f"❌ Database not found: {DB_PATH}")
            return False
        
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table'")
        table_count = cursor.fetchone()[0]
        conn.close()
        
        print(f"✅ Database OK ({table_count} tables)")
        return True
    except Exception as e:
        print(f"❌ Database error: {e}")
        return False


def check_api() -> bool:
    """Check API health endpoint."""
    try:
        api_key = os.getenv("SUITE_API_KEY")
        if not api_key:
            print("❌ SUITE_API_KEY not set")
            return False
        
        port = int(os.getenv("SUITE_PORT", "8090"))
        url = f"http://127.0.0.1:{port}/health"
        headers = {"X-API-Key": api_key}
        
        response = requests.get(url, headers=headers, timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ API OK: {data.get('message', 'Healthy')}")
            return True
        else:
            print(f"❌ API unhealthy: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("❌ API not reachable (not running?)")
        return False
    except Exception as e:
        print(f"❌ API check failed: {e}")
        return False


def check_pihole_log() -> bool:
    """Check Pi-hole log accessibility."""
    try:
        from shared.shared_config import PIHOLE_LOG_PATH
        if PIHOLE_LOG_PATH.exists():
            print(f"✅ Pi-hole log accessible: {PIHOLE_LOG_PATH}")
            return True
        else:
            print(f"⚠️  Pi-hole log not found: {PIHOLE_LOG_PATH}")
            return False
    except Exception as e:
        print(f"❌ Pi-hole log check failed: {e}")
        return False


def main():
    """Run all health checks."""
    print("🏥 Pi-hole Suite Health Check")
    print("=" * 40)
    
    checks = [
        ("Database", check_database),
        ("API", check_api), 
        ("Pi-hole Log", check_pihole_log),
    ]
    
    passed = 0
    for name, check_func in checks:
        print(f"\n🔍 Checking {name}...")
        if check_func():
            passed += 1
    
    print(f"\n📊 Results: {passed}/{len(checks)} checks passed")
    
    if passed == len(checks):
        print("🎉 All health checks passed!")
        return 0
    else:
        print("⚠️  Some health checks failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())