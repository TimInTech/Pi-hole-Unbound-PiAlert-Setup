#!/usr/bin/env bash
set -euo pipefail

# Ensure this script never blocks on sudo password prompts.
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  sudo() { "$@"; }
elif command -v sudo &>/dev/null; then
  sudo() { command sudo -n "$@"; }
fi

# =============================================
# POST-INSTALL CHECK SCRIPT
# Read-only verification for Pi-hole + Unbound + Pi.Alert setup
# =============================================

VERSION="1.0.1"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="${SCRIPT_DIR}/lib/ui.sh"
if [[ -f "$UI_LIB" ]]; then
  # shellcheck source=/dev/null
  source "$UI_LIB"
  ui_init
else
  # Minimal fallbacks when ui.sh is unavailable
  UI_RED='' UI_GREEN='' UI_YELLOW='' UI_BLUE='' UI_BOLD='' UI_RESET=''
  ui_pass()    { printf '[PASS] %s\n' "$*"; }
  ui_warn()    { printf '[WARN] %s\n' "$*"; }
  ui_fail()    { printf '[FAIL] %s\n' "$*"; }
  ui_info()    { printf '[INFO] %s\n' "$*"; }
  ui_section() { printf '\n=== %s ===\n' "$*"; }
  ui_dir_not_empty() { [[ -d "$1" ]] && find "$1" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; }
fi

# Status counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Detected Unbound port (derived from config or probing)
UNBOUND_PORT=""

# =============================================
# CONFIG DETECTION FUNCTIONS
# =============================================
detect_unbound_port() {
  local toml_file="/etc/pihole/pihole.toml"
  local detected_port=""

  if [[ -r "$toml_file" ]]; then
    detected_port=$(sed -n '/^\[dns\]/,/^\[/p' "$toml_file" 2>/dev/null | \
      grep 'upstreams' | \
      grep -o '127\.0\.0\.1#[0-9]*' | \
      sed 's/127\.0\.0\.1#//' | \
      head -n1 || true)
  fi

  if [[ -z "$detected_port" ]] && command -v ss &>/dev/null; then
    detected_port=$(ss -tuln 2>/dev/null | \
      grep '127.0.0.1:53' | \
      grep -v ':53[[:space:]]' | \
      sed 's/.*:53\([0-9][0-9]\).*/53\1/' | \
      head -n1 || true)
  fi

  if [[ -z "$detected_port" ]]; then
    detected_port="5335"
  fi

  UNBOUND_PORT="$detected_port"
}

# =============================================
# HELPER FUNCTIONS
# =============================================
pass() {
  ui_pass "$*"
  ((PASS_COUNT+=1))
}

warn() {
  ui_warn "$*"
  ((WARN_COUNT+=1))
}

fail() {
  ui_fail "$*"
  ((FAIL_COUNT+=1))
}

info() {
  ui_info "$*"
}

section() {
  ui_section "$*"
}

