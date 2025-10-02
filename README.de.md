<<<<<<< HEAD
<div align="center">

# 🛡️ Pi-hole + Unbound + NetAlertX
### **Ein-Klick DNS-Sicherheit & Monitoring-Stack**

[![Build Status](https://img.shields.io/github/actions/workflow/status/TimInTech/Pi-hole-Unbound-PiAlert-Setup/ci.yml?branch=main&style=for-the-badge&logo=github)](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/actions)
[![License](https://img.shields.io/github/license/TimInTech/Pi-hole-Unbound-PiAlert-Setup?style=for-the-badge&color=blue)](LICENSE)
[![Pi-hole](https://img.shields.io/badge/Pi--hole-v6.x-red?style=for-the-badge&logo=pihole)](https://pi-hole.net/)
[![Unbound](https://img.shields.io/badge/Unbound-DNS-orange?style=for-the-badge)](https://nlnetlabs.nl/projects/unbound/)
[![NetAlertX](https://img.shields.io/badge/NetAlertX-Monitor-green?style=for-the-badge)](https://github.com/jokob-sk/NetAlertX)
[![Debian](https://img.shields.io/badge/Debian-Compatible-red?style=for-the-badge&logo=debian)](https://debian.org/)
[![Python](https://img.shields.io/badge/Python-3.12+-blue?style=for-the-badge&logo=python)](https://python.org/)

**🧰 Tech Stack**  
<img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="Tech Stack" />

**🌐 Sprachen:** 🇩🇪 Deutsch (diese Datei) • [🇬🇧 English](README.md)

</div>

---

## ✨ Features

✅ **Ein-Klick-Installation** - Setup mit einem Befehl  
✅ **DNS-Sicherheit** - Pi-hole + Unbound mit DNSSEC  
✅ **Netzwerk-Monitoring** - NetAlertX Geräte-Tracking  
✅ **API-Monitoring** - Python FastAPI + SQLite  
✅ **Produktionsbereit** - Systemd-Hardening & Auto-Restart  
✅ **Idempotent** - Sicher mehrfach ausführbar  

---

## ⚡ Ein-Klick-Schnellstart

```bash
git clone https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup.git
cd Pi-hole-Unbound-PiAlert-Setup
chmod +x install.sh
sudo ./install.sh
```

**Fertig!** 🎉 Ihr kompletter DNS-Sicherheits-Stack läuft jetzt.

---

## 🧰 Was installiert wird

| Komponente | Zweck | Zugriff |
|------------|-------|---------|
| **🕳️ Pi-hole** | DNS-Werbeblocker & Web-UI | `http://[ihre-ip]/admin` |
| **🔐 Unbound** | Rekursiver DNS + DNSSEC | `127.0.0.1:5335` |
| **📡 NetAlertX** | Netzwerkgeräte-Monitoring | `http://[ihre-ip]:20211` |
| **🐍 Python API** | Monitoring & Statistik-API | `http://127.0.0.1:8090` |

---

## 🗺️ Architektur

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Clients   │───▶│   Pi-hole    │───▶│   Unbound   │
│ 192.168.x.x │    │    :53       │    │   :5335     │
└─────────────┘    └──────┬───────┘    └─────────────┘
                          │                     │
                          ▼                     ▼
                   ┌─────────────┐    ┌─────────────┐
                   │  NetAlertX  │    │ Root-Server │
                   │   :20211    │    │  + Quad9    │
                   └─────────────┘    └─────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │ Python API  │
                   │   :8090     │
                   └─────────────┘
```

**Datenfluss:**
1. **Clients** → Pi-hole (DNS-Filterung)
2. **Pi-hole** → Unbound (rekursive Auflösung)
3. **Unbound** → Root-Server (DNSSEC-Validierung)
4. **NetAlertX** → Netzwerk-Monitoring
5. **Python API** → Aggregierte Monitoring-Daten

---

## 🔌 API-Referenz

### Authentifizierung
Alle Endpunkte benötigen `X-API-Key`-Header:
```bash
curl -H "X-API-Key: ihr-api-key" http://127.0.0.1:8090/endpoint
```

### Endpunkte

#### `GET /health`
```json
{
  "ok": true,
  "message": "Pi-hole Suite API is running",
  "version": "1.0.0"
}
```

#### `GET /dns?limit=50`
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

#### `GET /devices`
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

#### `GET /stats`
```json
{
  "total_dns_logs": 1250,
  "total_devices": 15,
  "recent_queries": 89
}
```

---

## 🛠️ Manuelle Schritte (Optional)

### Pi-hole-Konfiguration
1. Admin-Interface aufrufen: `http://[ihre-ip]/admin`
2. **Einstellungen → DNS** navigieren
3. **Custom upstream** prüfen: `127.0.0.1#5335`
4. Geräte konfigurieren, um Pi-hole als DNS-Server zu verwenden

### NetAlertX-Setup
- Dashboard aufrufen: `http://[ihre-ip]:20211`
- Scan-Zeitpläne und Benachrichtigungen konfigurieren
- Netzwerk-Topologie und Geräteliste überprüfen

---

## 🧪 Gesundheitschecks & Problembehandlung

### Schneller Gesundheitscheck
```bash
# Unbound testen
dig @127.0.0.1 -p 5335 example.com

# Pi-hole testen
pihole status

# NetAlertX testen
docker logs netalertx

# Python API testen
curl -H "X-API-Key: $SUITE_API_KEY" http://127.0.0.1:8090/health
```

### Service-Verwaltung
```bash
# Services prüfen
systemctl status pihole-suite unbound pihole-FTL
docker ps

# Logs anzeigen  
journalctl -u pihole-suite -f
journalctl -u unbound -f

# Services neustarten
systemctl restart pihole-suite
pihole restartdns
docker restart netalertx
```

### Häufige Probleme

| Problem | Lösung |
|---------|--------|
| **Port 53 belegt** | `sudo systemctl stop systemd-resolved` |
| **API-Key fehlt** | `.env`-Datei prüfen oder mit Installer neu generieren |
| **Datenbankfehler** | `python scripts/bootstrap.py` ausführen |
| **Unbound startet nicht** | `/etc/unbound/unbound.conf.d/pi-hole.conf` prüfen |

---

## 🧯 Sicherheitshinweise

### 🔐 API-Sicherheit
- **API-Keys** werden automatisch generiert (16-Byte Hex)
- **CORS** nur für localhost aktiviert
- **Authentifizierung** für alle Endpunkte erforderlich

### 🛡️ Systemd-Hardening
- **NoNewPrivileges** verhindert Rechte-Eskalation
- **ProtectSystem=strict** Schreibschutz für Dateisystem
- **PrivateTmp** isolierte temporäre Verzeichnisse
- **Memory-Limits** verhindern Ressourcen-Erschöpfung

### 🔒 Netzwerk-Sicherheit
- **Unbound** nur auf localhost (nicht exponiert)
- **DNS über TLS** zu Upstream-Resolvern
- **DNSSEC**-Validierung aktiviert

---

## 🤝 Mitwirken

1. **Repository forken**
2. **Feature-Branch erstellen**: `git checkout -b feature/tolles-feature`
3. **Änderungen committen**: `git commit -m 'feat: tolles Feature hinzugefügt'`
4. **Testen mit**: `ruff check . && pytest`
5. **Push** und Pull Request erstellen

---

## 📜 Lizenz

Dieses Projekt ist unter der **MIT-Lizenz** lizenziert - siehe [LICENSE](LICENSE)-Datei.

---

## 📈 Changelog

Siehe [CHANGELOG.md](CHANGELOG.md) für Versionshistorie und Updates.

---

<div align="center">

**Mit ❤️ für die Pi-hole-Community erstellt**

[🐛 Bug melden](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/issues) •
[✨ Feature anfordern](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/issues) •
[💬 Diskussionen](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/discussions)

</div>
=======
# Pi-hole + Unbound + NetAlertX — Ein-Klick-Setup



- **Issues**: [GitHub Issues](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/issues)
- **Diskussionen**: [GitHub Discussions](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/discussions)
- **Dokumentation**: Diese README und Inline-Code-Kommentare
>>>>>>> origin/main
