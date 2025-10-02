# Pi-hole + Unbound + NetAlertX — Ein-Klick-Setup

> 🌐 Sprachen: 🇬🇧 Englisch ([README.md](README.md)) • Deutsch (diese Datei)  
> 🧰 Stack: <img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="stack icons" />

**Ein-Klick-Installer für einen kompletten DNS-Sicherheits- und Überwachungsstack:** Pi-hole mit Unbound rekursivem DNS-Resolver, NetAlertX Netzwerk-Monitoring und einer optionalen Python-Überwachungs-Suite.

---

## 🚀 Schnellstart (Ein-Klick-Installation)

```bash
# Repository herunterladen oder klonen
git clone https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup.git
cd Pi-hole-Unbound-PiAlert-Setup

# Ein-Klick-Installer ausführen
chmod +x install.sh
sudo ./install.sh
```

**Das war's!** Der Installer richtet automatisch ein:
- ✅ **Unbound** DNS-Resolver auf `127.0.0.1:5335` mit DNSSEC
- ✅ **Pi-hole** konfiguriert mit Unbound als Upstream-DNS
- ✅ **NetAlertX** Netzwerk-Monitoring auf Port `20211`
- ✅ **Python-Überwachungs-Suite** mit REST-API auf Port `8090`

---

## 📋 Was installiert wird

### 🔧 Kernkomponenten

| Komponente | Zweck | Zugang |
|------------|-------|--------|
| **Unbound** | Rekursiver DNS-Resolver mit DNSSEC | `127.0.0.1:5335` |
| **Pi-hole** | DNS-Werbeblocker und Web-Interface | `http://[ihre-ip]/admin` |
| **NetAlertX** | Netzwerkgeräte-Überwachung | `http://[ihre-ip]:20211` |
| **Python-Suite** | DNS-/Geräte-Überwachungs-API | `http://127.0.0.1:8090` |

### 🛡️ Sicherheitsfeatures

- **DNSSEC-Validierung** über Unbound
- **DNS über TLS** Upstream-Verbindungen (Quad9)
- **Zugriffskontrolle** für DNS-Anfragen
- **systemd-Hardening** für Python-Dienste
- **API-Key-Authentifizierung** für Monitoring-Endpunkte

---

## 🔍 Nach der Installation

### Pi-hole-Konfiguration
1. Pi-hole Admin-Interface aufrufen: `http://[ihre-server-ip]/admin`
2. Zu **Einstellungen → DNS** gehen
3. Prüfen, dass **Custom upstream** auf `127.0.0.1#5335` gesetzt ist
4. Ihre Geräte konfigurieren, um `[ihre-server-ip]` als DNS-Server zu nutzen

### NetAlertX Netzwerk-Monitoring
- Zugang: `http://[ihre-server-ip]:20211`
- Netzwerkgeräte überwachen und Alarme für neue Geräte erhalten
- Benachrichtigungen und Scan-Zeitpläne konfigurieren

### Python-Monitoring-API
API mit Ihrem generierten Schlüssel testen:
```bash
# API-Schlüssel aus der Installer-Ausgabe verwenden
curl -H "X-API-Key: IHR_API_KEY" http://127.0.0.1:8090/health
```

---

## 📡 API-Referenz

Die Python-Monitoring-Suite bietet diese Endpunkte:

### Authentifizierung
Alle Endpunkte benötigen den `X-API-Key`-Header mit Ihrem generierten API-Schlüssel.

### Endpunkte

#### `GET /health`
Gesundheits-Check-Endpunkt
```json
{"ok": true}
```

#### `GET /dns?limit=N`
Neueste DNS-Anfrage-Logs (Standard-Limit: 50)
```json
[
  {
    "timestamp": "Dec 21 10:30:45",
    "client": "192.168.1.100",
    "query": "example.com",
    "action": "query"
  }
]
```

#### `GET /leases`
DHCP-Lease-Informationen
```json
[
  {
    "ip": "192.168.1.100",
    "mac": "aa:bb:cc:dd:ee:ff",
    "hostname": "laptop",
    "lease_start": "2024-12-21 10:00:00",
    "lease_end": "2024-12-22 10:00:00"
  }
]
```

#### `GET /devices`
Netzwerkgeräte-Liste
```json
[
  {
    "id": 1,
    "ip": "192.168.1.100",
    "mac": "aa:bb:cc:dd:ee:ff",
    "hostname": "laptop",
    "last_seen": "2024-12-21 10:30:00"
  }
]
```

---

## ⚙️ Konfiguration

### Umgebungsvariablen

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| `SUITE_API_KEY` | *(generiert)* | API-Authentifizierungs-Schlüssel |
| `SUITE_DATA_DIR` | `data/` | Datenbank- und Log-Verzeichnis |
| `SUITE_LOG_LEVEL` | `INFO` | Log-Level (DEBUG, INFO, WARNING, ERROR) |
| `ENABLE_PYALLOC_DEMO` | `false` | Demo-IP-Allocator-Komponente aktivieren |

