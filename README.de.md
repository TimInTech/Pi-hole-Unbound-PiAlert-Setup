# Pi-hole + Unbound + NetAlertX – Setup & Mini-Suite

Dieses Repository bietet eine Kurzreferenz für **Pi-hole v6.x** mit **Unbound** sowie Hinweise zu **NetAlertX**. Ergänzend gibt es eine kleine Python-Suite mit REST-API für DNS- und Geräte-Logs.

## Schnellstart (Suite)

```bash
cd ~/github_repos/Pi-hole-Unbound-PiAlert-Setup
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
python3 scripts/bootstrap.py
python3 start_suite.py
```

API: `http://127.0.0.1:8090` • DNS-Logs: `GET /dns?limit=50` • Header `x-api-key: $SUITE_API_KEY`

## Unbound-Minimal (pi-hole.conf)

Siehe Abschnitt „Unbound“ im README, Root-Hints aktualisieren und `127.0.0.1#5335` als Upstream in Pi-hole setzen.

## Sicherheit

Vor dem Start `SUITE_API_KEY` als Umgebungsvariable definieren.

## Lizenz

MIT
