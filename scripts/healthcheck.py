#!/usr/bin/env python3
"""Basic healthcheck script."""
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from shared import shared_config as config

try:
    sqlite3.connect(config.DB_PATH).close()
    print("Database reachable")
except Exception as exc:
    print(f"Healthcheck failed: {exc}")
    raise SystemExit(1)
