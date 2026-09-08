#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DESTDIR="$(mktemp -d)"
GUARD_DIR="$(mktemp -d)"
UNSAFE_DESTDIR="$(mktemp -d)"
GUARD_LOG="$DESTDIR/forbidden-actions.log"
trap 'rm -rf -- "$DESTDIR" "$GUARD_DIR" "$UNSAFE_DESTDIR"' EXIT

# A staged install must never touch packages, networking, or live services.
for command in apt apt-get caddy curl service sudo systemctl; do
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$0 $*" >> "%s"\nexit 97\n' "$GUARD_LOG" > "$GUARD_DIR/$command"
  chmod 0755 "$GUARD_DIR/$command"
done

run_staged_install() {
  PATH="$GUARD_DIR:$PATH" bash "$ROOT_DIR/scripts/install_maintenance_web.sh" --destdir "$DESTDIR"
}

run_staged_install
first_tree="$({ cd "$DESTDIR" && find . -type f -print0 | sort -z | xargs -0 sha256sum; })"
run_staged_install
second_tree="$({ cd "$DESTDIR" && find . -type f -print0 | sort -z | xargs -0 sha256sum; })"
test "$first_tree" = "$second_tree"
test ! -s "$GUARD_LOG"

# A compromised prior app tree must not redirect a root-owned installation.
mkdir -p "$UNSAFE_DESTDIR/var/lib/pihole-suite/app"
ln -s /tmp "$UNSAFE_DESTDIR/var/lib/pihole-suite/app/web"
if PATH="$GUARD_DIR:$PATH" bash "$ROOT_DIR/scripts/install_maintenance_web.sh" --destdir "$UNSAFE_DESTDIR" >/dev/null 2>&1; then
  printf '%s\n' 'symlinked app parent was accepted' >&2
  exit 1
fi

assert_mode() {
  test "$(stat -c %a "$1")" = "$2"
}

assert_mode "$DESTDIR/usr/local/libexec/pihole-maintenance-runner" 755
assert_mode "$DESTDIR/usr/local/sbin/pihole-maintenance-web-rollback" 755
assert_mode "$DESTDIR/var/lib/pihole-suite/app" 755
assert_mode "$DESTDIR/var/lib/pihole-suite/app/web" 755
assert_mode "$DESTDIR/var/lib/pihole-suite/app/start_suite.py" 644
assert_mode "$DESTDIR/var/lib/pihole-suite/app/maintenance_web.py" 644
assert_mode "$DESTDIR/var/lib/pihole-suite/app/web/maintenance.html" 644
assert_mode "$DESTDIR/var/lib/pihole-suite/app/web/maintenance.css" 644
assert_mode "$DESTDIR/var/lib/pihole-suite/app/web/maintenance.js" 644

for action in check backup update; do
  unit="$DESTDIR/etc/systemd/system/pihole-maintenance-${action}.service"
  assert_mode "$unit" 644
  grep -Fqx 'User=root' "$unit"
  grep -Fqx 'Group=root' "$unit"
  grep -Fqx 'UMask=0077' "$unit"
  grep -Fqx 'Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' "$unit"
  grep -Fqx "ExecStart=/usr/local/libexec/pihole-maintenance-runner ${action}" "$unit"
  ! grep -Eq '^Exec(Start|StartPre|StartPost)=.*(sh -c|bash -c)' "$unit"
done
grep -Fqx 'TimeoutStartSec=15min' "$DESTDIR/etc/systemd/system/pihole-maintenance-check.service"
grep -Fqx 'TimeoutStartSec=15min' "$DESTDIR/etc/systemd/system/pihole-maintenance-backup.service"
grep -Fqx 'TimeoutStartSec=120min' "$DESTDIR/etc/systemd/system/pihole-maintenance-update.service"

SUDOERS="$DESTDIR/etc/sudoers.d/pihole-maintenance-web"
assert_mode "$SUDOERS" 440
for action in check backup update; do
  grep -Fqx "pihole-suite ALL=(root) NOPASSWD: /usr/bin/systemctl start --no-block pihole-maintenance-${action}.service" "$SUDOERS"
