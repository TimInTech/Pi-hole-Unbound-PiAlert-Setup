#!/usr/bin/env bash
# ============================================================================
# Pi-hole v6.x – Full Maintenance PRO MAX  (NO-BACKUP EDITION)
# Version: 5.3.2 (2025-10-10)
# Authors: TimInTech
# ----------------------------------------------------------------------------
# v5.3.2
#  • FIX: Robuste Autodetektion der 'pihole' CLI + Wrapper 'ph'
#  • Doku: Cron-PATH Hinweis (README*), damit v6 auf Trixie unter cron läuft
#  • Cleanup: Doppelte BACKUP_DIR-Zuweisung entfernt
#
# v5.3.1
#  • Intelligent Summary, Performance Dashboard, JSON-Output, FTL-Analytics
# v5.3.0
#  • Neues Step-Framework, optionale Flags, Healthchecks, saubere Logs
# ============================================================================
set -euo pipefail
IFS=$'\n\t'

# Script paths + UI helpers
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="${SCRIPT_DIR}/../scripts/lib/ui.sh"
if [[ -f "$UI_LIB" ]]; then
  # shellcheck source=/dev/null
  source "$UI_LIB"
  ui_init
fi

# Voller PATH für cron/Nicht-Login-Shells (früh setzen)
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

# --------------------------- Colors & symbols -------------------------------
RED="${UI_RED:-}"
GREEN="${UI_GREEN:-}"
YELLOW="${UI_YELLOW:-}"
BLUE="${UI_BLUE:-}"
MAGENTA="${UI_MAGENTA:-}"
CYAN="${UI_CYAN:-}"
BOLD="${UI_BOLD:-}"
NC="${UI_RESET:-}"
CHECK="${GREEN}✔${NC}"
WARN="${YELLOW}⚠${NC}"
FAIL="${RED}✖${NC}"

# --------------------------- Root check ------------------------------------
# Für sicheren lokalen Selftest (RUN_SELFTEST=1) ohne Root erlauben
if [[ ${EUID} -ne 0 ]]; then
  if [[ "${RUN_SELFTEST:-0}" == "1" ]]; then
    printf '%sHinweis:%s RUN_SELFTEST=1 erkannt – Root-Check übersprungen (APT/Upgrade/Gravity sollten via --no-* Flags deaktiviert sein).\n' "$YELLOW" "$NC"
  else
    printf '%s[ERROR]%s Bitte mit sudo oder als root ausführen.\n' "$RED" "$NC" >&2
    exit 1
  fi
fi

# --------------------------- Args ------------------------------------------
DO_APT=1
DO_UPGRADE=1
DO_GRAVITY=1
# shellcheck disable=SC2034  # legacy flag (kept for help text compatibility)
DO_DNSRELOAD=1 # no-op on v6, retained for help text compatibility
JSON_OUTPUT=0
DO_BACKUP=0
RESTART_FTL=0
while (("$#")); do
  case "$1" in
    --no-apt)
      DO_APT=0
      shift
      ;;
    --no-upgrade)
      DO_UPGRADE=0
      shift
      ;;
    --no-gravity)
      DO_GRAVITY=0
      shift
      ;;
    --no-dnsreload)
      # shellcheck disable=SC2034  # legacy flag retained for help text compatibility
      DO_DNSRELOAD=0
      shift
      ;;
    --restart-ftl)
      RESTART_FTL=1
      shift
      ;;
    --backup)
      DO_BACKUP=1
      shift
      ;;
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    -h | --help)
      cat << 'EOF'
Usage: sudo ./pihole_maintenance_pro.sh [options]
  --no-apt         Skip apt update/upgrade/autoremove
  --no-upgrade     Skip "pihole -up"
  --no-gravity     Skip "pihole -g"
  --no-dnsreload   Skip "pihole reloaddns"
  --restart-ftl    Restart pihole-FTL at the end (v6: only if needed)
  --json           Output results in JSON format
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

