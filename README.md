<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# 🛡️ Pi-hole + Unbound + NetAlertX

## **One-Click DNS Security & Monitoring Stack**

[![Build Status](https://img.shields.io/github/actions/workflow/status/TimInTech/Pi-hole-Unbound-PiAlert-Setup/ci.yml?branch=main&style=for-the-badge&logo=github)](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/actions)
[![License](https://img.shields.io/github/license/TimInTech/Pi-hole-Unbound-PiAlert-Setup?style=for-the-badge&color=blue)](LICENSE)
[![Pi-hole](https://img.shields.io/badge/Pi--hole-v6.1.4-red?style=for-the-badge&logo=pihole)](https://pi-hole.net/)
[![Unbound](https://img.shields.io/badge/Unbound-DNS-orange?style=for-the-badge)](https://nlnetlabs.nl/projects/unbound/)
[![NetAlertX](https://img.shields.io/badge/NetAlertX-Monitor-green?style=for-the-badge)](https://github.com/jokob-sk/NetAlertX)
[![Debian](https://img.shields.io/badge/Debian-Compatible-red?style=for-the-badge&logo=debian)](https://debian.org/)
[![Python](https://img.shields.io/badge/Python-3.12+-blue?style=for-the-badge&logo=python)](https://python.org/)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=000&style=for-the-badge)](https://buymeacoffee.com/timintech)
  
<img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="Tech Stack" />

**🌐 Languages:** 🇬🇧 English (this file) • [🇩🇪 Deutsch](README.de.md)

</div>
<!-- markdownlint-enable MD033 MD041 -->

---

## ✨ Features

✅ **Pi-hole Core 6.1.4 / FTL 6.1 / Web 6.2** – Built-in Pi-hole web server (no lighttpd)  
✅ **Target:** Raspberry Pi 3/4 (64-bit) on Debian Bookworm/Trixie (incl. Raspberry Pi OS)  
✅ **One-Click Installation** – Single command setup  
✅ **DNS Security** – Pi-hole + Unbound with DNSSEC (optional)  
✅ **Network Monitoring** – NetAlertX device tracking (optional)  
✅ **API Monitoring** – Python FastAPI + SQLite (optional)  
✅ **Production Ready** – Systemd hardening & auto-restart  
✅ **Idempotent** – Safe to re-run anytime  

> Tested on Raspberry Pi 3/4 (64-bit) running Debian Bookworm/Trixie (including Raspberry Pi OS). Uses Pi-hole Core 6.1.4 / FTL 6.1 / Web 6.2 with the built-in web server—no lighttpd required.

---

## ⚡ Quickstart

```bash
git clone https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup.git
cd Pi-hole-Unbound-PiAlert-Setup
chmod +x install.sh
sudo ./install.sh
````

## ✅ Prerequisites

- Supported: Debian/Ubuntu-family systems with `apt-get` and `systemd`.
- Clone as a normal user (do **not** run `sudo git clone` / do not work from a root shell).
- Run the installer via `sudo ./install.sh` (running as root directly is rejected on purpose).

The installer writes:
- Logs: `/var/log/pihole-suite/install.log` and `/var/log/pihole-suite/install_errors.log`
- Suite env (API key): `/etc/pihole-suite/pihole-suite.env`

If you want to install prerequisites manually:

```bash
sudo apt-get update
sudo apt-get install -y git curl jq dnsutils iproute2 openssl python3 python3-venv python3-pip ca-certificates
```


## 🔴 Required Step: Ensure Pi-hole Uses Unbound (Upstream DNS)

> ⚠️ **Important — do NOT skip this.** If Pi-hole does not use Unbound as its upstream, this stack is **functionally broken** (DNSSEC/DoT will be bypassed).

### What you must ensure

Pi-hole must forward DNS queries to Unbound running locally on port **5335**:

```text
Client → Pi-hole → Unbound → Internet
```

**Required upstream value:**

```text
127.0.0.1#5335
```

![Pi-hole installer dialog: Specify Upstream DNS Provider(s)](docs/assets/pihole-upstream-dns.png)


### How this repo behaves

- When you run `sudo ./install.sh` (default), the installer configures Pi-hole v6 upstreams automatically in `/etc/pihole/pihole.toml`.
- If you install Pi-hole manually (interactive installer), or you change DNS settings later, you **must** set the upstream to `127.0.0.1#5335` yourself.

### If you see the installer dialog

If Pi-hole asks you to **Specify Upstream DNS Provider(s)**, choose **Custom** and enter:

```text
127.0.0.1#5335
```

If you select Google/Cloudflare (or any public DNS):

- ❌ Unbound will NOT be used
- ❌ DNSSEC / DoT will be bypassed
- ❌ The setup is technically “installed” but logically wrong

### Verify after installation

```bash
sudo grep -A5 '^\[dns\]' /etc/pihole/pihole.toml
```

Expected:

```toml
[dns]
upstreams = ["127.0.0.1#5335"]
```

**Done!** 🎉 Your complete DNS security stack is now running.

## ✅ Post-Install Verification (post_install_check.sh)

This repo ships a **read-only** verification tool to quickly confirm that Pi-hole, Unbound (and optionally NetAlertX) are up and configured correctly.

Note: The script output is **English-only** (messages are not localized). If you see German output, you're likely running a modified/older copy — check `./scripts/post_install_check.sh --version`.

### Common commands

```bash
# Quick check
./scripts/post_install_check.sh --quick

# Full check (recommended with sudo)
sudo ./scripts/post_install_check.sh --full

# Show URLs only
./scripts/post_install_check.sh --urls

# View manual steps
./scripts/post_install_check.sh --steps | less
```

### Options & interactive menu

### Troubleshooting notes

If you see **German output**, you're not running the repo version (it is English-only). Check:

```bash
./scripts/post_install_check.sh --version
readlink -f ./scripts/post_install_check.sh
```

**NetAlertX / Pi.Alert Next (Docker):** This repo runs NetAlertX as a Docker container named `netalertx`. It's normal to have **no systemd service** for it. This setup uses **host networking** (recommended for device discovery), so Docker may not show a `0.0.0.0:PORT->...` mapping. Verify network mode:

```bash
sudo docker inspect -f '{{.HostConfig.NetworkMode}}' netalertx
# expected: host
```

Web UI: `http://[your-ip]:20211`

**Python API (`pihole-suite`, optional):** A local FastAPI service bound to `127.0.0.1:8090` with API-key auth (`X-API-Key`). It exposes read-only endpoints like `/health`, `/dns`, `/leases`, `/stats`. Some endpoints may return empty data depending on logs/permissions.


`--help` output:

```text
Usage: post_install_check.sh [OPTIONS]

Post-installation verification script for Pi-hole + Unbound + Pi.Alert setup.
Performs read-only checks to verify service health and configuration.

OPTIONS:
  --version     Show script version
  --quick       Run quick check (summary only)
  --full        Run full check (all sections)
  --urls        Show service URLs only
  --steps       Show manual step-by-step verification guide
  -h, --help    Show this help message

INTERACTIVE MODE:
  Run without arguments to enter interactive menu mode.

EXAMPLES:
  post_install_check.sh --version         # Show version
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

Interactive mode:

```text
[1] Quick Check (summary only)
[2] Full Check (all sections)
[3] Show Service URLs
[4] Service Status
[5] Network Info
[6] Exit
```

### Example output (full check)

Shortened real-world example from a Raspberry Pi run (`sudo ./scripts/post_install_check.sh --full`). Exact values vary by system.

```text
────────────────────────────────────────────────────────────────
POST-INSTALL CHECK — Pi-hole v6 / Unbound / Docker / Pi.Alert
Script: post_install_check.sh v1.0.0 (output language: English)
────────────────────────────────────────────────────────────────
Time                 2026-01-01T14:38:40+00:00
Host                 raspberrypi
OS                   Debian GNU/Linux 13 (trixie)
Kernel               6.12.47+rpt-rpi-v8
Default IF / GW      eth0 / 192.168.178.1
IPv4                 192.168.178.52,172.17.0.1
IPv6                 none

URLs (best guess)
• Pi-hole Admin: http://192.168.178.52/admin
• Pi.Alert/NetAlertX: (port 20211/8081 not detected — check if service/container is running)

Unbound
Service unbound.service            ✔  running
Listener 127.0.0.1:5335            ✔  TCP/UDP bound
dig @127.0.0.1#5335 cloudflare.com ✔  104.16.133.229

Pi-hole v6
Service pihole-FTL                 ✔  running
DNS Listener :53                   ✔  at least one listener active
pihole.toml Upstream               ⚠
dig @127.0.0.1 example.org         ✔  Pi-hole answered DNS

Docker
docker                             ✔  docker reachable
Running containers:
• netalertx  (Image: jokobsk/netalertx:latest)  Ports: 

Pi.Alert Next / NetAlertX
Service (pialert/netalertx)        ⚠  no systemd service found
Docker container (pialert/netalertx) ✔  container running

Summary
⚠ Basically OK, but there are warnings (check upstream/services).

Optional hard proof (if tcpdump installed):
  sudo tcpdump -i lo port 5335 -n  # parallel: dig example.org @127.0.0.1
```



> Prefer a slim install? Use `--skip-netalertx`, `--skip-python-api`, or `--minimal` to omit optional components.

---

## 🧰 What’s Installed

| Component         | Purpose                   | Access                   | Notes                                                |
| ----------------- | ------------------------- | ------------------------ | ---------------------------------------------------- |
| **🕳️ Pi-hole**   | DNS ad-blocker & web UI   | `http://[your-ip]/admin` | Core 6.1.4 / FTL 6.1 / Web 6.2 (built-in web server) |
| **🔐 Unbound**    | Recursive DNS + DNSSEC    | `127.0.0.1:5335`         | Optional (replace with your own upstream resolver)   |
| **📡 NetAlertX**  | Network device monitoring | `http://[your-ip]:20211` | Optional (`--skip-netalertx`)                        |
| **🐍 Python API** | Monitoring & stats API    | `http://127.0.0.1:8090`  | Optional (`--skip-python-api` or `--minimal`)        |


**NetAlertX data persistence**

- Container uses `/opt/netalertx/data` on the host mounted to `/data` in the container.
- If you previously used legacy mounts (`/opt/netalertx/config` and `/opt/netalertx/db`), migrate your data into `/opt/netalertx/data` before recreating the container.

---

## 🗺️ Architecture

```text
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Clients   │───▶│   Pi-hole    │───▶│   Unbound   │
│ 192.168.x.x │    │    :53       │    │   :5335     │
└─────────────┘    └──────┬───────┘    └─────────────┘
                          │                     │
                          ▼                     ▼
                   ┌─────────────┐    ┌─────────────┐
                   │  NetAlertX  │    │ Root Servers│
                   │   :20211    │    │   + Quad9   │
                   └─────────────┘    └─────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │ Python API  │
                   │   :8090     │
                   └─────────────┘
```

**Data Flow:**

1. **Clients** → Pi-hole (DNS filtering)
2. **Pi-hole** → Unbound (recursive resolution)
3. **Unbound** → Root servers (DNSSEC validation)
4. **NetAlertX** → Network monitoring
5. **Python API** → Aggregated monitoring data

---

## 🔌 API Reference

### Authentication

The installer generates an API key in `/etc/pihole-suite/pihole-suite.env` (`SUITE_API_KEY`). You can inspect it with `sudo cat /etc/pihole-suite/pihole-suite.env`.

### Smoke Test

```bash
# Load API key from the installer env file
SUITE_API_KEY="$(sudo awk -F= '/^SUITE_API_KEY=/{print $2}' /etc/pihole-suite/pihole-suite.env)"

# Ensure the service is running
sudo systemctl restart pihole-suite
sudo systemctl --no-pager --full status pihole-suite

# Call health endpoint
curl -s -H "X-API-Key: $SUITE_API_KEY" http://127.0.0.1:8090/health
```

### Endpoints

#### `GET /version`

Returns API version + uptime.

#### `GET /urls`

Returns best-guess URLs for Pi-hole / NetAlertX and the local Suite bind.

#### `GET /pihole`

Returns Pi-hole version/FTL status and configured v6 upstreams (from `pihole.toml`).

#### `GET /unbound`

Checks Unbound service + a quick `dig` against `127.0.0.1:${UNBOUND_PORT}`.

#### `GET /netalertx`

Checks whether NetAlertX responds on `http://127.0.0.1:20211` (host mode).

#### `GET /health`

```json
{
  "ok": true,
  "message": "Pi-hole Suite API is running",
  "version": "1.0.0"
}
```

#### `GET /leases`

```json
[
  {
    "ip": "192.168.1.101",
    "mac": "aa:bb:cc:dd:ee:ff",
    "hostname": "printer",
    "lease_start": null,
    "lease_end": "2026-01-01T14:38:40+00:00"
  }
]
```

Note: `lease_start` may be `null` (not available in all lease sources).

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
[]
```

Note: Device data depends on NetAlertX/Pi.Alert APIs/DB and is not populated in this minimal Suite API yet.

#### `GET /stats`

```json
{
  "total_dns_logs": 89,
  "total_devices": 0,
  "recent_queries": 89,
  "note": "DNS stats are derived from best-effort log parsing; may be empty depending on Pi-hole logging/permissions."
}
```

---

## 🛠️ Optional Manual Steps

### Pi-hole

1. Open `http://[your-ip]/admin`
2. Go to **Settings → DNS**
3. Verify **Custom upstream**: `127.0.0.1#5335`
4. Configure devices to use Pi-hole as DNS server

### NetAlertX

* Dashboard: `http://[your-ip]:20211`
* Configure scan schedules and notifications
* Review network topology and device list

---

## 🧪 Health Checks & Troubleshooting

### Post-Install Check Script

For automated checks, use `./scripts/post_install_check.sh` (see **Post-Install Verification (post_install_check.sh)** earlier in this README for commands and options).

**What it checks:**

✅ System information (OS, network, routes)
✅ Unbound service status and DNS resolution
✅ Pi-hole FTL service and port 53 listener
✅ **Pi-hole v6 upstream configuration** in `/etc/pihole/pihole.toml`
✅ Docker containers (NetAlertX, Pi.Alert)
✅ Network configuration and DNS settings

**Example output:**

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

**Status meanings:**

* **[PASS]** - Component is working correctly
* **[WARN]** - Component may need attention but system is functional
* **[FAIL]** - Critical issue detected, requires action

> **Note:** Running with `sudo` is recommended for complete checks. The script performs read-only operations and does not modify any configuration.

### Pi-hole v6 Configuration Note

**Pi-hole v6** uses `/etc/pihole/pihole.toml` as the **authoritative configuration file** for all settings, including DNS upstreams. The installer automatically configures:

```toml
[dns]
upstreams = ["127.0.0.1#5335"]
```

This ensures Pi-hole v6 always uses Unbound as its DNS upstream. The legacy `setupVars.conf` is maintained for backward compatibility but is not the primary configuration source in v6.

To verify your Pi-hole v6 upstream configuration:

```bash
# Check the authoritative config
sudo grep -A2 '^\[dns\]' /etc/pihole/pihole.toml

# Or use the post-install check script
sudo ./scripts/post_install_check.sh --full
```

### Interactive Console Menu

Access all verification and maintenance tools through an interactive menu:

```bash
# Start the console menu
./scripts/console_menu.sh

# Or create an alias for convenience
echo "alias pihole-suite='bash ~/Pi-hole-Unbound-PiAlert-Setup/scripts/console_menu.sh'" >> ~/.bash_aliases
source ~/.bash_aliases
pihole-suite
```

The console menu provides:
![Console menu: Pi-hole Suite Management](docs/assets/Screenshot%202026-01-01%20161018.png)

![View logs: Pi-hole + Unbound Management Suite](docs/assets/Pi-hole%20Unbound%20Management%20Suite.png)


- Quick and full system checks
- Service URL display
- Manual verification steps guide
- Maintenance Pro access (with confirmations)
- Log viewing
- Dialog-based UI (if installed) or text fallback

See [docs/CONSOLE_MENU.md](docs/CONSOLE_MENU.md) for detailed usage.

### Quick Manual Checks

```bash
dig @127.0.0.1 -p 5335 example.com     # Test Unbound
pihole status                          # Test Pi-hole
docker logs netalertx                  # Test NetAlertX
curl -H "X-API-Key: $SUITE_API_KEY" http://127.0.0.1:8090/health  # Test API
```

### Service Management

```bash
systemctl status pihole-suite unbound pihole-FTL
journalctl -u pihole-suite -f
journalctl -u unbound -f
docker ps
```

### Common Issues

| Issue                                | Solution                                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| **Port 53 in use (systemd-resolved)**| `sudo systemctl disable --now systemd-resolved`; re-run `sudo ./install.sh`. Check with `sudo ss -tulpen | grep :53`. |
| **FTL DB/UI corruption after upgrade** | Check logs with `sudo journalctl -u pihole-FTL -n 50`, then restart: `sudo systemctl restart pihole-FTL`. |
| **DNS outages / upstream failing**   | Verify Unbound with `dig @127.0.0.1 -p 5335 example.com`; check config with `./scripts/post_install_check.sh --full`; reapply with `./install.sh --force`. |
| **Missing API key**                  | Check `/etc/pihole-suite/pihole-suite.env` or re-run the installer to regenerate (`SUITE_API_KEY`).                                            |

---

## 🧯 Security Notes

### 🔐 API Security

* Auto-generated API keys (32-byte hex)
* CORS restricted to localhost
* Authentication required for all endpoints

### 🛡️ Systemd Hardening

* **NoNewPrivileges** prevents escalation
* **ProtectSystem=strict** read-only protection
* **PrivateTmp** isolated temp dirs
* **Memory limits** to prevent exhaustion

### 🔒 Network Security

* Unbound bound to localhost only
* DNS over TLS to upstream resolvers
* DNSSEC validation enabled

---

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** changes: `git commit -m 'feat: add amazing feature'`
4. **Run tests**: `ruff check . && pytest`
5. **Push** and create a Pull Request

---

## 📜 License

This project is licensed under the **MIT License** - see [LICENSE](LICENSE).

---

## 📈 Changelog

See [CHANGELOG.md](CHANGELOG.md) for history and updates.

---

<!-- markdownlint-disable MD033 MD036 -->
<div align="center">

### Made with ❤️ for the Pi-hole community

[🐛 Report Bug](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/issues) •
[✨ Request Feature](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/issues) •
[💬 Discussions](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/discussions)

</div>
<!-- markdownlint-enable MD033 MD036 -->
