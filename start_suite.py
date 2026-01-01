#!/usr/bin/env python3
import os
import re
import subprocess
import time
from typing import Any
from urllib.request import Request, urlopen

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


def _run(cmd: list[str], timeout: float = 2.0) -> dict[str, Any]:
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False)
        return {
            "ok": True,
            "cmd": cmd,
            "returncode": p.returncode,
            "stdout": p.stdout.strip(),
            "stderr": p.stderr.strip(),
        }
    except (OSError, subprocess.TimeoutExpired) as e:
        return {"ok": False, "cmd": cmd, "error": str(e)}


def _guess_host_ip() -> str:
    # Best-effort: pick first host IP; used for URL display.
    # Never blocks for long.
    r = _run(["hostname", "-I"], timeout=1.0)
    if r.get("ok") and r.get("stdout"):
        first = r["stdout"].split()[0]
        if first:
            return first

    r = _run(["ip", "-4", "route", "get", "1.1.1.1"], timeout=1.0)
    if r.get("ok") and r.get("stdout"):
        m = re.search(r"src\s+(\d+\.\d+\.\d+\.\d+)", r["stdout"])
        if m:
            return m.group(1)

    return "127.0.0.1"


def _http_ok(url: str, timeout: float = 1.5) -> bool:
    try:
        req = Request(url, method="GET")
        with urlopen(req, timeout=timeout) as resp:
            return 200 <= resp.status < 500
    except Exception:
        return False


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
    rx = re.compile(
        r"^(?P<ts>\w{3}\s+\d+\s+\d+:\d+:\d+).*(query\[[A-Z]+\])\s+(?P<q>[^\s]+)\s+from\s+(?P<client>[^\s]+)"
    )

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


def _read_pihole_v6_upstreams() -> list[str]:
    toml = "/etc/pihole/pihole.toml"
    try:
        with open(toml, "r", encoding="utf-8", errors="replace") as f:
            t = f.read()
    except OSError:
        return []

    # Very small parser: look for upstreams = ["127.0.0.1#5335", ...]
    m = re.search(r"^upstreams\s*=\s*\[(.*?)\]", t, flags=re.M)
    if not m:
        return []

    inner = m.group(1)
    return [s.strip().strip('"') for s in inner.split(",") if s.strip()]


@app.get("/health", dependencies=[Depends(require_api_key)])
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "message": "Pi-hole Suite API is running",
        "version": APP_VERSION,
        "uptime_seconds": int(time.time() - START_TIME),
    }


@app.get("/version", dependencies=[Depends(require_api_key)])
def version() -> dict[str, Any]:
    return {
        "app": "pihole-suite",
        "version": APP_VERSION,
        "uptime_seconds": int(time.time() - START_TIME),
    }


@app.get("/urls", dependencies=[Depends(require_api_key)])
def urls() -> dict[str, Any]:
    host_ip = _guess_host_ip()
    suite_port = int(_env("SUITE_PORT", default="8090"))
    netalertx_port = int(_env("NETALERTX_PORT", default="20211"))

    return {
        "host_ip": host_ip,
        "pihole_admin": f"http://{host_ip}/admin",
        "netalertx": f"http://{host_ip}:{netalertx_port}",
        "suite_local": f"http://127.0.0.1:{suite_port}",
        "note": "Suite binds to 127.0.0.1 by default; access remotely via a reverse proxy if needed.",
    }


@app.get("/pihole", dependencies=[Depends(require_api_key)])
def pihole() -> dict[str, Any]:
    v = _run(["pihole", "-v"], timeout=2.0)
    ftl = _run(["systemctl", "is-active", "pihole-FTL"], timeout=2.0)
    upstreams = _read_pihole_v6_upstreams()

    return {
        "pihole_version": v.get("stdout", "") if v.get("ok") else "unknown",
        "ftl_active": (ftl.get("ok") and ftl.get("returncode") == 0),
        "upstreams": upstreams,
    }


@app.get("/unbound", dependencies=[Depends(require_api_key)])
def unbound() -> dict[str, Any]:
    unbound_port = int(_env("UNBOUND_PORT", default="5335"))
    svc = _run(["systemctl", "is-active", "unbound"], timeout=2.0)
    dig = _run(
        [
            "dig",
            "+short",
            f"@127.0.0.1",
            "-p",
            str(unbound_port),
            "+time=1",
            "+tries=1",
            "cloudflare.com",
        ],
        timeout=2.0,
    )

    ok = bool(dig.get("ok") and dig.get("stdout"))

    return {
        "port": unbound_port,
        "service_active": (svc.get("ok") and svc.get("returncode") == 0),
        "dig_ok": ok,
        "dig_result": dig.get("stdout", ""),
    }


@app.get("/netalertx", dependencies=[Depends(require_api_key)])
def netalertx() -> dict[str, Any]:
    port = int(_env("NETALERTX_PORT", default="20211"))
    url = f"http://127.0.0.1:{port}/"
    reachable = _http_ok(url)

    return {
        "port": port,
        "url_local": url,
        "http_reachable": reachable,
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
