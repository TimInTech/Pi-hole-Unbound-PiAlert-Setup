import sqlite3
from .shared_config import DB_PATH

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    # Enhanced schema with indexes for performance
    cur.execute(
        """CREATE TABLE IF NOT EXISTS dns_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            client TEXT,
            query TEXT,
            action TEXT
        )"""
    )
    cur.execute("CREATE INDEX IF NOT EXISTS idx_dns_timestamp ON dns_logs(timestamp)")
    
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
    cur.execute("CREATE INDEX IF NOT EXISTS idx_devices_ip ON devices(ip)")
    
    conn.commit()
    return conn
