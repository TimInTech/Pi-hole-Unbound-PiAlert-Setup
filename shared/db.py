"""SQLite database initialization and helpers."""

import logging
import sqlite3

from .shared_config import DB_PATH

logger = logging.getLogger(__name__)

# Database schema
SCHEMA = """
-- DNS query logs from Pi-hole
CREATE TABLE IF NOT EXISTS dns_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    client TEXT NOT NULL,
    query TEXT NOT NULL,
    action TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_dns_timestamp ON dns_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_dns_client ON dns_logs(client);
CREATE INDEX IF NOT EXISTS idx_dns_query ON dns_logs(query);

-- DHCP lease information
CREATE TABLE IF NOT EXISTS ip_leases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip TEXT NOT NULL,
    mac TEXT NOT NULL,
    hostname TEXT,
    lease_start TEXT,
    lease_end TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ip, mac)
);
CREATE INDEX IF NOT EXISTS idx_leases_ip ON ip_leases(ip);
CREATE INDEX IF NOT EXISTS idx_leases_mac ON ip_leases(mac);

-- Network device information
CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip TEXT NOT NULL,
    mac TEXT NOT NULL,
    hostname TEXT,
    last_seen TEXT,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ip, mac)
);
CREATE INDEX IF NOT EXISTS idx_devices_ip ON devices(ip);
CREATE INDEX IF NOT EXISTS idx_devices_mac ON devices(mac);
CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices(last_seen);

-- System statistics (optional)
CREATE TABLE IF NOT EXISTS system_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_stats_timestamp ON system_stats(timestamp);
CREATE INDEX IF NOT EXISTS idx_stats_metric ON system_stats(metric_name);
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
    """Initialize the SQLite database with schema."""
    try:
        # Ensure parent directory exists
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        
        # Connect and setup
        conn = sqlite3.connect(str(DB_PATH), check_same_thread=False)
        conn.executescript(SCHEMA)
        conn.commit()
        
        logger.info(f"Database initialized at {DB_PATH}")
        return conn
        
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise


def get_connection() -> sqlite3.Connection:
    """Get a database connection with row factory."""
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn
    Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.executescript(SCHEMA)
    conn.commit()
    return conn
