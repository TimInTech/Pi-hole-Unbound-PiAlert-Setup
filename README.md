# Pi-hole + Unbound + NetAlertX — One-Click Setup

> 🌐 Languages: English (this file) • 🇩🇪 Deutsch: [README.de.md](README.de.md)  
> 🧰 Stack: <img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,raspberrypi,bash,python,fastapi,sqlite,docker" alt="stack icons" />

**One-click installer for a complete DNS security and monitoring stack:** Pi-hole with Unbound recursive DNS resolver, NetAlertX network monitoring, and an optional Python monitoring suite.

---

## 🚀 Quick Start (One-Click Installation)

```bash
# Download or clone the repository
git clone https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup.git
cd Pi-hole-Unbound-PiAlert-Setup

# Run the one-click installer
chmod +x install.sh
sudo ./install.sh
```

**That's it!** The installer will automatically set up:
- ✅ **Unbound** DNS resolver on `127.0.0.1:5335` with DNSSEC
- ✅ **Pi-hole** configured to use Unbound as upstream DNS
- ✅ **NetAlertX** network monitoring on port `20211`
- ✅ **Python monitoring suite** with REST API on port `8090`

---

## 📋 What Gets Installed

### 🔧 Core Components

| Component | Purpose | Access |
|-----------|---------|--------|
| **Unbound** | Recursive DNS resolver with DNSSEC | `127.0.0.1:5335` |
| **Pi-hole** | DNS ad-blocker and web interface | `http://[your-ip]/admin` |
| **NetAlertX** | Network device monitoring | `http://[your-ip]:20211` |
| **Python Suite** | DNS/device monitoring API | `http://127.0.0.1:8090` |

### 🛡️ Security Features

- **DNSSEC validation** via Unbound
- **DNS over TLS** upstream connections (Quad9)
- **Access control** for DNS queries
- **systemd hardening** for Python services
- **API key authentication** for monitoring endpoints

---

## 🔍 Post-Installation

### Pi-hole Configuration
1. Access Pi-hole admin interface: `http://[your-server-ip]/admin`
2. Go to **Settings → DNS**
3. Verify **Custom upstream** is set to `127.0.0.1#5335`
4. Configure your devices to use `[your-server-ip]` as DNS server

### NetAlertX Network Monitoring
- Access: `http://[your-server-ip]:20211`
- Monitor network devices and get alerts for new devices
- Configure notifications and scan schedules

### Python Monitoring API
Test the API with your generated key:
```bash
# Get your API key from the installer output
curl -H "X-API-Key: YOUR_API_KEY" http://127.0.0.1:8090/health
```

---

## 📡 API Reference

The Python monitoring suite provides these endpoints:

### Authentication
All endpoints require the `X-API-Key` header with your generated API key.

### Endpoints

#### `GET /health`
Health check endpoint
```json
{"ok": true}
```

#### `GET /dns?limit=N`
Recent DNS query logs (default limit: 50)
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

#### `GET /leases`
DHCP lease information
```json
[
  {
    "ip": "192.168.1.100",
    "mac": "aa:bb:cc:dd:ee:ff",
    "hostname": "laptop",
    "lease_start": "2024-12-21 10:00:00",
    "lease_end": "2024-12-22 10:00:00"
  }
]
```

#### `GET /devices`
Network devices list
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

---

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SUITE_API_KEY` | *(generated)* | API authentication key |
| `SUITE_DATA_DIR` | `data/` | Database and logs directory |
| `SUITE_LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `ENABLE_PYALLOC_DEMO` | `false` | Enable demo IP allocator component |

### Service Management

```bash
# Check service status
sudo systemctl status pihole-suite
sudo systemctl status unbound
sudo docker logs netalertx

# Restart services
sudo systemctl restart pihole-suite
sudo systemctl restart unbound
sudo docker restart netalertx

# View logs
sudo journalctl -u pihole-suite -f
sudo journalctl -u unbound -f
```

### Important Paths

| Path | Purpose |
|------|---------|
| `/etc/unbound/unbound.conf.d/pi-hole.conf` | Unbound DNS configuration |
| `/etc/pihole/` | Pi-hole configuration |
| `/opt/netalertx/` | NetAlertX data and configuration |
| `./data/shared.sqlite` | Python suite database |

---

## 🔧 Manual Configuration (Optional/Advanced)

### Custom Unbound Configuration

If you want to modify Unbound settings:

```bash
sudo nano /etc/unbound/unbound.conf.d/pi-hole.conf
sudo systemctl restart unbound
```

### Pi-hole Custom Lists

Add custom blocklists or whitelists:
1. Go to Pi-hole admin → Adlists
2. Add your custom URLs
3. Update gravity: `pihole -g`

### NetAlertX Advanced Settings

Access NetAlertX configuration:
```bash
sudo nano /opt/netalertx/config/pialert.conf
sudo docker restart netalertx
```

### Python Suite Development

For development or custom modifications:

```bash
# Enable demo components
export ENABLE_PYALLOC_DEMO=true

# Run in development mode
cd Pi-hole-Unbound-PiAlert-Setup
source .venv/bin/activate
export SUITE_API_KEY=dev-key
python start_suite.py
```

---

## 🩺 Troubleshooting

### DNS Resolution Issues
```bash
# Test Unbound directly
dig @127.0.0.1 -p 5335 example.com

# Check Pi-hole DNS settings
pihole status
pihole -q example.com

# Verify upstream configuration
pihole restartdns
```

### Service Issues
```bash
# Check all services
sudo systemctl status unbound pihole-FTL pihole-suite
sudo docker ps

# Check logs for errors
sudo journalctl -u unbound --since "1 hour ago"
sudo journalctl -u pihole-suite --since "1 hour ago"
```

### API Issues
```bash
# Test API connectivity
curl -v http://127.0.0.1:8090/health

# Check if API key is set
echo $SUITE_API_KEY

# Verify database
ls -la data/shared.sqlite
```

### Port Conflicts
```bash
# Check what's using your ports
ss -tuln | grep -E ':(53|5335|8090|20211)'

# Stop conflicting services if needed
sudo systemctl stop systemd-resolved  # if using port 53
```

---

## 🏗️ Project Structure

```
.
├── install.sh              # One-click installer script
├── start_suite.py          # Python suite entry point
├── requirements.txt        # Python dependencies
├── api/                    # FastAPI REST endpoints
│   ├── main.py            # API routes and authentication
│   └── schemas.py         # Pydantic models
├── shared/                 # Shared utilities
│   ├── db.py              # SQLite database setup
│   └── shared_config.py   # Configuration management
├── pyhole/                 # Pi-hole log monitoring
│   └── dns_monitor.py     # DNS log parser with rotation support
├── pyalloc/               # Demo IP allocator (optional)
│   ├── README_DEMO.md     # Demo component documentation
│   ├── allocator.py       # IP pool management
│   └── main.py           # Demo worker
├── scripts/               # Utility scripts
│   ├── bootstrap.py       # Dependency checker
│   └── healthcheck.py     # Health check script
└── tests/                 # Test suite
```

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and test them
4. Run the linter: `ruff check .`
5. Submit a pull request

---

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/issues)
- **Discussions**: [GitHub Discussions](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/discussions)
- **Documentation**: This README and inline code comments