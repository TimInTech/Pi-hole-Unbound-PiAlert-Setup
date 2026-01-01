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

`--help` output:

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

Interactive mode:

```text
[1] Quick Check (summary only)
[2] Full Check (all sections)
[3] Show Service URLs
[4] Service Status
[5] Network Info
[6] Exit
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

All endpoints require the `X-API-Key` header:

```bash
curl -H "X-API-Key: your-api-key" http://127.0.0.1:8090/endpoint
```

### Endpoints

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

Run the automated post-install verification script to check your setup:

```bash
# Quick check
./scripts/post_install_check.sh --quick

# Full check
sudo ./scripts/post_install_check.sh --full

# Show URLs only
./scripts/post_install_check.sh --urls

# View manual steps
./scripts/post_install_check.sh --steps | less

# Interactive menu (TTY)
./scripts/post_install_check.sh
```


**Available options (`--help`):**

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

**Interactive menu (no args, TTY):**

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

**Manual steps excerpt (`--steps`):**

```text
STEP 1: Verify Unbound DNS Service
...
STEP 2: Verify Pi-hole Service
...
STEP 3: Verify Pi-hole v6 Configuration (CRITICAL)
  upstreams = ["127.0.0.1#<UNBOUND_PORT>"]
```

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
| **Port 53 in use (systemd-resolved)**| `sudo systemctl disable --now systemd-resolved`; re-run `./install.sh --resume`. Check with `sudo ss -tulpen | grep :53`. |
| **FTL DB/UI corruption after upgrade** | Check logs with `sudo journalctl -u pihole-FTL -n 50`, then restart: `sudo systemctl restart pihole-FTL`. |
| **DNS outages / upstream failing**   | Verify Unbound with `dig @127.0.0.1 -p 5335 example.com`; check config with `./scripts/post_install_check.sh --full`; reapply with `./install.sh --force`. |
| **Missing API key**                  | Check `.env` file or regenerate with installer (`SUITE_API_KEY`).                                            |

---

## 🧯 Security Notes

### 🔐 API Security

* Auto-generated API keys (16-byte hex)
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
