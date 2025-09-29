# Pi-hole + Unbound + NetAlertX – Setup & Mini-Suite

Dieses Repository liefert eine kurze Anleitung für **Pi-hole v6.x** mit **Unbound** sowie Hinweise zu **NetAlertX**. Zusätzlich enthält es eine kleine Python-Suite mit REST-API zum Log-Einblick.

## Quickstart (Suite)

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

## Unbound Minimal (pi-hole.conf)

Siehe README-Abschnitt „Unbound“, Root-Hints laden und `127.0.0.1#5335` in Pi-hole setzen.

## Security

Setze `SUITE_API_KEY` als Umgebungsvariable vor dem Start.

## Lizenz

MIT
