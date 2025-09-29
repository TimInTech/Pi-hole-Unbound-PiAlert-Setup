# Pi-hole + Unbound + NetAlertX – Setup & Mini-Suite

> 🌐 Sprachen: 🇬🇧 [English](README.md) • Deutsch (diese Datei)  
> 🧰 Stack-Icons:  
> <img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="stack icons" />

Kurzreferenz für **Pi-hole v6.x** mit **Unbound** sowie eine kleine **Python-Suite** (FastAPI + SQLite) für DNS-/Geräte-Logs und Healthchecks.  
Kein vollständiger Installer; die README beschreibt die Mini-API und lokale Nutzung.

---

## Inhalt

- Mini-API (FastAPI): `/health`, `/dns?limit=N`, `/leases`, `/devices`  
- SQLite-Schema & Init (`shared/db.py`) mit Indizes  
- Optionale Worker: `pyhole/dns_monitor.py`, `pyalloc/*`  
- Helper-Skripte: `scripts/bootstrap.py`, `scripts/healthcheck.py`

---

## Struktur

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
├─ README.md       # EN
└─ README.de.md    # DE
~~~

---

## Schnellstart: Mini-Suite (API)

~~~bash
cd ~/github_repos/Pi-hole-Unbound-PiAlert-Setup
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
python3 scripts/bootstrap.py
export SUITE_API_KEY="testkey"   # optional, empfohlen
python3 start_suite.py
~~~

Smoke-Test:

~~~bash
curl -s -H "X-API-Key: testkey" http://127.0.0.1:8090/health | python -m json.tool
~~~

---

## Pi-hole + Unbound auf Debian/Ubuntu (copy & paste)

~~~bash
sudo apt-get update
sudo apt-get install -y unbound ca-certificates curl
sudo install -d -m 0755 /var/lib/unbound
sudo curl -fsSL https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints
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
sudo unbound-anchor -a /var/lib/unbound/root.key || true
sudo systemctl enable --now unbound
sudo systemctl restart unbound
sudo systemctl status --no-pager unbound
dig +short @127.0.0.1 -p 5335 example.com
~~~

Pi-hole Admin → Settings → DNS → Custom Upstream: 127.0.0.1#5335

~~~bash
pihole restartdns
~~~

---

## Konfiguration (ENV)

| Variable          | Default | Beschreibung                                  |
| ----------------- | ------- | --------------------------------------------- |
| SUITE_API_KEY     | (unset) | Wenn gesetzt, Header X-API-Key erforderlich   |
| SUITE_DATA_DIR    | data/   | Verzeichnis für die SQLite-DB                 |
| SUITE_INTERFACE   | eth0    | Informativ                                    |
| SUITE_DNS_PORT    | 5335    | Informativ                                    |
| SUITE_LOG_LEVEL   | INFO    | Log-Level                                     |

DB-Pfad: SUITE_DATA_DIR/shared.sqlite (Standard: data/shared.sqlite).

---

## Troubleshooting

| Problem                    | Ursache / Lösung                                                          |
| -------------------------- | ------------------------------------------------------------------------- |
| no such table (SQLite)     | API einmal starten (auto-init) oder: from shared.db import init_db; init_db() |
| 401 Invalid API key        | X-API-Key korrekt senden (entspricht SUITE_API_KEY)                       |
| Leere /dns-Ergebnisse      | Daten seeden oder DNS-Monitor laufen lassen; Pfad zum Pi-hole-Log prüfen |
| /health nicht erreichbar   | Prozess/Port prüfen; uvicorn-Logs ansehen                                 |

---

## Optional: systemd

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

## Changelog & Lizenz

* Änderungen: CHANGELOG.md  
* Lizenz: MIT (siehe LICENSE)
