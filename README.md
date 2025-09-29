# Pi-hole + Unbound + NetAlertX — Setup & Minimal Python Suite

> 🌐 **Languages:** English (this file) • 🇩🇪 [Deutsch](README.de.md)  
> 🧰 **Stack icons:**  
> <img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="stack icons" />

This repository contains a concise setup helper for **Pi-hole**, **Unbound**, and **NetAlertX**, plus a **minimal Python suite** (FastAPI + SQLite) for simple DNS/device logging and health checks.  
It is **not** a full-blown installer; it documents the code that exists here and how to run it locally if you want the small API.

---

## What’s in this repo

- **Minimal API (FastAPI)** exposing:
  - `GET /health` (ok check)
  - `GET /dns?limit=N` (recent DNS log rows)
  - `GET /leases` (IP leases table)
  - `GET /devices` (devices table)
- **SQLite schema & init** (`shared/db.py`) with indexes
- **Lightweight workers (placeholders):**
  - `pyhole/dns_monitor.py` — tails Pi-hole log and inserts into `dns_logs` (best effort parser, optional)
  - `pyalloc/*` — simple IP allocation skeleton (no DHCP hook wired yet)
- **Helper scripts**
  - `scripts/bootstrap.py` — dependency sanity check
  - `scripts/healthcheck.py` — DB connectivity check
  - (optional) `scripts/ci.sh` — quick smoke test of imports + `/health`

---

## Repository layout

```

.
├─ api/
│  └─ main.py              # FastAPI app (API v2); DB init on startup
├─ shared/
│  ├─ db.py                # SQLite schema + init
│  └─ shared_config.py     # ENV & defaults (DB path, log level, etc.)
├─ pyhole/
│  └─ dns_monitor.py       # optional: tail /var/log/pihole.log -> dns_logs
├─ pyalloc/
│  ├─ allocator.py         # simple IP pool class
│  └─ main.py              # skeleton worker
├─ scripts/
│  ├─ bootstrap.py         # checks libs
│  ├─ healthcheck.py       # DB check
│  └─ ci.sh                # local smoke test (optional)
├─ start_suite.py          # start workers + uvicorn (optional)
├─ requirements.txt
├─ README.md               # (EN)
└─ README.de.md            # (DE)

````

---

## Requirements

- **Python**: 3.12+ recommended (3.13 works too)
- **OS**: Linux (Debian/Ubuntu/Raspberry Pi OS tested by users)
- **Packages (Python)**:
  - `fastapi==0.115.0`
  - `uvicorn==0.30.6`
  - `pydantic==2.9.2`

Install Python deps:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
````

---

## Configuration

Environment variables read by `shared/shared_config.py`:

| Variable          | Default | Description                             |
| ----------------- | ------- | --------------------------------------- |
| `SUITE_API_KEY`   | (unset) | If set, API requires header `X-API-Key` |
| `SUITE_DATA_DIR`  | `data/` | Directory to store the SQLite DB        |
| `SUITE_INTERFACE` | `eth0`  | Informational (not strictly required)   |
| `SUITE_DNS_PORT`  | `5335`  | Informational (for Unbound setups)      |
| `SUITE_LOG_LEVEL` | `INFO`  | Logging level                           |

The SQLite DB is created at: **`$SUITE_DATA_DIR/shared.sqlite`** (defaults to `data/shared.sqlite`).

---

## Quick start (local)

**1) Bootstrap & DB health:**

```bash
source .venv/bin/activate
python scripts/bootstrap.py
python scripts/healthcheck.py
```

**2a) Run just the API via uvicorn (no background workers):**

```bash
export SUITE_API_KEY="testkey"   # optional but recommended
uvicorn api.main:app --host 127.0.0.1 --port 8090 --log-level info
```

**2b) Or start the whole suite (API + threads) — optional:**

```bash
export SUITE_API_KEY="testkey"   # optional
python start_suite.py
```

**3) Smoke test (new terminal):**

```bash
curl -s http://127.0.0.1:8090/health | python -m json.tool
```

If you set `SUITE_API_KEY`, include it:

```bash
curl -s -H "X-API-Key: testkey" http://127.0.0.1:8090/health | python -m json.tool
```

---

## API (short reference)

> Base URL (default): `http://127.0.0.1:8090`
> Auth (optional): send header `X-API-Key: <value>` if `SUITE_API_KEY` is set.

| Method | Path       | Query         | Headers              | Response (example)                                                                      |
| -----: | ---------- | ------------- | -------------------- | --------------------------------------------------------------------------------------- |
|    GET | `/health`  | —             | optional `X-API-Key` | `{"ok": true}`                                                                          |
|    GET | `/dns`     | `limit` (int) | optional `X-API-Key` | `[{"timestamp":"...", "client":"...", "query":"...", "action":"..."}]`                  |
|    GET | `/leases`  | —             | optional `X-API-Key` | `[{"ip":"...", "mac":"...", "hostname":"...", "lease_start":"...", "lease_end":"..."}]` |
|    GET | `/devices` | —             | optional `X-API-Key` | `[{"ip":"...", "mac":"...", "hostname":"...", "last_seen":"..."}]`                      |

Example:

```bash
curl -s -H "X-API-Key: testkey" "http://127.0.0.1:8090/dns?limit=5" | python -m json.tool
```

---

## Database

**Schema highlights** (`shared/db.py`):

* `dns_logs(id, timestamp, client, query, action)` + index on `timestamp`
* `ip_leases(id, ip UNIQUE, mac, hostname, lease_start, lease_end)`
* `devices(id, ip, mac, hostname, last_seen)` + index on `ip`

The API initializes the schema at startup (`api/main.py` uses `init_db()`).

---

## Optional workers

* **DNS monitor** (`pyhole/dns_monitor.py`):
  Tails `/var/log/pihole.log` and inserts parsed lines into `dns_logs`.
  Parsing is intentionally simple; adapt for your environment if needed.

* **Allocator** (`pyalloc/*`):
  Placeholder for IP allocation workflow; no DHCP integration yet.

---

## Troubleshooting

| Symptom                                   | Likely cause / fix                                                                                |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `sqlite3.OperationalError: no such table` | Ensure API started once (auto-init), or run `from shared.db import init_db; init_db()` in Python. |
| `401 Invalid API key`                     | Set correct `X-API-Key` header to match `SUITE_API_KEY`.                                          |
| Empty `/dns` results                      | Seed rows or run DNS monitor and ensure Pi-hole log path is correct.                              |
| `curl` to `/health` fails                 | Check port/bind or process; review `uvicorn` logs.                                                |

---

## Systemd (optional)

If you really want a service, create a unit with your **actual user and path**:

```ini
[Unit]
Description=Pi-hole Suite (API + workers)
After=network.target

[Service]
WorkingDirectory=/home/<USER>/github_repos/Pi-hole-Unbound-PiAlert-Setup
Environment=SUITE_API_KEY=testkey
ExecStart=/home/<USER>/github_repos/Pi-hole-Unbound-PiAlert-Setup/.venv/bin/python start_suite.py
Restart=always
User=<USER>

[Install]
WantedBy=multi-user.target
```

---

## Changelog & License

* See **[CHANGELOG.md](CHANGELOG.md)** for updates.
* Licensed under **MIT** (see **[LICENSE](LICENSE)**).
