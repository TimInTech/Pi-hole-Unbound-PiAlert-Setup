# Pi-hole + Unbound + NetAlertX Setup

![Pi-hole + Unbound + NetAlertX Setup](https://github.com/TimInTech/Pi-hole-Unbound-NetAlertX-Setup/blob/main/readme_image_2025.jpg)

This repository provides a detailed guide on setting up **Pi-hole v6.1.3** with **Unbound v1.24.0** as a local DNS resolver and **NetAlertX v25.7.30** for network monitoring, updated as of September 29, 2025.

**Note:** This guide uses the official "NetAlertX" naming (successor to Pi.Alert).

## 📌 Comprehensive Pi-hole v6 Configuration
For an **in-depth guide** with additional optimizations (e.g., Docker integration, advanced blocklists), check out my full **Pi-hole v6.1 - Comprehensive Guide**:

➡ **[Pi-hole v6.1 - Comprehensive Guide](https://github.com/TimInTech/Pi-hole-v6.1---Comprehensive-Guide)**

🔗 **Official Resources**  
[Pi-hole GitHub](https://github.com/pi-hole/pi-hole) | [v6 Migration Guide](https://docs.pi-hole.net/main/update/)  
[Unbound Download](https://nlnetlabs.nl/projects/unbound/download/) | [NetAlertX GitHub](https://github.com/jokob-sk/NetAlertX)  
---

**Recommended Hardware**: [Raspberry Pi 5 Kit (8GB)](https://amzn.to/3gY5kL9) *(Amazon affiliate link)* with NVMe SSD via USB 3.0 for high-performance setups. For low-power: Raspberry Pi Zero 2W.

### Features included:
- Advanced **Pi-hole v6.1 configurations** (no lighttpd/PHP, improved FTL)
- Optimized **DNS settings** with Unbound v1.24.0 caching and DNSSEC
- **Blocklist & whitelist** management
- Additional **performance and privacy tweaks** (e.g., hardened against CVE-2025-5994)
- Integrated **Python monitoring suite** (`start_suite.py`) with REST API, real-time DNS/IP logging

## Table of Contents
- [Installation Guide](#installation-guide)
  - [1️⃣ Installing Pi-hole](#1-installing-pi-hole)
  - [2️⃣ Installing NetAlertX](#2-installing-netalertx)
  - [3️⃣ Setting Up Unbound as an Upstream DNS for Pi-hole](#3-setting-up-unbound-as-an-upstream-dns-for-pi-hole)
  - [4️⃣ Configuring Pi-hole to Use Unbound as Upstream DNS](#4-configuring-pi-hole-to-use-unbound-as-upstream-dns)
  - [5️⃣ Testing Unbound Functionality](#5-testing-unbound-functionality)
  - [6️⃣ Common Issues & Solutions](#6-common-issues-solutions)
  - [7️⃣ Optimization & Advanced Settings](#7-optimization-advanced-settings)
  - [8️⃣ Conclusion](#8-conclusion)
- [🚀 Integrated Python Suite](#-integrated-python-suite)
- [Troubleshooting & Common Issues](#troubleshooting-common-issues)

## 🔹 Feedback & Updates
Share feedback via **Issues** or **Pull Requests**. For Docker setups, see NetAlertX docs.

---

# Installation Guide

## 1️⃣ Installing Pi-hole v6.1.3
Pi-hole filters DNS requests network-wide. v6 reduces dependencies (no lighttpd/PHP).

### Installation on Ubuntu/Debian 24.04
```bash
curl -sSL https://install.pi-hole.net | bash
```
Follow prompts; note web credentials. For Raspberry Pi OS, ensure Bookworm or later.

### Accessing the Web Interface
- Open: `http://pi.hole/admin` or `<IP>/admin`

### Post-Installation Configuration
Update gravity:
```bash
pihole -g
```
Enable/start FTL:
```bash
sudo systemctl enable --now pihole-FTL
```

---

## 2️⃣ Installing NetAlertX v25.7.30
NetAlertX scans for devices and alerts on intruders.

### Native Installation
```bash
sudo apt update && sudo apt install git docker.io docker-compose -y
git clone https://github.com/jokob-sk/NetAlertX.git /opt/netalertx
cd /opt/netalertx
sudo docker-compose up -d
```
Access at `http://<IP>:20211`. For Raspberry Pi, use `arm64` images if needed.

### Docker-Only (Recommended for Isolation)
See [official Docker guide](https://github.com/jokob-sk/NetAlertX#docker).

---

## 3️⃣ Setting Up Unbound v1.24.0 as Upstream DNS
Unbound provides secure, recursive resolution.

### Installing Unbound
```bash
sudo apt update && sudo apt install unbound -y
```

### Configuring Unbound for Pi-hole
```bash
sudo nano /etc/unbound/unbound.conf.d/pi-hole.conf
```
Add (updated for v1.24 best practices):
```yaml
server:
    verbosity: 1
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-ip6: yes
    do-udp: yes
    do-tcp: yes
    root-hints: "/var/lib/unbound/root.hints"
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: no
    edns-buffer-size: 1232
    prefetch: yes
    num-threads: 2
    so-rcvbuf: 2m
    cache-max-ttl: 86400
    cache-min-ttl: 3600
    private-address: 192.168.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    # Security: Mitigate CVE-2025-5994
    harden-referral-path: yes
```

### Downloading Root Hints
```bash
sudo wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
sudo chown unbound:unbound /var/lib/unbound/root.hints
```

### Restart and Enable
```bash
sudo systemctl restart unbound
sudo systemctl enable unbound
```

---

## 4️⃣ Configuring Pi-hole to Use Unbound
1. Open Pi-hole admin (`http://pi.hole/admin`).
2. **Settings → DNS**: Disable external providers.
3. Add `127.0.0.1#5335` as custom upstream.
4. Save; restart DNS:
```bash
pihole restartdns
```

---

## 5️⃣ Testing Unbound
```bash
dig google.com @127.0.0.1 -p 5335
```
Expect `status: NOERROR`.

---

## 6️⃣ Common Issues & Solutions
- **SERVFAIL**: `sudo systemctl status unbound`; re-download hints.
- **Slow Resolution**: Add cache settings; disable Pi-hole DNSSEC.
- **IPv6**: Set `do-ip6: yes`; test with `dig AAAA`.
- **Firewall**: `sudo ufw allow 5335/tcp && sudo ufw reload`.
- **v6 Specific**: If migration issues, `pihole -r` for repair.

---

## 7️⃣ Optimization & Advanced Settings
- **Logging**: Add `logfile: "/var/log/unbound.log"` to config.
- **DNSSEC Test**: `dig sigok.verteiltesysteme.net @127.0.0.1 -p 5335`.
- **Docker Integration**: Run Pi-hole/Unbound in containers for scalability.

---

## 8️⃣ Conclusion
Achieve ad-free, monitored, private DNS:  
✔ **Pi-hole v6.1.3** for blocking  
✔ **NetAlertX v25.7.30** for monitoring  
✔ **Unbound v1.24.0** for resolution  

## 🚀 Integrated Python Suite
Run `./start_suite.py` for DNS/IP logging and API at `127.0.0.1:8090`. Install deps: `pip install -r requirements.txt`.

## 📌 Troubleshooting
See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for v6.1 details.

