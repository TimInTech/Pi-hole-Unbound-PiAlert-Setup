# 🛡️ Pi-hole + Unbound + NetAlertX + Python Suite
### **Ein-Klick-DNS-Sicherheit & Monitoring-Stack**
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/blob/main/LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Pass-brightgreen?style=for-the-badge&logo=gnu-bash)](https://www.shellcheck.net/)
[![Debian](https://img.shields.io/badge/Debian-11%2B%20%7C%20Ubuntu-22.04%2B-red?style=for-the-badge&logo=debian)](https://debian.org/)
**🧰 Technologie-Stack**  
<img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,bash,python,fastapi,sqlite,docker" alt="Tech Stack" />
**🌐 Sprachen:** [🇬🇧 English](README.md) • 🇩🇪 Deutsch
## ✨ **Hauptmerkmale**
| Funktion                    | Host-Modus              | Container-Modus               |
|-----------------------------|--------------------------|------------------------------|
| **🕳️ Pi-hole**             | Systemd-Dienst          | Docker-Container (Ports 8053→53, 8080→80) |
| **🔐 Unbound**              | Systemd-Dienst (Port 5335) | Host-gebunden (Port 5335)       |
| **📡 NetAlertX**            | Docker-Container         | Docker-Container             |
| **🐍 Python Suite**         | Systemd-Dienst          | Vordergrundprozess           |
| **🔄 Idempotenz**           | ✅ Checkpoint-Fortsetzung | ✅ Checkpoint-Fortsetzung     |
| **🔒 Sicherheit**           | Systemd-Hardening       | Localhost-Binding + Docker-Isolation |

✅ **Ein-Klick-Installation** – Vollständiger Stack mit einem Befehl  
✅ **Dual-Modus-Betrieb** – Host- oder Container-Bereitstellung  
✅ **Idempotent & Fortsetzbar** – Sichere Wiederholung mit `--resume`  
✅ **DNS-Sicherheit** – Pi-hole + Unbound mit DNSSEC und DoT  
✅ **Netzwerk-Monitoring** – NetAlertX-Geräteverfolgung  
✅ **Produktionsbereit** – Systemd-Hardening, Auto-Restart und Logging  
## ⚡ **Schnellstart**
### **1. Repository klonen**
### **2. Installationsmodus wählen**
#### Option A: Host-Modus (Standard)
```bash
sudo ./install.sh
```
- Nutzt systemd für alle Dienste
- Unbound: localhost:5335 (DNSSEC + DoT zu Quad9)
- Pi-hole: Standard-Ports (53, 80)
- Python Suite: Systemd-Dienst mit Sicherheitshärtung
#### Option B: Container-Modus
```bash
sudo ./install.sh --container-mode
```
- Pi-hole und NetAlertX laufen in Docker
- Port-Mappings:
  - Pi-hole DNS: 8053→53 (Host→Container)
  - Pi-hole Web: 8080→80
  - NetAlertX: 20211→20211
- Python Suite läuft im Vordergrund (kein systemd)

### **3. Erweiterte Optionen**

| Flag | Beschreibung |
|------|-------------|
| `--resume` | Fortsetzen vom letzten Checkpoint |
| `--force` | Alle Zustände zurücksetzen und neu installieren |
| `--dry-run` | Zeigt Aktionen ohne Ausführung |
| `--auto-remove-conflicts` | Löst APT-Paketkonflikte automatisch |
## 🗺️ **Architektur**
┌─────────────┐    ┌─────────────────┐    ┌─────────────┐
│   Clients   │───▶│    Pi-hole     │───▶│   Unbound   │
│ 192.168.x.x │    │ (Port 53/80)   │    │ (Port 5335) │
└─────────────┘    └──────┬──────────┘    └──────┬──────┘
                          │                      │
                          ▼                      ▼
                   ┌─────────────┐         ┌─────────────┐
                   │  NetAlertX  │         │  Quad9      │
                   │ (Port 20211) │         │ (DoT)       │
                   └─────────────┘         └─────────────┘
                   │ (Port 8090)  │
1. Clients → Pi-hole (DNS-Filterung)
2. Pi-hole → Unbound (rekursive Auflösung mit DNSSEC)
3. Unbound → Quad9 (DNS-over-TLS)
4. NetAlertX → Netzwerkgeräte-Monitoring
5. Python API → Aggregierte Monitoring-Daten
## 🔌 **API-Referenz**
### **Authentifizierung**
Alle Endpunkte erfordern den `X-API-Key`-Header:
curl -H "X-API-Key: $(grep SUITE_API_KEY .env | cut -d= -f2)" http://127.0.0.1:8090/health
### **Endpunkte**
| Endpunkt | Methode | Beschreibung |
|----------|--------|-------------|
| `/health` | GET | Gesundheitscheck |
| `/info` | GET | Systeminformationen |
| `/stats` | GET | Systemstatistiken |
---
## 🛠️ **Nach der Installation**
### **1. Dienste überprüfen**
```bash
# Host-Modus
systemctl status unbound pihole-FTL pihole-suite
# Container-Modus
docker ps
# Unbound testen
dig @127.0.0.1 -p 5335 example.com +short
# Python API testen
API_KEY=$(grep SUITE_API_KEY .env | cut -d= -f2)
curl -H "X-API-Key: $API_KEY" http://127.0.0.1:8090/health
```
### **2. Clients konfigurieren**
- Pi-hole (192.168.x.x) als DNS-Server auf allen Geräten einrichten.
- **Zugriff:**
  - Pi-hole Admin: `http://[Server-IP]` (Host-Modus) oder `http://[Server-IP]:8080` (Container-Modus)
  - NetAlertX: `http://[Server-IP]:20211`
  - Python API: `http://127.0.0.1:8090/docs`
## 🧪 **Problembehandlung**
### **Häufige Probleme**
| Problem | Lösung |
|-------|----------|
| Port 53 belegt | `sudo systemctl stop systemd-resolved` |
| APT-Konflikte | Flag `--auto-remove-conflicts` verwenden |
| Docker-Berechtigungen | `sudo usermod -aG docker $USER` + Neuanmeldung |
| Unbound startet nicht | `/etc/unbound/unbound.conf.d/` prüfen |
| API-Key fehlt | Neu generieren mit `openssl rand -hex 16` |

### **Gesundheitschecks**
# Unbound
dig @127.0.0.1 -p 5335 example.com +short
# Pi-hole (Host-Modus)
# Docker (Container-Modus)
docker logs pihole netalertx
# Python Suite
systemctl status pihole-suite  # Host-Modus
### **systemd-resolved (Ubuntu)**
Dieses Skript deaktiviert `systemd-resolved`, um Port 53 freizugeben:
# Ursprüngliches Verhalten wiederherstellen
sudo mv /etc/resolv.conf.bak /etc/resolv.conf
sudo systemctl enable --now systemd-resolved
## 🔒 **Sicherheitshinweise**
### **API-Sicherheit**
- Automatisch generierte Keys: 16-Byte-Hex (`openssl rand -hex 16`)
- CORS: Auf localhost beschränkt
- Authentifizierung: Für alle Endpunkte erforderlich
### **Systemd-Hardening**
```ini
[Service]
NoNewPrivileges=yes
ProtectSystem=full
PrivateTmp=yes
MemoryDenyWriteExecute=yes
```
### **Netzwerksicherheit**
- Unbound: Nur localhost (127.0.0.1:5335)
- NetAlertX: Containerisiert (isoliert vom Host)
- DNS-over-TLS: Verschlüsselte Upstream-Verbindung zu Quad9
## 🤝 **Mitwirken**
1. Repository forken
2. Feature-Branch erstellen: `git checkout -b feat/ihr-feature`
3. Änderungen commiten: `git commit -m 'feat: füge ihr Feature hinzu'`
4. Pushen und einen Pull Request öffnen
## 📜 **Lizenz**
MIT-Lizenz – Siehe [LICENSE](LICENSE).
**Mit ❤️ für die Pi-hole-Community entwickelt**
