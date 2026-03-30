#!/usr/bin/env bash
# =============================================================================
# rescue_menu.sh  --  Pi-hole + Unbound Rescue & Maintenance Menu
# Version: 1.0.0
# Repo:    https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup
# =============================================================================
# Start globally:  sudo pihole-rescue
# Self-contained:  works without repo present; sources lib/ui.sh if found.
# =============================================================================

# No -e: interactive menus must survive individual command failures.
set -uo pipefail
IFS=$'\n\t'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------
readonly SCRIPT_VERSION="1.0.0"
readonly BACKUP_DIR="/home/pi/pihole-rescue-backups"
readonly LOG_FILE="/var/log/pihole-rescue-menu.log"
readonly RESOLV_BACKUP="/tmp/.pihole-rescue-resolv.bak"
readonly PIHOLE_CONF="/etc/pihole/pihole.toml"
readonly UNBOUND_CONF_DIR="/etc/unbound"

# ---------------------------------------------------------------------------
# UI SETUP -- source lib/ui.sh if accessible, otherwise inline fallback
# ---------------------------------------------------------------------------
_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_ui_lib="${_script_dir}/lib/ui.sh"
if [[ -f "$_ui_lib" ]]; then
  # shellcheck source=/dev/null
  source "$_ui_lib"
  ui_init
else
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    UI_RED=$'\033[0;31m'
    UI_GREEN=$'\033[0;32m'
    UI_YELLOW=$'\033[1;33m'
    UI_BLUE=$'\033[0;34m'
    UI_CYAN=$'\033[0;36m'
    UI_BOLD=$'\033[1m'
    UI_RESET=$'\033[0m'
  else
    UI_RED='' UI_GREEN='' UI_YELLOW='' UI_BLUE='' UI_CYAN='' UI_BOLD='' UI_RESET=''
  fi
  log_ok()   { printf '[OK]   %s\n' "$*"; }
  log_err()  { printf '[ERR]  %s\n' "$*" >&2; }
  log_warn() { printf '[WARN] %s\n' "$*" >&2; }
  log_info() { printf '[INFO] %s\n' "$*"; }
fi

# ---------------------------------------------------------------------------
# ROOT CHECK
# ---------------------------------------------------------------------------
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  printf '%s[ERROR]%s Root required. Re-running with sudo...\n' \
    "$UI_RED" "$UI_RESET" >&2
  exec sudo "$0" "$@"
fi

