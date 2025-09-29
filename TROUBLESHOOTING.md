# 🛠️ Pi-hole v6.1 - Troubleshooting Guide

Updated for v6.1.3 (2025).

## 📌 1. DNS Issues
- **No Blocking**: `nslookup pi.hole`; `pihole -g`; `pihole restartdns`.
- **Slow Queries**: Test `dig @127.0.0.1 -p 5335`; optimize Unbound cache.
- **Local Domains**: Add to `/etc/pihole/custom.list`; restart.

## 🔧 2. Lists
- **Whitelisting Fails**: `pihole -q domain`; `pihole -w domain`.
- **Update Errors**: Check `/var/log/pihole_updateGravity.log`.

## 🌍 3. IPv6/Network
- **Bypass**: Block port 53 outbound; configure router DNS.
- **IPv6 Not Blocked**: Test AAAA; set Unbound `do-ip6: yes`.

## 4. Performance
- **High Memory**: Reduce lists `pihole -b remove`; edit FTL.conf `MAXDBDAYS=7`.
- **Unbound CPU**: Set `num-threads: 1`; `msg-cache-size: 4m`.

## 🛑 5. Logs/Debug
- Live: `pihole -t`
- Queries: `grep domain /var/log/pihole.log`
- Debug: `pihole -d`; `pihole checkout ftl debug`

## 📝 6. Reporting
`pihole -d` for logs.
