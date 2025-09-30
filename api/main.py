"""FastAPI app exposing Pi-hole suite data."""
import os
import sqlite3
from contextlib import asynccontextmanager
from typing import AsyncGenerator, Generator, List

from fastapi import Depends, FastAPI, Header, HTTPException, Path
from shared import shared_config as config
from shared.db import init_db
from .schemas import DeviceRequest, DeviceResponse, DNSLogResponse, HealthResponse


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    init_db()
    yield


app = FastAPI(title="Pi-hole Suite API", lifespan=lifespan)


def _get_api_key() -> str:
    return os.getenv("SUITE_API_KEY", "")


def get_db() -> Generator[sqlite3.Connection, None, None]:
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def require_key(x_api_key: str = Header()) -> None:
    api_key = _get_api_key()
    if not api_key:
        raise HTTPException(status_code=500, detail="API key not configured")
    if x_api_key != api_key:
        raise HTTPException(status_code=401, detail="Invalid API key")





@app.get("/health", dependencies=[Depends(require_key)], response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(ok=True)


@app.get("/dns", dependencies=[Depends(require_key)], response_model=List[DNSLogResponse])
def get_dns_logs(limit: int = 50, db=Depends(get_db)) -> List[DNSLogResponse]:
    cur = db.execute(
        "SELECT timestamp, client, query, action FROM dns_logs ORDER BY id DESC LIMIT ?",
        (limit,),
    )
    return [DNSLogResponse(**dict(row)) for row in cur.fetchall()]


@app.get("/leases", dependencies=[Depends(require_key)])
def get_ip_leases(db=Depends(get_db)):
    cur = db.execute("SELECT ip, mac, hostname, lease_start, lease_end FROM ip_leases")
    return [dict(row) for row in cur.fetchall()]


@app.get("/devices", dependencies=[Depends(require_key)], response_model=List[DeviceResponse])
def get_devices(db=Depends(get_db)) -> List[DeviceResponse]:
    cur = db.execute("SELECT id, ip, mac, hostname, last_seen FROM devices")
    return [DeviceResponse(**dict(row)) for row in cur.fetchall()]


@app.get("/devices/{device_id}", dependencies=[Depends(require_key)], response_model=DeviceResponse)
def get_device(device_id: int = Path(..., description="Device ID"), db=Depends(get_db)) -> DeviceResponse:
    """Get a specific device by ID."""
    cur = db.execute(
        "SELECT id, ip, mac, hostname, last_seen FROM devices WHERE id = ?",
        (device_id,)
    )
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Device not found")
    return DeviceResponse(**dict(row))


@app.post("/devices", dependencies=[Depends(require_key)], response_model=DeviceResponse)
def create_device(device: DeviceRequest, db=Depends(get_db)) -> DeviceResponse:
    """Create or update a device."""
    # Check if device already exists by IP
    cur = db.execute("SELECT id FROM devices WHERE ip = ?", (device.ip_address,))
    existing = cur.fetchone()
    
    if existing:
        # Update existing device
        db.execute(
            "UPDATE devices SET mac = ?, hostname = ?, last_seen = datetime('now') WHERE ip = ?",
            (device.mac_address, device.hostname, device.ip_address)
        )
        device_id = existing[0]
    else:
        # Create new device
        cur = db.execute(
            "INSERT INTO devices (ip, mac, hostname, last_seen) VALUES (?, ?, ?, datetime('now'))",
            (device.ip_address, device.mac_address, device.hostname)
        )
        device_id = cur.lastrowid
    
    db.commit()
    
    # Return the created/updated device
    cur = db.execute(
        "SELECT id, ip, mac, hostname, last_seen FROM devices WHERE id = ?",
        (device_id,)
    )
    row = cur.fetchone()
    return DeviceResponse(**dict(row))
