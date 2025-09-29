#!/usr/bin/env python3
"""Healthcheck."""
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from shared import shared_config as config

try:
    with sqlite3.connect(config.DB_PATH) as conn:
        conn.execute("SELECT 1")
    print("Database healthy")
except Exception as e:
    print(f"Failed: {e}")
    sys.exit(1)