# ---------------------------------------------------------------------------
# LOGGING
# ---------------------------------------------------------------------------
_log() {
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  printf '[%s] %s\n' "$ts" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# PRINT HELPERS
# ---------------------------------------------------------------------------
_pause() {
  printf '\n'
  read -rp "  Press [Enter] to continue... " _dummy
}

_header() {
  clear
  local pi_ip
  pi_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  printf '%s' "$UI_BLUE"
  printf '  +================================================================+\n'
  printf '  |   Pi-hole + Unbound  RESCUE MENU  v%-6s                     |\n' \
    "$SCRIPT_VERSION"
  printf '  |   Pi: %-22s  |  %s               |\n' \
    "${pi_ip:-unknown}" "$(date '+%H:%M:%S')"
  printf '  +================================================================+\n'
  printf '%s\n' "$UI_RESET"
}

_ok()   { printf '  %s[OK]%s   %s\n' "$UI_GREEN"  "$UI_RESET" "$*"; }
_err()  { printf '  %s[ERR]%s  %s\n' "$UI_RED"    "$UI_RESET" "$*"; }
_warn() { printf '  %s[WARN]%s %s\n' "$UI_YELLOW" "$UI_RESET" "$*"; }
_info() { printf '  %s[..]%s   %s\n' "$UI_CYAN"   "$UI_RESET" "$*"; }

# ---------------------------------------------------------------------------
# DNS TEST HELPER
# ---------------------------------------------------------------------------
_dns_test() {
  local label="$1" server="$2" port="${3:-53}"
  local ans
  if [[ "$port" == "53" ]]; then
    ans=$(dig +short @"$server" google.com +time=3 +tries=1 2>/dev/null | head -1)
  else
    ans=$(dig +short -p "$port" @"$server" google.com +time=3 +tries=1 2>/dev/null | head -1)
  fi
  if [[ -n "$ans" ]]; then
    _ok "${label} -> ${UI_CYAN}${ans}${UI_RESET}"
    return 0
  else
    _err "${label} -> NO RESPONSE"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# READ PIHOLE UPSTREAM HELPER
# ---------------------------------------------------------------------------
_read_upstream() {
  if command -v python3 &>/dev/null && [[ -f "$PIHOLE_CONF" ]]; then
    python3 - "$PIHOLE_CONF" <<'PYEOF' 2>/dev/null
import re, sys
with open(sys.argv[1]) as f:
    c = f.read()
m = re.search(r'upstreams\s*=\s*(\[[^\]]*\])', c, re.DOTALL)
print(m.group(1).strip().replace('\n', ' ').replace('  ', '') if m else 'not_found')
PYEOF
  else
    grep -A4 'upstreams' "$PIHOLE_CONF" 2>/dev/null | tr '\n' ' ' | cut -c1-80 \
      || echo 'not_found'
  fi
}

# ---------------------------------------------------------------------------
# SET PIHOLE UPSTREAM HELPER
# ---------------------------------------------------------------------------
_set_pihole_upstream() {
  local target="${1:-127.0.0.1#5335}"

  # Method 1: pihole v6 CLI
  if command -v pihole &>/dev/null; then
    if pihole --config dns.upstreams "[\"$target\"]" 2>/dev/null; then
      _ok "Upstream set via pihole CLI -> $target"
      return 0
    fi
  fi

  # Method 2: python3 regex TOML rewrite (multiline-safe)
  if [[ -f "$PIHOLE_CONF" ]] && command -v python3 &>/dev/null; then
    python3 - "$PIHOLE_CONF" "$target" <<'PYEOF' 2>/dev/null
import re, sys
conf_path, target = sys.argv[1], sys.argv[2]
with open(conf_path, 'r') as f:
    content = f.read()
new_val = '  upstreams = [\n    "{}"\n  ]'.format(target)
content_new = re.sub(
    r'\bupstreams\s*=\s*\[[^\]]*\](\s*###[^\n]*)?',
    lambda m: new_val + (m.group(1) or ''),
    content, flags=re.DOTALL
)
with open(conf_path, 'w') as f:
    f.write(content_new)
PYEOF
    _ok "Upstream set via TOML rewrite -> $target"
    return 0
  fi

  _err "Cannot set upstream: pihole CLI and python3 unavailable"
  return 1
}

# ---------------------------------------------------------------------------
# BACKUP HELPERS
# ---------------------------------------------------------------------------
_backup_write() {
  local bdir="$1"
  mkdir -p "$bdir"
  local ok=0 fail=0

  if [[ -f "$PIHOLE_CONF" ]]; then
    cp "$PIHOLE_CONF" "$bdir/pihole.toml" \
      && _ok "pihole.toml" && ok=$((ok + 1)) \
      || { _err "pihole.toml copy failed"; fail=$((fail + 1)); }
  else
    _warn "pihole.toml not found at $PIHOLE_CONF"
  fi

  if [[ -d "$UNBOUND_CONF_DIR" ]]; then
    cp -r "$UNBOUND_CONF_DIR" "$bdir/unbound" \
      && _ok "/etc/unbound" && ok=$((ok + 1)) \
      || { _err "/etc/unbound copy failed"; fail=$((fail + 1)); }
  else
    _warn "/etc/unbound not found"
  fi

  for dropin in \
    /etc/systemd/system/unbound.service.d \
    /etc/systemd/system/pihole-FTL.service.d; do
    if [[ -d "$dropin" ]]; then
      local dname
      dname=$(basename "$dropin")
      cp -r "$dropin" "$bdir/$dname" \
        && _ok "$dropin" && ok=$((ok + 1)) \
        || { _err "$dropin copy failed"; fail=$((fail + 1)); }
    fi
  done

  {
    printf 'version=%s\n' "$SCRIPT_VERSION"
    printf 'timestamp=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'hostname=%s\n' "$(hostname)"
    printf 'pihole_upstream=%s\n' "$(_read_upstream)"
    printf 'unbound_active=%s\n' \
      "$(systemctl is-active unbound 2>/dev/null || echo unknown)"
    printf 'pihole_ftl_active=%s\n' \
      "$(systemctl is-active pihole-FTL 2>/dev/null || echo unknown)"
  } > "$bdir/meta.txt"

  printf '  --\n'
  printf '  Saved: %s%s%s\n' "$UI_CYAN" "$bdir" "$UI_RESET"
  printf '  Files: %s%d OK%s  %s%d failed%s\n' \
    "$UI_GREEN" "$ok" "$UI_RESET" "$UI_RED" "$fail" "$UI_RESET"
  return "$fail"
}

_list_backups() {
  _BACKUPS=()
  if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
    _warn "No backups found in $BACKUP_DIR"
    return 1
  fi
  mapfile -t _BACKUPS < <(ls -1t "$BACKUP_DIR")
  local i=1
  for b in "${_BACKUPS[@]}"; do
    local meta="${BACKUP_DIR}/${b}/meta.txt"
    local ts=''
    [[ -f "$meta" ]] && ts=$(grep '^timestamp=' "$meta" 2>/dev/null | cut -d= -f2)
    printf '  %2d)  %-25s %s\n' "$i" "$b" "${ts:+(${ts})}"
    i=$((i + 1))
  done
  return 0
}

# =============================================================================
# MENU FUNCTIONS
# =============================================================================

# --- 1. System Status --------------------------------------------------------
menu_status() {
  _header
  printf '  %s=== SYSTEM STATUS ===%s\n\n' "$UI_BOLD" "$UI_RESET"

  printf '  %sServices:%s\n' "$UI_BOLD" "$UI_RESET"
  for svc in unbound pihole-FTL; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      local since
      since=$(systemctl show "$svc" --property=ActiveEnterTimestamp \
        --no-pager 2>/dev/null | cut -d= -f2 | awk '{print $2, $3}')
      _ok "$svc  active  ${since:+(since $since)}"
    else
      _err "$svc  INACTIVE"
    fi
  done

  printf '\n  %sDNS Tests:%s\n' "$UI_BOLD" "$UI_RESET"
  _dns_test "Unbound  127.0.0.1:5335" "127.0.0.1" "5335"
  _dns_test "Pi-hole  127.0.0.1:53  " "127.0.0.1" "53"

  printf '\n  %sPi-hole Upstream:%s\n' "$UI_BOLD" "$UI_RESET"
  printf '  %s    %s%s\n' "$UI_CYAN" "$(_read_upstream)" "$UI_RESET"

  printf '\n  %sListening Ports (53 / 5335):%s\n' "$UI_BOLD" "$UI_RESET"
  ss -lnup 2>/dev/null | grep -E ':53 |:5335 ' | \
    awk '{printf "    %-65s\n", $0}' | head -8 \
    || _warn "ss not available"

  printf '\n  %sSystem Resources:%s\n' "$UI_BOLD" "$UI_RESET"
  printf '  %s    RAM:  %s  |  Disk: %s%s\n' "$UI_CYAN" \
    "$(free -h | awk '/Mem:/{print $3"/"$2}')" \
    "$(df -h / | awk 'NR==2{print $3"/"$2" ("$5" used)"}')" \
    "$UI_RESET"
  if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    local temp
    temp=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
    printf '  %s    Temp: %d C%s\n' "$UI_CYAN" "$temp" "$UI_RESET"
  fi

  _log "status check"
  _pause
}

# --- 2. DNS Loop / Upstream Check --------------------------------------------
menu_dns_loop_check() {
  _header
  printf '  %s=== DNS LOOP / UPSTREAM CHECK ===%s\n\n' "$UI_BOLD" "$UI_RESET"
  local issues=0

  printf '  %s[1] Unbound 127.0.0.1:5335%s\n' "$UI_BOLD" "$UI_RESET"
  _dns_test "  Direct query" "127.0.0.1" "5335" || issues=$((issues + 1))

  printf '\n  %s[2] Pi-hole 127.0.0.1:53%s\n' "$UI_BOLD" "$UI_RESET"
  _dns_test "  Query" "127.0.0.1" "53" || issues=$((issues + 1))

  printf '\n  %s[3] Loop detection -- Pi-hole upstream%s\n' "$UI_BOLD" "$UI_RESET"
  if [[ -f "$PIHOLE_CONF" ]]; then
    local upstream_raw
    upstream_raw=$(_read_upstream)
    if printf '%s' "$upstream_raw" | grep -qE '"127\.0\.0\.1"[^#5]|127\.0\.0\.1"\s*\]'; then
      _err "LOOP RISK: upstream has 127.0.0.1 without port 5335"
      issues=$((issues + 1))
    elif printf '%s' "$upstream_raw" | grep -q '5335'; then
      _ok "Upstream uses Unbound port 5335 -- OK"
      printf '  %s    -> %s%s\n' "$UI_CYAN" "$upstream_raw" "$UI_RESET"
    else
      _warn "Upstream value: $upstream_raw"
    fi
  else
    _warn "pihole.toml not found"
  fi

  printf '\n  %s[4] Blocking test (doubleclick.net)%s\n' "$UI_BOLD" "$UI_RESET"
  local blocked
  blocked=$(dig +short @127.0.0.1 doubleclick.net +time=3 +tries=1 2>/dev/null | head -1)
  if [[ "$blocked" == "0.0.0.0" || -z "$blocked" ]]; then
    _ok "doubleclick.net blocked -> ${blocked:-NXDOMAIN/empty}"
  else
    _warn "doubleclick.net -> $blocked  (check blocklists)"
  fi

  printf '\n  %s[5] External recursive (Unbound)%s\n' "$UI_BOLD" "$UI_RESET"
  _dns_test "  cloudflare.com via Unbound" "127.0.0.1" "5335" \
    || issues=$((issues + 1))

  printf '\n  --\n'
  if (( issues == 0 )); then
    printf '  %s[OK] No DNS issues detected%s\n' "$UI_GREEN" "$UI_RESET"
  else
    printf '  %s[!!] %d issue(s) found -- run option 9 (Standard Fix)%s\n' \
      "$UI_RED" "$issues" "$UI_RESET"
  fi

  _log "dns-loop-check: $issues issue(s)"
  _pause
}

# --- 3. Nightly Diagnostic Test ----------------------------------------------
menu_nightly_test() {
  _header
  printf '  %s=== NIGHTLY / DIAGNOSTIC TEST ===%s\n\n' "$UI_BOLD" "$UI_RESET"

  local nightly="/home/pi/Pi-hole-Unbound-PiAlert-Setup/scripts/nightly_test.sh"
  if [[ -x "$nightly" ]]; then
    printf '  %sRunning nightly_test.sh...%s\n\n' "$UI_BLUE" "$UI_RESET"
    "$nightly" 2>&1 | sed 's/^/  /'
  else
    _info "nightly_test.sh not found -- running inline diagnostic"
    printf '\n  %s-- Services --%s\n' "$UI_BOLD" "$UI_RESET"
    for svc in unbound pihole-FTL; do
      local state
      state=$(systemctl is-active "$svc" 2>/dev/null || echo inactive)
      if [[ "$state" == "active" ]]; then
        _ok "$svc: $state"
      else
        _err "$svc: $state"
      fi
    done

    printf '\n  %s-- DNS Resolution --%s\n' "$UI_BOLD" "$UI_RESET"
    for domain in google.com cloudflare.com github.com; do
      local ans
      ans=$(dig +short @127.0.0.1 "$domain" +time=3 +tries=1 2>/dev/null | head -1)
      if [[ -n "$ans" ]]; then
        printf '  %s[OK]%s   %-22s -> %s\n' "$UI_GREEN" "$UI_RESET" "$domain" "$ans"
      else
        printf '  %s[ERR]%s  %-22s -> FAILED\n' "$UI_RED" "$UI_RESET" "$domain"
      fi
    done

    printf '\n  %s-- Blocking Test --%s\n' "$UI_BOLD" "$UI_RESET"
    for bd in doubleclick.net pagead2.googlesyndication.com; do
      local r
      r=$(dig +short @127.0.0.1 "$bd" +time=3 +tries=1 2>/dev/null | head -1)
      if [[ "$r" == "0.0.0.0" || -z "$r" ]]; then
        printf '  %s[OK]%s   %-42s -> BLOCKED\n' "$UI_GREEN" "$UI_RESET" "$bd"
      else
        printf '  %s[WARN]%s %-42s -> %s\n' "$UI_YELLOW" "$UI_RESET" "$bd" "$r"
      fi
    done

    printf '\n  %s-- System Load --%s\n' "$UI_BOLD" "$UI_RESET"
    uptime | awk '{printf "  %s\n", $0}'
  fi

  _log "diagnostic test run"
  _pause
}

# --- 4. Create Backup --------------------------------------------------------
menu_backup_create() {
  _header
  printf '  %s=== CREATE BACKUP ===%s\n\n' "$UI_BOLD" "$UI_RESET"
  mkdir -p "$BACKUP_DIR"
  local ts
  ts=$(date '+%Y%m%d_%H%M%S')
  _backup_write "${BACKUP_DIR}/${ts}"
  _log "backup created: ${BACKUP_DIR}/${ts}"
  _pause
}

# --- 5. Restore Backup -------------------------------------------------------
menu_backup_restore() {
  _header
  printf '  %s=== RESTORE BACKUP ===%s\n\n' "$UI_BOLD" "$UI_RESET"

  _BACKUPS=()
  _list_backups || { _pause; return; }

  printf '\n   0)  Cancel\n\n'
  read -rp "  Choice: " sel

  if [[ "$sel" == "0" || -z "$sel" ]]; then return; fi
  if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#_BACKUPS[@]} )); then
    _err "Invalid selection"
    _pause
    return
  fi

  local chosen="${_BACKUPS[$((sel - 1))]}"
  local bdir="${BACKUP_DIR}/${chosen}"
  printf '\n  %sRestore from: %s%s\n' "$UI_YELLOW" "$chosen" "$UI_RESET"
  read -rp "  Confirm? [y/N] " confirm
  [[ "${confirm,,}" != "y" ]] && return

  [[ -f "$bdir/pihole.toml" ]] \
    && cp "$bdir/pihole.toml" "$PIHOLE_CONF" && _ok "pihole.toml restored" \
    || _warn "pihole.toml not in this backup"

  if [[ -d "$bdir/unbound" ]]; then
    cp -r "$bdir/unbound/." "$UNBOUND_CONF_DIR/" \
      && _ok "/etc/unbound restored" \
      || _err "/etc/unbound restore failed"
  fi

  printf '\n  Restarting services...\n'
  systemctl restart unbound 2>&1 && _ok "unbound restarted" \
    || _err "unbound restart failed"
  sleep 1
  systemctl restart pihole-FTL 2>&1 && _ok "pihole-FTL restarted" \
    || _err "pihole-FTL restart failed"
  sleep 2

  printf '\n  %sVerification:%s\n' "$UI_BOLD" "$UI_RESET"
  _dns_test "Unbound :5335" "127.0.0.1" "5335"
  _dns_test "Pi-hole :53  " "127.0.0.1" "53"

  _log "restored from: $bdir"
  _pause
}

# --- 6. Delete Old Backups ---------------------------------------------------
menu_backup_delete() {
  _header
  printf '  %s=== DELETE OLD BACKUPS ===%s\n\n' "$UI_BOLD" "$UI_RESET"

  _BACKUPS=()
  _list_backups || { _pause; return; }

  printf '\n  Options:\n'
  printf '   a)  Delete all except newest\n'
  printf '   b)  Delete backups older than 14 days\n'
  printf '   0)  Cancel\n\n'
  read -rp "  Choice: " sel

  case "${sel,,}" in
    a)
      local count=0
      for b in "${_BACKUPS[@]:1}"; do
        rm -rf "${BACKUP_DIR:?}/${b}" && count=$((count + 1)) || true
      done
      _ok "$count backup(s) deleted (newest kept)"
      _log "deleted $count backups (keep-newest)"
      ;;
    b)
      local count=0
      while IFS= read -r -d '' f; do
        rm -rf "$f" && count=$((count + 1)) || true
      done < <(find "$BACKUP_DIR" -maxdepth 1 -mindepth 1 \
        -type d -mtime +14 -print0 2>/dev/null)
      _ok "$count backup(s) older than 14 days deleted"
      _log "deleted $count backups >14 days"
      ;;
    0 | '') return ;;
    *) _err "Invalid choice: '$sel'" ;;
  esac
  _pause
}