# --------------------------- PATH + pihole wrapper --------------------------
# 'pihole' binär finden
PIHOLE_BIN="$(command -v pihole || true)"
if [[ -z "$PIHOLE_BIN" ]]; then
  for d in /usr/local/bin /usr/local/sbin /usr/bin /usr/sbin /bin /sbin; do
    if [[ -x "$d/pihole" ]]; then
      PIHOLE_BIN="$d/pihole"
      break
    fi
  done
fi
if [[ -z "$PIHOLE_BIN" ]]; then
  if [[ -n "${CI:-}" ]]; then
    echo "Warnung: pihole CLI nicht im CI vorhanden. Test wird übersprungen."
    exit 0
  else
    printf '%s[ERROR]%s '\''pihole'\'' CLI nicht gefunden. PATH=%s\n' "$RED" "$NC" "$PATH" >&2
    echo "Auf Pi-hole-Host ausführen oder CLI installieren." >&2
    exit 127
  fi
fi
# Einheitlicher Wrapper
ph() { "$PIHOLE_BIN" "$@"; }
export PIHOLE_BIN
export -f ph

# --------------------------- Paths & globals --------------------------------
TMPDIR="$(mktemp -d -t pihole_maint_XXXX)"
LOGDIR="/var/log"
if [[ -d "$LOGDIR" && -w "$LOGDIR" ]]; then
  LOGFILE="$LOGDIR/pihole_maintenance_pro_$(date +%Y-%m-%d_%H-%M-%S).log"
else
  LOGFILE="$TMPDIR/pihole_maintenance_pro_$(date +%Y-%m-%d_%H-%M-%S).log"
  printf '%sHinweis:%s /var/log nicht beschreibbar, Log nach %s.\n' "$YELLOW" "$NC" "$TMPDIR"
fi

cleanup_tmpdir() { rm -rf "$TMPDIR" 2>/dev/null || true; }
trap cleanup_tmpdir EXIT INT TERM
exec > >(tee -a "$LOGFILE") 2>&1

# shellcheck disable=SC2034
declare -A STATUS STEP_LOGFILE STEP_DATA PERFORMANCE_DATA

# --------------------------- Utils -----------------------------------------
strip_ansi() { sed -r $'s/\x1B\[[0-9;]*[a-zA-Z]//g' | tr -d '\r'; }

echo_hdr() {
  if [[ -t 1 ]]; then clear; fi
  printf '%s╔════════════════════════════════════════════════════════════════════════╗%s\n' "$MAGENTA" "$NC"
  printf '%s║%s   🛰️  %sPI-HOLE MAINTENANCE PRO MAX%s%s  -  TimInTech  (%sv5.3.2%s)  ║%s\n' \
    "$MAGENTA" "$NC" "$BOLD" "$NC" "$MAGENTA" "$CYAN" "$MAGENTA" "$NC"
  printf '%s╠════════════════════════════════════════════════════════════════════════╣%s\n' "$MAGENTA" "$NC"
  if "$PIHOLE_BIN" -v > /dev/null 2>&1; then
    PH_VER="$("$PIHOLE_BIN" -v 2> /dev/null || true)"
    printf '%s║%s Version: %s%s%s\n' "$MAGENTA" "$NC" "$CYAN" "${PH_VER:-unbekannt}" "$NC"
  else
    printf '%s║%s %sPi-hole CLI nicht gefunden%s\n' "$MAGENTA" "$NC" "$YELLOW" "$NC"
  fi
  printf '%s╚════════════════════════════════════════════════════════════════════════╝%s\n' "$MAGENTA" "$NC"
}