# =============================================
# MANUAL STEPS DOCUMENTATION
# =============================================
show_manual_steps() {
  # Ensure port is detected for --steps mode too
  detect_unbound_port

  cat <<EOF
┌─────────────────────────────────────────────────────────────────┐
│        POST-INSTALLATION VERIFICATION - MANUAL STEPS            │
│                     (Step-by-Step Guide)                        │
└─────────────────────────────────────────────────────────────────┘

STEP 1: Verify Unbound DNS Service
───────────────────────────────────────────────────────────────────
Command:
  sudo systemctl status unbound

Expected Output:
  ● unbound.service - Unbound DNS server
     Loaded: loaded (/lib/systemd/system/unbound.service; enabled)
     Active: active (running) since ...

───────────────────────────────────────────────────────────────────
Command:
  sudo ss -tulpen | grep ${UNBOUND_PORT}

Expected Output:
  udp   UNCONN 0   0   127.0.0.1:${UNBOUND_PORT}   0.0.0.0:*   users:(("unbound",pid=...))
  tcp   LISTEN 0   256 127.0.0.1:${UNBOUND_PORT}   0.0.0.0:*   users:(("unbound",pid=...))

───────────────────────────────────────────────────────────────────
Command:
  dig cloudflare.com @127.0.0.1 -p ${UNBOUND_PORT} +short

Expected Output:
  104.16.132.229
  104.16.133.229

STEP 2: Verify Pi-hole Service
───────────────────────────────────────────────────────────────────
Command:
  pihole -v

Expected Output:
  Pi-hole version is v6.x.x

───────────────────────────────────────────────────────────────────
Command:
  sudo systemctl status pihole-FTL

Expected Output:
  ● pihole-FTL.service - Pi-hole FTL
     Active: active (running) since ...

───────────────────────────────────────────────────────────────────
Command:
  sudo ss -tulpen | grep ':53'

Expected Output:
  udp   UNCONN 0   0   0.0.0.0:53   0.0.0.0:*   users:(("pihole-FTL",pid=...))
  tcp   LISTEN 0   32  0.0.0.0:53   0.0.0.0:*   users:(("pihole-FTL",pid=...))

STEP 3: Verify Pi-hole v6 Configuration (CRITICAL)
───────────────────────────────────────────────────────────────────
Command:
  sudo grep -A5 '^\[dns\]' /etc/pihole/pihole.toml

Expected Output:
  [dns]
  upstreams = ["127.0.0.1#${UNBOUND_PORT}"]

IMPORTANT:
  In Pi-hole v6, /etc/pihole/pihole.toml is AUTHORITATIVE.
  If upstreams is missing or points elsewhere, Pi-hole will use
  public DNS resolvers instead of Unbound.

───────────────────────────────────────────────────────────────────
Command:
  dig example.org @127.0.0.1 +short

Expected Output:
  93.184.215.14

STEP 4: Advanced Verification (Optional)
───────────────────────────────────────────────────────────────────
Command (terminal 1):
  sudo tcpdump -i lo port ${UNBOUND_PORT} -c 10

Command (terminal 2):
  dig test.com @127.0.0.1

Note: Requires tcpdump: sudo apt-get install tcpdump

STEP 5: Verify Optional Services
───────────────────────────────────────────────────────────────────
If Docker is installed:
  docker ps

If NetAlertX/Pi.Alert is running:
  Visit: http://[your-ip]:20211

INTERPRETATION OF RESULTS:
───────────────────────────────────────────────────────────────────
✓ PASS: Everything working as expected
⚠ WARN: Non-critical issue, system functional but attention needed
✗ FAIL: Critical problem, immediate action required

Common Issues:
  - Port 53 in use: sudo systemctl disable --now systemd-resolved
  - Unbound not resolving: Check /var/log/unbound/unbound.log
  - Pi-hole v6 wrong upstream: sudo ./install.sh --force

EOF
}

print_header() {
  printf '%.0s─' {1..64}; printf '\n'
  printf 'POST-INSTALL CHECK — Pi-hole v6 / Unbound / Docker / Pi.Alert\n'
  printf 'Script: %s v%s (output language: English)\n' "$SCRIPT_NAME" "$VERSION"
  printf '%.0s─' {1..64}; printf '\n'
}

show_version() {
  printf '%s v%s\n' "$SCRIPT_NAME" "$VERSION"
  printf 'Output language: English\n'
}

# =============================================
# CHECK FUNCTIONS
# =============================================
check_system_info() {
  section "System Information"

  if command -v lsb_release &>/dev/null; then
    info "OS: $(lsb_release -ds 2>/dev/null || printf 'Unknown')"
  elif [[ -f /etc/os-release ]]; then
    info "OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
  fi

  info "Hostname: $(hostname)"
  info "Kernel: $(uname -r)"

  local ipv4
  ipv4=$(hostname -I 2>/dev/null | awk '{print $1}' || printf "N/A")
  info "IPv4: $ipv4"

  if command -v ip &>/dev/null; then
    local default_route
    default_route=$(ip route | grep default | awk '{print $3}' | head -n1 || printf "N/A")
    info "Default Gateway: $default_route"
  fi
}

check_unbound() {
  section "Unbound DNS Service"

  if systemctl is-active --quiet unbound 2>/dev/null; then
    pass "Unbound service is running"
  else
    fail "Unbound service is NOT running"
    return
  fi

  local unbound_port="${UNBOUND_PORT:-5335}"
  info "Using Unbound port: $unbound_port"

  if command -v ss &>/dev/null; then
    if ss -tuln | grep -q "127.0.0.1:${unbound_port}"; then
      pass "Unbound listening on 127.0.0.1:${unbound_port}"
    else
      fail "Unbound NOT listening on 127.0.0.1:${unbound_port}"
    fi
  elif command -v netstat &>/dev/null; then
    if netstat -tuln | grep -q "127.0.0.1:${unbound_port}"; then
      pass "Unbound listening on 127.0.0.1:${unbound_port}"
    else
      fail "Unbound NOT listening on 127.0.0.1:${unbound_port}"
    fi
  else
    warn "Cannot verify port (ss/netstat not available)"
  fi

  if command -v dig &>/dev/null; then
    if dig +short @127.0.0.1 -p "${unbound_port}" cloudflare.com +time=1 +tries=1 2>/dev/null | grep -qE '^[0-9.]+$'; then
      pass "Unbound resolves cloudflare.com"
    else
      fail "Unbound cannot resolve cloudflare.com"
    fi
  else
    warn "dig not available, skipping resolution test"
  fi
}