# --- 7. Last Known Good Restore ----------------------------------------------
menu_last_known_good() {
  _header
  printf '  %s=== LAST KNOWN GOOD RESTORE ===%s\n\n' "$UI_BOLD" "$UI_RESET"
  printf '  Steps:\n'
  printf '    [1] Restore newest backup (if available)\n'
  printf '    [2] Force Pi-hole upstream -> 127.0.0.1#5335\n'
  printf '    [3] Restart unbound + pihole-FTL\n'
  printf '    [4] Verify DNS resolution\n\n'

  local newest=''
  [[ -d "$BACKUP_DIR" ]] && newest=$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -1)

  if [[ -n "$newest" ]]; then
    printf '  %sNewest backup: %s%s\n\n' "$UI_CYAN" "$newest" "$UI_RESET"
  else
    _warn "No backup found -- will only fix config + restart"
    printf '\n'
  fi

  read -rp "  Proceed? [y/N] " confirm
  [[ "${confirm,,}" != "y" ]] && return

  if [[ -n "$newest" ]]; then
    printf '\n  %s[1/4] Restoring backup...%s\n' "$UI_BLUE" "$UI_RESET"
    local bdir="${BACKUP_DIR}/${newest}"
    [[ -f "$bdir/pihole.toml" ]] \
      && cp "$bdir/pihole.toml" "$PIHOLE_CONF" && _ok "pihole.toml" || true
    [[ -d "$bdir/unbound" ]] \
      && cp -r "$bdir/unbound/." "$UNBOUND_CONF_DIR/" && _ok "/etc/unbound" || true
  else
    printf '\n  %s[1/4] No backup -- skipped%s\n' "$UI_BLUE" "$UI_RESET"
  fi

  printf '\n  %s[2/4] Setting upstream -> 127.0.0.1#5335...%s\n' \
    "$UI_BLUE" "$UI_RESET"
  _set_pihole_upstream "127.0.0.1#5335"

  printf '\n  %s[3/4] Restarting services...%s\n' "$UI_BLUE" "$UI_RESET"
  systemctl restart unbound 2>&1 && _ok "unbound" \
    || _err "unbound restart failed"
  sleep 2
  systemctl restart pihole-FTL 2>&1 && _ok "pihole-FTL" \
    || _err "pihole-FTL restart failed"
  sleep 2

  printf '\n  %s[4/4] DNS Verification...%s\n' "$UI_BLUE" "$UI_RESET"
  _dns_test "Unbound 127.0.0.1:5335" "127.0.0.1" "5335"
  _dns_test "Pi-hole 127.0.0.1:53  " "127.0.0.1" "53"

  _log "last-known-good restore (backup: ${newest:-none})"
  _pause
}

