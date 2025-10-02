#!/usr/bin/env python3
"""Bootstrap script to check dependencies and initialize the suite."""

import importlib.util
import sys
from pathlib import Path


def check_dependency(module_name: str) -> bool:
    """Check if a module is available."""
    spec = importlib.util.find_spec(module_name)
    return spec is not None


def main():
    """Check all required dependencies."""
    print("🔍 Checking Pi-hole Suite dependencies...")
    
    required_modules = [
        "fastapi",
        "uvicorn",
        "pydantic", 
        "sqlite3",  # Built-in
    ]
    
    missing = []
    for module in required_modules:
        if check_dependency(module):
            print(f"✓ {module}")
        else:
            print(f"✗ {module}")
            missing.append(module)
    
    if missing:
        print(f"\n❌ Missing dependencies: {', '.join(missing)}")
        print("📥 Install with: pip install -r requirements.txt")
        return 1
    
    # Check if we can import our modules
    try:
        from shared.db import init_db
        from api.main import app
        print("✓ Internal modules")
    except ImportError as e:
        print(f"✗ Internal module import failed: {e}")
        return 1
    
    # Initialize database
    try:
        init_db()
        print("✓ Database initialization")
    except Exception as e:
        print(f"✗ Database initialization failed: {e}")
        return 1
    
    print("\n🎉 All dependencies satisfied!")
    print("🚀 Ready to run: python start_suite.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())