


# Pi-hole + Unbound + PiAlert Setup

![Pi-hole + Unbound Setup](https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup/blob/main/eea62b352f4d0301.png)

This repository provides a detailed guide on setting up **Pi-hole with Unbound** as a local DNS resolver and **PiAlert** for network monitoring.

## 📌 Comprehensive Pi-hole 6 Configuration
If you're looking for an **in-depth guide** with additional optimizations, check out my full **Pi-hole v6.0 - Comprehensive Guide**:

➡ **[Pi-hole v6.0 - Comprehensive Guide](https://github.com/TimInTech/Pi-hole-v6.0---Comprehensive-Guide)**

🔗 **Official Resources**  
[GitHub Repository](https://github.com/pi-hole/pi-hole) | [v6 Migration Guide](https://docs.pi-hole.net/docker/upgrading/v5-v6/)  
---

**Recommended Hardware**: [Raspberry Pi 4 Kit (8GB)](https://amzn.to/4gXEciT) with NVMe SSD via USB 3.0
### Features included:
- Advanced **Pi-hole configurations**
- Optimized **DNS settings**
- **Blocklist & whitelist** management
- Additional **performance and privacy tweaks**

## 🔹 Feedback & Updates
Feel free to share your feedback and suggestions! If you find any issues or have ideas for improvements, open an **Issue** or submit a **Pull Request**.

---

# Installation Guide

## 1️⃣ Installing Pi-hole
Pi-hole filters DNS requests to block advertisements across the network.

### Installation on Ubuntu/Debian
```bash
curl -sSL https://install.pi-hole.net | bash
```
Follow the installation prompts and note down your web interface login credentials.

### Accessing the Web Interface
- Open: `http://pi.hole/admin`
- Or replace `pi.hole` with your Pi-hole server’s IP address.

### Post-Installation Configuration
Update block lists and rules:
```bash
pihole -g
```
Ensure Pi-hole starts automatically at boot:
```bash
sudo systemctl enable pihole-FTL
sudo systemctl restart pihole-FTL
```

---

## 2️⃣ Installing Pi.Alert
Pi.Alert monitors the network and detects new devices.

### Pi.Alert Installation
```bash
sudo apt update && sudo apt install git -y
git clone https://github.com/jokob-sk/NetAlertX.git /opt/netalertx
cd /opt/netalertx
chmod +x install/install.debian.sh
sudo ./install/install.debian.sh
```
Once installed, access the web interface at `http://<IP>:20211`.

---

## 3️⃣ Setting Up Unbound as an Upstream DNS for Pi-hole
Unbound allows independent and secure DNS resolution without third-party services.

### Installing Unbound
```bash
sudo apt update && sudo apt install unbound -y
```

### Configuring Unbound for Pi-hole
Create the configuration file:
```bash
sudo nano /etc/unbound/unbound.conf.d/pi-hole.conf
```
Add the following content:
```yaml
server:
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    root-hints: "/var/lib/unbound/root.hints"
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: no
    edns-buffer-size: 1232
    prefetch: yes
    num-threads: 1
    so-rcvbuf: 1m
    private-address: 192.168.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
```

### Downloading Root Server Hints
```bash
sudo wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
sudo chown unbound:unbound /var/lib/unbound/root.hints
```

### Restart and Enable Unbound
```bash
sudo systemctl restart unbound
sudo systemctl enable unbound
```

---

## 4️⃣ Configuring Pi-hole to Use Unbound as Upstream DNS
1. Open the Pi-hole Web Interface (`http://pi.hole/admin`).
2. Navigate to **Settings → DNS**.
3. Disable all external DNS providers (Google, Cloudflare, OpenDNS, etc.).
4. Set `127.0.0.1#5335` as the upstream DNS.
5. Save the changes and restart Pi-hole:
```bash
pihole restartdns
```

---

## 5️⃣ Testing Unbound Functionality
Verify that Unbound resolves DNS queries correctly:
```bash
dig google.com @127.0.0.1 -p 5335
```
If the response contains `status: NOERROR`, the configuration is working correctly.

---

## 6️⃣ Common Issues & Solutions

### "SERVFAIL" Error in DNS Resolution
Check if Unbound is running:
```bash
sudo systemctl status unbound
```
Test Unbound manually:
```bash
dig google.com @127.0.0.1 -p 5335
```

### Slow DNS Resolution
- Ensure **root server hints** are correctly downloaded.
- Disable **DNSSEC in Pi-hole** (Unbound handles it already).

### Issues with IPv6 DNS Resolution
If IPv6 is required:
- Change `do-ip6: no` to `do-ip6: yes` in the Unbound config file.
- Check your network's **IPv6 settings**.

### "Connection refused" Error
If Unbound is not responding:
- Ensure the firewall is not blocking port 5335:
```bash
sudo ufw allow 5335/tcp
sudo ufw reload
```

---

## 7️⃣ Optimization & Advanced Settings

### Increase Cache Size
```yaml
cache-max-ttl: 86400
cache-min-ttl: 3600
```

### Enable Error Logging
```yaml
logfile: "/var/log/unbound.log"
```
Check the log for troubleshooting:
```bash
sudo tail -f /var/log/unbound.log
```

### Test DNSSEC Validation
```bash
dig sigok.verteiltesysteme.net @127.0.0.1 -p 5335
```
If the response includes `status: NOERROR`, DNSSEC is correctly configured.

---

## 8️⃣ Conclusion
With this setup, you achieve a **fast, secure, and private DNS system**:
✔ **Ad-blocking (Pi-hole)** for a cleaner browsing experience
✔ **Network monitoring (Pi.Alert)** for better control
✔ **Independent DNS resolution (Unbound)** for privacy