# --- 8. Emergency DNS Bypass -------------------------------------------------
menu_emergency_bypass() {
  _header
  printf '  %s=== EMERGENCY DNS BYPASS ===%s\n\n' "$UI_BOLD" "$UI_RESET"
  printf '  %sTemporarily routes the Pi itself to an external resolver.\n' \
    "$UI_YELLOW"
  printf '  SSH / apt / curl stay functional.\n'
  printf '  Pi-hole continues serving the rest of the network.%s\n\n' "$UI_RESET"

  printf '  Current /etc/resolv.conf:\n'
  sed 's/^/    /' /etc/resolv.conf 2>/dev/null
  printf '\n'

  printf '  Options:\n'
  printf '   1)  Activate bypass   -> 8.8.8.8 / 1.1.1.1\n'
  printf '   2)  Restore original  (deactivate bypass)\n'
  printf '   3)  Show current status\n'
  printf '   0)  Cancel\n\n'
  read -rp "  Choice: " sel

  case "$sel" in
    1)
      cp /etc/resolv.conf "$RESOLV_BACKUP" 2>/dev/null || true
      if [[ -L /etc/resolv.conf ]]; then
        local tgt
        tgt=$(readlink -f /etc/resolv.conf)
        _info "resolv.conf is symlink -> $tgt (replacing with regular file)"
        rm /etc/resolv.conf
        cp "$tgt" /etc/resolv.conf 2>/dev/null || touch /etc/resolv.conf
      fi
      printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n# pihole-rescue bypass\n' \
        > /etc/resolv.conf
      _ok "Bypass active: 8.8.8.8 / 1.1.1.1"
      printf '  %s    Backup: %s%s\n' "$UI_CYAN" "$RESOLV_BACKUP" "$UI_RESET"
      printf '  %s    Revert: choose option 2, or manually:%s\n' \
        "$UI_YELLOW" "$UI_RESET"
      printf '  %s      cp %s /etc/resolv.conf%s\n' \
        "$UI_YELLOW" "$RESOLV_BACKUP" "$UI_RESET"
      _log "emergency DNS bypass ACTIVATED"
      ;;
    2)
      if [[ -f "$RESOLV_BACKUP" ]]; then
        cp "$RESOLV_BACKUP" /etc/resolv.conf
        _ok "Original /etc/resolv.conf restored"
        _log "emergency DNS bypass DEACTIVATED"
      else
        _warn "No backup at $RESOLV_BACKUP"
        _info "Try: systemctl restart dhcpcd || systemctl restart NetworkManager"
      fi
      ;;
    3)
      printf '\n  Active /etc/resolv.conf:\n'
      sed 's/^/    /' /etc/resolv.conf 2>/dev/null
      if [[ -f "$RESOLV_BACKUP" ]]; then
        printf '\n  %sRescue backup present -> bypass WAS activated%s\n' \
          "$UI_YELLOW" "$UI_RESET"
      else
        printf '\n  No rescue backup -> bypass is not active.\n'
      fi
      ;;
    0 | '') return ;;
    *) _err "Invalid choice" ;;
  esac
  _pause
}

