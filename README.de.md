# Pi-hole + Unbound + NetAlertX – Setup & Mini-Suite

🌐 Sprachen: 🇬🇧 Englisch ([README.md]) • Deutsch (diese Datei)  
🧰 Stack: <img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" />

Dieses Repository liefert eine **kompakte Anleitung** für **Pi-hole v6.x** mit **Unbound** und Hinweise zu **NetAlertX**.  
Zusätzlich gibt es eine **optionale Minimal-Suite in Python** (FastAPI + SQLite), um DNS-/Geräte-Daten per kleiner API bereitzustellen.

---

## Inhalt

- **Anleitungen:**
  - Pi-hole + Unbound auf Debian/Ubuntu
  - Hinweise zu NetAlertX
- **Optionale Python-Suite (FastAPI + SQLite):**
  - Endpunkte: `/health`, `/dns?limit=N`, `/leases`, `/devices`
  - Worker: `pyhole/dns_monitor.py`, `pyalloc/*`
  - DB-Schema: `shared/db.py` → `data/shared.sqlite`
  - Helfer: `scripts/bootstrap.py`, `scripts/healthcheck.py`

---

## Schnellstart: Pi-hole + Unbound (Debian/Ubuntu)

### 1) Unbound installieren & Root-Hints

~~~bash
sudo apt-get update
sudo apt-get install -y unbound ca-certificates curl
sudo install -d -m 0755 /var/lib/unbound
sudo curl -fsSL https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints
~~~

### 2) Minimale Unbound-Config (127.0.0.1:5335)

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

Trust-Anchor initialisieren & Dienst neustarten:

~~~bash
sudo unbound-anchor -a /var/lib/unbound/root.key || true
sudo systemctl enable --now unbound
sudo systemctl restart unbound
sudo systemctl status --no-pager unbound
~~~

Kurztest:

~~~bash
dig +short @127.0.0.1 -p 5335 example.com
~~~

### 3) Pi-hole auf Unbound zeigen

Pi-hole Admin → Settings → DNS → **Custom upstream**: `127.0.0.1#5335`, dann:

~~~bash
pihole restartdns
~~~

---

## NetAlertX (Hinweis)

NetAlertX kann parallel laufen; nicht am selben DNS-Port binden. Hier nutzt Pi-hole Unbound lokal auf `127.0.0.1:5335`.

---

## Optional: Mini-Suite (FastAPI + SQLite)

### Was enthalten ist

- **API**
  - `GET /health`, `GET /dns?limit=N`, `GET /leases`, `GET /devices`
- **Worker**
  - `pyhole/dns_monitor.py` liest `/var/log/pihole.log` in `dns_logs`
  - `pyalloc/*` als Demo-IP-Allocator
- **Datenbank**
  - SQLite unter `data/shared.sqlite` (Auto-Init)

### Lokal starten

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

Smoke-Test:

~~~bash
curl -s -H "X-API-Key: testkey" http://127.0.0.1:8090/health | python -m json.tool
~~~

### ENV

- `SUITE_API_KEY` (optional; wenn gesetzt, Header `X-API-Key` senden)
- `SUITE_DATA_DIR` (Standard `data/`)
- `SUITE_LOG_LEVEL` (Standard `INFO`)

DB-Pfad: `data/shared.sqlite`.

### Troubleshooting

- `no such table` → API einmal starten (Auto-Init)
- `401 Invalid API key` → Header prüfen
- Leere `/dns` → Pfad zum Pi-hole-Log prüfen und Monitor laufen lassen
- `/health` nicht erreichbar → Prozess/Port/Logs prüfen

### Optionales systemd-Unit

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

## Struktur

~~~text
.
├─ api/
├─ shared/
├─ pyhole/
├─ pyalloc/
├─ scripts/
├─ start_suite.py
├─ requirements.txt
├─ README.md
└─ README.de.md
~~~

---

## Lizenz

MIT — siehe LICENSE.

