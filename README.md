# 🚀 Pi-hole + Unbound + NetAlertX – Modern Setup Guide

[![Build Status](https://img.shields.io/github/actions/workflow/status/TimInTech/Pi-hole-Unbound-PiAlert-Setup/main.yml?branch=main)](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/actions)
[![Unbound](https://img.shields.io/badge/unbound-1.17.1-blue.svg?logo=unbound&logoColor=white)](https://www.nlnetlabs.nl/projects/unbound/about/)
[![Pi-hole](https://img.shields.io/badge/Pi--hole-2023.11-red.svg?logo=pihole&logoColor=white)](https://pi-hole.net/)
[![NetAlertX](https://img.shields.io/badge/NetAlertX-latest-brightgreen.svg)](https://github.com/TechxArtisan/netalertx)
[![Debian](https://img.shields.io/badge/Debian-12.5-lightgrey?logo=debian)](https://www.debian.org/)
[![Python](https://img.shields.io/badge/Python-3.11-blue.svg?logo=python)](https://www.python.org/)

---

## ✨ Einleitung

Diese Suite automatisiert die Installation und Absicherung von **Pi-hole** (DNS Ad-Blocker), **Unbound** (rekursiver DNS Resolver) und **NetAlertX** (Netzwerk-Alarmierung) auf einem Debian-basierten Host. Ziel ist eine robuste, private und wartungsarme Netzwerk-Infrastruktur für anspruchsvolle Self-Hosting-Umgebungen.

---

## 🛠️ Technologien & Abhängigkeiten

- **Unbound** – DNS Resolver  
  ![Unbound](https://img.shields.io/badge/unbound-1.17.1-blue.svg?logo=unbound&logoColor=white)
- **Pi-hole** – Ad-Blocker  
  ![Pi-hole](https://img.shields.io/badge/Pi--hole-2023.11-red.svg?logo=pihole&logoColor=white)
- **NetAlertX** – Netzwerk-Alarmierung  
  ![NetAlertX](https://img.shields.io/badge/NetAlertX-latest-brightgreen.svg)
- **Debian/Linux** – OS  
  ![Debian](https://img.shields.io/badge/Debian-12.5-lightgrey?logo=debian)
- **Python 3.x** – für Skripte & Suite  
  ![Python](https://img.shields.io/badge/Python-3.11-blue.svg?logo=python)

ℹ️ Weitere Abhängigkeiten werden systemweit über `apt` installiert.

---

## ⚡ Installation

```bash
# 1️⃣ System aktualisieren & Basis-Pakete installieren
sudo apt-get update
sudo apt-get install -y unbound ca-certificates curl

# 2️⃣ Root-Hints für Unbound laden
sudo install -d -m 0755 /var/lib/unbound
sudo curl -fsSL https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints

# 3️⃣ Minimal-Konfiguration für Unbound (127.0.0.1:5335)
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

# 4️⃣ Trust-Anchor initialisieren & Unbound starten
sudo unbound-anchor -a /var/lib/unbound/root.key || true
sudo systemctl enable --now unbound
sudo systemctl restart unbound
sudo systemctl status --no-pager unbound

# 5️⃣ Pi-hole DNS neu starten
pihole restartdns
```

---

## 📝 Service Unit Beispiel (systemd)

```ini
[Unit]
Description=Pi-hole Suite (API + workers)
After=network.target

[Service]

[Install]
WantedBy=multi-user.target
```

---

## 📊 Status

[![Build Status](https://img.shields.io/github/actions/workflow/status/TimInTech/Pi-hole-Unbound-PiAlert-Setup/main.yml?branch=main)](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/actions)

---

## 🤝 Mitmachen & Feedback

Verbesserungsvorschläge gern via Pull Request oder Issue.  
Fragen, Fehler oder Erweiterungen bitte klar und strukturiert melden.

---

## 📚 Lizenz & Quellen

Siehe LICENSE-Datei im Repo.  
Projekte: [Pi-hole](https://pi-hole.net/), [Unbound](https://www.nlnetlabs.nl/projects/unbound/about/), [NetAlertX](https://github.com/TechxArtisan/netalertx)