# --- 9. Pi-hole -> Unbound Standard Fix -------------------------------------
menu_pihole_unbound_fix() {
  _header
  printf '  %s=== PI-HOLE -> UNBOUND STANDARD FIX ===%s\n\n' "$UI_BOLD" "$UI_RESET"
  printf '  Applies:\n'
  printf '    [1] Pi-hole upstream = 127.0.0.1#5335\n'
  printf '    [2] Verify unbound listening on port 5335\n'
  printf '    [3] Restart + enable both services\n\n'

  read -rp "  Apply fix now? [y/N] " confirm
  [[ "${confirm,,}" != "y" ]] && return

  printf '\n  %s[1/3] Setting Pi-hole upstream...%s\n' "$UI_BLUE" "$UI_RESET"
  _set_pihole_upstream "127.0.0.1#5335"

  printf '\n  %s[2/3] Checking unbound config...%s\n' "$UI_BLUE" "$UI_RESET"
  if grep -r 'port: 5335\|port 5335' "$UNBOUND_CONF_DIR" 2>/dev/null | grep -q .; then
    _ok "Unbound configured for port 5335"
  else
    _warn "Port 5335 not found -- creating minimal config"
    mkdir -p "$UNBOUND_CONF_DIR/unbound.conf.d"
    cat > "$UNBOUND_CONF_DIR/unbound.conf.d/10-pihole-listen.conf" <<'UBCONF'
server:
  interface: 127.0.0.1
  port: 5335
  do-ip4: yes
  do-udp: yes
  do-tcp: yes
  do-ip6: no
  access-control: 127.0.0.0/8 allow
  access-control: 192.168.0.0/16 allow
  root-hints: "/var/lib/unbound/root.hints"
  qname-minimisation: yes
  prefetch: yes
UBCONF
    _ok "Created $UNBOUND_CONF_DIR/unbound.conf.d/10-pihole-listen.conf"
  fi

  printf '\n  %s[3/3] Restarting services...%s\n' "$UI_BLUE" "$UI_RESET"
  systemctl enable --now unbound 2>&1 && _ok "unbound enabled + started" \
    || _err "unbound enable failed"
  sleep 1
  systemctl restart pihole-FTL 2>&1 && _ok "pihole-FTL restarted" \
    || _err "pihole-FTL restart failed"
  sleep 2

  printf '\n  %sVerification:%s\n' "$UI_BOLD" "$UI_RESET"
  _dns_test "Unbound :5335" "127.0.0.1" "5335"
  _dns_test "Pi-hole :53  " "127.0.0.1" "53"

  _log "pi-hole->unbound standard fix applied"
  _pause
}

