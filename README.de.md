<div align="center">

# 🛡️ Pi-hole + Unbound + NetAlertX
### **One-Click DNS Security & Monitoring Stack**

[![Build Status](https://img.shields.io/github/actions/workflow/status/TimInTech/Pi-hole-Unbound-PiAlert-Setup/ci.yml?branch=main&style=for-the-badge&logo=github)](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/actions)
[![License](https://img.shields.io/github/license/TimInTech/Pi-hole-Unbound-PiAlert-Setup?style=for-the-badge&color=blue)](LICENSE)
[![Pi-hole](https://img.shields.io/badge/Pi--hole-v6.1.4-red?style=for-the-badge&logo=pihole)](https://pi-hole.net/)
[![Unbound](https://img.shields.io/badge/Unbound-DNS-orange?style=for-the-badge)](https://nlnetlabs.nl/projects/unbound/)
[![NetAlertX](https://img.shields.io/badge/NetAlertX-Monitor-green?style=for-the-badge)](https://github.com/jokob-sk/NetAlertX)
[![Debian](https://img.shields.io/badge/Debian-Compatible-red?style=for-the-badge&logo=debian)](https://debian.org/)
[![Python](https://img.shields.io/badge/Python-3.12+-blue?style=for-the-badge&logo=python)](https://python.org/)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=000&style=for-the-badge)](https://buymeacoffee.com/timintech)



<img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="Tech Stack" />

**🌐 Sprachen:** 🇩🇪 Deutsch (diese Datei) • [🇬🇧 English](README.md)

</div>

---

## ✨ Features

✅ **Pi-hole Core 6.1.4 / FTL 6.1 / Web 6.2** – Eingebauter Webserver (kein lighttpd nötig)  
✅ **Zielplattform:** Raspberry Pi 3/4 (64-bit) mit Debian Bookworm/Trixie (inkl. Raspberry Pi OS)  
✅ **Ein-Klick-Installation** – Setup mit einem Befehl  
✅ **DNS-Sicherheit** – Pi-hole + Unbound mit DNSSEC (optional)  
✅ **Netzwerk-Monitoring** – NetAlertX Geräte-Tracking (optional)  
✅ **API-Monitoring** – Python FastAPI + SQLite (optional)  
✅ **Produktionsbereit** – Systemd-Hardening & Auto-Restart  
✅ **Idempotent** – Sicher mehrfach ausführbar  

> Getestet auf Raspberry Pi 3/4 (64-bit) unter Debian Bookworm/Trixie. Nutzt Pi-hole Core 6.1.4 / FTL 6.1 / Web 6.2 mit eingebautem Webserver – kein lighttpd nötig.

---

## ⚡ Ein-Klick-Schnellstart

```bash
git clone https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup.git
cd Pi-hole-Unbound-PiAlert-Setup
chmod +x install.sh
sudo ./install.sh
````



## 🔴 ZWINGEND erforderlich: Pi-hole muss Unbound als Upstream nutzen

> ⚠️ **Achtung — diesen Schritt nicht überspringen.** Wenn Pi-hole nicht Unbound als Upstream nutzt, ist das Setup **fachlich kaputt** (DNSSEC/DoT werden umgangen).

### Was zwingend sichergestellt werden muss

Pi-hole muss DNS-Anfragen an Unbound weiterleiten (lokal auf Port **5335**):

```text
Client → Pi-hole → Unbound → Internet
```

**Erforderlicher Upstream-Wert:**

```text
127.0.0.1#5335
```

![Pi-hole Installer-Dialog: Specify Upstream DNS Provider(s)](docs/assets/pihole-upstream-dns.png)


### Verhalten dieses Repos

- Wenn du `sudo ./install.sh` ausführst (Standard), setzt der Installer die Pi-hole-v6-Upstreams automatisch in `/etc/pihole/pihole.toml`.
- Wenn du Pi-hole manuell installierst (interaktiver Installer) oder später DNS-Einstellungen änderst, musst du den Upstream **selbst** auf `127.0.0.1#5335` setzen.

### Wenn der Installer-Dialog erscheint

Wenn Pi-hole dich nach **Upstream DNS Provider(s)** fragt, wähle **Custom** und trage ein:

```text
127.0.0.1#5335
```

Wenn stattdessen Google/Cloudflare (oder ein anderer Public DNS) gewählt wird:

- ❌ Unbound wird **nicht** genutzt
- ❌ DNSSEC / DoT sind wirkungslos
- ❌ Setup wirkt „fertig“, ist aber logisch falsch

### Kontrolle nach der Installation

```bash
sudo grep -A5 '^\[dns\]' /etc/pihole/pihole.toml
```

Erwartet:

```toml
[dns]
upstreams = ["127.0.0.1#5335"]
```

**Fertig!** 🎉 Ihr kompletter DNS-Sicherheits-Stack läuft jetzt.

## ✅ Post-Install Prüfung (post_install_check.sh)

Dieses Repo enthält ein **read-only** Prüfskript, mit dem du nach der Installation schnell verifizieren kannst, dass Pi-hole, Unbound (und optional NetAlertX) laufen und korrekt konfiguriert sind.

### Häufige Kommandos

```bash
# Quick check
./scripts/post_install_check.sh --quick

# Full check (mit sudo empfohlen)
sudo ./scripts/post_install_check.sh --full

# Nur URLs anzeigen
./scripts/post_install_check.sh --urls

# Manuelle Schritt-für-Schritt-Anleitung
./scripts/post_install_check.sh --steps | less
```

### Optionen & interaktives Menü

Ausgabe von `--help`:

```text
Usage: post_install_check.sh [OPTIONS]

Post-installation verification script for Pi-hole + Unbound + Pi.Alert setup.
Performs read-only checks to verify service health and configuration.

OPTIONS:
  --quick       Run quick check (summary only)
  --full        Run full check (all sections)
  --urls        Show service URLs only
  --steps       Show manual step-by-step verification guide
  -h, --help    Show this help message

INTERACTIVE MODE:
  Run without arguments to enter interactive menu mode.

EXAMPLES:
  post_install_check.sh --quick           # Quick status check
  post_install_check.sh --full            # Comprehensive check
  post_install_check.sh --urls            # Display service URLs
  post_install_check.sh --steps | less    # View manual verification steps
  post_install_check.sh                   # Interactive menu

NOTES:
  - This script performs read-only checks only
  - Some checks may require sudo privileges
  - Running with sudo is recommended for complete checks
  - Pi-hole v6 uses /etc/pihole/pihole.toml as authoritative config
```

Interaktiver Modus:

```text
[1] Quick Check (summary only)
[2] Full Check (all sections)
[3] Show Service URLs
[4] Service Status
[5] Network Info
[6] Exit
```


> Schlanke Installation? Nutze `--skip-netalertx`, `--skip-python-api` oder `--minimal`, um nur die Kernkomponenten zu installieren.

---

## 🧰 Was installiert wird

| Komponente        | Zweck                             | Zugriff                  | Hinweis                                                   |
| ----------------- | --------------------------------- | ------------------------ | --------------------------------------------------------- |
| **🕳️ Pi-hole**   | DNS-Werbeblocker & Web-Oberfläche | `http://[ihre-ip]/admin` | Core 6.1.4 / FTL 6.1 / Web 6.2 (eingebauter Webserver)   |
| **🔐 Unbound**    | Rekursiver DNS + DNSSEC           | `127.0.0.1:5335`         | Optional; eigenen Upstream nutzen, falls Unbound entfällt |
| **📡 NetAlertX**  | Netzwerkgeräte-Monitoring         | `http://[ihre-ip]:20211` | Optional (`--skip-netalertx`)                             |
| **🐍 Python API** | Monitoring- & Statistik-API       | `http://127.0.0.1:8090`  | Optional (`--skip-python-api` oder `--minimal`)           |

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

#### `GET /leases`

```json
[
  {
    "ip": "192.168.1.101",
    "mac": "aa:bb:cc:dd:ee:ff",
    "hostname": "drucker",
    "lease_start": "2024-12-21 10:00:00",
    "lease_end": "2024-12-21 12:00:00"
  }
]
```

### Authentifizierung

Alle Endpunkte benötigen den `X-API-Key`-Header:

```bash
curl -H "X-API-Key: $SUITE_API_KEY" http://127.0.0.1:8090/endpoint
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

1. Admin-Oberfläche aufrufen: `http://[ihre-ip]/admin`
2. **Einstellungen → DNS** navigieren
3. **Custom Upstream** setzen: `127.0.0.1#5335`
4. Geräte im Netzwerk konfigurieren, um Pi-hole als DNS-Server zu nutzen

### NetAlertX-Setup

* Dashboard aufrufen: `http://[ihre-ip]:20211`
* Scan-Zeitpläne und Benachrichtigungen konfigurieren
* Netzwerk-Topologie und Geräteliste prüfen

---

## 🧪 Gesundheitschecks & Problembehandlung

### Post-Install-Prüfskript

Führen Sie das automatisierte Verifizierungsskript aus, um Ihre Installation zu überprüfen:

```bash
# Interaktives Menü (empfohlen)
sudo ./scripts/post_install_check.sh

# Schnellprüfung (nur Zusammenfassung)
sudo ./scripts/post_install_check.sh --quick

# Vollständige Prüfung
sudo ./scripts/post_install_check.sh --full

# Service-URLs anzeigen
./scripts/post_install_check.sh --urls
```


**Verfügbare Optionen (`--help`):**

```text
Usage: post_install_check.sh [OPTIONS]

Post-installation verification script for Pi-hole + Unbound + Pi.Alert setup.
Performs read-only checks to verify service health and configuration.

OPTIONS:
  --quick       Run quick check (summary only)
  --full        Run full check (all sections)
  --urls        Show service URLs only
  --steps       Show manual step-by-step verification guide
  -h, --help    Show this help message
```

**Interaktives Menü (ohne Argumente, TTY):**

```text
┌─────────────────────────────────────────────────────────────────┐
│         Pi-hole + Unbound Post-Install Check v1.0.0           │
├─────────────────────────────────────────────────────────────────┤
│ [1] Quick Check (summary only)                                  │
│ [2] Full Check (all sections)                                   │
│ [3] Show Service URLs                                           │
│ [4] Service Status                                              │
│ [5] Network Info                                                │
│ [6] Exit                                                        │
└─────────────────────────────────────────────────────────────────┘
```

**Auszug der manuellen Schritte (`--steps`):**

```text
STEP 1: Verify Unbound DNS Service
...
STEP 2: Verify Pi-hole Service
...
STEP 3: Verify Pi-hole v6 Configuration (CRITICAL)
  upstreams = ["127.0.0.1#<UNBOUND_PORT>"]
```

**Was wird geprüft:**

✅ Systeminformationen (OS, Netzwerk, Routen)
✅ Unbound-Dienststatus und DNS-Auflösung
✅ Pi-hole FTL-Dienst und Port-53-Listener
✅ **Pi-hole v6 Upstream-Konfiguration** in `/etc/pihole/pihole.toml`
✅ Docker-Container (NetAlertX, Pi.Alert)
✅ Netzwerkkonfiguration und DNS-Einstellungen

**Beispielausgabe:**

```
=== Pi-hole v6 Configuration ===
[PASS] Pi-hole v6 config file exists: /etc/pihole/pihole.toml
[PASS] Pi-hole v6 upstreams configured: upstreams = ["127.0.0.1#5335"]

┌─────────────────────────────────────────────────────────────────┐
│                         Check Summary                           │
├─────────────────────────────────────────────────────────────────┤
│ PASS: 12                                                        │
│ WARN: 1                                                         │
│ FAIL: 0                                                         │
└─────────────────────────────────────────────────────────────────┘
```

**Status-Bedeutungen:**

* **[PASS]** - Komponente funktioniert korrekt
* **[WARN]** - Komponente benötigt möglicherweise Aufmerksamkeit, System ist aber funktionsfähig
* **[FAIL]** - Kritisches Problem erkannt, Maßnahme erforderlich

> **Hinweis:** Die Ausführung mit `sudo` wird für vollständige Prüfungen empfohlen. Das Skript führt nur Nur-Lese-Operationen aus und ändert keine Konfiguration.

### Pi-hole v6 Konfigurationshinweis

**Pi-hole v6** verwendet `/etc/pihole/pihole.toml` als **maßgebliche Konfigurationsdatei** für alle Einstellungen, einschließlich DNS-Upstreams. Der Installer konfiguriert automatisch:

```toml
[dns]
upstreams = ["127.0.0.1#5335"]
```

Dies stellt sicher, dass Pi-hole v6 immer Unbound als DNS-Upstream verwendet. Die veraltete `setupVars.conf` wird für Rückwärtskompatibilität beibehalten, ist aber nicht die primäre Konfigurationsquelle in v6.

Um Ihre Pi-hole v6 Upstream-Konfiguration zu überprüfen:

```bash
# Maßgebliche Konfiguration prüfen
sudo grep -A2 '^\[dns\]' /etc/pihole/pihole.toml

# Oder das Post-Install-Prüfskript verwenden
sudo ./scripts/post_install_check.sh --full
```

### Interaktives Konsolenmenü

Zugriff auf alle Verifizierungs- und Wartungstools über ein interaktives Menü:

```bash
# Konsolenmenü starten
./scripts/console_menu.sh

# Oder einen Alias für mehr Komfort erstellen
echo "alias pihole-suite='bash ~/Pi-hole-Unbound-PiAlert-Setup/scripts/console_menu.sh'" >> ~/.bash_aliases
source ~/.bash_aliases
pihole-suite
```

Das Konsolenmenü bietet:
- Schnell- und Vollprüfungen
- Anzeige der Service-URLs
- Leitfaden für manuelle Verifizierung
- Zugriff auf Maintenance Pro (mit Bestätigungen)
- Log-Ansicht
- Dialog-basierte UI (falls installiert) oder Text-Fallback

Siehe [docs/CONSOLE_MENU.md](docs/CONSOLE_MENU.md) für detaillierte Nutzung.

### Schneller manueller Gesundheitscheck

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
sudo systemctl restart pihole-suite
sudo systemctl restart pihole-FTL
docker restart netalertx
```

### Häufige Probleme

| Problem                                  | Lösung                                                                                                                                   |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **Port 53 belegt (systemd-resolved)**    | `sudo systemctl disable --now systemd-resolved`; danach `./install.sh --resume` ausführen. Prüfen mit `sudo ss -tulpen | grep :53`. |
| **FTL-DB/UI-Korruption nach Upgrade**    | Logs prüfen mit `sudo journalctl -u pihole-FTL -n 50`, dann neustarten: `sudo systemctl restart pihole-FTL`.           |
| **DNS-Ausfälle / Upstream-Fehler**       | `dig @127.0.0.1 -p 5335 example.com`; Konfiguration prüfen mit `./scripts/post_install_check.sh --full`; bei Problemen `./install.sh --force` erneut anwenden. |
| **API-Key fehlt**                        | `.env` prüfen oder mit dem Installer neu generieren (`SUITE_API_KEY`).                                                                   |

---

## 🧯 Sicherheitshinweise

### 🔐 API-Sicherheit

* **API-Keys** werden automatisch generiert (16-Byte Hex)
* **CORS** nur für localhost aktiviert
* **Authentifizierung** für alle Endpunkte erforderlich

### 🛡️ Systemd-Hardening

* `NoNewPrivileges` verhindert Rechte-Eskalation
* `ProtectSystem=strict` schützt das Dateisystem
* `PrivateTmp` isoliert temporäre Verzeichnisse
* Speicherlimits verhindern Ressourcenüberlastung

### 🔒 Netzwerk-Sicherheit

* **Unbound** lauscht nur auf `localhost`
* DNS über TLS zu Upstream-Resolvern
* DNSSEC-Validierung ist aktiviert

---

## 🤝 Mitwirken

1. **Repository forken**
2. **Feature-Branch erstellen**: `git checkout -b feature/tolles-feature`
3. **Änderungen committen**: `git commit -m 'feat: tolles Feature hinzugefügt'`
4. **Testen mit**: `ruff check . && pytest`
5. **Push** und Pull Request erstellen

---

## 📜 Lizenz

Dieses Projekt ist unter der **MIT-Lizenz** lizenziert – siehe [LICENSE](LICENSE)-Datei.

---

## 📈 Changelog

Siehe [CHANGELOG.md](CHANGELOG.md) für Versionsverlauf und Updates.

---

<div align="center">

**Mit ❤️ für die Pi-hole-Community entwickelt**

[🐛 Bug melden](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/issues) •
[✨ Feature anfordern](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/issues) •
[💬 Diskussionen](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/discussions)

</div>
