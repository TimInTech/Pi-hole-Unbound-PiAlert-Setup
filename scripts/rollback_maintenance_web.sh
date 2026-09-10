#!/usr/bin/env bash
set -euo pipefail

readonly BACKUP_ROOT="/var/backups/pihole-suite-deploy"
readonly MANIFEST_NAME="manifest.tsv"
readonly -a TARGETS=(
  "/etc/systemd/system/pihole-maintenance-check.service"
  "/etc/systemd/system/pihole-maintenance-backup.service"
  "/etc/systemd/system/pihole-maintenance-update.service"
  "/etc/sudoers.d/pihole-maintenance-web"
  "/etc/caddy/Caddyfile"
  "/etc/caddy/Caddyfile.d/pihole-maintenance.caddy"
  "/usr/local/libexec/pihole-maintenance-runner"
  "/usr/local/sbin/pihole-maintenance-web-rollback"
  "/var/lib/pihole-suite/app/start_suite.py"
  "/var/lib/pihole-suite/app/maintenance_web.py"
  "/var/lib/pihole-suite/app/web/maintenance.html"
  "/var/lib/pihole-suite/app/web/maintenance.css"
  "/var/lib/pihole-suite/app/web/maintenance.js"
  "/etc/systemd/system/pihole-suite.service"
  "/etc/systemd/system/pihole-suite.service.d/maintenance-web.conf"
  "/etc/pihole-suite/maintenance-web.json"
  "/usr/local/libexec/pihole-maintenance-backups"
  "/usr/local/libexec/maintenance_runner.py"
  "/usr/local/libexec/maintenance_backups.py"
  "/var/lib/pihole-suite/app/maintenance_backups.py"
  "/var/lib/pihole-suite/app/maintenance_config.py"
)

die() {
  printf 'maintenance web rollback: %s\n' "$*" >&2
  exit 1
}

is_allowed_target() {
  local target
  for target in "${TARGETS[@]}"; do
    [[ "$1" == "$target" ]] && return 0
  done
  return 1
}

assert_safe_parent_chain() {
  local path
  path="$(dirname -- "$1")"
  while [[ "$path" != "/" && "$path" != "." ]]; do
    [[ ! -L "$path" ]] || die "refusing symlinked parent directory: $path"
    path="$(dirname -- "$path")"
  done
}

validate_backup_dir() {
  local requested="$1" root_real backup_real
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "rollback must run as root"
  [[ -d "$requested" && ! -L "$requested" ]] || die "backup must be a real directory"
  root_real="$(realpath -e -- "$BACKUP_ROOT")"
  backup_real="$(realpath -e -- "$requested")"
  [[ "$(dirname -- "$backup_real")" == "$root_real" ]] || die "backup must be directly below $BACKUP_ROOT"
  [[ -f "$backup_real/$MANIFEST_NAME" && ! -L "$backup_real/$MANIFEST_NAME" ]] || die "missing safe manifest"
  printf '%s\n' "$backup_real"
}

