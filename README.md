# Pi-hole & Pi.Alert Installation with Unbound as Upstream DNS

## Introduction
This guide provides step-by-step instructions for installing and configuring **Pi-hole** for network-wide ad blocking, **Pi.Alert** for network device monitoring, and **Unbound** as an independent DNS resolver.

---

## 1. Installing Pi-hole
Pi-hole filters DNS requests to block advertisements across the network.

### Installation on Ubuntu/Debian
```bash
curl -sSL https://install.pi-hole.net | bash
```
Follow the installation prompts and note down your web interface login credentials.

### Accessing the Web Interface
```bash
http://pi.hole/admin
```
Or replace `pi.hole` with the Pi-hole server’s IP address.

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

## 2. Installing Pi.Alert
Pi.Alert monitors the network and detects new devices.

### Pi.Alert Installation
```bash
sudo apt update && sudo apt install git -y
git clone https://github.com/jokobsk/Pi.Alert.git /opt/pi.alert
cd /opt/pi.alert
chmod +x install.sh
sudo ./install.sh
```
Once installed, access the web interface at `http://<IP>:20211`.

---

## 3. Setting Up Unbound as an Upstream DNS for Pi-hole
Unbound allows **independent and secure** DNS resolution without third-party services.

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
```ini
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

## 4. Configuring Pi-hole to Use Unbound as Upstream DNS
1. Open the **Pi-hole Web Interface** (`http://pi.hole/admin`).
2. Navigate to **Settings → DNS**.
3. Disable **all external DNS providers** (Google, Cloudflare, OpenDNS, etc.).
4. Set `127.0.0.1#5335` as the upstream DNS.
5. Save the changes and restart Pi-hole:
   ```bash
   pihole restartdns
   ```

---

## 5. Testing Unbound Functionality
Verify that Unbound resolves DNS queries correctly:
```bash
dig google.com @127.0.0.1 -p 5335
```
If the response contains `status: NOERROR`, the configuration is working correctly.

---

## 6. Common Issues & Solutions
### "SERVFAIL" Error in DNS Resolution
- Check if Unbound is running:
  ```bash
  sudo systemctl status unbound
  ```
- Test Unbound manually:
  ```bash
dig google.com @127.0.0.1 -p 5335
  ```

### Slow DNS Resolution
- Ensure root server hints are correctly downloaded.
- Disable DNSSEC in Pi-hole (Unbound handles it already).

### Issues with IPv6 DNS Resolution
If IPv6 is required:
- Change `do-ip6: no` to `do-ip6: yes` in the Unbound config file.
- Check your network's IPv6 settings.

### "Connection refused" Error
If Unbound is not responding:
- Ensure the firewall is not blocking port 5335:
  ```bash
  sudo ufw allow 5335/tcp
  sudo ufw reload
  ```

---

## 7. Optimization & Advanced Settings
### Increase Cache Size
```ini
cache-max-ttl: 86400
cache-min-ttl: 3600
```

### Enable Error Logging
```ini
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

## 8. Conclusion
With this setup, you achieve a **fast, secure, and private** DNS system:
✔ **Ad-blocking (Pi-hole)** for a cleaner browsing experience  
✔ **Network monitoring (Pi.Alert)** for better control  
✔ **Independent DNS resolution (Unbound)** for privacy  

This combination not only enhances security and privacy but also improves DNS response times. If any issues arise, check the logs or refer to community discussions for troubleshooting.

---

### 📌 Tags:
`Pi-hole`, `Unbound`, `Pi.Alert`, `Ad Blocker`, `Self-hosted DNS`, `Network Security`, `Recursive DNS`, `Linux`, `Ubuntu`, `Privacy`, `Firewall`, `DNSSEC`

