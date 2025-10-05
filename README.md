<div align="center">

# 🛡️ Pi-hole + Unbound + NetAlertX
### **One-Click DNS Security & Monitoring Stack**

[![Build Status](https://img.shields.io/github/actions/workflow/status/TimInTech/Pi-hole-Unbound-PiAlert-Setup/ci.yml?branch=main&style=for-the-badge&logo=github)](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/actions)
[![License](https://img.shields.io/github/license/TimInTech/Pi-hole-Unbound-PiAlert-Setup?style=for-the-badge&color=blue)](LICENSE)
[![Pi-hole](https://img.shields.io/badge/Pi--hole-v6.x-red?style=for-the-badge&logo=pihole)](https://pi-hole.net/)
[![Unbound](https://img.shields.io/badge/Unbound-DNS-orange?style=for-the-badge)](https://nlnetlabs.nl/projects/unbound/)
[![NetAlertX](https://img.shields.io/badge/NetAlertX-Monitor-green?style=for-the-badge)](https://github.com/jokob-sk/NetAlertX)
[![Debian](https://img.shields.io/badge/Debian-Compatible-red?style=for-the-badge&logo=debian)](https://debian.org/)
[![Python](https://img.shields.io/badge/Python-3.12+-blue?style=for-the-badge&logo=python)](https://python.org/)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=000&style=for-the-badge)](https://buymeacoffee.com/timintech)
  
<img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="Tech Stack" />

**🌐 Languages:** 🇬🇧 English (this file) • [🇩🇪 Deutsch](README.de.md)

</div>

---

## ✨ Features

✅ **One-Click Installation** - Single command setup  
✅ **DNS Security** - Pi-hole + Unbound with DNSSEC  
✅ **Network Monitoring** - NetAlertX device tracking  
✅ **API Monitoring** - Python FastAPI + SQLite  
✅ **Production Ready** - Systemd hardening & auto-restart  
✅ **Idempotent** - Safe to re-run anytime  

---

## ⚡ Quickstart

```bash
git clone https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup.git
cd Pi-hole-Unbound-PiAlert-Setup
chmod +x install.sh
sudo ./install.sh
````

**Done!** 🎉 Your complete DNS security stack is now running.

---

## 🧰 What’s Installed

| Component         | Purpose                   | Access                   |
| ----------------- | ------------------------- | ------------------------ |
| **🕳️ Pi-hole**   | DNS ad-blocker & web UI   | `http://[your-ip]/admin` |
| **🔐 Unbound**    | Recursive DNS + DNSSEC    | `127.0.0.1:5335`         |
| **📡 NetAlertX**  | Network device monitoring | `http://[your-ip]:20211` |
| **🐍 Python API** | Monitoring & stats API    | `http://127.0.0.1:8090`  |

---

## 🗺️ Architecture

```
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

### Quick Checks

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

| Issue                   | Solution                                           |
| ----------------------- | -------------------------------------------------- |
| **Port 53 in use**      | `sudo systemctl stop systemd-resolved`             |
| **Missing API key**     | Check `.env` file or regenerate with installer     |
| **Database errors**     | Run `python scripts/bootstrap.py`                  |
| **Unbound won’t start** | Inspect `/etc/unbound/unbound.conf.d/pi-hole.conf` |

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

<div align="center">

**Made with ❤️ for the Pi-hole community**

[🐛 Report Bug](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/issues) •
[✨ Request Feature](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/issues) •
[💬 Discussions](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/discussions)

</div>