done
test "$(grep -Ec '^pihole-suite ALL=' "$SUDOERS")" = 3
! grep -Eq '[*]|ALL[[:space:]]*=.*(sh|bash)' "$SUDOERS"

CADDY_MAIN="$DESTDIR/etc/caddy/Caddyfile"
CADDY_SNIPPET="$DESTDIR/etc/caddy/Caddyfile.d/pihole-maintenance.caddy"
assert_mode "$CADDY_MAIN" 644
assert_mode "$CADDY_SNIPPET" 644
test "$(grep -Fxc 'import Caddyfile.d/*' "$CADDY_MAIN")" = 1
grep -Fqx 'pi.hole:8443, 192.168.178.2:8443 {' "$CADDY_SNIPPET"
grep -Fqx '    tls internal' "$CADDY_SNIPPET"
grep -Fqx '    @lan remote_ip 192.168.178.0/24 127.0.0.1 ::1' "$CADDY_SNIPPET"
grep -Fqx '    handle @lan {' "$CADDY_SNIPPET"
grep -Fqx '        reverse_proxy 127.0.0.1:8090' "$CADDY_SNIPPET"
grep -Fqx '    respond "Forbidden" 403' "$CADDY_SNIPPET"
test "$(grep -Foc '{' "$CADDY_SNIPPET")" = "$(grep -Foc '}' "$CADDY_SNIPPET")"

# Source intent: default Python API install is complete and root-owned, while
# privileged web exposure remains explicitly opt-in.
grep -Fqx 'INSTALL_MAINTENANCE_WEB=false' "$ROOT_DIR/install.sh"
grep -Fq -- '--with-maintenance-web) INSTALL_MAINTENANCE_WEB=true ;;' "$ROOT_DIR/install.sh"
grep -Fq -- '--skip-maintenance-web) INSTALL_MAINTENANCE_WEB=false ;;' "$ROOT_DIR/install.sh"
grep -Fq 'install_python_suite_app_files' "$ROOT_DIR/install.sh"
grep -Fq 'maintenance_web.py' "$ROOT_DIR/install.sh"
grep -Fq 'web/maintenance.html' "$ROOT_DIR/install.sh"
grep -Fq 'web/maintenance.css' "$ROOT_DIR/install.sh"
grep -Fq 'web/maintenance.js' "$ROOT_DIR/install.sh"
grep -Fq 'install -o root -g root -m 0644' "$ROOT_DIR/install.sh"
grep -Fq 'scripts/install_maintenance_web.sh' "$ROOT_DIR/install.sh"
grep -Fq 'DRY RUN: Would install privileged maintenance web exposure' "$ROOT_DIR/install.sh"
test -x "$ROOT_DIR/scripts/install_maintenance_web.sh"
test -x "$ROOT_DIR/scripts/rollback_maintenance_web.sh"

# Deployment backup/rollback must be manifest-bound and preserve metadata.
grep -Fq 'manifest.tsv' "$ROOT_DIR/scripts/install_maintenance_web.sh"
grep -Fq 'sha256sum' "$ROOT_DIR/scripts/install_maintenance_web.sh"
grep -Fq 'install -o "$uid" -g "$gid" -m "$mode"' "$ROOT_DIR/scripts/rollback_maintenance_web.sh"
grep -Fq 'validate_manifest "$backup_dir"' "$ROOT_DIR/scripts/rollback_maintenance_web.sh"
grep -Fq 'restore_manifest "$backup_dir"' "$ROOT_DIR/scripts/rollback_maintenance_web.sh"
grep -Fq 'missing safe artifact directory' "$ROOT_DIR/scripts/rollback_maintenance_web.sh"
grep -Fq 'manifest does not cover all deployment artifacts' "$ROOT_DIR/scripts/rollback_maintenance_web.sh"
grep -Fq 'refusing to replace symlink target' "$ROOT_DIR/scripts/rollback_maintenance_web.sh"

echo 'maintenance web staged installer: PASS'
