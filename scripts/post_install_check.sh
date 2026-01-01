#!/usr/bin/env bash
set -euo pipefail

# Ensure this script never blocks on sudo password prompts.
# - If running as root, treat "sudo cmd" as just "cmd".
# - Otherwise, use "sudo -n" (non-interactive). Calls will fail fast if
#   sudo access is not available, instead of hanging.
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  sudo() { "$@"; }
elif command -v sudo &>/dev/null; then
  sudo() { command sudo -n "$@"; }
fi

# =============================================
# POST-INSTALL CHECK SCRIPT
# Read-only verification for Pi-hole + Unbound + Pi.Alert setup
# =============================================

VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"

# Colors (only if TTY)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
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
  # Try to detect Unbound port from Pi-hole v6 config
  local toml_file="/etc/pihole/pihole.toml"
  local detected_port=""

  # Try reading without sudo first (for --steps and non-sudo invocations)
  if [[ -r "$toml_file" ]]; then
    detected_port=$(sed -n '/^\[dns\]/,/^\[/p' "$toml_file" 2>/dev/null | \
      grep 'upstreams' | \
      grep -o '127\.0\.0\.1#[0-9]*' | \
      sed 's/127\.0\.0\.1#//' | \
      head -n1 || true)
  fi

  # Fallback: probe for listening Unbound port
  if [[ -z "$detected_port" ]] && command -v ss &>/dev/null; then
    detected_port=$(ss -tuln 2>/dev/null | \
      grep '127.0.0.1:53' | \
      grep -v ':53[[:space:]]' | \
      sed 's/.*:53\([0-9][0-9]\).*/53\1/' | \
      head -n1 || true)
  fi

  # Final fallback: default to 5335
  if [[ -z "$detected_port" ]]; then
    detected_port="5335"
  fi

  UNBOUND_PORT="$detected_port"
}

# =============================================
# HELPER FUNCTIONS
# =============================================
pass() {
  echo -e "${GREEN}[PASS]${NC} $*"
  ((PASS_COUNT++))
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
  ((WARN_COUNT++))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $*"
  ((FAIL_COUNT++))
}

info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

section() {
  echo ""
  echo -e "${BLUE}=== $* ===${NC}"
}