validate_manifest() {
  local backup_dir="$1" line target status saved mode uid gid digest actual_digest count=0
  declare -A seen=()
  IFS= read -r line < "$backup_dir/$MANIFEST_NAME"
  [[ "$line" == 'version|2' ]] || die "unsupported manifest: use the rollback helper saved with an older snapshot"
  [[ -d "$backup_dir/files" && ! -L "$backup_dir/files" ]] || die "missing safe artifact directory"
  while IFS='|' read -r target status saved mode uid gid digest; do
    [[ -n "$target" ]] || die "empty manifest entry"
    is_allowed_target "$target" || die "unexpected manifest target"
    [[ -z "${seen[$target]:-}" ]] || die "duplicate manifest target"
    seen[$target]=1
    count=$((count + 1))
    case "$status" in
      present)
        [[ "$saved" =~ ^files/[0-9]+$ ]] || die "unsafe saved artifact path"
        [[ -f "$backup_dir/$saved" && ! -L "$backup_dir/$saved" ]] || die "missing saved artifact"
        [[ "$mode" =~ ^[0-7]{3,4}$ && "$uid" =~ ^[0-9]+$ && "$gid" =~ ^[0-9]+$ && "$digest" =~ ^[0-9a-f]{64}$ ]] || die "invalid saved artifact metadata"
        actual_digest="$(sha256sum -- "$backup_dir/$saved" | awk '{print $1}')"
        [[ "$actual_digest" == "$digest" ]] || die "saved artifact checksum mismatch"
        assert_safe_parent_chain "$target"
        [[ ! -L "$target" ]] || die "refusing to replace symlink target"
        ;;
      absent)
        [[ "$saved" == '-' && "$mode" == '-' && "$uid" == '-' && "$gid" == '-' && "$digest" == '-' ]] || die "invalid absent entry"
        assert_safe_parent_chain "$target"
        [[ ! -L "$target" ]] || die "refusing to remove symlink target"
        ;;
      *) die "invalid manifest status" ;;
    esac
  done < <(tail -n +2 "$backup_dir/$MANIFEST_NAME")
  [[ "$count" -eq "${#TARGETS[@]}" ]] || die "manifest does not cover all deployment artifacts"
  for target in "${TARGETS[@]}"; do
    [[ -n "${seen[$target]:-}" ]] || die "manifest misses expected target"
  done
}

restore_manifest() {
  local backup_dir="$1" line target status saved mode uid gid digest
  while IFS='|' read -r target status saved mode uid gid digest; do
    case "$status" in
      present)
        assert_safe_parent_chain "$target"
        [[ ! -L "$target" ]] || die "refusing to replace symlink target"
        install -d -o root -g root -m 0755 "$(dirname -- "$target")"
        install -o "$uid" -g "$gid" -m "$mode" -- "$backup_dir/$saved" "$target"
        ;;
      absent)
        assert_safe_parent_chain "$target"
        [[ ! -L "$target" ]] || die "refusing to remove symlink target"
        rm -f -- "$target"
        ;;
    esac
  done < <(tail -n +2 "$backup_dir/$MANIFEST_NAME")
}

validate_and_activate() {
  local unit artifact
  local -a python_artifacts=()
  for artifact in /usr/local/libexec/pihole-maintenance-runner /var/lib/pihole-suite/app/start_suite.py /var/lib/pihole-suite/app/maintenance_web.py; do
    [[ -f "$artifact" ]] && python_artifacts+=("$artifact")
  done
  [[ ${#python_artifacts[@]} -gt 0 ]] && /usr/bin/python3 -m py_compile "${python_artifacts[@]}"
  if [[ -f /etc/sudoers.d/pihole-maintenance-web ]]; then
    /usr/sbin/visudo -cf /etc/sudoers.d/pihole-maintenance-web
  fi
  for unit in /etc/systemd/system/pihole-maintenance-*.service; do
    [[ -e "$unit" ]] || continue
    /usr/bin/systemd-analyze verify "$unit"
  done
  /usr/bin/caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
  /usr/bin/systemctl daemon-reload
  /usr/bin/systemctl reload caddy
  /usr/bin/systemctl restart pihole-suite.service
  /usr/bin/systemctl is-active --quiet pihole-FTL.service
  /usr/bin/systemctl is-active --quiet unbound.service
  /usr/bin/dig +time=3 +tries=1 +short @127.0.0.1 example.com A | /usr/bin/grep -Eq '^[0-9.]+'
  /usr/bin/dig +time=3 +tries=1 +short @127.0.0.1 -p 5335 example.com A | /usr/bin/grep -Eq '^[0-9.]+'
}

main() {
  [[ $# -eq 2 && "$1" == '--backup-dir' ]] || die "usage: $0 --backup-dir /var/backups/pihole-suite-deploy/NAME"
  local backup_dir
  backup_dir="$(validate_backup_dir "$2")"
  validate_manifest "$backup_dir"
  restore_manifest "$backup_dir"
  validate_and_activate
}

main "$@"