# --- 10. Router / Client DNS Hint --------------------------------------------
menu_router_hint() {
  _header
  printf '  %s=== ROUTER / CLIENT DNS HINT ===%s\n\n' "$UI_BOLD" "$UI_RESET"

  local pi_ip
  pi_ip=$(hostname -I 2>/dev/null | awk '{print $1}')

  printf '  %sPi-hole IP (enter this in your router):%s\n' "$UI_BOLD" "$UI_RESET"
  printf '    %s%s%s\n\n' "$UI_CYAN" "${pi_ip:-unknown}" "$UI_RESET"

  printf '  %sRouter Settings (FritzBox / OpenWRT / DD-WRT):%s\n' \
    "$UI_BOLD" "$UI_RESET"
  printf '    Primary DNS:    %s%s%s\n' "$UI_CYAN" "${pi_ip:-<pi-ip>}" "$UI_RESET"
  printf '    Secondary DNS:  %s(leave EMPTY)%s\n' "$UI_YELLOW" "$UI_RESET"
  printf '    Note: a secondary DNS allows clients to bypass Pi-hole.\n\n'

  printf '  %sFritzBox:%s\n' "$UI_BOLD" "$UI_RESET"
  printf '    Heimnetz -> Netzwerk -> DNS-Rebind-Schutz: add "pi.hole"\n\n'

  printf '  %sManual client tests:%s\n' "$UI_BOLD" "$UI_RESET"
  printf '    %sdig google.com @%s +short%s\n' \
    "$UI_CYAN" "${pi_ip:-<pi-ip>}" "$UI_RESET"
  printf '    %snslookup google.com %s%s\n\n' \
    "$UI_CYAN" "${pi_ip:-<pi-ip>}" "$UI_RESET"

  printf '  %sCurrent blocking test:%s\n' "$UI_BOLD" "$UI_RESET"
  local blocked
  blocked=$(dig +short @127.0.0.1 doubleclick.net +time=3 +tries=1 2>/dev/null | head -1)
  if [[ "$blocked" == "0.0.0.0" || -z "$blocked" ]]; then
    _ok "Blocking active -- doubleclick.net -> ${blocked:-NXDOMAIN}"
  else
    _warn "Blocking may be inactive -- doubleclick.net -> $blocked"
  fi

  _pause
}

