# Pi-hole + Unbound + NetAlertX — Setup & Minimale Python-Suite

> 🌐 **Sprachen:** 🇬🇧 [English](README.md) • Deutsch (diese Datei)
> 🧰 **Stack-Icons:** <img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="stack icons" />

Dieses Repository enthält eine kompakte Hilfestellung für **Pi-hole**, **Unbound** und **NetAlertX** sowie eine **kleine Python-API** (FastAPI + SQLite) für einfache DNS-/Geräte-Logs und Healthchecks.
Es ist **kein** vollständiger Installer; die README beschreibt den vorhandenen Code und wie man die kleine API lokal nutzt.

---

## Inhalt des Repos

* **Minimale API (FastAPI)** mit:

  * `GET /health` (OK-Check)
  * `GET /dns?limit=N` (letzte DNS-Logzeilen)
  * `GET /leases` (IP-Leases)
  * `GET /devices` (Geräte)
* **SQLite-Schema & Init** (`shared/db.py`) mit Indizes
* **Leichte Worker (Platzhalter):**

  * `pyhole/dns_monitor.py` — liest `/var/log/pihole.log` und schreibt nach `dns_logs` (einfacher Parser)
  * `pyalloc/*` — IP-Allocator-Skelett (noch ohne DHCP-Hook)
* **Helper-Skripte**

  * `scripts/bootstrap.py` — Bibliotheks-Check
  * `scripts/healthcheck.py` — DB-Test
  * (optional) `scripts/ci.sh` — lokaler Smoke-Test (Imports + `/health`)

---

## Struktur

```
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
│  ├─ healthcheck.py
│  └─ ci.sh
├─ start_suite.py
├─ requirements.txt
├─ README.md       # EN
└─ README.de.md    # DE
```

---

## Voraussetzungen

* **Python**: 3.12+ empfohlen (3.13 funktioniert ebenfalls)
* **OS**: Linux (Debian/Ubuntu/Raspberry Pi OS)
* **Python-Pakete**:

  * `fastapi==0.115.0`
  * `uvicorn==0.30.6`
  * `pydantic==2.9.2`

Installation:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

## Konfiguration

Umgebungsvariablen (siehe `shared/shared_config.py`):

| Variable          | Default | Beschreibung                                  |
| ----------------- | ------- | --------------------------------------------- |
| `SUITE_API_KEY`   | (unset) | Wenn gesetzt, Header `X-API-Key` erforderlich |
| `SUITE_DATA_DIR`  | `data/` | Verzeichnis für die SQLite-DB                 |
| `SUITE_INTERFACE` | `eth0`  | Informativ                                    |
| `SUITE_DNS_PORT`  | `5335`  | Informativ                                    |
| `SUITE_LOG_LEVEL` | `INFO`  | Log-Level                                     |

DB-Pfad: **`$SUITE_DATA_DIR/shared.sqlite`** (Standard: `data/shared.sqlite`).

---

## Schnellstart (lokal)

**1) Bootstrap & DB-Check:**

```bash
source .venv/bin/activate
python scripts/bootstrap.py
python scripts/healthcheck.py
```

**2a) Nur API via uvicorn:**

```bash
export SUITE_API_KEY="testkey"   # optional, empfohlen
uvicorn api.main:app --host 127.0.0.1 --port 8090 --log-level info
```

**2b) Ganze Suite (API + Threads) — optional:**

```bash
export SUITE_API_KEY="testkey"
python start_suite.py
```

**3) Smoke-Test:**

```bash
curl -s http://127.0.0.1:8090/health | python -m json.tool
```

Mit API-Key:

```bash
curl -s -H "X-API-Key: testkey" http://127.0.0.1:8090/health | python -m json.tool
```

---

## API (Kurzreferenz)

| Methode | Pfad       | Query         | Header               | Beispielantwort                                                 |
| ------: | ---------- | ------------- | -------------------- | --------------------------------------------------------------- |
|     GET | `/health`  | —             | optional `X-API-Key` | `{"ok": true}`                                                  |
|     GET | `/dns`     | `limit` (int) | optional `X-API-Key` | Liste von Objekten (`timestamp`, `client`, `query`, `action`)   |
|     GET | `/leases`  | —             | optional `X-API-Key` | Liste mit (`ip`, `mac`, `hostname`, `lease_start`, `lease_end`) |
|     GET | `/devices` | —             | optional `X-API-Key` | Liste mit (`ip`, `mac`, `hostname`, `last_seen`)                |

---

## Datenbank

Tabellen (vereinfacht):

* `dns_logs(id, timestamp, client, query, action)` — Index auf `timestamp`
* `ip_leases(id, ip UNIQUE, mac, hostname, lease_start, lease_end)`
* `devices(id, ip, mac, hostname, last_seen)` — Index auf `ip`

Schema wird beim API-Start erzeugt (siehe `api/main.py` → `init_db()`).

---

## Optionale Worker

* **DNS-Monitor** (`pyhole/dns_monitor.py`):
  Liest `/var/log/pihole.log` periodisch und schreibt Treffer in `dns_logs`. Parser ist bewusst einfach gehalten.
* **Allocator** (`pyalloc/*`):
  Skelett für IP-Adressvergabe; keine DHCP-Integration vorhanden.

---

## Troubleshooting

| Problem                    | Ursache / Lösung                                                          |
| -------------------------- | ------------------------------------------------------------------------- |
| `no such table` in SQLite  | API einmal starten (init), oder `init_db()` manuell ausführen.            |
| `401 Invalid API key`      | `X-API-Key`-Header korrekt setzen (falls `SUITE_API_KEY` aktiv).          |
| Leere `/dns`-Ergebnisse    | Daten seeden oder DNS-Monitor laufen lassen; Pfad zum Pi-hole-Log prüfen. |
| `/health` nicht erreichbar | Prozess/Port prüfen; `uvicorn`-Logs ansehen.                              |

---

## Systemd (optional)

Nur wenn gewünscht; Pfade/Benutzer anpassen:

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

## Changelog & Lizenz

* Änderungen: **[CHANGELOG.md](CHANGELOG.md)**
* Lizenz: **MIT** (**[LICENSE](LICENSE)**)
