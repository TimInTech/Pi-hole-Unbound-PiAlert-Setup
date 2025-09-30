#!/usr/bin/env python3
"""Verify database connectivity."""
import sqlite3
import sys
from pathlib import Path

from shared import shared_config as config

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))


def main() -> None:
    try:
        with sqlite3.connect(config.DB_PATH) as conn:
            conn.execute("SELECT 1")
        print("Database healthy")
    except Exception as exc:  # noqa: BLE001 - we want to show any failure
        print(f"Failed: {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