run_step() {
  local n="$1" icon="$2" title="$3" cmd="$4" critical="${5:-false}" display_only="${6:-false}"
  local step_log="$TMPDIR/step_${n}.log"
  # shellcheck disable=SC2034  # consumed later when printing per-step log paths
  STEP_LOGFILE["$n"]="$step_log"
  printf '\n%s╔═[Step %s]%s\n%s║ %s %s%s\n%s╚═>%s ' "$BLUE" "$n" "$NC" "$BLUE" "$icon" "$title" "$NC" "$BLUE" "$NC"

  local out="/dev/null"
  if [[ -t 1 ]]; then
    if [[ -w /dev/tty ]]; then out="/dev/tty"; else out="/dev/stdout"; fi
  fi

  if [[ "$display_only" == "true" ]]; then
    if bash -lc "$cmd" 2>&1 | tee -a "$out" | strip_ansi > "$step_log"; then
      log_ok "Step $n: $title"
      STATUS["$n"]="${GREEN}✔ OK${NC}"
      [[ -f "$step_log" ]] && extract_step_data "$n" "$(cat "$step_log")"
    else
      log_warn "Step $n: $title"
      STATUS["$n"]="${YELLOW}⚠ WARN${NC}"
      [[ -s "$step_log" ]] && tail -n 20 "$step_log"
      [[ "$critical" == "true" ]] && log_err "Kritischer Fehler in Step $n – Abbruch" && exit 1
    fi
    return 0
  fi

  bash -lc "$cmd" 2>&1 | strip_ansi > "$step_log" &
  local pid=$!
  (
    local spin=('⠋' '⠙' '⠸' '⠴' '⠦' '⠇')
    local i=0
    while kill -0 "$pid" 2> /dev/null; do
      local last=""
      [[ -f "$step_log" ]] && last="$(tail -n1 "$step_log" | cut -c1-80)"
      printf '\r%s%s%s %s[PID:%s]%s %s' "$CYAN" "$last" "$NC" "$BLUE" "$pid" "$NC" "${spin[$((i % ${#spin[@]}))]}" > "$out" 2> /dev/null || true
      i=$((i + 1))
      sleep 0.25
    done
    printf '\r' > "$out" 2> /dev/null || true
  ) &
  if wait "$pid"; then
    printf '\n'
    log_ok "Step $n: $title"
    STATUS["$n"]="${GREEN}✔ OK${NC}"
    [[ -f "$step_log" ]] && extract_step_data "$n" "$(cat "$step_log")"
  else
    local ec=$?
    printf '\n'
    log_err "Step $n: $title (Code: $ec)"
    STATUS["$n"]="${RED}✖ FAIL${NC}"
    [[ -f "$step_log" ]] && tail -n 50 "$step_log"
    [[ "$critical" == "true" ]] && log_err "Kritischer Fehler in Step $n: $title" && exit $ec
  fi
}

collect_system_info() {
  PERFORMANCE_DATA[load]=$(uptime | awk -F'load average: ' '{print $2}' | cut -d',' -f1 | xargs)
  PERFORMANCE_DATA[memory]=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}' 2> /dev/null || echo "N/A")
  PERFORMANCE_DATA[disk]=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  [[ -f /sys/class/thermal/thermal_zone0/temp ]] && PERFORMANCE_DATA[temp]=$(($(cat /sys/class/thermal/thermal_zone0/temp 2> /dev/null || echo 0) / 1000)) || PERFORMANCE_DATA[temp]="N/A"
}

extract_step_data() {
  local step_num="$1" output="$2"
  case "$step_num" in
    00) STEP_DATA[00_ip]=$(echo "$output" | grep -oE '192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+' | head -1) ;;
    03) STEP_DATA[03_version]=$(echo "$output" | grep "Core version" | awk '{print $4}') ;;
    07) STEP_DATA[07_listeners]=$(echo "$output" | wc -l) ;;
    08) STEP_DATA[08_response]=$(echo "$output" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1) ;;
    09) STEP_DATA[09_response]=$(echo "$output" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1) ;;
    10) STEP_DATA[10_github]=$(echo "$output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1) ;;
  esac
}

