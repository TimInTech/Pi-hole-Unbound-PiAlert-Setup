# Pi-hole + Unbound + NetAlertX – Setup & Mini-Suite

> 🌐 **Sprachen:** 🇬🇧 [English](README.md) • Deutsch (diese Datei)  
> 🧰 **Stack-Icons:**  
> <img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="stack icons" />

Dieses Repository liefert eine Kurzreferenz für **Pi-hole v6.x** mit **Unbound** sowie Hinweise zu **NetAlertX**. Zusätzlich gibt es eine **kleine Python-Suite** (FastAPI + SQLite) für DNS-/Geräte-Logs und Healthchecks.  
Es ist **kein** vollwertiger Installer; die README beschreibt die vorhandene Mini-API und wie man sie lokal nutzt.

---

## Inhalt

* **Mini-API (FastAPI)**:
  * `GET /health` (OK-Check)
  * `GET /dns?limit=N` (letzte DNS-Logzeilen)
  * `GET /leases` (IP-Leases)
  * `GET /devices` (Geräte-Tabelle)
* **SQLite-Schema & Init** (`shared/db.py`) mit Indizes
* **Leichte Worker (optional/Platzhalter)**:
  * `pyhole/dns_monitor.py` liest `/var/log/pihole.log` → `dns_logs`
  * `pyalloc/*` einfacher IP-Allocator
* **Helper-Skripte**
  * `scripts/bootstrap.py` Bibliotheks-Check
  * `scripts/healthcheck.py` DB-Test

---

## Struktur

~~~text
.
├─ api/
│  └─ main.py              # FastAPI; DB-Init beim Start
├─ shared/
│  ├─ db.py                # SQLite-Schema + Init
│  └─ shared_config.py     # ENV & Defaults
├─ pyhole/
│  └─ dns_monitor.py       # optional: Pi-hole-Log → dns_logs
├─ pyalloc/
│  ├─ allocator.py         # einfacher IP-Pool
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

> Pi-hole v6.x vorausgesetzt. Befehle nutzen `sudo`.

### 1) Unbound installieren & Root-Hints laden

~~~bash
sudo apt-get update
sudo apt-get install -y unbound ca-certificates curl
sudo install -d -m 0755 /var/lib/unbound
sudo curl -fsSL https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints
~~~

### 2) Minimale Unbound-Config (Loopback:5335)

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

* **Pi-hole Admin → Settings → DNS → Custom Upstream**: `127.0.0.1#5335`
* Andere Upstreams deaktivieren, speichern, dann:

~~~bash
pihole restartdns
~~~

### 4) (Optional) NetAlertX

NetAlertX nicht am Pi-hole-DNS-Port binden; es ist hier unabhängig.

---

## API (Kurzreferenz)

Basis: `http://127.0.0.1:8090` • Auth-Header (optional, falls `SUITE_API_KEY`): `X-API-Key: <Wert>`

| Methode | Pfad       | Query         | Beispiel                                     |
| ------: | ---------- | ------------- | -------------------------------------------- |
|     GET | `/health`  | —             | `{"ok": true}`                               |
|     GET | `/dns`     | `limit` (int) | Liste mit `timestamp, client, query, action` |
|     GET | `/leases`  | —             | `ip, mac, hostname, lease_start, lease_end`  |
|     GET | `/devices` | —             | `ip, mac, hostname, last_seen`               |

---

## Konfiguration (ENV)

| Variable          | Default | Beschreibung                                  |
| ----------------- | ------- | --------------------------------------------- |
| `SUITE_API_KEY`   | (unset) | Wenn gesetzt, Header `X-API-Key` erforderlich |
| `SUITE_DATA_DIR`  | `data/` | Verzeichnis für die SQLite-DB                 |
| `SUITE_INTERFACE` | `eth0`  | Informativ                                    |
| `SUITE_DNS_PORT`  | `5335`  | Informativ                                    |
| `SUITE_LOG_LEVEL` | `INFO`  | Log-Level                                     |

DB-Pfad: **`$SUITE_DATA_DIR/shared.sqlite`** (Standard: `data/shared.sqlite`).

---

## Troubleshooting

| Problem                    | Ursache / Lösung                                                          |
| -------------------------- | ------------------------------------------------------------------------- |
| `no such table` in SQLite  | API einmal starten (auto-init) oder `init_db()` manuell ausführen.        |
| `401 Invalid API key`      | `X-API-Key` korrekt setzen (entspricht `SUITE_API_KEY`).                  |
| Leere `/dns`-Ergebnisse    | Daten seeden oder DNS-Monitor laufen lassen; Pfad zum Pi-hole-Log prüfen. |
| `/health` nicht erreichbar | Prozess/Port prüfen; `uvicorn`-Logs ansehen.                              |

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

* Änderungen: **CHANGELOG.md**
* Lizenz: **MIT** (siehe **LICENSE**)
