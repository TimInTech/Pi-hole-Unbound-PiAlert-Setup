#!/usr/bin/env python3
"""Simple dependency checker for the suite."""
import importlib.util
import sys

REQUIRED = [
    "netifaces",
    "psutil",
    "ipaddress",
    "sqlite3",
    "fastapi",
    "scapy",
    "requests",
    "uvicorn",
    "colorlog",
    "rich",
]

def main():
    missing = []
    for mod in REQUIRED:
        if importlib.util.find_spec(mod) is None:
            missing.append(mod)
    if missing:
        print("Missing dependencies:\n - " + "\n - ".join(missing))
        sys.exit(1)
    print("All dependencies satisfied")

if __name__ == "__main__":
    main()
