<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# 🛡️ Pi-hole + Unbound

## **One-Click DNS Security Stack**

[![License](https://img.shields.io/github/license/TimInTech/Pi-hole-Unbound-PiAlert-Setup?style=for-the-badge&color=blue)](LICENSE)
[![Pi-hole](https://img.shields.io/badge/Pi--hole-v6.4-red?style=for-the-badge&logo=pihole)](https://pi-hole.net/)
[![Unbound](https://img.shields.io/badge/Unbound-DNS-orange?style=for-the-badge)](https://nlnetlabs.nl/projects/unbound/)
[![Debian](https://img.shields.io/badge/Debian-Bookworm%2FTrixie-red?style=for-the-badge&logo=debian)](https://debian.org/)
[![Python](https://img.shields.io/badge/Python-3.12+-blue?style=for-the-badge&logo=python)](https://python.org/)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=000&style=for-the-badge)](https://buymeacoffee.com/timintech)

<img src="https://skillicons.dev/icons?i=linux,debian,raspberrypi,bash,python,fastapi" alt="Tech Stack" />

**🌐 Languages:** 🇬🇧 English (this file) • [🇩🇪 Deutsch](README.de.md)

</div>
<!-- markdownlint-enable MD033 MD041 -->

---

## ✨ What This Is

A **production-ready installer and management suite** for running Pi-hole + Unbound on a Raspberry Pi.

**DNS chain:**
```
Client → Pi-hole (port 53) → Unbound (port 5335) → Internet
```

Pi-hole handles ad/tracker blocking; Unbound handles recursive DNS resolution with full DNSSEC validation — no third-party DNS resolver required.

---

## ⚡ Quickstart

```bash
git clone https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup.git
cd Pi-hole-Unbound-PiAlert-Setup
chmod +x install.sh
sudo ./install.sh
```

> Clone as a **normal user** (`pi`), not root. The installer requires `sudo ./install.sh`.

---

## ✅ Requirements

| Requirement | Details |
|---|---|
| **Platform** | Raspberry Pi 3/4/5, Debian Bookworm/Trixie (64-bit) |
| **Pi-hole** | v6.x (installed by this script) |
| **Unbound** | Installed and configured to port 5335 |
| **Python** | 3.12+ (for optional Suite API) |
| **User** | Normal user with sudo |

Install prerequisites manually (optional):
```bash
sudo apt-get update
sudo apt-get install -y git curl jq dnsutils iproute2 openssl python3 python3-venv
```

---

## 🔴 Critical: Pi-hole Must Use Unbound as Upstream

> Without this, the stack is broken — DNSSEC is bypassed and you are using an external resolver.

Pi-hole must forward DNS queries to Unbound on **127.0.0.1#5335**.

**Verify via Pi-hole admin → Settings → DNS:**

![Pi-hole upstream DNS setting](docs/assets/pihole-upstream-dns.png)

**Or via the installer / Rescue Menu:**
```bash
sudo pihole-rescue   # Option 9: Pi-hole → Unbound standard fix
```

---

## 🖥️ Management Tools

This repo ships three complementary management interfaces:

### 1. Console Menu (`scripts/console_menu.sh`)

General-purpose interactive menu for everyday management.

```bash
bash ~/Pi-hole-Unbound-PiAlert-Setup/scripts/console_menu.sh
# or with forced text mode:
bash ~/Pi-hole-Unbound-PiAlert-Setup/scripts/console_menu.sh --text
```

![Console Menu](docs/assets/screenshot_console_menu.png)

| Option | Action |
|--------|--------|
| 1 | Post-Install Check (Quick) |
| 2 | Post-Install Check (Full) — requires sudo |
| 3 | Show Service URLs |
| 4 | Manual Steps Guide |
| 5 | Maintenance Pro — requires sudo |
| 6 | View Logs |
| **7** | **Rescue & Backup Menu** |
| 8 | Exit |

---

### 2. Rescue & Backup Menu (`scripts/rescue_menu.sh`)

Standalone recovery and diagnostic tool. Accessible globally:

```bash
sudo pihole-rescue
```

![Rescue Menu](docs/assets/screenshot_rescue_menu.png)

| Option | Action |
|--------|--------|
| 1 | System status check (services, DNS, ports, temperature) |
| 2 | DNS loop / upstream check |
| 3 | Nightly / diagnostic test |
| 4 | Create backup (pihole.toml + Unbound config + systemd drop-ins) |
| 5 | Restore from backup |
| 6 | Delete old backups |
| **7** | **Last-Known-Good restore** |
| **8** | **Emergency DNS bypass** (Pi → 8.8.8.8/1.1.1.1, reversible) |
| **9** | **Pi-hole → Unbound standard fix** |
| 10 | Router / client DNS hint (FritzBox guide) |
| 11 | Show last report / log |
| 0 | Exit |

**System Status:**

![System Status](docs/assets/screenshot_status_check.png)

**DNS Check:**

![DNS Check](docs/assets/screenshot_dns_check.png)

---

### 3. Maintenance Pro (`tools/pihole_maintenance_pro.sh`)

Batch maintenance script (apt updates, Pi-hole update, gravity update, security scan).

```bash
sudo bash tools/pihole_maintenance_pro.sh
# or with flags:
sudo bash tools/pihole_maintenance_pro.sh --no-apt --no-upgrade
```

Available flags: `--no-apt`, `--no-upgrade`, `--no-gravity`, `--restart-ftl`, `--backup`, `--json`

---

## 📁 Repository Structure

```
Pi-hole-Unbound-PiAlert-Setup/
├── install.sh                     # Main installer
├── start_suite.py                 # Optional REST API (FastAPI/uvicorn)
├── requirements.txt               # Python deps for Suite API
├── .env.example                   # Environment variables template
├── scripts/
│   ├── console_menu.sh            # Interactive management menu
│   ├── rescue_menu.sh             # Rescue & backup menu (sudo pihole-rescue)
│   ├── post_install_check.sh      # Post-install verification
│   ├── nightly_test.sh            # Nightly DNS/service test
│   ├── repo_selftest.sh           # Repo integrity self-test
│   └── lib/
│       └── ui.sh                  # Shared UI library (colors, log helpers)
├── tools/
│   └── pihole_maintenance_pro.sh  # Batch maintenance script
└── docs/
    ├── CONSOLE_MENU.md            # Full menu documentation
    └── assets/                    # Screenshots
```

---

## ⚙️ Post-Install Verification

```bash
# Quick check (no sudo)
bash scripts/post_install_check.sh --quick

# Full check (requires sudo)
sudo bash scripts/post_install_check.sh --full
```

![Post-Install Check](docs/assets/screenshot_post_install.png)

---

## 🆘 Rescue Operations

### Emergency DNS Bypass
When Pi-hole or Unbound is broken and you have no DNS:

```bash
sudo pihole-rescue  # Option 8: Emergency DNS bypass
```

This sets the Pi itself to use 8.8.8.8/1.1.1.1 directly. **Fully reversible** — the menu stores your previous config and lets you restore it.

### Last-Known-Good Restore
Restores your last known-working backup and verifies DNS is working:

```bash
sudo pihole-rescue  # Option 7: Last-Known-Good restore
```

### Backup / Restore
```bash
sudo pihole-rescue  # Option 4: Create backup
sudo pihole-rescue  # Option 5: Restore from backup
```

Backups are stored in `/home/pi/pihole-rescue-backups/` and include:
- `/etc/pihole/pihole.toml`
- `/etc/unbound/unbound.conf.d/`
- Systemd drop-in files

---

## 🐍 Optional: Suite REST API

`start_suite.py` is an **optional** FastAPI server providing a JSON API for monitoring.

```bash
# Setup
cp .env.example .env
nano .env   # set SUITE_API_KEY

# Install deps
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Start
python3 start_suite.py
# API docs: http://127.0.0.1:8090/docs
```

**Not required** for the core Pi-hole + Unbound stack.

---

## 🌐 Optional: NetAlertX

Network device monitoring (separate install):

```bash
sudo ./install.sh --with-netalertx
```

---

## 🔧 Troubleshooting

### DNS not resolving
```bash
sudo pihole-rescue   # Option 2: DNS check, or Option 8: Emergency bypass
```

### Pi-hole not using Unbound
```bash
sudo pihole-rescue   # Option 9: Pi-hole → Unbound fix
```

### Check system status
```bash
systemctl status pihole-FTL unbound
dig +short @127.0.0.1 google.com
dig +short @127.0.0.1 -p 5335 google.com
```

### Run full diagnostic
```bash
sudo bash scripts/post_install_check.sh --full
sudo bash scripts/nightly_test.sh
```

---

## 🛡️ Security Notes

- The Suite API (`start_suite.py`) binds to **127.0.0.1 only** by default
- Always set a strong `SUITE_API_KEY`
- The Pi-hole admin interface is protected by Pi-hole's own authentication
- Unbound runs on port 5335 (not exposed externally unless you configure it)
- See [SECURITY.md](SECURITY.md) for vulnerability reporting

---

## 📜 License

[MIT License](LICENSE) — © TimInTech
