# Pi-hole + Unbound + NetAlertX — Setup & Minimal Python Suite

> 🌐 **Languages:** English (this file) • 🇩🇪 Deutsch: [README.de.md]  
> 🧰 **Stack:** <img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="stack icons" />

This repository helps set up **Pi-hole v6.x** with **Unbound** and notes for **NetAlertX**. It also ships a **minimal Python suite** (FastAPI + SQLite) for DNS/device logging and health checks.  
It is **not** a full installer; it documents and runs the small API in this repo.

---

## What’s inside
- **FastAPI endpoints:** `/health`, `/dns?limit=N`, `/leases`, `/devices`
- **SQLite schema & init:** `shared/db.py` (indexed tables)
- **Optional workers:** `pyhole/dns_monitor.py` (tails Pi-hole log), `pyalloc/*`
- **Helper scripts:** `scripts/bootstrap.py`, `scripts/healthcheck.py`

---

## Quick start (API)
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

## Pi-hole + Unbound (Debian/Ubuntu)

### 1) Install Unbound & root hints
~~~bash
sudo apt-get update
sudo apt-get install -y unbound ca-certificates curl
sudo install -d -m 0755 /var/lib/unbound
sudo curl -fsSL https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints
~~~

### 2) Minimal Unbound config (127.0.0.1:5335)
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
Set **Custom upstream** to `127.0.0.1#5335` in the Pi-hole admin UI, then:
~~~bash
pihole restartdns
~~~

---

## ENV (short)
`SUITE_API_KEY` (optional), `SUITE_DATA_DIR` (default `data/`), `SUITE_LOG_LEVEL` (`INFO`).  
DB path: `data/shared.sqlite`.

## Troubleshooting
- `no such table` → start API once or run: `python -c "from shared.db import init_db; init_db()"`
- `401` → wrong/missing `X-API-Key`
- empty `/dns` → run DNS monitor / check Pi-hole log path
- `/health` fails → check process/port/logs

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