# --- 11. Show Last Report / Log ----------------------------------------------
menu_show_report() {
  _header
  printf '  %s=== LAST REPORT / LOG ===%s\n\n' "$UI_BOLD" "$UI_RESET"

  local latest_maint
  latest_maint=$(ls -1t /var/log/pihole_maintenance_pro_*.log 2>/dev/null | head -1)
  if [[ -n "$latest_maint" ]]; then
    printf '  %sMaintenance log: %s%s\n  Last 40 lines:\n  --\n' \
      "$UI_CYAN" "$latest_maint" "$UI_RESET"
    tail -40 "$latest_maint" \
      | sed -r 's/\x1B\[[0-9;]*[mK]//g' \
      | tr -cd '[:print:]\t\n' \
      | sed 's/^/  /'
    printf '  --\n'
  else
    _info "No maintenance log at /var/log/pihole_maintenance_pro_*.log"
  fi

  printf '\n  %sRescue log (%s):%s\n' "$UI_CYAN" "$LOG_FILE" "$UI_RESET"
  if [[ -f "$LOG_FILE" ]]; then
    tail -20 "$LOG_FILE" | sed 's/^/  /'
  else
    _info "No rescue log entries yet"
  fi

  if journalctl -u pihole-FTL --no-pager -n 10 &>/dev/null; then
    printf '\n  %spihole-FTL journal (last 10):%s\n' "$UI_CYAN" "$UI_RESET"
    journalctl -u pihole-FTL --no-pager -n 10 2>/dev/null | sed 's/^/  /'
  fi

  _pause
}

