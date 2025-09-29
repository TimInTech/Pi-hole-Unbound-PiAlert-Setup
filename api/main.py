"""FastAPI app exposing Pi-hole suite data."""
import os
import sqlite3
from typing import Generator

from fastapi import Depends, FastAPI, Header, HTTPException
from shared import shared_config as config
from shared.db import init_db

app = FastAPI(title="Pi-hole Suite API")


def _get_api_key() -> str:
    return os.getenv("SUITE_API_KEY", "")


def get_db() -> Generator[sqlite3.Connection, None, None]:
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def require_key(x_api_key: str = Header(default="")) -> None:
    api_key = _get_api_key()
    if api_key and x_api_key != api_key:
        raise HTTPException(status_code=401, detail="Invalid API key")


@app.on_event("startup")
def _ensure_db() -> None:
    init_db()


@app.get("/health", dependencies=[Depends(require_key)])
def health() -> dict:
    return {"ok": True}


@app.get("/dns", dependencies=[Depends(require_key)])
def get_dns_logs(limit: int = 50, db=Depends(get_db)):
    cur = db.execute(
        "SELECT timestamp, client, query, action FROM dns_logs ORDER BY id DESC LIMIT ?",
        (limit,),
    )
    return [dict(row) for row in cur.fetchall()]


@app.get("/leases", dependencies=[Depends(require_key)])
def get_ip_leases(db=Depends(get_db)):
    cur = db.execute("SELECT ip, mac, hostname, lease_start, lease_end FROM ip_leases")
    return [dict(row) for row in cur.fetchall()]


@app.get("/devices", dependencies=[Depends(require_key)])
def get_devices(db=Depends(get_db)):
    cur = db.execute("SELECT ip, mac, hostname, last_seen FROM devices")
    return [dict(row) for row in cur.fetchall()]
