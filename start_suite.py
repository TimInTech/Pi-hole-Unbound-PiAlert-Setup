#!/usr/bin/env python3
import os
import re
import time
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException
import uvicorn

APP_VERSION = "1.0.0"
START_TIME = time.time()


def _env(name: str, default: str | None = None) -> str:
    value = os.getenv(name)
    if value is None or value == "":
        if default is None:
            raise RuntimeError(f"Missing required environment variable: {name}")
        return default
    return value


def require_api_key(x_api_key: str | None = Header(default=None, alias="X-API-Key")) -> None:
    expected = _env("SUITE_API_KEY", default="")
    if expected == "":
        raise HTTPException(status_code=500, detail="Server not configured: SUITE_API_KEY missing")
    if x_api_key != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")


app = FastAPI(title="Pi-hole Suite API", version=APP_VERSION)


def _read_lines(path: str, limit: int) -> list[str]:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        return lines[-limit:]
    except OSError:
        return []


def _parse_pihole_log(limit: int) -> list[dict[str, Any]]:
    # Best-effort parser for classic Pi-hole log format.
    # If file isn't present/accessible, returns empty list.
    candidates = [
        "/var/log/pihole/pihole.log",
        "/var/log/pihole.log",
    ]
    lines: list[str] = []
    for p in candidates:
        lines = _read_lines(p, limit * 3)
        if lines:
            break

    out: list[dict[str, Any]] = []
    # Example patterns differ by versions; keep it permissive.
    # Jan  1 12:00:00 dnsmasq[1234]: query[A] example.com from 192.168.1.2
    rx = re.compile(r"^(?P<ts>\w{3}\s+\d+\s+\d+:\d+:\d+).*(query\[[A-Z]+\])\s+(?P<q>[^\s]+)\s+from\s+(?P<client>[^\s]+)")

    for line in reversed(lines):
        m = rx.search(line)
        if not m:
            continue
        out.append(
            {
                "timestamp": m.group("ts"),
                "client": m.group("client"),
                "query": m.group("q"),
                "action": "query",
            }
        )
        if len(out) >= limit:
            break

    return list(reversed(out))


def _parse_dhcp_leases(limit: int) -> list[dict[str, Any]]:
    # Pi-hole DHCP leases file: /etc/pihole/dhcp.leases
    # Format: <expiry_epoch> <mac> <ip> <hostname> <clientid>
    # We only have expiry; lease_start may be unknown.
    import datetime

    path = "/etc/pihole/dhcp.leases"
    lines = _read_lines(path, limit * 3)
    out: list[dict[str, Any]] = []

    def to_iso(epoch: str) -> str | None:
        try:
            ts = int(epoch)
        except ValueError:
            return None
        return datetime.datetime.fromtimestamp(ts, tz=datetime.timezone.utc).isoformat()

    for line in reversed(lines):
        parts = line.strip().split()
        if len(parts) < 4:
            continue
        expiry, mac, ip, hostname = parts[0:4]
        out.append(
            {
                "ip": ip,
                "mac": mac,
                "hostname": hostname,
                "lease_start": None,
                "lease_end": to_iso(expiry) or expiry,
            }
        )
        if len(out) >= limit:
            break

    return list(reversed(out))


@app.get("/health", dependencies=[Depends(require_api_key)])
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "message": "Pi-hole Suite API is running",
        "version": APP_VERSION,
        "uptime_seconds": int(time.time() - START_TIME),
    }


@app.get("/dns", dependencies=[Depends(require_api_key)])
def dns(limit: int = 50) -> list[dict[str, Any]]:
    limit = max(1, min(limit, 500))
    return _parse_pihole_log(limit)


@app.get("/devices", dependencies=[Depends(require_api_key)])
def devices() -> list[dict[str, Any]]:
    # Placeholder: device discovery depends on NetAlertX/Pi.Alert APIs and is
    # environment-specific.
    return []


@app.get("/leases", dependencies=[Depends(require_api_key)])
def leases(limit: int = 200) -> list[dict[str, Any]]:
    limit = max(1, min(limit, 2000))
    return _parse_dhcp_leases(limit)


@app.get("/stats", dependencies=[Depends(require_api_key)])
def stats() -> dict[str, Any]:
    recent = _parse_pihole_log(100)
    return {
        "total_dns_logs": len(recent),
        "total_devices": 0,
        "recent_queries": len(recent),
        "note": "DNS stats are derived from best-effort log parsing; may be empty depending on Pi-hole logging/permissions.",
    }


def main() -> None:
    port = int(_env("SUITE_PORT", default="8090"))
    host = _env("SUITE_HOST", default="127.0.0.1")
    uvicorn.run(app, host=host, port=port, log_level=os.getenv("SUITE_LOG_LEVEL", "info").lower())


if __name__ == "__main__":
    main()
