# Pi-hole + Unbound + NetAlertX — Setup & Minimal Python Suite

> 🌐 Languages: English (this file) • 🇩🇪 [Deutsch](README.de.md)  
> 🧰 Stack icons:  
> <img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="stack icons" />

This repository provides a concise helper to set up **Pi-hole v6.x** with **Unbound** (local, validating resolver) and notes for **NetAlertX**. It also includes a **minimal Python suite** (FastAPI + SQLite) for DNS/device logging and health checks.  
It is not a full installer; it documents the small API here and how to run it locally.

---

## What’s inside

- Minimal API (FastAPI): `/health`, `/dns?limit=N`, `/leases`, `/devices`
- SQLite schema & init (`shared/db.py`) with indexes
- Lightweight workers (optional/placeholders): `pyhole/dns_monitor.py`, `pyalloc/*`
- Helper scripts: `scripts/bootstrap.py`, `scripts/healthcheck.py`

---

## Repository layout

~~~text
.
├─ api/
│  └─ main.py              # FastAPI app; DB init on startup
├─ shared/
│  ├─ db.py                # SQLite schema + init
│  └─ shared_config.py     # ENV & defaults (DB path, log level, etc.)
├─ pyhole/
│  └─ dns_monitor.py       # optional: tail Pi-hole log -> dns_logs
├─ pyalloc/
│  ├─ allocator.py         # simple IP pool class
│  └─ main.py              # skeleton worker
├─ scripts/
│  ├─ bootstrap.py         # checks libs
│  └─ healthcheck.py       # DB check
├─ start_suite.py          # start workers + uvicorn (optional)
├─ requirements.txt
├─ README.md               # EN
└─ README.de.md            # DE
~~~

---

## Quick start: Mini Suite (API)

~~~bash
cd ~/github_repos/Pi-hole-Unbound-PiAlert-Setup
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
python3 scripts/bootstrap.py
export SUITE_API_KEY="testkey"   # optional but recommended
python3 start_suite.py
~~~

Smoke test:

~~~bash
curl -s -H "X-API-Key: testkey" http://127.0.0.1:8090/health | python -m json.tool
~~~

---

## Pi-hole + Unbound on Debian/Ubuntu (copy/paste)

Assumes Pi-hole v6.x is already installed. Commands use sudo.

### 1) Install Unbound & get root hints

~~~bash
sudo apt-get update
sudo apt-get install -y unbound ca-certificates curl
sudo install -d -m 0755 /var/lib/unbound
sudo curl -fsSL https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints
~~~

### 2) Minimal Unbound config (listens on loopback:5335)

~~~bash
sudo tee /etc/unbound/unbound.conf.d/pi-hole.conf >/dev/null <<'CONF'
server:
  verbosity: 0
  interface: 127.0.0.1
  port: 5335
  do-ip4: yes
  do-ip6: no
  do-udp: yes
  do-tcp: yes
  edns-buffer-size: 1232
  prefetch: yes
  qname-minimisation: yes
  harden-glue: yes
  harden-dnssec-stripped: yes
  hide-identity: yes
  hide-version: yes
  trust-anchor-file: /var/lib/unbound/root.key
  root-hints: /var/lib/unbound/root.hints
  cache-min-ttl: 60
  cache-max-ttl: 86400

forward-zone:
  name: "."
  forward-first: no
  forward-addr: 9.9.9.9#dns.quad9.net
  forward-addr: 149.112.112.112#dns.quad9.net
CONF
~~~

Initialize trust anchor & restart:

~~~bash
sudo unbound-anchor -a /var/lib/unbound/root.key || true
sudo systemctl enable --now unbound
sudo systemctl restart unbound
sudo systemctl status --no-pager unbound
~~~

Quick check:

~~~bash
dig +short @127.0.0.1 -p 5335 example.com
~~~

### 3) Point Pi-hole to Unbound

Pi-hole Admin → Settings → DNS → Custom upstream: 127.0.0.1#5335  
Disable any other upstreams, save, then:

~~~bash
pihole restartdns
~~~

---

## API (short reference)

Base: http://127.0.0.1:8090 • Auth header (optional if SUITE_API_KEY set): X-API-Key: <value>

| Method | Path       | Query         | Example result                                                                          |
| -----: | ---------- | ------------- | --------------------------------------------------------------------------------------- |
|    GET | /health    | —             | {"ok": true}                                                                            |
|    GET | /dns       | limit (int)   | [{"timestamp":"...", "client":"...", "query":"...", "action":"..."}]                   |
|    GET | /leases    | —             | [{"ip":"...", "mac":"...", "hostname":"...", "lease_start":"...", "lease_end":"..."}]  |
|    GET | /devices   | —             | [{"ip":"...", "mac":"...", "hostname":"...", "last_seen":"..."}]                        |

---

## Configuration (ENV)

| Variable          | Default | Description                            |
| ----------------- | ------- | -------------------------------------- |
| SUITE_API_KEY     | (unset) | If set, header X-API-Key is required   |
| SUITE_DATA_DIR    | data/   | Directory for the SQLite DB            |
| SUITE_INTERFACE   | eth0    | Informational                          |
| SUITE_DNS_PORT    | 5335    | Informational                          |
| SUITE_LOG_LEVEL   | INFO    | Logging level                          |

DB path: SUITE_DATA_DIR/shared.sqlite (default: data/shared.sqlite).

---

## Troubleshooting

| Symptom                                   | Likely cause / fix                                                                           |
| ----------------------------------------- | -------------------------------------------------------------------------------------------- |
| sqlite3.OperationalError: no such table   | Start the API once (auto-inits) or run: from shared.db import init_db; init_db()            |
| 401 Invalid API key                        | Send correct X-API-Key header matching SUITE_API_KEY                                        |
| Empty /dns results                         | Seed rows or run the DNS monitor; ensure Pi-hole log path is correct                        |
| curl to /health fails                      | Check process/port; review uvicorn logs                                                     |

---

## Optional systemd

~~~ini
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
~~~

---

## Changelog & License

* See CHANGELOG.md
* Licensed under MIT (see LICENSE)
