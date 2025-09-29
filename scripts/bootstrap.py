#!/usr/bin/env python3
"""Dependency checker. Updated for 2025 libs."""
import importlib.util
import sys

REQUIRED = [
    "fastapi",
    "uvicorn",
    "pydantic",
    "sqlite3",  # Built-in
    "ipaddress",  # Built-in
    "asyncio",  # Built-in
]

def main():
    missing = [mod for mod in REQUIRED if importlib.util.find_spec(mod) is None]
    if missing:
        print("Missing: " + ", ".join(missing))
        print("Run: pip install -r requirements.txt")
        sys.exit(1)
    print("Dependencies OK")

if __name__ == "__main__":
    main()