# =============================================
# MANUAL STEPS DOCUMENTATION
# =============================================
show_manual_steps() {
  cat <<'EOF'
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

What it checks:
  - Unbound service is running and enabled
  - No recent errors in service logs

───────────────────────────────────────────────────────────────────
Command:
  sudo ss -tulpen | grep <UNBOUND_PORT>

Expected Output:
  udp   UNCONN 0   0   127.0.0.1:<UNBOUND_PORT>   0.0.0.0:*   users:(("unbound",pid=...))
  tcp   LISTEN 0   256 127.0.0.1:<UNBOUND_PORT>   0.0.0.0:*   users:(("unbound",pid=...))

What it checks:
  - Unbound is listening on localhost port <UNBOUND_PORT>
  - Both UDP and TCP protocols are available

───────────────────────────────────────────────────────────────────
Command:
  dig cloudflare.com @127.0.0.1 -p <UNBOUND_PORT> +short

Expected Output:
  104.16.132.229
  104.16.133.229
  (or similar IP addresses)

What it checks:
  - Unbound can successfully resolve DNS queries
  - Recursive DNS resolution is working
  - DoT (DNS-over-TLS) upstream is functional

───────────────────────────────────────────────────────────────────

STEP 2: Verify Pi-hole Service
───────────────────────────────────────────────────────────────────
Command:
  pihole -v

Expected Output:
  Pi-hole version is v6.x.x (vDev branch)
  FTL version is v6.x.x

What it checks:
  - Pi-hole v6 is installed
  - FTL (Faster Than Light) DNS engine is present

───────────────────────────────────────────────────────────────────
Command:
  sudo systemctl status pihole-FTL

Expected Output:
  ● pihole-FTL.service - Pi-hole FTL
     Loaded: loaded (/etc/systemd/system/pihole-FTL.service; enabled)
     Active: active (running) since ...

What it checks:
  - Pi-hole FTL service is running and enabled
  - No errors in service startup

───────────────────────────────────────────────────────────────────
Command:
  sudo ss -tulpen | grep ':53'

Expected Output:
  udp   UNCONN 0   0   0.0.0.0:53   0.0.0.0:*   users:(("pihole-FTL",pid=...))
  tcp   LISTEN 0   32  0.0.0.0:53   0.0.0.0:*   users:(("pihole-FTL",pid=...))

What it checks:
  - Pi-hole is listening on port 53 (standard DNS port)
  - Available on all network interfaces

───────────────────────────────────────────────────────────────────

STEP 3: Verify Pi-hole v6 Configuration (CRITICAL)
───────────────────────────────────────────────────────────────────
Command:
  sudo grep -A5 '^\[dns\]' /etc/pihole/pihole.toml

Expected Output:
  [dns]
  upstreams = ["127.0.0.1#<UNBOUND_PORT>"]

What it checks:
  - Pi-hole v6 is configured to use Unbound as DNS upstream
  - /etc/pihole/pihole.toml is the authoritative config file
  - Upstream is set to localhost:<UNBOUND_PORT> (Unbound)

IMPORTANT:
  In Pi-hole v6, /etc/pihole/pihole.toml is AUTHORITATIVE.
  The legacy setupVars.conf may exist but is NOT the primary config.
  If upstreams is missing or points elsewhere, Pi-hole will use
  public DNS resolvers (Google, Cloudflare, etc.) instead of Unbound.

───────────────────────────────────────────────────────────────────
Command:
  dig example.org @127.0.0.1 +short

Expected Output:
  93.184.215.14
  (or similar IP address)

What it checks:
  - Pi-hole can resolve queries through Unbound
  - End-to-end DNS resolution chain works:
    Client → Pi-hole:53 → Unbound:<UNBOUND_PORT> → DoT Upstream

───────────────────────────────────────────────────────────────────

STEP 4: Advanced Verification (Optional)
───────────────────────────────────────────────────────────────────
Command:
  sudo tcpdump -i lo port <UNBOUND_PORT> -c 10

Run in one terminal, then in another:
  dig test.com @127.0.0.1

Expected Output:
  You should see DNS packets between Pi-hole and Unbound on port <UNBOUND_PORT>

What it checks:
  - Hard proof that Pi-hole is actually querying Unbound
  - Traffic flow visualization

Note: Requires tcpdump package. Install with:
  sudo apt-get install tcpdump

───────────────────────────────────────────────────────────────────

STEP 5: Verify Optional Services
───────────────────────────────────────────────────────────────────
If Docker is installed:
  docker ps

Expected Output:
  CONTAINER ID   IMAGE                    STATUS
  abc123def456   jokobsk/netalertx:latest Up X minutes

If NetAlertX/Pi.Alert is running:
  Visit: http://[your-ip]:20211

───────────────────────────────────────────────────────────────────

INTERPRETATION OF RESULTS:
───────────────────────────────────────────────────────────────────
✓ PASS: Everything working as expected
⚠ WARN: Non-critical issue, system functional but attention needed
✗ FAIL: Critical problem, immediate action required

Common Issues:
  - Port 53 in use: systemd-resolved conflict
    Fix: sudo systemctl disable --now systemd-resolved
  - Unbound not resolving: Check /var/log/unbound/unbound.log
  - Pi-hole v6 wrong upstream: Run installer with --force flag

EOF
}

print_header() {
  echo "────────────────────────────────────────────────────────────────"
  echo "POST-INSTALL CHECK — Pi-hole v6 / Unbound / Docker / Pi.Alert"
  echo "Script: ${SCRIPT_NAME} v${VERSION} (output language: English)"
  echo "────────────────────────────────────────────────────────────────"
}

