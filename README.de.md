# Pi-hole + Unbound + NetAlertX – Setup & Mini-Suite

> 🌐 **Sprachen:** 🇬🇧 Englisch: [README.md] • Deutsch (diese Datei)  
> 🧰 **Stack:** <img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="stack icons" />

Kurzreferenz für **Pi-hole v6.x** mit **Unbound** sowie eine kleine **Python-Suite** (FastAPI + SQLite) für DNS-/Geräte-Logs und Healthchecks.  
Dies ist **kein** Full-Installer; die README beschreibt, wie die Mini-API lokal läuft.

---

## Schnellstart (API)
~~~bash
cd ~/github_repos/Pi-hole-Unbound-PiAlert-Setup
python3 -m venv .venv
source .venv/bin/activate
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

---

## Pi-hole + Unbound (Debian/Ubuntu)

### 1) Unbound installieren & Root-Hints laden
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
In der Admin-Oberfläche **Custom Upstream** auf `127.0.0.1#5335` setzen, dann:
~~~bash
pihole restartdns
~~~

---

## ENV (kurz)
`SUITE_API_KEY` (optional), `SUITE_DATA_DIR` (Standard `data/`), `SUITE_LOG_LEVEL` (`INFO`).  
DB: `data/shared.sqlite`.

## Troubleshooting (kurz)
- `no such table` → API einmal starten oder: `python -c "from shared.db import init_db; init_db()"`
- `401` → Header `X-API-Key` fehlt/falsch
- leere `/dns` → DNS-Monitor starten / Pi-hole-Logpfad prüfen
- `/health` down → Prozess/Port/Logs prüfen

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