summary() {
  collect_system_info
  echo
  printf '%s╔═══════════════ PERFORMANCE DASHBOARD ═══════════════╗%s\n' "$CYAN" "$NC"
  printf "${CYAN}║${NC} 🚀 Load: %-8s 💾 RAM: %s%%    🌡️  Temp: %s°C    🗄️  Disk: %s%% ${CYAN}║${NC}\n" \
    "${PERFORMANCE_DATA[load]:-N/A}" "${PERFORMANCE_DATA[memory]:-N/A}" "${PERFORMANCE_DATA[temp]:-N/A}" "${PERFORMANCE_DATA[disk]:-N/A}"
  printf '%s╚═══════════════════════════════════════════════════════╝%s\n' "$CYAN" "$NC"
  echo
  printf '%s════════ INTELLIGENTE ZUSAMMENFASSUNG ════════%s\n' "$MAGENTA" "$NC"
  for k in $(printf '%s\n' "${!STATUS[@]}" | sort -n); do
    local step_info=""
    case "$k" in
      00) step_info="🌍 Network    ${STEP_DATA[00_ip]:+IP: ${STEP_DATA[00_ip]}}" ;;
      03)
        ver="${STEP_DATA[03_version]}"
        ver="${ver#v}"
        step_info="🛡️  Pi-hole    ${ver:+v$ver}"
        ;;
      07) step_info="🔍 Health     ${STEP_DATA[07_listeners]:+${STEP_DATA[07_listeners]} listeners}" ;;
      08) step_info="🌐 DNS Ext    ${STEP_DATA[08_response]:-${NC}}" ;;
      09) step_info="🏠 DNS Local  ${STEP_DATA[09_response]:-${NC}}" ;;
      10) step_info="📡 GitHub     ${STEP_DATA[10_github]:-${NC}}" ;;
      12) step_info="📊 FTL Query  $(get_query_summary)" ;;
      13) step_info="👥 FTL Client $(get_client_summary)" ;;
      *) step_info="$(get_step_description "$k")" ;;
    esac
    # %b nötig, damit ANSI-Sequenzen in STATUS farbig ausgegeben werden (nicht als \033…)
    printf '  %-4s %-50s %b\n' "#${k}" "$step_info" "${STATUS[$k]}"
    : "${STEP_LOGFILE[$k]+x}" > /dev/null
  done
  echo
  show_recommendations
  printf 'Log: %s%s%s\n' "$CYAN" "$LOGFILE" "$NC"
  printf 'Step logs: %s%s%s (werden beim Exit gelöscht)\n' "$CYAN" "$TMPDIR" "$NC"
}

get_step_description() {
  case "$1" in
    01) echo "📦 APT Updates" ;;
    04) echo "🆙 Pi-hole Update" ;;
    05) echo "📋 Gravity Update" ;;
    06) echo "🔁 DNS Reload" ;;
    *) echo "Step $1" ;;
  esac
}

get_query_summary() {
  if [[ -n "$FTL_DB" ]] && command -v sqlite3 > /dev/null 2>&1; then
    local total_queries blocked_queries blocked_percent
    total_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s','now','-24 hours');" 2> /dev/null || echo 0)
    blocked_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s','now','-24 hours') AND status IN (1,4,5,6,7,8,9,10,11);" 2> /dev/null || echo 0)
    if [[ "$total_queries" -gt 0 ]]; then
      blocked_percent=$((blocked_queries * 100 / total_queries))
      echo "24h: ${total_queries} queries, ${blocked_percent}% blocked"
    else echo "No recent data"; fi
  else
    echo "DB not available"
  fi
}

get_client_summary() {
  if [[ -n "$FTL_DB" ]] && command -v sqlite3 > /dev/null 2>&1; then
    local unique_clients
    unique_clients=$(sqlite3 "$FTL_DB" "SELECT COUNT(DISTINCT client) FROM queries WHERE timestamp > strftime('%s','now','-24 hours');" 2> /dev/null || echo 0)
    echo "${unique_clients} active clients"
  else
    echo "DB not available"
  fi
}