# =============================================================================
# MAIN MENU LOOP
# =============================================================================
main() {
  mkdir -p "$BACKUP_DIR"
  _log "session started (UID=${EUID:-$(id -u)}, host=$(hostname))"

  while true; do
    _header
    printf '  %sWhat would you like to do?%s\n\n' "$UI_BOLD" "$UI_RESET"

    printf '  %s---- Status & Diagnostics ----%s\n' "$UI_BLUE" "$UI_RESET"
    printf '   1)  System status check\n'
    printf '   2)  DNS loop / upstream check\n'
    printf '   3)  Nightly / diagnostic test\n'

    printf '\n  %s---- Backup & Restore ----%s\n' "$UI_BLUE" "$UI_RESET"
    printf '   4)  Create backup now\n'
    printf '   5)  Restore from backup\n'
    printf '   6)  Delete old backups\n'

    printf '\n  %s---- Rescue Operations ----%s\n' "$UI_BLUE" "$UI_RESET"
    printf '   7)  Last-Known-Good restore\n'
    printf '   8)  Emergency DNS bypass  (this Pi only)\n'
    printf '   9)  Pi-hole -> Unbound standard fix\n'

    printf '\n  %s---- Info & Reports ----%s\n' "$UI_BLUE" "$UI_RESET"
    printf '  10)  Router / client DNS hint\n'
    printf '  11)  Show last report / log\n'

    printf '\n  %s 0)  Exit%s\n\n' "$UI_RED" "$UI_RESET"
    read -rp "  Choice: " choice

    case "$choice" in
      1) menu_status ;;
      2) menu_dns_loop_check ;;
      3) menu_nightly_test ;;
      4) menu_backup_create ;;
      5) menu_backup_restore ;;
      6) menu_backup_delete ;;
      7) menu_last_known_good ;;
      8) menu_emergency_bypass ;;
      9) menu_pihole_unbound_fix ;;
      10) menu_router_hint ;;
      11) menu_show_report ;;
      0 | q | Q)
        _log "session ended"
        printf '\n  %sBye.%s\n\n' "$UI_GREEN" "$UI_RESET"
        exit 0
        ;;
      *)
        _warn "Unknown option: '$choice'"
        sleep 1
        ;;
    esac
  done
}

main
