"""SQLite helpers for the Pi-hole suite."""
import sqlite3
from pathlib import Path

from .shared_config import DB_PATH

SCHEMA = """
CREATE TABLE IF NOT EXISTS dns_logs(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT,
  client TEXT,
  query TEXT,
  action TEXT
);
CREATE INDEX IF NOT EXISTS idx_dns_timestamp ON dns_logs(timestamp);

CREATE TABLE IF NOT EXISTS ip_leases(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ip TEXT,
  mac TEXT,
  hostname TEXT,
  lease_start TEXT,
  lease_end TEXT
);

CREATE TABLE IF NOT EXISTS devices(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ip TEXT,
  mac TEXT,
  hostname TEXT,
  last_seen TEXT
);
CREATE INDEX IF NOT EXISTS idx_devices_ip ON devices(ip);
"""


def init_db() -> sqlite3.Connection:
    Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.executescript(SCHEMA)
    conn.commit()
    return conn
