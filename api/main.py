from fastapi import FastAPI, Depends, HTTPException, Header
from fastapi.responses import JSONResponse
import os
import sqlite3
from shared import shared_config as config

app = FastAPI(title="Pi-hole Suite API")

API_KEY = None

@app.on_event("startup")
def startup_event():
    global API_KEY
    API_KEY = os.getenv("SUITE_API_KEY")


def get_db():
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def require_key(x_api_key: str = Header(default="")):
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")


@app.get("/dns", dependencies=[Depends(require_key)])
def get_dns_logs(limit: int = 50, db=Depends(get_db)):
    cur = db.execute("SELECT timestamp, client, query, action FROM dns_logs ORDER BY id DESC LIMIT ?", (limit,))
    return [dict(row) for row in cur.fetchall()]


@app.get("/leases", dependencies=[Depends(require_key)])
def get_ip_leases(db=Depends(get_db)):
    cur = db.execute("SELECT ip, mac, hostname, lease_start, lease_end FROM ip_leases")
    return [dict(row) for row in cur.fetchall()]


@app.get("/devices", dependencies=[Depends(require_key)])
def get_devices(db=Depends(get_db)):
    cur = db.execute("SELECT ip, mac, hostname, last_seen FROM devices")
    return [dict(row) for row in cur.fetchall()]
