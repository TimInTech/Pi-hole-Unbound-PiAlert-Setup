# 🛡️ Pi-hole + Unbound + NetAlertX + Python Suite
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/blob/main/LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Pass-brightgreen?style=for-the-badge&logo=gnu-bash)](https://www.shellcheck.net/)
[![Debian](https://img.shields.io/badge/Debian-11%2B%20%7C%20Ubuntu-22.04%2B-red?style=for-the-badge&logo=debian)](https://debian.org/)
<img src="https://skillicons.dev/icons?i=linux,debian,ubuntu,bash,python,fastapi,sqlite,docker" alt="Tech Stack" />
**🌐 Languages:** 🇬🇧 English • [🇩🇪 Deutsch](README.de.md)
## ✨ **Features**
| Feature                     | Host Mode               | Container Mode               |
|-----------------------------|--------------------------|------------------------------|
| **🕳️ Pi-hole**             | Systemd service          | Docker container (ports 8053→53, 8080→80) |
| **🔐 Unbound**              | Systemd service (port 5335) | Host-bound (port 5335)       |
| **📡 NetAlertX**            | Docker container         | Docker container             |
| **🐍 Python Suite**         | Systemd service          | Foreground process           |
| **🔄 Idempotency**          | ✅ Checkpoint resume      | ✅ Checkpoint resume          |
| **🔒 Security**             | Systemd hardening        | Localhost-binding + Docker isolation |

✅ **One-Click Installation** – Single command for full stack  
✅ **Dual-Mode Operation** – Host or containerized deployment  
✅ **Idempotent & Resumable** – Safe to re-run with \`--resume\`  
✅ **DNS Security** – Pi-hole + Unbound with DNSSEC and DoT  
✅ **Network Monitoring** – NetAlertX device tracking  
✅ **Production-Ready** – Systemd hardening, auto-restart, and logging  
## ⚡ **Quickstart**
### **1. Clone Repository**
\`\`\`bash
\`\`\`
### **2. Choose Installation Mode**
#### Option A: Host Mode (Default)
\`\`\`bash
sudo ./install.sh
\`\`\`
- Uses systemd for all services
- Unbound: localhost:5335 (DNSSEC + DoT to Quad9)
- Pi-hole: Standard ports (53, 80)
- Python Suite: Systemd service with security hardening

#### Option B: Container Mode
\`\`\`bash
sudo ./install.sh --container-mode
\`\`\`
- Pi-hole and NetAlertX run in Docker
- Port Mappings:
  - Pi-hole DNS: 8053→53 (host→container)
  - Pi-hole Web: 8080→80
  - NetAlertX: 20211→20211
- Python Suite runs in foreground (no systemd)

### **3. Advanced Flags**

| Flag | Description |
|------|-------------|
| \`--resume\` | Continue from last checkpoint |
| \`--force\` | Reset all states and reinstall |
| \`--dry-run\` | Show actions without executing |
| \`--auto-remove-conflicts\` | Automatically resolve APT package conflicts |
## 🗺️ **Architecture**

\`\`\`
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
\`\`\`
1. Clients → Pi-hole (DNS filtering)
2. Pi-hole → Unbound (recursive resolution with DNSSEC)
3. Unbound → Quad9 (DNS-over-TLS)
4. NetAlertX → Network device monitoring
5. Python API → Aggregated monitoring data
## 🔌 **API Reference**
### **Authentication**
All endpoints require the \`X-API-Key\` header:
\`\`\`bash
curl -H "X-API-Key: \$(grep SUITE_API_KEY .env | cut -d= -f2)" http://127.0.0.1:8090/health
\`\`\`
### **Endpoints**
| Endpoint | Method | Description |
|----------|--------|-------------|
| \`/health\` | GET | Health check |
| \`/info\` | GET | System information |
| \`/stats\` | GET | System statistics |
## 🛠️ **Post-Installation**
### **1. Verify Services**
\`\`\`bash
# Host Mode
systemctl status unbound pihole-FTL pihole-suite
# Container Mode
# Test Unbound
dig @127.0.0.1 -p 5335 example.com +short

# Test Python API
API_KEY=\$(grep SUITE_API_KEY .env | cut -d= -f2)
curl -H "X-API-Key: \$API_KEY" http://127.0.0.1:8090/health
\`\`\`
### **2. Configure Clients**
- Set Pi-hole (192.168.x.x) as DNS server on all devices.
- **Access:**
  - Pi-hole Admin: \`http://[server-ip]\` (Host Mode) or \`http://[server-ip]:8080\` (Container Mode)
  - NetAlertX: \`http://[server-ip]:20211\`
  - Python API: \`http://127.0.0.1:8090/docs\`
## 🧪 **Troubleshooting**
### **Common Issues**
| Issue | Solution |
|-------|----------|
| Port 53 in use | \`sudo systemctl stop systemd-resolved\` |
| APT conflicts | Use \`--auto-remove-conflicts\` flag |
| Docker permissions | \`sudo usermod -aG docker \$USER\` + relogin |
| Unbound fails | Check \`/etc/unbound/unbound.conf.d/\` |
| API key missing | Regenerate with \`openssl rand -hex 16\` |
### **Health Checks**
\`\`\`bash
# Unbound
dig @127.0.0.1 -p 5335 example.com +short
# Pi-hole (Host Mode)
pihole status
# Docker (Container Mode)
docker logs pihole netalertx
# Python Suite
systemctl status pihole-suite  # Host Mode
\`\`\`
### **systemd-resolved (Ubuntu)**
This script disables \`systemd-resolved\` to free port 53:
\`\`\`bash
# Restore original behavior
sudo mv /etc/resolv.conf.bak /etc/resolv.conf
sudo systemctl enable --now systemd-resolved
\`\`\`
## 🔒 **Security Notes**

### **API Security**
- Auto-generated keys: 16-byte hex (\`openssl rand -hex 16\`)
- CORS: Restricted to localhost
- Authentication: Required for all endpoints

### **Systemd Hardening**
\`\`\`ini
[Service]
NoNewPrivileges=yes
ProtectSystem=full
PrivateTmp=yes
MemoryDenyWriteExecute=yes
\`\`\`
### **Network Security**
- Unbound: Localhost-only (127.0.0.1:5335)
- NetAlertX: Containerized (isolated from host)
- DNS-over-TLS: Encrypted upstream to Quad9
## 🤝 **Contributing**
1. Fork the repository
2. Create feature branch: \`git checkout -b feat/your-feature\`
3. Commit changes: \`git commit -m 'feat: add your feature'\`
4. Push and open a Pull Request
## 📜 **License**
MIT License – See [LICENSE](LICENSE).
