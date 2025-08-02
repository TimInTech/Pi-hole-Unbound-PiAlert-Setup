import sqlite3
from .shared_config import DB_PATH

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """CREATE TABLE IF NOT EXISTS dns_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            client TEXT,
            query TEXT,
            action TEXT
        )"""
    )
    cur.execute(
        """CREATE TABLE IF NOT EXISTS ip_leases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ip TEXT UNIQUE,
            mac TEXT,
            hostname TEXT,
            lease_start TEXT,
            lease_end TEXT
        )"""
    )
    cur.execute(
        """CREATE TABLE IF NOT EXISTS devices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ip TEXT,
            mac TEXT,
            hostname TEXT,
            last_seen TEXT
        )"""
    )
    conn.commit()
    return conn