check_pihole() {
  section "Pi-hole DNS Service"

  if command -v pihole &>/dev/null; then
    local version
    version=$(pihole -v 2>/dev/null | grep -E "^(Pi-hole|Core) version is" | head -n1 | awk '{print $NF}' || printf "unknown")
    info "Pi-hole version: $version"
    if [[ "$version" =~ v([0-9]+)\. ]]; then
      local major="${BASH_REMATCH[1]}"
      if (( major < 6 )); then
        fail "Pi-hole v6 required (detected $version)"
      else
        pass "Pi-hole major version OK (v${major})"
      fi
    else
      warn "Could not parse Pi-hole version (expected v6.x.y): $version"
    fi
  fi

  if systemctl is-active --quiet pihole-FTL 2>/dev/null; then
    pass "Pi-hole FTL service is running"
  else
    fail "Pi-hole FTL service is NOT running"
    return
  fi

  if command -v ss &>/dev/null; then
    if ss -tuln | grep -qE ':53[[:space:]]'; then
      pass "Pi-hole listening on port 53"
    else
      fail "Pi-hole NOT listening on port 53"
    fi
  elif command -v netstat &>/dev/null; then
    if netstat -tuln | grep -qE ':53[[:space:]]'; then
      pass "Pi-hole listening on port 53"
    else
      fail "Pi-hole NOT listening on port 53"
    fi
  else
    warn "Cannot verify port (ss/netstat not available)"
  fi

  if command -v dig &>/dev/null; then
    if dig +short @127.0.0.1 example.org +time=1 +tries=1 2>/dev/null | grep -qE '^[0-9.]+$'; then
      pass "Pi-hole resolves example.org"
    else
      fail "Pi-hole cannot resolve example.org"
    fi
  else
    warn "dig not available, skipping resolution test"
  fi
}

