"""FastAPI app for Pi-hole suite monitoring and management."""

import os
import sqlite3
from contextlib import asynccontextmanager
from typing import AsyncGenerator, Generator, List, Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from shared import shared_config as config
from shared.db import init_db
from .schemas import (
    DeviceResponse,
    DNSLogResponse, 
    HealthResponse,
    LeaseResponse,
    StatsResponse
)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Initialize database on startup."""
    init_db()
    yield


# FastAPI app with modern configuration
app = FastAPI(
    title="Pi-hole Suite API",
    description="Monitoring and management API for Pi-hole + Unbound + NetAlertX stack",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)


def get_api_key() -> str:
    """Get configured API key."""
    return os.getenv("SUITE_API_KEY", "")


def get_db() -> Generator[sqlite3.Connection, None, None]:
    """Database dependency."""
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def require_api_key(x_api_key: Optional[str] = Header(None)) -> None:
    """Require valid API key for authentication."""
    api_key = get_api_key()
    if not api_key:
        raise HTTPException(
            status_code=500, 
            detail="API key not configured on server"
        )
    if not x_api_key:
        raise HTTPException(
            status_code=401, 
            detail="Missing API key header"
        )
    if x_api_key != api_key:
        raise HTTPException(
            status_code=401, 
            detail="Invalid API key"
        )


@app.get("/", include_in_schema=False)
async def root():
    """Root endpoint redirect."""
    return {"message": "Pi-hole Suite API", "docs": "/docs"}


@app.get(
    "/health", 
    dependencies=[Depends(require_api_key)], 
    response_model=HealthResponse,
    summary="Health Check",
    description="Simple health check endpoint to verify API is running"
)
def health() -> HealthResponse:
    """Health check endpoint."""
    return HealthResponse(
        ok=True,
        message="Pi-hole Suite API is running",
        version="1.0.0"
    )


@app.get(
    "/dns", 
    dependencies=[Depends(require_api_key)], 
    response_model=List[DNSLogResponse],
    summary="DNS Query Logs",
    description="Get recent DNS query logs from Pi-hole"
)
def get_dns_logs(
    limit: int = Query(50, ge=1, le=1000, description="Maximum number of logs to return"),
    db: sqlite3.Connection = Depends(get_db)
) -> List[DNSLogResponse]:
    """Get recent DNS query logs."""
    cursor = db.execute(
        "SELECT timestamp, client, query, action FROM dns_logs ORDER BY id DESC LIMIT ?",
        (limit,)
    )
    return [DNSLogResponse(**dict(row)) for row in cursor.fetchall()]


@app.get(
    "/leases", 
    dependencies=[Depends(require_api_key)],
    response_model=List[LeaseResponse],
    summary="DHCP Leases", 
    description="Get current DHCP lease information"
)
def get_ip_leases(db: sqlite3.Connection = Depends(get_db)) -> List[LeaseResponse]:
    """Get IP lease information."""
    cursor = db.execute(
        "SELECT ip, mac, hostname, lease_start, lease_end FROM ip_leases ORDER BY lease_start DESC"
    )
    return [LeaseResponse(**dict(row)) for row in cursor.fetchall()]


@app.get(
    "/devices", 
    dependencies=[Depends(require_api_key)], 
    response_model=List[DeviceResponse],
    summary="Network Devices",
    description="Get list of known network devices"
)
def get_devices(db: sqlite3.Connection = Depends(get_db)) -> List[DeviceResponse]:
    """Get network devices list."""
    cursor = db.execute(
        "SELECT id, ip, mac, hostname, last_seen FROM devices ORDER BY last_seen DESC"
    )
    return [DeviceResponse(**dict(row)) for row in cursor.fetchall()]


@app.get(
    "/stats",
    dependencies=[Depends(require_api_key)],
    response_model=StatsResponse,
    summary="System Statistics",
    description="Get basic statistics about the monitored system"
)
def get_stats(db: sqlite3.Connection = Depends(get_db)) -> StatsResponse:
    """Get system statistics."""
    # Get DNS log count
    dns_cursor = db.execute("SELECT COUNT(*) as count FROM dns_logs")
    dns_count = dns_cursor.fetchone()["count"]
    
    # Get device count
    device_cursor = db.execute("SELECT COUNT(*) as count FROM devices")
    device_count = device_cursor.fetchone()["count"]
    
    # Get recent queries (last hour)
    recent_cursor = db.execute(
        "SELECT COUNT(*) as count FROM dns_logs WHERE timestamp > datetime('now', '-1 hour')"
    )
    recent_queries = recent_cursor.fetchone()["count"]
    
    return StatsResponse(
        total_dns_logs=dns_count,
        total_devices=device_count,
        recent_queries=recent_queries
    )