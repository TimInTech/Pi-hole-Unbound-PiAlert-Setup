# Pi-hole + Unbound + NetAlertX — Setup & Minimal Python Suite

> 🌐 Languages: English (this file) • 🇩🇪 Deutsch: [README.de.md]  
> 🧰 Stack: <img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="stack icons" />

This repository provides a **concise setup** for **Pi-hole v6.x** with **Unbound** and notes for **NetAlertX**.  
Additionally, it contains an **optional minimal Python suite** (FastAPI + SQLite) to surface DNS/device data via a tiny API.

---

## Contents

- **Setup guides:**
  - Pi-hole + Unbound on Debian/Ubuntu
  - NetAlertX notes
- **Optional Python Suite (FastAPI + SQLite):**
  - Endpoints: `/health`, `/dns?limit=N`, `/leases`, `/devices`
  - Workers: `pyhole/dns_monitor.py` (tails Pi-hole log), `pyalloc/*` (demo IP allocator)
  - DB schema: `shared/db.py` → `data/shared.sqlite`
  - Helper tools: `scripts/bootstrap.py`, `scripts/healthcheck.py`

---

## Quick start: Pi-hole + Unbound (Debian/Ubuntu)

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

## NetAlertX (Note)

NetAlertX can run alongside Pi-hole. Avoid binding to the same DNS port; this setup assumes Pi-hole resolves via Unbound on `127.0.0.1:5335`.

---

## Optional: Minimal Python Suite (FastAPI + SQLite)

### What you get

- **API**
  - `GET /health` → simple OK
  - `GET /dns?limit=N` → recent DNS log rows
  - `GET /leases` → IP leases
  - `GET /devices` → devices table
- **Workers**
  - `pyhole/dns_monitor.py` tails `/var/log/pihole.log` into `dns_logs`
  - `pyalloc/*` demo IP pool allocator
- **Database**
  - SQLite at `data/shared.sqlite` (auto-initialized)

### Run locally

~~~bash
cd ~/github_repos/Pi-hole-Unbound-PiAlert-Setup
python3 -m venv .venv
. .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
python3 scripts/bootstrap.py
export SUITE_API_KEY="testkey"
python3 start_suite.py
~~~

Smoke test:

~~~bash
curl -s -H "X-API-Key: testkey" http://127.0.0.1:8090/health | python -m json.tool
~~~

### ENV

- `SUITE_API_KEY` (optional; if set, send header `X-API-Key`)
- `SUITE_DATA_DIR` (default `data/`)
- `SUITE_LOG_LEVEL` (default `INFO`)

DB path: `data/shared.sqlite`.

### Troubleshooting

- `no such table` → start API once (auto-init) or run init manually
- `401 Invalid API key` → wrong/missing `X-API-Key`
- empty `/dns` → ensure Pi-hole log path and run DNS monitor
- `/health` unreachable → check process/port/logs

### Optional systemd unit

~~~ini
[Unit]
Description=Pi-hole Suite (API + workers)
After=network.target

[Service]
WorkingDirectory=/home/USER/github_repos/Pi-hole-Unbound-PiAlert-Setup
Environment=SUITE_API_KEY=testkey
ExecStart=/home/USER/github_repos/Pi-hole-Unbound-PiAlert-Setup/.venv/bin/python start_suite.py
Restart=always
User=USER

[Install]
WantedBy=multi-user.target
~~~

---

## Project structure

~~~text
.
├─ api/
│  └─ main.py
├─ shared/
│  ├─ db.py
│  └─ shared_config.py
├─ pyhole/
│  └─ dns_monitor.py
├─ pyalloc/
│  ├─ allocator.py
│  └─ main.py
├─ scripts/
│  ├─ bootstrap.py
│  └─ healthcheck.py
├─ start_suite.py
├─ requirements.txt
├─ README.md
└─ README.de.md
~~~

---

## License

MIT — see LICENSE.