check_pihole_v6_config() {
  section "Pi-hole v6 Configuration (CRITICAL)"

  local toml_file="/etc/pihole/pihole.toml"

  if [[ ! -f "$toml_file" ]]; then
    fail "Pi-hole v6 config file NOT found: $toml_file"
    return
  fi

  pass "Pi-hole v6 config file exists: $toml_file"

  local upstreams
  if sudo test -r "$toml_file" 2>/dev/null; then
    upstreams=$(sudo awk '
      /^\[dns\]/ { in_dns=1; next }
      /^\[/ && !/^\[dns\]/ { in_dns=0 }
      in_dns && /^[[:space:]]*upstreams[[:space:]]*=/ {
        print
        found=1
      }
      END { if (!found) print "NOT_FOUND" }
    ' "$toml_file")
  else
    upstreams=$(awk '
      /^\[dns\]/ { in_dns=1; next }
      /^\[/ && !/^\[dns\]/ { in_dns=0 }
      in_dns && /^[[:space:]]*upstreams[[:space:]]*=/ {
        print
        found=1
      }
      END { if (!found) print "NOT_FOUND" }
    ' "$toml_file" 2>/dev/null || printf "NOT_FOUND")
  fi

  if [[ "$upstreams" == "NOT_FOUND" || -z "$upstreams" ]]; then
    fail "Pi-hole v6 upstreams NOT configured in [dns] section"
    warn "Pi-hole will use public DNS resolvers instead of Unbound!"
  else
    local expected_port="${UNBOUND_PORT:-5335}"
    if grep -q "127.0.0.1#${expected_port}" "$toml_file"; then
      pass "Pi-hole v6 upstreams configured correctly: $upstreams"
    else
      warn "Pi-hole v6 upstreams found but NOT pointing to Unbound port ${expected_port}: $upstreams"
    fi
  fi
}

check_docker() {
  section "Docker Service"

  if ! command -v docker &>/dev/null; then
    info "Docker not installed (optional component)"
    return
  fi

  if systemctl is-active --quiet docker 2>/dev/null; then
    pass "Docker service is running"
  else
    warn "Docker service is NOT running"
    return
  fi

  if sudo docker info &>/dev/null 2>&1 || docker info &>/dev/null 2>&1; then
    pass "Docker daemon is accessible"
  else
    warn "Docker daemon is not accessible (may need sudo)"
  fi

  local containers
  if sudo test -x /usr/bin/docker 2>/dev/null; then
    containers=$(sudo docker ps --format "{{.Names}}" 2>/dev/null || printf "")
  else
    containers=$(docker ps --format "{{.Names}}" 2>/dev/null || printf "")
  fi

  if [[ -n "$containers" ]]; then
    info "Running containers: $containers"
  else
    info "No running containers detected"
  fi
}

check_netalertx() {
  section "NetAlertX / Pi.Alert"

  local found=false
  local port=""

  if [[ -d /opt/netalertx/data ]]; then
    pass "NetAlertX data dir present: /opt/netalertx/data"
  fi
  if [[ -d /opt/netalertx/config || -d /opt/netalertx/db ]]; then
    if ui_dir_not_empty "/opt/netalertx/config" || ui_dir_not_empty "/opt/netalertx/db"; then
      warn "Legacy NetAlertX dirs detected. New mount uses /opt/netalertx/data -> /data; migrate if needed."
    fi
  fi

  if command -v docker &>/dev/null; then
    if sudo docker ps 2>/dev/null | grep -q netalertx || docker ps 2>/dev/null | grep -q netalertx; then
      pass "NetAlertX container is running"
      found=true

      local network_mode=""
      network_mode=$(sudo docker inspect -f '{{.HostConfig.NetworkMode}}' netalertx 2>/dev/null || \
        docker inspect -f '{{.HostConfig.NetworkMode}}' netalertx 2>/dev/null || printf "")

      if [[ "$network_mode" == "host" ]]; then
        pass "NetAlertX container network mode: host"
        port="20211"
      else
        if [[ -n "$network_mode" ]]; then
          warn "NetAlertX container not in host mode (NetworkMode: $network_mode). Device discovery may be limited."
        else
          warn "Could not determine NetAlertX container network mode"
        fi
        port=$(sudo docker ps --filter name=netalertx --format "{{.Ports}}" 2>/dev/null | \
          grep -oP '\d+(?=->20211)' | head -n1 || printf "")
        if [[ -z "$port" ]]; then
          port=$(docker ps --filter name=netalertx --format "{{.Ports}}" 2>/dev/null | \
            grep -oP '\d+(?=->20211)' | head -n1 || printf "")
        fi
      fi
    fi
  fi

  if systemctl list-units --type=service --all 2>/dev/null | grep -qiE 'pi.?alert'; then
    if systemctl is-active --quiet pialert 2>/dev/null || systemctl is-active --quiet pi-alert 2>/dev/null; then
      pass "Pi.Alert service is running"
      found=true
    fi
  fi

  if $found && [[ -n "$port" ]]; then
    info "NetAlertX likely at: http://$(hostname -I | awk '{print $1}'):${port}"
  elif ! $found; then
    info "NetAlertX/Pi.Alert not detected (optional component)"
  fi
}

check_network_info() {
  section "Network Configuration"

  if [[ -f /etc/resolv.conf ]]; then
    local nameservers
    nameservers=$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
    info "System nameservers: $nameservers"

    if printf '%s' "$nameservers" | grep -q "127.0.0.1"; then
      pass "System using local DNS (127.0.0.1)"
    else
      warn "System NOT using local DNS"
    fi
  fi

  if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    warn "systemd-resolved is running (may conflict with Pi-hole on port 53)"
  fi
}

get_service_urls() {
  section "Service URLs"

  local ipv4
  ipv4=$(hostname -I 2>/dev/null | awk '{print $1}' || printf "127.0.0.1")

  printf '\n'
  printf '┌─────────────────────────────────────────────────────────────────┐\n'
  printf '│                         Service URLs                            │\n'
  printf '├─────────────────────────────────────────────────────────────────┤\n'

  if systemctl is-active --quiet pihole-FTL 2>/dev/null; then
    printf "│ %-63s │\n" "Pi-hole Admin:   http://${ipv4}/admin"
  fi

  if command -v docker &>/dev/null; then
    local netalertx_port=""
    local network_mode=""

    if sudo docker ps --filter name=netalertx --format "{{.Names}}" 2>/dev/null | grep -q '^netalertx$' || \
       docker ps --filter name=netalertx --format "{{.Names}}" 2>/dev/null | grep -q '^netalertx$'; then

      network_mode=$(sudo docker inspect -f '{{.HostConfig.NetworkMode}}' netalertx 2>/dev/null || \
        docker inspect -f '{{.HostConfig.NetworkMode}}' netalertx 2>/dev/null || printf "")

      if [[ "$network_mode" == "host" ]]; then
        netalertx_port="20211"
      else
        netalertx_port=$(sudo docker ps --filter name=netalertx --format "{{.Ports}}" 2>/dev/null | \
          grep -oP '\d+(?=->20211)' | head -n1 || \
          docker ps --filter name=netalertx --format "{{.Ports}}" 2>/dev/null | \
          grep -oP '\d+(?=->20211)' | head -n1 || printf "")
      fi

      if [[ -n "$netalertx_port" ]]; then
        printf "│ %-63s │\n" "NetAlertX:       http://${ipv4}:${netalertx_port}"
      fi
    fi
  fi

  if systemctl is-active --quiet pihole-suite 2>/dev/null; then
    printf "│ %-63s │\n" "Python Suite API: http://127.0.0.1:8090"
  fi

  printf '└─────────────────────────────────────────────────────────────────┘\n'
  printf '\n'
}

show_service_status() {
  section "Service Status Summary"

  printf '\n'
  printf "%-20s %s\n" "Service" "Status"
  printf "%-20s %s\n" "-------" "------"

  local active_label="${UI_GREEN}ACTIVE${UI_RESET}"
  local inactive_label="${UI_RED}INACTIVE${UI_RESET}"
  local optional_label="${UI_YELLOW}INACTIVE/NOT INSTALLED${UI_RESET}"
  local running_label="${UI_GREEN}RUNNING${UI_RESET}"
  local skipped_label="${UI_YELLOW}NOT RUNNING/SKIPPED${UI_RESET}"

  if systemctl is-active --quiet unbound 2>/dev/null; then
    printf "%-20s %b\n" "Unbound" "$active_label"
  else
    printf "%-20s %b\n" "Unbound" "$inactive_label"
  fi

  if systemctl is-active --quiet pihole-FTL 2>/dev/null; then
    printf "%-20s %b\n" "Pi-hole FTL" "$active_label"
  else
    printf "%-20s %b\n" "Pi-hole FTL" "$inactive_label"
  fi

  if systemctl is-active --quiet docker 2>/dev/null; then
    printf "%-20s %b\n" "Docker" "$active_label"
  else
    printf "%-20s %b\n" "Docker" "$optional_label"
  fi

  if command -v docker &>/dev/null && \
     (sudo docker ps 2>/dev/null | grep -q netalertx || docker ps 2>/dev/null | grep -q netalertx); then
    printf "%-20s %b\n" "NetAlertX" "$running_label"
  else
    printf "%-20s %b\n" "NetAlertX" "$skipped_label"
  fi

  printf '\n'
}

print_summary() {
  printf '\n'
  printf '┌─────────────────────────────────────────────────────────────────┐\n'
  printf '│                         Check Summary                           │\n'
  printf '├─────────────────────────────────────────────────────────────────┤\n'
  printf "│ %bPASS:%b %-57s│\n" "$UI_GREEN" "$UI_RESET" "$PASS_COUNT"
  printf "│ %bWARN:%b %-57s│\n" "$UI_YELLOW" "$UI_RESET" "$WARN_COUNT"
  printf "│ %bFAIL:%b %-57s│\n" "$UI_RED" "$UI_RESET" "$FAIL_COUNT"
  printf '└─────────────────────────────────────────────────────────────────┘\n'
  printf '\n'

  if [[ $FAIL_COUNT -gt 0 ]]; then
    printf '%sSome checks failed. Please review the output above.%s\n' "$UI_RED" "$UI_RESET"
    return 1
  elif [[ $WARN_COUNT -gt 0 ]]; then
    printf '%sSome checks produced warnings. Review recommended.%s\n' "$UI_YELLOW" "$UI_RESET"
    return 0
  else
    printf '%sAll checks passed successfully!%s\n' "$UI_GREEN" "$UI_RESET"
    return 0
  fi
}

quick_check() {
  print_header
  info "Running Quick Check..."
  printf '\n'

  PASS_COUNT=0 WARN_COUNT=0 FAIL_COUNT=0

  if systemctl is-active --quiet unbound 2>/dev/null; then
    pass "Unbound is running"
  else
    fail "Unbound is NOT running"
  fi

  if systemctl is-active --quiet pihole-FTL 2>/dev/null; then
    pass "Pi-hole FTL is running"
  else
    fail "Pi-hole FTL is NOT running"
  fi

  local expected_port="${UNBOUND_PORT:-5335}"
  if [[ -f /etc/pihole/pihole.toml ]]; then
    if sudo grep -q "127.0.0.1#${expected_port}" /etc/pihole/pihole.toml 2>/dev/null || \
       grep -q "127.0.0.1#${expected_port}" /etc/pihole/pihole.toml 2>/dev/null; then
      pass "Pi-hole v6 upstreams configured (port ${expected_port})"
    else
      fail "Pi-hole v6 upstreams NOT configured for port ${expected_port}"
    fi
  else
    fail "Pi-hole v6 config file not found"
  fi

  print_summary
}

full_check() {
  print_header
  info "Running Full Check..."

  PASS_COUNT=0 WARN_COUNT=0 FAIL_COUNT=0

  check_system_info
  check_unbound
  check_pihole
  check_pihole_v6_config
  check_docker
  check_netalertx
  check_network_info

  print_summary
}

show_menu() {
  while true; do
    printf '\n'
    printf '%s v%s (output language: English)\n' "$SCRIPT_NAME" "$VERSION"
    printf '┌─────────────────────────────────────────────────────────────────┐\n'
    printf '│         Pi-hole + Unbound Post-Install Check v%s           │\n' "$VERSION"
    printf '├─────────────────────────────────────────────────────────────────┤\n'
    printf '│ [1] Quick Check (summary only)                                  │\n'
    printf '│ [2] Full Check (all sections)                                   │\n'
    printf '│ [3] Show Service URLs                                           │\n'
    printf '│ [4] Service Status                                              │\n'
    printf '│ [5] Network Info                                                │\n'
    printf '│ [6] Exit                                                        │\n'
    printf '└─────────────────────────────────────────────────────────────────┘\n'
    printf '\n'
    IFS= read -rp "Select option [1-6]: " choice

    case $choice in
      1) quick_check ;;
      2) full_check ;;
      3) get_service_urls ;;
      4) show_service_status ;;
      5) check_network_info ;;
      6) printf 'Exiting.\n'; exit 0 ;;
      *) printf '%sInvalid option. Please select 1-6.%s\n' "$UI_RED" "$UI_RESET" ;;
    esac
  done
}

