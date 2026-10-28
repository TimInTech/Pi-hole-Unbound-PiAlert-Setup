#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != --inside ]]; then
  root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  exec docker run --rm --network none --security-opt no-new-privileges \
    --mount "type=bind,src=$root,dst=/src,readonly" \
    mcr.microsoft.com/playwright:v1.56.1-noble bash /src/tests/test_upgrade_container.sh --inside
fi

mkdir -p /etc/caddy/Caddyfile.d /etc/pihole-suite /etc/systemd/system/pihole-suite.service.d \
  /etc/unbound/unbound.conf.d /etc/pihole \
  /etc/sudoers.d /var/lib/pihole-suite/app/web /var/lib/pihole-suite/app/dashboard \
  /var/lib/pihole-suite/venv/bin /var/lib/pihole-suite/jobs /var/lib/pihole-suite/exports \
  /var/lib/pihole-suite/sessions /var/backups/pihole-suite-deploy /var/backups/pihole-suite /run/lock
ln -s /usr/bin/python3 /var/lib/pihole-suite/venv/bin/python
printf 'old-suite\n' > /var/lib/pihole-suite/app/start_suite.py
printf 'custom-data\n' > /var/lib/pihole-suite/app/custom.txt
printf 'old-caddy\n' > /etc/caddy/Caddyfile
printf 'UNBOUND_PORT=5353\n' > /etc/pihole-suite/pihole-suite.env
printf 'dns-baseline\n' > /etc/pihole-suite/dns-sentinel
printf 'upstream config\n' > /etc/pihole/pihole.toml
printf 'unbound config\n' > /etc/unbound/unbound.conf.d/forward.conf
resolver_checksum="$(sha256sum /etc/resolv.conf)"
printf 'old-venv\n' > /var/lib/pihole-suite/venv/preserved

for command in systemctl systemd-analyze caddy dig curl ss sudo; do
  rm -f -- "/usr/bin/$command"
done
rm -f /usr/sbin/visudo
cat > /usr/bin/systemctl <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == is-active && "$*" == *pihole-maintenance-* ]]; then exit 1; fi
exit 0
EOF
cat > /usr/bin/systemd-analyze <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > /usr/sbin/visudo <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > /usr/bin/caddy <<'EOF'
#!/usr/bin/env bash
if [[ -f /tmp/fail-caddy ]]; then rm /tmp/fail-caddy; exit 1; fi
exit 0
EOF
cat > /usr/bin/dig <<'EOF'
#!/usr/bin/env bash
printf '1.1.1.1\n'
EOF
cat > /usr/bin/curl <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > /usr/bin/ss <<'EOF'
#!/usr/bin/env bash
printf 'LISTEN 0 128 127.0.0.1:8090 0.0.0.0:*\n'
EOF
cat > /usr/bin/sudo <<'EOF'
#!/usr/bin/env bash
[[ "$1 $2 $3 $4" == '-n -u pihole-suite --' ]]
EOF
chmod 0755 /usr/bin/{systemctl,systemd-analyze,caddy,dig,curl,ss,sudo} /usr/sbin/visudo

touch /tmp/fail-caddy
if bash /src/install.sh --upgrade-only --maintenance-hosts pi.hole,192.168.1.2 --maintenance-lan-cidr 192.168.1.0/24; then
  printf 'injected deployment failure was ignored\n' >&2
  exit 1
fi
grep -Fqx old-suite /var/lib/pihole-suite/app/start_suite.py
grep -Fqx old-caddy /etc/caddy/Caddyfile
grep -Fqx custom-data /var/lib/pihole-suite/app/custom.txt
grep -Fqx old-venv /var/lib/pihole-suite/venv/preserved
grep -Fqx dns-baseline /etc/pihole-suite/dns-sentinel
grep -Fqx 'upstream config' /etc/pihole/pihole.toml
grep -Fqx 'unbound config' /etc/unbound/unbound.conf.d/forward.conf
test "$(sha256sum /etc/resolv.conf)" = "$resolver_checksum"

bash /src/install.sh --upgrade-only --maintenance-hosts pi.hole,192.168.1.2 --maintenance-lan-cidr 192.168.1.0/24
cmp /src/start_suite.py /var/lib/pihole-suite/app/start_suite.py
grep -Fqx custom-data /var/lib/pihole-suite/app/custom.txt
grep -Fqx old-venv /var/lib/pihole-suite/venv/preserved
grep -Fqx dns-baseline /etc/pihole-suite/dns-sentinel
grep -Fqx 'upstream config' /etc/pihole/pihole.toml
grep -Fqx 'unbound config' /etc/unbound/unbound.conf.d/forward.conf
test "$(sha256sum /etc/resolv.conf)" = "$resolver_checksum"
printf 'isolated upgrade and rollback: PASS\n'
