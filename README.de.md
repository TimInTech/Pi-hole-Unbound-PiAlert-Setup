```markdown
# 🛡️ Pi-hole + Unbound + NetAlertX + Python Suite
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/blob/main/LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Pass-brightgreen?style=for-the-badge&logo=gnu-bash)](https://www.shellcheck.net/)
[![Debian](https://img.shields.io/badge/Debian-11%2B%20%7C%20Ubuntu-22.04%2B-red?style=for-the-badge&logo=debian)](https://debian.org/)
<img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,bash,python,fastapi,sqlite,docker" alt="Tech Stack" />
**🌐 Sprachen:** [🇬🇧 English](README.md) • 🇩🇪 Deutsch
## ✨ Hauptmerkmale
Dieses Repository bietet einen reproduzierbaren Ein-Klick-Installer für einen sicheren DNS- und Monitoring-Stack (Pi-hole, Unbound mit DoT, NetAlertX und eine kleine Python-Suite).

Wesentliche Merkmale
- Ein-Klick-Installation (Host- oder Containermodus)
- Idempotent mit Checkpoint-Fortsetzung
- DNSSEC und DoT Upstream (standardmäßig Quad9)
- Optional containerisierte Pi-hole & NetAlertX
- Systemd-Härtung für Host-Modus-Services
# 🛡️ Pi-hole + Unbound + NetAlertX + Python Suite

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/blob/main/LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Pass-brightgreen?style=for-the-badge&logo=gnu-bash)](https://www.shellcheck.net/)
[![Debian](https://img.shields.io/badge/Debian-11%2B%20%7C%20Ubuntu-22.04%2B-red?style=for-the-badge&logo=debian)](https://debian.org/)

<img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,bash,python,fastapi,sqlite,docker" alt="Tech Stack" />

**🌐 Sprachen:** [🇬🇧 English](README.md) • 🇩🇪 Deutsch

## ✨ Hauptmerkmale

Dieses Repository bietet einen reproduzierbaren Ein-Klick-Installer für einen sicheren DNS- und Monitoring-Stack (Pi-hole, Unbound mit DoT, NetAlertX und eine kleine Python-Suite).

Wesentliche Merkmale

- Ein-Klick-Installation (Host- oder Containermodus)
- Idempotent mit Checkpoint-Fortsetzung
- DNSSEC und DoT Upstream (standardmäßig Quad9)
- Optional containerisierte Pi-hole & NetAlertX
- Systemd-Härtung für Host-Modus-Services

## ⚡ Schnellstart

1) Repository klonen

```bash
git clone https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup.git
cd Pi-hole-Unbound-PiAlert-Setup
chmod +x install.sh
```

2) Installationsmodus wählen

### Option A: Host-Modus (Standard)

```bash
sudo ./install.sh
```

- Nutzt systemd für alle Dienste
- Unbound: localhost:5335 (DNSSEC + DoT zu Quad9)
- Pi-hole: Standard-Ports (53, 80)
- Python Suite: Systemd-Dienst mit Sicherheitshärtung

### Option B: Container-Modus

```bash
sudo ./install.sh --container-mode
```


- Pi-hole und NetAlertX laufen in Docker

Port-Mappings:

- Pi-hole DNS: 8053→53 (Host→Container)
- Pi-hole Web: 8080→80
- NetAlertX: 20211→20211

- Python Suite läuft im Vordergrund (kein systemd)

### 3. Erweiterte Optionen

| Flag | Beschreibung |
|------|-------------|
| `--resume` | Fortsetzen vom letzten Checkpoint |
| `--force` | Alle Zustände zurücksetzen und neu installieren |
| `--dry-run` | Zeigt Aktionen ohne Ausführung |
| `--auto-remove-conflicts` | Löst APT-Paketkonflikte automatisch |

## 🗺️ Architektur

```text
┌─────────────┐    ┌─────────────────┐    ┌─────────────┐
│   Clients   │───▶│    Pi-hole     │───▶│   Unbound   │
│ 192.168.x.x │    │ (Port 53/80)   │    │ (Port 5335) │
└─────────────┘    └──────┬──────────┘    └──────┬──────┘
                          │                      │
                          ▼                      ▼
                   ┌─────────────┐         ┌─────────────┐
                   │  NetAlertX  │         │  Quad9      │
                   │ (Port 20211)│         │ (DoT)       │
                   └─────────────┘         └─────────────┘
```


1. Clients → Pi-hole (DNS-Filterung)
2. Pi-hole → Unbound (rekursive Auflösung mit DNSSEC)
3. Unbound → Quad9 (DNS-over-TLS)
4. NetAlertX → Netzwerkgeräte-Monitoring
5. Python API → Aggregierte Monitoring-Daten


## 🔌 API-Referenz

### Authentifizierung

Alle Endpunkte erfordern den `X-API-Key`-Header. Beispiel:

```bash
API_KEY=$(grep SUITE_API_KEY .env | cut -d= -f2)
curl -H "X-API-Key: $API_KEY" http://127.0.0.1:8090/health
```

### Endpunkte

| Endpunkt | Methode | Beschreibung |
|----------|--------|-------------|
| `/health` | GET | Gesundheitscheck |
| `/info` | GET | Systeminformationen |
| `/stats` | GET | Systemstatistiken |

## 🛠️ Nach der Installation

### 1. Dienste überprüfen

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

### 2. Clients konfigurieren

- Pi-hole (192.168.x.x) als DNS-Server auf allen Geräten einrichten.

Zugriff:

- Pi-hole Admin: `http://[Server-IP]` (Host-Modus) oder `http://[Server-IP]:8080` (Container-Modus)
- NetAlertX: `http://[Server-IP]:20211`
- Python API: `http://127.0.0.1:8090/docs`


## 🧪 Problembehandlung

### Häufige Probleme

| Problem | Lösung |
|-------|----------|
| Port 53 belegt | `sudo systemctl stop systemd-resolved` |
| APT-Konflikte | Flag `--auto-remove-conflicts` verwenden |
| Docker-Berechtigungen | `sudo usermod -aG docker $USER` + Neuanmeldung |
| Unbound startet nicht | `/etc/unbound/unbound.conf.d/` prüfen |
| API-Key fehlt | Neu generieren mit `openssl rand -hex 16` |

### Gesundheitschecks

```bash
dig @127.0.0.1 -p 5335 example.com +short
docker logs pihole netalertx
systemctl status pihole-suite
```

### systemd-resolved (Ubuntu)

Dieses Projekt enthält Skripte, die `systemd-resolved` deaktivieren können, um Port 53 freizugeben. Zur Wiederherstellung:

```bash
sudo mv /etc/resolv.conf.bak /etc/resolv.conf
sudo systemctl enable --now systemd-resolved
```

## � Sicherheitshinweise

- API-Keys geheim halten; CORS auf localhost beschränken.
- Systemd-Sandboxing für Host-Mode bevorzugen (siehe SECURITY.md).
- Installer auf dedizierten Hosts/VMs ausführen.

### Systemd-Hardening

```ini
[Service]
NoNewPrivileges=yes
ProtectSystem=full
PrivateTmp=yes
MemoryDenyWriteExecute=yes
```

## 🤝 Mitwirken

1. Fork
2. Branch erstellen: git checkout -b feat/your-feature
3. Commit & push
4. PR öffnen

## 📜 Lizenz

MIT-Lizenz – siehe LICENSE

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