### Dienst-Verwaltung

```bash
# Dienst-Status prüfen
sudo systemctl status pihole-suite
sudo systemctl status unbound
sudo docker logs netalertx

# Dienste neustarten
sudo systemctl restart pihole-suite
sudo systemctl restart unbound
sudo docker restart netalertx

# Logs anzeigen
sudo journalctl -u pihole-suite -f
sudo journalctl -u unbound -f
```

### Wichtige Pfade

| Pfad | Zweck |
|------|-------|
| `/etc/unbound/unbound.conf.d/pi-hole.conf` | Unbound-DNS-Konfiguration |
| `/etc/pihole/` | Pi-hole-Konfiguration |
| `/opt/netalertx/` | NetAlertX-Daten und -Konfiguration |
| `./data/shared.sqlite` | Python-Suite-Datenbank |

---

## 🔧 Manuelle Konfiguration (Optional/Erweitert)

### Benutzerdefinierte Unbound-Konfiguration

Wenn Sie Unbound-Einstellungen ändern möchten:

```bash
sudo nano /etc/unbound/unbound.conf.d/pi-hole.conf
sudo systemctl restart unbound
```

### Pi-hole benutzerdefinierte Listen

Benutzerdefinierte Blocklisten oder Whitelists hinzufügen:
1. Pi-hole Admin → Adlists aufrufen
2. Ihre benutzerdefinierten URLs hinzufügen
3. Gravity aktualisieren: `pihole -g`

### NetAlertX erweiterte Einstellungen

NetAlertX-Konfiguration aufrufen:
```bash
sudo nano /opt/netalertx/config/pialert.conf
sudo docker restart netalertx
```

### Python-Suite-Entwicklung

Für Entwicklung oder benutzerdefinierte Änderungen:

```bash
# Demo-Komponenten aktivieren
export ENABLE_PYALLOC_DEMO=true

# Im Entwicklungsmodus ausführen
cd Pi-hole-Unbound-PiAlert-Setup
source .venv/bin/activate
export SUITE_API_KEY=dev-key
python start_suite.py
```

---

## 🩺 Problembehandlung

### DNS-Auflösungsprobleme
```bash
# Unbound direkt testen
dig @127.0.0.1 -p 5335 example.com

# Pi-hole-DNS-Einstellungen prüfen
pihole status
pihole -q example.com

# Upstream-Konfiguration überprüfen
pihole restartdns
```

### Dienst-Probleme
```bash
# Alle Dienste prüfen
sudo systemctl status unbound pihole-FTL pihole-suite
sudo docker ps

# Logs auf Fehler prüfen
sudo journalctl -u unbound --since "1 hour ago"
sudo journalctl -u pihole-suite --since "1 hour ago"
```

### API-Probleme
```bash
# API-Konnektivität testen
curl -v http://127.0.0.1:8090/health

# Prüfen ob API-Schlüssel gesetzt ist
echo $SUITE_API_KEY

# Datenbank überprüfen
ls -la data/shared.sqlite
```

### Port-Konflikte
```bash
# Prüfen was Ihre Ports verwendet
ss -tuln | grep -E ':(53|5335|8090|20211)'

# Konflikthafte Dienste stoppen falls nötig
sudo systemctl stop systemd-resolved  # falls Port 53 verwendet wird
```

---

## 🏗️ Projektstruktur

```
.
├── install.sh              # Ein-Klick-Installer-Skript
├── start_suite.py          # Python-Suite-Einstiegspunkt
├── requirements.txt        # Python-Abhängigkeiten
├── api/                    # FastAPI REST-Endpunkte
│   ├── main.py            # API-Routen und Authentifizierung
│   └── schemas.py         # Pydantic-Modelle
├── shared/                 # Geteilte Hilfsprogramme
│   ├── db.py              # SQLite-Datenbank-Setup
│   └── shared_config.py   # Konfigurationsverwaltung
├── pyhole/                 # Pi-hole-Log-Monitoring
│   └── dns_monitor.py     # DNS-Log-Parser mit Rotationsunterstützung
├── pyalloc/               # Demo-IP-Allocator (optional)
│   ├── README_DEMO.md     # Demo-Komponentendokumentation
│   ├── allocator.py       # IP-Pool-Verwaltung
│   └── main.py           # Demo-Worker
├── scripts/               # Hilfsskripte
│   ├── bootstrap.py       # Abhängigkeitsprüfer
│   └── healthcheck.py     # Gesundheits-Check-Skript
└── tests/                 # Test-Suite
```

---

## 📄 Lizenz

MIT-Lizenz - siehe [LICENSE](LICENSE)-Datei für Details.

---

## 🤝 Mitwirken

1. Repository forken
2. Feature-Branch erstellen: `git checkout -b feature-name`
3. Änderungen vornehmen und testen
4. Linter ausführen: `ruff check .`
5. Pull Request einreichen

---

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/issues)
- **Diskussionen**: [GitHub Discussions](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/discussions)
- **Dokumentation**: Diese README und Inline-Code-Kommentare