show_recommendations() {
  local warnings=() recommendations=()
  [[ "${PERFORMANCE_DATA[memory]}" =~ ^[0-9]+$ ]] && ((PERFORMANCE_DATA[memory] > 85)) && {
    warnings+=("⚠️  High memory usage: ${PERFORMANCE_DATA[memory]}%")
    recommendations+=("💡 Consider restarting FTL or increasing RAM")
  }
  [[ "${PERFORMANCE_DATA[disk]}" =~ ^[0-9]+$ ]] && ((PERFORMANCE_DATA[disk] > 85)) && {
    warnings+=("⚠️  Low disk space: ${PERFORMANCE_DATA[disk]}% used")
    recommendations+=("💡 Consider log rotation or cleanup: pihole -f")
  }
  [[ "${PERFORMANCE_DATA[temp]}" =~ ^[0-9]+$ ]] && ((PERFORMANCE_DATA[temp] > 70)) && {
    warnings+=("🌡️  High temperature: ${PERFORMANCE_DATA[temp]}°C")
    recommendations+=("💡 Check cooling/ventilation")
  }
  [[ "${STEP_DATA[07_listeners]}" =~ ^[0-9]+$ ]] && ((STEP_DATA[07_listeners] < 1)) && {
    warnings+=("🔥 CRITICAL: No DNS listeners on port 53")
    recommendations+=("🚨 Restart Pi-hole FTL: sudo systemctl restart pihole-FTL")
  }
  ((${#warnings[@]})) && {
    printf '\n%s════════ WARNINGS ════════%s\n' "$YELLOW" "$NC"
    printf '%s\n' "${warnings[@]}"
  }
  ((${#recommendations[@]})) && {
    printf '\n%s════════ RECOMMENDATIONS ════════%s\n' "$BLUE" "$NC"
    printf '%s\n' "${recommendations[@]}"
  }
}

output_json() {
  collect_system_info
  local timestamp total_steps successful_steps failed_steps warned_steps overall_status total_queries blocked_queries blocked_percentage
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  total_steps=${#STATUS[@]}
  successful_steps=0
  failed_steps=0
  warned_steps=0
  for s in "${STATUS[@]}"; do
    if [[ "$s" == *OK* ]]; then ((successful_steps++)); fi
    if [[ "$s" == *FAIL* ]]; then ((failed_steps++)); fi
    if [[ "$s" == *WARN* ]]; then ((warned_steps++)); fi
  done
  overall_status="healthy"
  ((failed_steps > 0)) && overall_status="critical"
  ((warned_steps > 0 && failed_steps == 0)) && overall_status="warning"

  total_queries=0
  blocked_queries=0
  blocked_percentage=0
  if [[ -n "$FTL_DB" ]] && command -v sqlite3 > /dev/null 2>&1; then
    total_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s','now','-24 hours');" 2> /dev/null || echo 0)
    blocked_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s','now','-24 hours') AND status IN (1,4,5,6,7,8,9,10,11);" 2> /dev/null || echo 0)
    if [[ "$total_queries" -gt 0 ]]; then blocked_percentage=$(awk "BEGIN {printf \"%.1f\", $blocked_queries/$total_queries*100}"); fi
  fi

  local issues=() recommendations=()
  [[ "${PERFORMANCE_DATA[memory]}" =~ ^[0-9]+$ ]] && ((PERFORMANCE_DATA[memory] > 85)) && {
    issues+=("high_memory")
    recommendations+=("restart_ftl")
  }
  [[ "${PERFORMANCE_DATA[disk]}" =~ ^[0-9]+$ ]] && ((PERFORMANCE_DATA[disk] > 85)) && {
    issues+=("low_disk_space")
    recommendations+=("log_rotation")
  }
  [[ "${STEP_DATA[07_listeners]}" =~ ^[0-9]+$ ]] && ((STEP_DATA[07_listeners] < 1)) && {
    issues+=("no_dns_listeners")
    recommendations+=("restart_pihole_ftl")
  }

  cat << EOF
{
  "timestamp": "$timestamp",
  "status": "$overall_status",
  "version": "5.3.2",
  "summary": {
    "total_steps": $total_steps,
    "successful_steps": $successful_steps,
    "failed_steps": $failed_steps,
    "warned_steps": $warned_steps,
    "total_queries_24h": $total_queries,
    "blocked_queries_24h": $blocked_queries,
    "blocked_percentage": $blocked_percentage,
    "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')],
    "recommendations": [$(printf '"%s",' "${recommendations[@]}" | sed 's/,$//')]
  },
  "performance": {
    "load_average": "${PERFORMANCE_DATA[load]:-N/A}",
    "memory_usage_percent": ${PERFORMANCE_DATA[memory]:-0},
    "disk_usage_percent": ${PERFORMANCE_DATA[disk]:-0},
    "temperature_celsius": "${PERFORMANCE_DATA[temp]:-N/A}"
  },
  "network": {
    "local_ip": "${STEP_DATA[00_ip]:-N/A}",
    "dns_listeners": ${STEP_DATA[07_listeners]:-0},
    "external_dns_response": "${STEP_DATA[08_response]:-N/A}",
    "local_dns_response": "${STEP_DATA[09_response]:-N/A}",
    "github_connectivity": "${STEP_DATA[10_github]:-N/A}"
  },
  "pihole": {
    "version": "${STEP_DATA[03_version]:-N/A}",
    "gravity_last_update": "$(stat -c %Y /etc/pihole/gravity.db 2> /dev/null || echo 0)"
  },
  "logs": { "main_log": "$LOGFILE", "step_logs": "$TMPDIR" }
}
EOF
}

# Detect databases (best-effort)
FTL_DB=""
for c in /etc/pihole/pihole-FTL.db /run/pihole-FTL.db /var/lib/pihole/pihole-FTL.db; do
  [[ -f "$c" ]] && FTL_DB="$c" && break
done
# (gravity DB path is queried lazily when needed)

# shellcheck disable=SC2317  # trap callback is invoked by bash
on_exit() {
  local rc="$1"
  echo ""
  if [[ "$JSON_OUTPUT" == "1" ]]; then
    output_json 2> /dev/null || true
  else
    summary 2> /dev/null || true
  fi
  cleanup_tmpdir
  [[ $rc -ne 0 ]] && printf '%sScript ended with exit code %s%s\n' "$RED" "$rc" "$NC"
  exit "$rc"
}
trap 'on_exit $?' EXIT INT TERM

# --------------------------- Run -------------------------------------------
echo_hdr

# 00 – Quick context (robuste Quoting, kein $2/$NF in Bash expandieren)
run_step 00 "🧭" "Kontext: Host & Netz" "\
  echo \"Host: $(hostname)\"; \
  echo \"Kernel: $(uname -r)\"; \
  echo \"Arch: $(dpkg --print-architecture)\"; \
  ip -4 addr show scope global | awk '/inet /{print \$2, \"on\", \$NF}'; \
  echo \"Default route:\"; ip route show default || true; \
  echo \"DNS servers (/etc/resolv.conf):\"; grep -E '^nameserver' /etc/resolv.conf || true" false true

# 01 – APT
if ((DO_APT == 1)); then
  export DEBIAN_FRONTEND=noninteractive
  run_step 01 "🔄" "APT: update & upgrade" "apt update && apt -y upgrade" true
  run_step 02 "🧹" "APT: autoremove & autoclean" "apt -y autoremove && apt -y autoclean"
      if dpkg --print-architecture | grep -q '^armhf$'; then
    if apt list --upgradable 2> /dev/null | grep -q '^linux-image-rpi-v8'; then
      printf '%sHinweis:%s '\''linux-image-rpi-v8'\'' ist 64-bit (ARMv8). Auf Pi 3B (ARMv7) ignorierbar.\n' "$YELLOW" "$NC"
    fi
  fi
else
  printf '%sAPT-Schritte übersprungen (--no-apt).%s\n' "$YELLOW" "$NC"
fi

# 02 – Security Checks (optional display)
run_step 20 "🔒" "Security: Offene Ports" "ss -tuln | grep -E '(:22|:80|:443|:53|:8080|:8888)' || true" false true
run_step 21 "🛡️" "Security: SSH Login Attempts" "lastb -i | head -n 10 || true" false true
# 22 – awk-Programm strikt in Single-Quotes, damit $2 nicht von Bash expandiert
run_step 22 "🔑" "Security: Schwache Passwörter (shadow)" "awk -F: '(\$2==\"\"||\$2==\"*\"||\$2==\"!\") {print \$1}' /etc/shadow || true" false true
run_step 23 "🕸️" "Security: Pi-hole Admin Interface" "ss -tuln | grep ':80' | grep 'LISTEN' && grep -q 'webserver' /etc/pihole/pihole.toml && echo 'Admin interface active (detected via pihole.toml)' || echo 'Admin interface not detected'" false true
run_step 24 "🧑‍💻" "Security: Sudo-Konfiguration" "grep -E 'NOPASSWD|ALL' /etc/sudoers /etc/sudoers.d/* 2>/dev/null || echo 'Sudo-Konfiguration OK'" false true
run_step 25 "🔐" "Security: SSH-Konfiguration" "grep -E 'PermitRootLogin|PasswordAuthentication' /etc/ssh/sshd_config || true" false true
run_step 26 "📦" "Security: Ausstehende Updates" "apt list --upgradable 2>/dev/null | grep -v 'Listing' || echo 'Keine Updates verfügbar'" false true
command -v chkrootkit > /dev/null 2>&1 && run_step 27 "🦠" "Security: chkrootkit" "chkrootkit || true" false true
command -v rkhunter > /dev/null 2>&1 && run_step 28 "🦠" "Security: rkhunter" "rkhunter --check --sk --nocolors || true" false true
command -v clamscan > /dev/null 2>&1 && run_step 29 "🦠" "Security: clamav" "clamscan -r /etc/pihole || true" false true

# Logfile-Monitoring
PIHOLE_LOG="/var/log/pihole.log"
if [[ -f "$PIHOLE_LOG" ]]; then
  LOGSIZE=$(stat -c %s "$PIHOLE_LOG" 2> /dev/null || echo 0)
  ((LOGSIZE > 1073741824)) && printf '%sWARNUNG: pihole.log > 1GB! Empfehlung: logrotate aktivieren.%s\n' "$YELLOW" "$NC"
fi

# Backup-Integration (optional)
if ((DO_BACKUP == 1)); then
  BACKUP_DIR="/var/backups/pihole/$(date +%Y%m%d_%H%M%S)"
  MAX_BACKUPS=5
  mkdir -p "$BACKUP_DIR"
  cp -a /etc/pihole/gravity.db "$BACKUP_DIR" 2> /dev/null || true
  cp -a /etc/pihole/pihole-FTL.db "$BACKUP_DIR" 2> /dev/null || true
  cp -a /etc/pihole/pihole.toml "$BACKUP_DIR" 2> /dev/null || true
  cp -a /etc/pihole/hosts/*.list "$BACKUP_DIR" 2> /dev/null || true
  echo "Backup gespeichert: $BACKUP_DIR"
  find /var/backups/pihole/ -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | awk '{print $2}' | head -n -$MAX_BACKUPS | xargs -r rm -rf
fi
backup_pihole() {
  local backup_dir
  backup_dir="/etc/pihole/backup_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$backup_dir"
  cp -a /etc/pihole/*.db "$backup_dir" 2> /dev/null || true
  cp -a /etc/pihole/pihole.toml "$backup_dir" 2> /dev/null || true
  cp -a /etc/pihole/hosts/*.list "$backup_dir" 2> /dev/null || true
  echo "Backup erstellt: $backup_dir"
}

# 03 – Pi-hole Version & Updates
run_step 03 "🔎" "Pi-hole Version" "\"$PIHOLE_BIN\" -v" false true
if ((DO_UPGRADE == 1)); then
  backup_pihole
  run_step 04 "🆙" "Pi-hole self-update" "\"$PIHOLE_BIN\" -up"
else
  printf '%sPi-hole Upgrade übersprungen (--no-upgrade).%s\n' "$YELLOW" "$NC"
fi

# 05 – Gravity
if ((DO_GRAVITY == 1)); then
  backup_pihole
  run_step 05 "📋" "Update Gravity / Blocklists" "\"$PIHOLE_BIN\" -g"
else
  printf '%sGravity-Update übersprungen (--no-gravity).%s\n' "$YELLOW" "$NC"
fi

# 06 – optionaler FTL-Restart (v6: nur bei Bedarf)
if ((RESTART_FTL == 1)); then
  run_step 06 "🔁" "Restart FTL (v6: nur bei Bedarf)" "systemctl restart pihole-FTL"
fi

# 07 – Health
run_step 07 "🧪" "Health: Port 53 listeners" "ss -lntup | awk '/:53[[:space:]]/ {print}' || true" false true
run_step 08 "🌐" "DNS Test: google.com @127.0.0.1" $'dig +time=2 +tries=1 +short google.com @127.0.0.1 || true' false true
run_step 09 "🏠" "DNS Test: pi.hole @127.0.0.1" $'dig +time=2 +tries=1 +short pi.hole @127.0.0.1 || true' false true

# 10 – GitHub Reachability
run_step 10 "🐙" "GitHub Reachability" $'\
  dig +time=2 +tries=1 +short raw.githubusercontent.com @127.0.0.1 || true; \
  echo "curl -I https://raw.githubusercontent.com (IPv4)"; \
  curl -4 -sI https://raw.githubusercontent.com | head -n 1 || true' false true

# 11 – Tailscale (optional)
if command -v tailscale > /dev/null 2>&1; then
  run_step 11 "🧩" "Tailscale Status (Kurz)" $'\
    echo -n "TS IPv4: "; tailscale ip -4 2>/dev/null || true; \
    echo -n "TS IPv6: "; tailscale ip -6 2>/dev/null || true; \
    tailscale status --peers=false 2>/dev/null || tailscale status 2>/dev/null || true' false true
fi

# 12 – FTL Toplists
if command -v sqlite3 > /dev/null 2>&1 && [[ -f "$FTL_DB" ]]; then
  run_step 12 "📈" "Top 5 Domains (FTL)" $'sqlite3 -readonly "$FTL_DB" "SELECT domain, COUNT(1) c FROM queries GROUP BY domain ORDER BY c DESC LIMIT 5;" || true' false true
  run_step 13 "👥" "Top 5 Clients (FTL)" $'sqlite3 -readonly "$FTL_DB" "SELECT client, COUNT(1) c FROM queries GROUP BY client ORDER BY c DESC LIMIT 5;" || true' false true
else
  printf '%ssqlite3 oder FTL DB nicht gefunden – Überspringe Top-Listen.%s\n' "$YELLOW" "$NC"
fi

# 14 – Abschluss (Summary/JSON kommt aus EXIT-Trap)

# 🧪 Repo-Selftest
if [[ "${RUN_SELFTEST:-0}" == "1" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TEST_SCRIPT="${SCRIPT_DIR}/scripts/test-repo.sh"
  if [[ -f "$TEST_SCRIPT" ]]; then
    echo "Führe Repository-Selftest aus..."
    bash "$TEST_SCRIPT" || echo "Selftest fehlgeschlagen"
  else
    echo "Selftest übersprungen (scripts/test-repo.sh nicht gefunden)"
  fi
fi
