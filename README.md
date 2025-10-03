```markdown
# 🛡️ Pi-hole + Unbound + NetAlertX + Python Suite
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/blob/main/LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Pass-brightgreen?style=for-the-badge&logo=gnu-bash)](https://www.shellcheck.net/)
[![Debian](https://img.shields.io/badge/Debian-11%2B%20%7C%20Ubuntu-22.04%2B-red?style=for-the-badge&logo=debian)](https://debian.org/)
<img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,bash,python,fastapi,sqlite,docker" alt="Tech Stack" />
**🌐 Languages:** 🇬🇧 English • [🇩🇪 Deutsch](README.de.md)
## ✨ Features
This repository provides a reproducible one-click installer for a secure DNS+monitoring stack powered by Pi-hole, Unbound (DNS-over-TLS upstream), NetAlertX and a small Python monitoring suite.

Key features
- One-click installation (host or container mode)
- Idempotent with checkpoint resume
- DNSSEC and DoT upstream (Quad9 by default)
- Optional containerized Pi-hole & NetAlertX
- Systemd hardening for services in Host mode

## ⚡ Quickstart

1) Clone repository

```bash
git clone https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup.git
cd Pi-hole-Unbound-PiAlert-Setup
chmod +x install.sh
```

2) Host mode (default)

```bash
sudo ./install.sh
```

Container mode (example)

```bash
sudo ./install.sh --container-mode
```

Advanced useful flags

```bash
sudo ./install.sh --resume        # continue from last checkpoint
sudo ./install.sh --force         # reset state and reinstall
sudo ./install.sh --dry-run       # only show actions
sudo ./install.sh --container-mode
```

## 🗺️ Architecture

```text
┌─────────────┐    ┌─────────────────┐    ┌─────────────┐
│   Clients   │───▶│    Pi-hole     │───▶│   Unbound   │
│ 192.168.x.x │    │ (Port 53/80)   │    │ (Port 5335) │
└─────────────┘    └──────┬──────────┘    └──────┬──────┘
                          │                      │
                          ▼                      ▼