show_usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Post-installation verification script for Pi-hole + Unbound + Pi.Alert setup.
Performs read-only checks to verify service health and configuration.

OPTIONS:
  --version     Show script version
  --quick       Run quick check (summary only)
  --full        Run full check (all sections)
  --urls        Show service URLs only
  --steps       Show manual step-by-step verification guide
  -h, --help    Show this help message

INTERACTIVE MODE:
  Run without arguments to enter interactive menu mode.

EXAMPLES:
  $SCRIPT_NAME --version         # Show version
  $SCRIPT_NAME --quick           # Quick status check
  $SCRIPT_NAME --full            # Comprehensive check
  $SCRIPT_NAME --urls            # Display service URLs
  $SCRIPT_NAME --steps | less    # View manual verification steps
  $SCRIPT_NAME                   # Interactive menu

NOTES:
  - This script performs read-only checks only
  - Some checks may require sudo privileges
  - Running with sudo is recommended for complete checks
  - Pi-hole v6 uses /etc/pihole/pihole.toml as authoritative config

EOF
}

# =============================================
# MAIN
# =============================================
main() {
  case "${1:-}" in
    --version)
      show_version
      exit 0
      ;;
    --quick)
      detect_unbound_port
      quick_check
      exit $?
      ;;
    --full)
      detect_unbound_port
      full_check
      exit $?
      ;;
    --urls)
      detect_unbound_port
      get_service_urls
      exit 0
      ;;
    --steps)
      show_manual_steps
      exit 0
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    "")
      if [[ -t 0 ]]; then
        detect_unbound_port
        show_menu
      else
        detect_unbound_port
        quick_check
        exit $?
      fi
      ;;
    *)
      printf '%sUnknown option: %s%s\n' "$UI_RED" "$1" "$UI_RESET"
      show_usage
      exit 1
      ;;
  esac
}

main "$@"