show_version() {
  echo "${SCRIPT_NAME} v${VERSION}"
  echo "Output language: English"
}

# =============================================
# CHECK FUNCTIONS
# =============================================
check_system_info() {
  section "System Information"

  if command -v lsb_release &>/dev/null; then
    info "OS: $(lsb_release -ds 2>/dev/null || echo 'Unknown')"
  elif [[ -f /etc/os-release ]]; then
    info "OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
  fi

  info "Hostname: $(hostname)"
  info "Kernel: $(uname -r)"

  local ipv4
  ipv4=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
  info "IPv4: $ipv4"

  if command -v ip &>/dev/null; then
    local default_route
    default_route=$(ip route | grep default | awk '{print $3}' | head -n1 || echo "N/A")
    info "Default Gateway: $default_route"
  fi
}

check_unbound() {
  section "Unbound DNS Service"

  # Service status
  if systemctl is-active --quiet unbound 2>/dev/null; then
    pass "Unbound service is running"
  else
    fail "Unbound service is NOT running"
    return
  fi

  # Port check (use detected port)
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

  # DNS resolution test
  if command -v dig &>/dev/null; then
    if dig +short @127.0.0.1 -p ${unbound_port} cloudflare.com +time=1 +tries=1 2>/dev/null | grep -qE '^[0-9.]+$'; then
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

  # Version check
  if command -v pihole &>/dev/null; then
    local version
    version=$(pihole -v 2>/dev/null | grep "Pi-hole version is" | awk '{print $NF}' || echo "unknown")
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

  # Service status
  if systemctl is-active --quiet pihole-FTL 2>/dev/null; then
    pass "Pi-hole FTL service is running"
  else
    fail "Pi-hole FTL service is NOT running"
    return
  fi

  # Port check
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

  # DNS resolution test
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

  # Parse upstreams from [dns] section
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
    ' "$toml_file" 2>/dev/null || echo "NOT_FOUND")
  fi

  if [[ "$upstreams" == "NOT_FOUND" || -z "$upstreams" ]]; then
    fail "Pi-hole v6 upstreams NOT configured in [dns] section"
    warn "Pi-hole will use public DNS resolvers instead of Unbound!"
  else
    local expected_port="${UNBOUND_PORT:-5335}"
    if echo "$upstreams" | grep -q "127.0.0.1#${expected_port}"; then
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

  # List containers
  local containers
  if sudo test -x /usr/bin/docker 2>/dev/null; then
    containers=$(sudo docker ps --format "{{.Names}}" 2>/dev/null || echo "")
  else
    containers=$(docker ps --format "{{.Names}}" 2>/dev/null || echo "")
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

  # Check for NetAlertX container
  if [[ -d /opt/netalertx/data ]]; then
    pass "NetAlertX data dir present: /opt/netalertx/data"
  fi
  if [[ -d /opt/netalertx/config || -d /opt/netalertx/db ]]; then
    if [[ -n "$(ls -A /opt/netalertx/config 2>/dev/null || true)" ||           -n "$(ls -A /opt/netalertx/db 2>/dev/null || true)" ]]; then
      warn "Legacy NetAlertX dirs detected (/opt/netalertx/config,/opt/netalertx/db). New mount uses /opt/netalertx/data -> /data; migrate if needed."
    fi
  fi

  if command -v docker &>/dev/null; then
    if sudo docker ps 2>/dev/null | grep -q netalertx || docker ps 2>/dev/null | grep -q netalertx; then
      pass "NetAlertX container is running"
      found=true

      # Host networking is recommended for reliable device discovery.
      local network_mode=""
      network_mode=$(sudo docker inspect -f '{{.HostConfig.NetworkMode}}' netalertx 2>/dev/null || docker inspect -f '{{.HostConfig.NetworkMode}}' netalertx 2>/dev/null || echo "")

      if [[ "$network_mode" == "host" ]]; then
        pass "NetAlertX container network mode: host"
        port="20211"
      else
        if [[ -n "$network_mode" ]]; then
          warn "NetAlertX container not in host mode (NetworkMode: $network_mode). Device discovery may be limited."
        else
          warn "Could not determine NetAlertX container network mode"
        fi

        # Try to get port mapping (bridge mode)
        port=$(sudo docker ps --filter name=netalertx --format "{{.Ports}}" 2>/dev/null | grep -oP '\d+(?=->20211)' | head -n1 || echo "")
        if [[ -z "$port" ]]; then
          port=$(docker ps --filter name=netalertx --format "{{.Ports}}" 2>/dev/null | grep -oP '\d+(?=->20211)' | head -n1 || echo "")
        fi
      fi
    fi
  fi

  # Check for Pi.Alert systemd service
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

  # DNS configuration
  if [[ -f /etc/resolv.conf ]]; then
    local nameservers
    nameservers=$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
    info "System nameservers: $nameservers"

    if echo "$nameservers" | grep -q "127.0.0.1"; then
      pass "System using local DNS (127.0.0.1)"
    else
      warn "System NOT using local DNS"
    fi
  fi

  # Check for systemd-resolved conflict
  if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    warn "systemd-resolved is running (may conflict with Pi-hole on port 53)"
  fi
}

get_service_urls() {
  section "Service URLs"

  local ipv4
  ipv4=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")

  echo ""
  echo "┌─────────────────────────────────────────────────────────────────┐"
  echo "│                         Service URLs                            │"
  echo "├─────────────────────────────────────────────────────────────────┤"

  # Pi-hole
  if systemctl is-active --quiet pihole-FTL 2>/dev/null; then
    printf "│ %-63s │\n" "Pi-hole Admin:   http://${ipv4}/admin"
  fi

  # NetAlertX
  if command -v docker &>/dev/null; then
    local netalertx_port=""
    local network_mode=""

    if sudo docker ps --filter name=netalertx --format "{{.Names}}" 2>/dev/null | grep -q '^netalertx$' ||        docker ps --filter name=netalertx --format "{{.Names}}" 2>/dev/null | grep -q '^netalertx$'; then

      network_mode=$(sudo docker inspect -f '{{.HostConfig.NetworkMode}}' netalertx 2>/dev/null || docker inspect -f '{{.HostConfig.NetworkMode}}' netalertx 2>/dev/null || echo "")

      if [[ "$network_mode" == "host" ]]; then
        netalertx_port="20211"
      else
        netalertx_port=$(sudo docker ps --filter name=netalertx --format "{{.Ports}}" 2>/dev/null | grep -oP '\d+(?=->20211)' | head -n1 ||                          docker ps --filter name=netalertx --format "{{.Ports}}" 2>/dev/null | grep -oP '\d+(?=->20211)' | head -n1 || echo "")
      fi

      if [[ -n "$netalertx_port" ]]; then
        printf "│ %-63s │\n" "NetAlertX:       http://${ipv4}:${netalertx_port}"
      fi
    fi
  fi

  # Python Suite (optional)
  if systemctl is-active --quiet pihole-suite 2>/dev/null; then
    printf "│ %-63s │\n" "Python Suite API: http://127.0.0.1:8090"
  fi

  echo "└─────────────────────────────────────────────────────────────────┘"
  echo ""
}

show_service_status() {
  section "Service Status Summary"

  echo ""
  printf "%-20s %s\n" "Service" "Status"
  printf "%-20s %s\n" "-------" "------"

  # Unbound
  if systemctl is-active --quiet unbound 2>/dev/null; then
    printf "%-20s ${GREEN}%s${NC}\n" "Unbound" "ACTIVE"
  else
    printf "%-20s ${RED}%s${NC}\n" "Unbound" "INACTIVE"
  fi

  # Pi-hole FTL
  if systemctl is-active --quiet pihole-FTL 2>/dev/null; then
    printf "%-20s ${GREEN}%s${NC}\n" "Pi-hole FTL" "ACTIVE"
  else
    printf "%-20s ${RED}%s${NC}\n" "Pi-hole FTL" "INACTIVE"
  fi

  # Docker
  if systemctl is-active --quiet docker 2>/dev/null; then
    printf "%-20s ${GREEN}%s${NC}\n" "Docker" "ACTIVE"
  else
    printf "%-20s ${YELLOW}%s${NC}\n" "Docker" "INACTIVE/NOT INSTALLED"
  fi

  # NetAlertX container
  if command -v docker &>/dev/null && (sudo docker ps 2>/dev/null | grep -q netalertx || docker ps 2>/dev/null | grep -q netalertx); then
    printf "%-20s ${GREEN}%s${NC}\n" "NetAlertX" "RUNNING"
  else
    printf "%-20s ${YELLOW}%s${NC}\n" "NetAlertX" "NOT RUNNING/SKIPPED"
  fi

  echo ""
}

print_summary() {
  echo ""
  echo "┌─────────────────────────────────────────────────────────────────┐"
  echo "│                         Check Summary                           │"
  echo "├─────────────────────────────────────────────────────────────────┤"
  printf "│ ${GREEN}PASS:${NC} %-57s│\n" "$PASS_COUNT"
  printf "│ ${YELLOW}WARN:${NC} %-57s│\n" "$WARN_COUNT"
  printf "│ ${RED}FAIL:${NC} %-57s│\n" "$FAIL_COUNT"
  echo "└─────────────────────────────────────────────────────────────────┘"
  echo ""

  if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}Some checks failed. Please review the output above.${NC}"
    return 1
  elif [[ $WARN_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}Some checks produced warnings. Review recommended.${NC}"
    return 0
  else
    echo -e "${GREEN}All checks passed successfully!${NC}"
    return 0
  fi
}

quick_check() {
  print_header
  info "Running Quick Check..."
  echo ""

  # Reset counters
  PASS_COUNT=0 WARN_COUNT=0 FAIL_COUNT=0

  # Quick checks
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

  # Quick Pi-hole v6 config check (use detected port)
  local expected_port="${UNBOUND_PORT:-5335}"
  if [[ -f /etc/pihole/pihole.toml ]]; then
    if sudo grep -q "127.0.0.1#${expected_port}" /etc/pihole/pihole.toml 2>/dev/null || grep -q "127.0.0.1#${expected_port}" /etc/pihole/pihole.toml 2>/dev/null; then
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

  # Reset counters
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
    echo ""
    echo "${SCRIPT_NAME} v${VERSION} (output language: English)"
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│         Pi-hole + Unbound Post-Install Check v${VERSION}           │"
    echo "├─────────────────────────────────────────────────────────────────┤"
    echo "│ [1] Quick Check (summary only)                                  │"
    echo "│ [2] Full Check (all sections)                                   │"
    echo "│ [3] Show Service URLs                                           │"
    echo "│ [4] Service Status                                              │"
    echo "│ [5] Network Info                                                │"
    echo "│ [6] Exit                                                        │"
    echo "└─────────────────────────────────────────────────────────────────┘"
    echo ""
    read -rp "Select option [1-6]: " choice

    case $choice in
      1) quick_check ;;
      2) full_check ;;
      3) get_service_urls ;;
      4) show_service_status ;;
      5) check_network_info ;;
      6) echo "Exiting."; exit 0 ;;
      *) echo -e "${RED}Invalid option. Please select 1-6.${NC}" ;;
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
  # Check for non-interactive flags
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
      get_service_urls
      exit 0
      ;;
    --steps)
      # Don't detect port for --steps (just show placeholders)
      show_manual_steps
      exit 0
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    "")
      # Interactive mode (only if stdin is a TTY). If not, default to a
      # non-blocking quick check so automation/SSH pipes don't hang.
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
      echo -e "${RED}Unknown option: $1${NC}"
      show_usage
      exit 1
      ;;
  esac
}

main "$@"
