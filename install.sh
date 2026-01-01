#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# =============================================
# GLOBAL VARIABLES
# =============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
LOG_FILE="${SCRIPT_DIR}/install.log"
ERROR_LOG="${SCRIPT_DIR}/install_errors.log"
STATE_FILE="${SCRIPT_DIR}/data/install.state"
ENV_FILE="${SCRIPT_DIR}/.env"
RESOLV_CONF="/etc/resolv.conf"
RESOLV_CONF_BACKUP="/etc/resolv.conf.bak"
PIHOLE_TOML="/etc/pihole/pihole.toml"

# Defaults (NOT readonly)
CONTAINER_MODE=false
DRY_RUN=false
FORCE=false
AUTO_REMOVE_CONFLICTS=false
INSTALL_NETALERTX=true
INSTALL_PYTHON_SUITE=true

# Ports
UNBOUND_PORT=5335
NETALERTX_PORT=20211
PYTHON_SUITE_PORT=8090
CONTAINER_PIHOLE_DNS_PORT=8053
CONTAINER_PIHOLE_WEB_PORT=8080

# =============================================
# LOGGING
# =============================================
log() { 
  local msg
  msg="[\033[34m$(date +"%H:%M:%S")\033[0m] $*"
  echo -e "$msg"
  if [[ -w "$(dirname "$LOG_FILE")" ]]; then
    echo -e "$msg" >> "$LOG_FILE" 2>/dev/null || true
  fi
}
log_success() { 
  local msg
  msg="[\033[34m$(date +"%H:%M:%S")\033[0m] \033[32m✓\033[0m $*"
  echo -e "$msg"
  if [[ -w "$(dirname "$LOG_FILE")" ]]; then
    echo -e "$msg" >> "$LOG_FILE" 2>/dev/null || true
  fi
}
log_error() { 
  local msg
  msg="[\033[34m$(date +"%H:%M:%S")\033[0m] \033[31m✗\033[0m $*"
  echo -e "$msg" >&2
  if [[ -w "$(dirname "$LOG_FILE")" ]]; then
    echo -e "$msg" >> "$LOG_FILE" 2>/dev/null || true
    echo -e "$msg" >> "$ERROR_LOG" 2>/dev/null || true
  fi
}
log_warning() { 
  local msg
  msg="[\033[34m$(date +"%H:%M:%S")\033[0m] \033[33m!\033[0m $*"
  echo -e "$msg"
  if [[ -w "$(dirname "$LOG_FILE")" ]]; then
    echo -e "$msg" >> "$LOG_FILE" 2>/dev/null || true
  fi
}

init_runtime_paths() {
  # Enforce: clone as normal user, execute via sudo.
  # (root shells like "su -" are intentionally rejected)
  if [[ ${EUID:-$(id -u)} -eq 0 && -z "${SUDO_USER:-}" ]]; then
    echo "Do not run this installer as root directly." >&2
    echo "Clone the repo as a normal user and run it via: sudo ./install.sh" >&2
    exit 1
  fi

  # Ensure log dir exists; fall back to repo dir if it cannot be used.
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    chmod 0755 "$LOG_DIR" 2>/dev/null || true
  fi

  if [[ ! -d "$LOG_DIR" || ! -w "$LOG_DIR" ]]; then
    LOG_FILE="${SCRIPT_DIR}/install.log"
    ERROR_LOG="${SCRIPT_DIR}/install_errors.log"
  fi

  # Ensure state dir exists; fall back to repo dir if it cannot be used.
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    chmod 0755 "$STATE_DIR" 2>/dev/null || true
  fi

  if [[ ! -d "$(dirname "$STATE_FILE")" || ! -w "$(dirname "$STATE_FILE")" ]]; then
    STATE_FILE="${SCRIPT_DIR}/data/install.state"
  fi

  # Ensure env dir exists; fall back to repo dir if it cannot be used.
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    mkdir -p "$ENV_DIR" 2>/dev/null || true
    chmod 0755 "$ENV_DIR" 2>/dev/null || true
  fi

  if [[ ! -d "$(dirname "$ENV_FILE")" || ! -w "$(dirname "$ENV_FILE")" ]]; then
    ENV_FILE="${SCRIPT_DIR}/.env"
  fi
}

# =============================================
# STATE MANAGEMENT
# =============================================
init_state() {
  mkdir -p "$(dirname "$STATE_FILE")"
  if [[ ! -f "$STATE_FILE" ]]; then
    cat > "$STATE_FILE" <<EOF
PACKAGES_OK=false
UNBOUND_OK=false
PIHOLE_OK=false
NETALERTX_OK=false
PY_SUITE_OK=false
HEALTH_OK=false
EOF
  fi
  # shellcheck source=/dev/null
  source "$STATE_FILE"
}

update_state() {
  sed -i "s/^$1=.*/$1=$2/" "$STATE_FILE"
  # shellcheck source=/dev/null
  source "$STATE_FILE"
}


# =============================================
# STATE VALIDATION (avoid stale install.state)
# =============================================
validate_state_against_system() {
  # The state file is an optimization only. If it claims something is OK but the
  # underlying binary/service/container is missing, reset the flag so the
  # installer performs the step again.
  [[ "$FORCE" == true ]] && return

  local changed=false

  # Unbound
  if [[ "${UNBOUND_OK:-false}" == true ]]; then
    if ! command -v unbound-checkconf >/dev/null 2>&1; then
      log_warning "State override: UNBOUND_OK=true but unbound not installed"
      update_state UNBOUND_OK false
      changed=true
    elif command -v systemctl >/dev/null 2>&1 && ! systemctl is-active --quiet unbound 2>/dev/null; then
      log_warning "State override: UNBOUND_OK=true but unbound service not active"
      update_state UNBOUND_OK false
      changed=true
    fi
  fi

  # Pi-hole
  if [[ "${PIHOLE_OK:-false}" == true ]]; then
    if [[ "$CONTAINER_MODE" == true ]]; then
      if ! command -v docker >/dev/null 2>&1; then
        log_warning "State override: PIHOLE_OK=true but docker missing"
        update_state PIHOLE_OK false
        changed=true
      elif ! sudo -n docker ps 2>/dev/null | grep -q '\bpihole\b'; then
        log_warning "State override: PIHOLE_OK=true but pihole container missing"
        update_state PIHOLE_OK false
        changed=true
      fi
    else
      if ! command -v pihole >/dev/null 2>&1; then
        log_warning "State override: PIHOLE_OK=true but pihole command missing"
        update_state PIHOLE_OK false
        changed=true
      elif command -v systemctl >/dev/null 2>&1 && ! systemctl is-active --quiet pihole-FTL 2>/dev/null; then
        log_warning "State override: PIHOLE_OK=true but pihole-FTL service not active"
        update_state PIHOLE_OK false
        changed=true
      fi
    fi
  fi

  # NetAlertX
  if [[ "${NETALERTX_OK:-false}" == true && "${INSTALL_NETALERTX:-true}" == true ]]; then
    if ! command -v docker >/dev/null 2>&1; then
      log_warning "State override: NETALERTX_OK=true but docker missing"
      update_state NETALERTX_OK false
      changed=true
    elif ! sudo -n docker ps 2>/dev/null | grep -q '\bnetalertx\b'; then
      log_warning "State override: NETALERTX_OK=true but netalertx container missing"
      update_state NETALERTX_OK false
      changed=true
    fi
  fi

  # Python Suite
  if [[ "${PY_SUITE_OK:-false}" == true && "$CONTAINER_MODE" == false && "${INSTALL_PYTHON_SUITE:-true}" == true ]]; then
    if command -v systemctl >/dev/null 2>&1 && ! systemctl is-active --quiet pihole-suite 2>/dev/null; then
      log_warning "State override: PY_SUITE_OK=true but pihole-suite service not active"
      update_state PY_SUITE_OK false
      changed=true
    fi
  fi

  # Health is derived; if anything changed, recompute.
  if [[ "$changed" == true ]]; then
    update_state HEALTH_OK false
  fi
}

# =============================================
# ARGUMENT PARSING
# =============================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --container-mode) CONTAINER_MODE=true ;;
      --dry-run) DRY_RUN=true ;;
      --force) FORCE=true ;;
      # Compatibility alias: some docs/older guidance referenced --resume.
      # Default behavior is already idempotent; keep it as a no-op.
      --resume) : ;;
      --auto-remove-conflicts) AUTO_REMOVE_CONFLICTS=true ;;
      --skip-netalertx) INSTALL_NETALERTX=false ;;
      --skip-python-api) INSTALL_PYTHON_SUITE=false ;;
      --minimal) INSTALL_NETALERTX=false; INSTALL_PYTHON_SUITE=false ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
    shift
  done
}

# =============================================
# SYSTEM CHECKS
# =============================================
check_dependencies() {
  # OS / package manager sanity
  if [[ ! -r /etc/os-release ]]; then
    log_error "Cannot read /etc/os-release (unsupported system)"
    exit 1
  fi

  if ! grep -Eq "^(ID|ID_LIKE)=(debian|ubuntu|.*debian.*|.*ubuntu.*)$" /etc/os-release; then
    log_error "Unsupported OS (expected Debian/Ubuntu family)"
    exit 1
  fi

  command -v apt-get >/dev/null 2>&1 || { log_error "apt-get not found"; exit 1; }

  # Enforce sudo invocation to keep stable paths writable.
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    log_error "Run this installer via sudo: sudo ./install.sh"
    exit 1
  fi

  # Note: most dependencies are installed by install_packages(); warn early for clarity
  local missing_bootstrap=()
  for cmd in curl openssl python3; do
    command -v "$cmd" >/dev/null 2>&1 || missing_bootstrap+=("$cmd")
  done
  if [[ ${#missing_bootstrap[@]} -gt 0 ]]; then
    log_warning "Bootstrap tools missing (installer will install): ${missing_bootstrap[*]}"
  fi

  # Optional tools (installer will install them, but preflight helps when debugging)
  local missing_optional=()
  for cmd in git jq dig ss ip; do
    command -v "$cmd" >/dev/null 2>&1 || missing_optional+=("$cmd")
  done
  if [[ ${#missing_optional[@]} -gt 0 ]]; then
    log_warning "Optional tools missing (installer will install): ${missing_optional[*]}"
  fi
}

handle_systemd_resolved() {
  if [[ -f /etc/os-release ]] && grep -q "ubuntu" /etc/os-release; then
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
      log "Stopping systemd-resolved..."
      sudo systemctl stop systemd-resolved || true
      sudo systemctl disable systemd-resolved || true
      [[ -L "$RESOLV_CONF" ]] && sudo mv -f "$RESOLV_CONF" "$RESOLV_CONF_BACKUP"
      echo "nameserver 1.1.1.1" | sudo tee "$RESOLV_CONF" >/dev/null
    fi
  fi
}


check_ports() {
  if [[ "$DRY_RUN" == true ]]; then
    log "DRY RUN: Would check ports $UNBOUND_PORT, $NETALERTX_PORT, $PYTHON_SUITE_PORT, 53"
    return 0
  fi

  # Idempotency: during re-runs it's expected that Unbound/Pi-hole/etc. are
  # already bound to their ports. Only fail if a port is occupied by an
  # unexpected service.
  is_expected_listener() {
    local port="$1"
    local ss_line=""

    if command -v ss >/dev/null 2>&1; then
      ss_line="$(ss -H -ltnup "sport = :$port" 2>/dev/null || true)"
    fi

    if [[ "$port" == "$UNBOUND_PORT" ]]; then
      if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet unbound 2>/dev/null; then
        return 0
      fi
      echo "$ss_line" | grep -qi unbound && return 0
    fi

    if [[ "$port" == "53" && "$CONTAINER_MODE" == false ]]; then
      if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet pihole-FTL 2>/dev/null; then
        return 0
      fi
      echo "$ss_line" | grep -qiE 'pihole-FTL|pihole' && return 0
    fi

    if [[ "$port" == "$NETALERTX_PORT" && "${INSTALL_NETALERTX:-true}" == true ]]; then
      if command -v docker >/dev/null 2>&1; then
        docker ps --format '{{.Names}}' 2>/dev/null | grep -qx netalertx && return 0
      fi
    fi

    if [[ "$port" == "$PYTHON_SUITE_PORT" && "$CONTAINER_MODE" == false && "${INSTALL_PYTHON_SUITE:-true}" == true ]]; then
      if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet pihole-suite 2>/dev/null; then
        return 0
      fi
      echo "$ss_line" | grep -qiE 'pihole-suite|uvicorn|python' && return 0
    fi

    return 1
  }

  port_is_in_use() {
    local port="$1"
    if command -v ss &>/dev/null; then
      ss -tuln 2>/dev/null | grep -q "\:$port "
    elif command -v netstat &>/dev/null; then
      netstat -tuln 2>/dev/null | grep -q "\:$port "
    else
      return 1
    fi
  }

  local ports=("$UNBOUND_PORT" "53")
  [[ "$INSTALL_NETALERTX" == true ]] && ports+=("$NETALERTX_PORT")
  [[ "$INSTALL_PYTHON_SUITE" == true ]] && ports+=("$PYTHON_SUITE_PORT")
  if [[ "$CONTAINER_MODE" == true ]]; then
    ports+=("$CONTAINER_PIHOLE_DNS_PORT" "$CONTAINER_PIHOLE_WEB_PORT")
  fi

  for port in "${ports[@]}"; do
    if port_is_in_use "$port"; then
      if is_expected_listener "$port"; then
        log "✅ Port $port already in use (expected)"
        continue
      fi
      log_error "Port $port in use"
      return 1
    fi
  done
}

# =============================================
# DOCKER SERVICE MANAGEMENT
# =============================================
ensure_docker_service() {
  log "Ensuring Docker service is running..."
  if ! systemctl is-active --quiet docker 2>/dev/null; then
    if ! $DRY_RUN; then
      sudo systemctl enable docker || { log_error "Failed to enable Docker"; exit 1; }
      sudo systemctl start docker || { log_error "Failed to start Docker"; exit 1; }
      
      # Wait for Docker to be ready
      local timeout=30
      local count=0
      while ! docker info >/dev/null 2>&1 && [ $count -lt $timeout ]; do
        sleep 1
        ((count++))
      done
      
      if [ $count -eq $timeout ]; then
        log_error "Docker service failed to start within ${timeout}s"
        exit 1
      fi
      
      log_success "Docker service is running"
    else
      log "DRY RUN: Would ensure Docker service is running"
    fi
  else
    log "✅ Docker service already running"
  fi
}
install_packages() {
  [[ "$PACKAGES_OK" == true && "$FORCE" != true ]] && { log "✅ Packages OK"; return; }

  local packages=(
    unbound unbound-host unbound-anchor dns-root-data ca-certificates curl dnsutils iproute2
    python3 python3-venv python3-pip git openssl sqlite3 docker.io
  )

  log "Installing packages..."
  sudo apt-get update -qq
  [[ "$AUTO_REMOVE_CONFLICTS" == true ]] && {
    sudo apt-get remove -y containerd.io docker-ce docker-ce-cli || true
  }

  for _ in {1..3}; do
    if ! $DRY_RUN; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}" && {
        log_success "Packages installed"
        update_state PACKAGES_OK true
        return
      }
    else
      log "DRY RUN: Would install ${packages[*]}"
      update_state PACKAGES_OK true
      return
    fi
    sleep 2
  done
  log_error "Failed to install packages"
  exit 1
}

# =============================================
# UNBOUND CONFIGURATION
# =============================================
configure_unbound() {
  [[ "$UNBOUND_OK" == true && "$FORCE" != true ]] && { log "✅ Unbound OK"; return; }

  log "Configuring Unbound DNS with DoT (DNS-over-TLS)..."
  if ! $DRY_RUN; then
    # Create Unbound directories
    sudo install -d -m 0755 /var/lib/unbound
    
    # Download root hints for DNS resolution
    sudo curl -fsSL https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints || {
      log_error "Failed to download root.hints"; exit 1;
    }
    
    # Update/validate DNSSEC trust anchor (root.key)
    command -v unbound-anchor >/dev/null 2>&1 || { log_error "unbound-anchor missing"; exit 1; }

    local unbound_anchor="/var/lib/unbound/root.key"
    local unbound_anchor_log="/tmp/unbound-anchor.log"

    log "Updating/validating DNSSEC trust anchor (root.key)..."

    if [[ -f "$unbound_anchor" ]]; then
      if sudo unbound-anchor -a "$unbound_anchor" -v >"$unbound_anchor_log" 2>&1; then
        log_success "trust anchor ok (existing root.key)"
      else
        log_warning "unbound-anchor returned non-zero, but root.key exists; retrying..."
        sudo tail -n 50 "$unbound_anchor_log" 2>/dev/null || true
        sleep 2
        if sudo unbound-anchor -a "$unbound_anchor" -v >"$unbound_anchor_log" 2>&1; then
          log_success "trust anchor ok after retry"
        else
          log_warning "unbound-anchor still failing; continuing (DNSSEC may be impaired)."
          sudo tail -n 80 "$unbound_anchor_log" 2>/dev/null || true
        fi
      fi
    else
      if sudo unbound-anchor -a "$unbound_anchor" -v >"$unbound_anchor_log" 2>&1; then
        log_success "trust anchor created"
      else
        log_warning "unbound-anchor failed to create root.key; continuing (DNSSEC may be impaired)."
        sudo tail -n 80 "$unbound_anchor_log" 2>/dev/null || true
      fi
    fi
    
    # Verify TLS certificate bundle exists
    if [[ ! -f /etc/ssl/certs/ca-certificates.crt ]]; then
      log_error "TLS certificate bundle missing at /etc/ssl/certs/ca-certificates.crt"
      exit 1
    fi

    # Create Unbound configuration directory if missing
    sudo mkdir -p /etc/unbound/unbound.conf.d

    # Ensure base config exists (it may be missing after manual cleanup or on some distros)
    if [[ ! -f /etc/unbound/unbound.conf ]]; then
      log_warning "/etc/unbound/unbound.conf missing; creating minimal include file"
      sudo bash -c 'cat > /etc/unbound/unbound.conf' <<'EOF'
# Minimal Unbound config created by installer.
# Loads all drop-in configs from /etc/unbound/unbound.conf.d/.
server:
    directory: "/etc/unbound"
include: "/etc/unbound/unbound.conf.d/*.conf"
EOF
    fi

    # Create comprehensive Unbound configuration
    sudo bash -c 'cat > /etc/unbound/unbound.conf.d/forward.conf' <<EOF
server:
    # Network interface and port
    interface: 127.0.0.1
    port: $UNBOUND_PORT
    
    # TLS configuration for DNS-over-TLS
    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt
    
    # DNSSEC validation: Ubuntu bringt auto-trust-anchor-file als Drop-in
    root-hints: /var/lib/unbound/root.hints
    
    # Protocol support
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    
    # Access control
    access-control: 127.0.0.0/8 allow
    access-control: 10.0.0.0/8 allow
    access-control: 172.16.0.0/12 allow
    access-control: 192.168.0.0/16 allow
    
    # Privacy and security
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-below-nxdomain: yes
    harden-referral-path: yes
    
    # Performance
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    prefetch: yes
    
    # Logging (disable for production)
    verbosity: 1
    log-queries: no

# Forward zone for DNS-over-TLS to Quad9
forward-zone:
    name: "."
    forward-tls-upstream: yes
    # Primary Quad9 DoT servers
    forward-addr: 9.9.9.9@853#dns.quad9.net
    forward-addr: 149.112.112.112@853#dns.quad9.net
    # Backup Cloudflare DoT servers
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 1.0.0.1@853#cloudflare-dns.com
EOF

    # Remove duplicate trust anchor directives if Ubuntu drop-in exists
    if [[ -f /etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf ]]; then
      sudo sed -i '/^[[:space:]]*trust-anchor-file:/d' /etc/unbound/unbound.conf.d/forward.conf || true
      log "Ubuntu auto-trust-anchor detected, removed duplicate trust-anchor-file directive"
    fi

    # Validate configuration before restart
    if ! sudo unbound-checkconf; then
      log_error "Unbound configuration validation failed"
      exit 1
    fi

    # Restart and verify Unbound service
    sudo systemctl restart unbound || { log_error "Failed to restart Unbound"; exit 1; }
    sleep 3
    
    # Comprehensive health check
    local health_checks=("example.com" "google.com" "cloudflare.com")
    local failed_checks=0
    
    for domain in "${health_checks[@]}"; do
      if dig +short @127.0.0.1 -p $UNBOUND_PORT "$domain" | grep -qE '^[0-9.]+$'; then
        log "✓ Unbound resolves $domain"
      else
        log_warning "✗ Unbound failed to resolve $domain"
        ((failed_checks++))
      fi
    done
    
    if [ $failed_checks -lt ${#health_checks[@]} ]; then
      log_success "Unbound DNS-over-TLS configured successfully"
      update_state UNBOUND_OK true
    else
      log_error "Unbound health check failed for all test domains"
      exit 1
    fi
  else
    log "DRY RUN: Would configure Unbound with DoT, root.hints, trust anchors, and TLS certificates"
    update_state UNBOUND_OK true
  fi
}

# =============================================
# PI-HOLE SETUP
# =============================================
configure_pihole_v6_toml_upstreams() {
  local toml_file="/etc/pihole/pihole.toml"
  local temp_file
  temp_file="$(mktemp)" || { log_error "Failed to create temp file"; exit 1; }

  # Create the file if it doesn't exist
  if [[ ! -f "$toml_file" ]]; then
    log "Creating $toml_file..."
    sudo install -o pihole -g pihole -m 0644 /dev/null "$toml_file"
  fi

  # Create timestamped backup preserving attributes
  local backup_file="${toml_file}.backup.$(date +%Y%m%d_%H%M%S)"
  sudo cp -a "$toml_file" "$backup_file"
  log "Backup created: $backup_file"

  # Single-pass awk rewrite: ensure [dns] exists, remove old upstreams, insert new upstream
  sudo awk -v upstream="127.0.0.1#${UNBOUND_PORT}" '
    BEGIN { in_dns=0; dns_exists=0; dns_written=0 }

    # Track when we enter [dns] section
    /^\[dns\]/ {
      in_dns=1
      dns_exists=1
      print
      print "upstreams = [\"" upstream "\"]"
      dns_written=1
      next
    }

    # Track when we leave [dns] section
    /^\[/ && !/^\[dns\]/ {
      in_dns=0
    }

    # Skip upstreams lines only within [dns] section
    in_dns && /^[[:space:]]*upstreams[[:space:]]*=/ {
      next
    }

    # Print all other lines
    { print }

    # At end of file, if [dns] was never found, add it
    END {
      if (!dns_exists) {
        print ""
        print "[dns]"
        print "upstreams = [\"" upstream "\"]"
      }
    }
  ' "$toml_file" > "$temp_file"

  # Move temp file to final location
  sudo mv "$temp_file" "$toml_file"

  # Restore ownership and permissions
  sudo chown pihole:pihole "$toml_file"
  sudo chmod 0644 "$toml_file"

  log "Configured DNS upstreams in $toml_file"

  # Restart pihole-FTL
  log "Restarting pihole-FTL..."
  if ! sudo systemctl restart pihole-FTL; then
    log_error "Failed to restart pihole-FTL"
    exit 1
  fi

  log_success "Pi-hole v6 DNS upstreams configured"
}

setup_pihole() {
  [[ "$PIHOLE_OK" == true && "$FORCE" != true ]] && { log "✅ Pi-hole OK"; return; }

  if [[ "$CONTAINER_MODE" == true ]]; then
    setup_pihole_container
  else
    setup_pihole_host
  fi
}

setup_pihole_host() {
  if ! $DRY_RUN; then
    if ! command -v pihole &>/dev/null; then
      # Install Pi-hole non-interactively (SSH-safe)
      curl -sSL https://install.pi-hole.net | sudo \
        PIHOLE_SKIP_OS_CHECK=true \
        PIHOLE_INSTALL_AUTO=true \
        DEBIAN_FRONTEND=noninteractive \
        DNS1=127.0.0.1#$UNBOUND_PORT \
        DNS2=no \
        bash -s -- --unattended || {
        log_error "Pi-hole install failed"; exit 1;
      }
    fi
    
    # Wait for Pi-hole setup to complete and configuration file to be created
    for i in {1..30}; do
      if [[ -f /etc/pihole/setupVars.conf ]]; then
        break
      fi
      log "Waiting for Pi-hole setup to complete... ($i/30)"
      sleep 2
    done
    
    if [[ -f /etc/pihole/setupVars.conf ]]; then
      sudo sed -i "s/^PIHOLE_DNS_1=.*/PIHOLE_DNS_1=127.0.0.1#$UNBOUND_PORT/" /etc/pihole/setupVars.conf
      sudo sed -i "s/^PIHOLE_DNS_2=.*/PIHOLE_DNS_2=/" /etc/pihole/setupVars.conf
      log "Updated legacy setupVars.conf for backward compatibility"
    else
      log_warning "Pi-hole setupVars.conf not found (OK for v6, uses pihole.toml)"
    fi
    if [[ -f "$PIHOLE_TOML" ]]; then
      log "Detected pihole.toml at $PIHOLE_TOML (v6.1.4+ built-in web server)"
    else
      log_warning "pihole.toml missing; creating placeholder for Pi-hole v6.1.4 expectations"
      sudo install -o pihole -g pihole -m 0644 /dev/null "$PIHOLE_TOML"
      echo "# Managed via Pi-hole UI (placeholder created by installer)" | sudo tee "$PIHOLE_TOML" >/dev/null
    fi
    configure_pihole_v6_toml_upstreams
    echo "nameserver 127.0.0.1" | sudo tee "$RESOLV_CONF" >/dev/null
    log_success "Pi-hole OK"
    update_state PIHOLE_OK true
  else
    log "DRY RUN: Would install Pi-hole"
    update_state PIHOLE_OK true
  fi
}

setup_pihole_container() {
  if ! $DRY_RUN; then
    ensure_docker_service
    
    # Remove existing Pi-hole container if it exists
    sudo docker rm -f pihole 2>/dev/null || true
    
    log "Creating Pi-hole container with host networking..."
    sudo docker run -d --name pihole --network host \
      -e DNS1=127.0.0.1#$UNBOUND_PORT -e DNS2=no -e TZ=UTC \
      -e WEBPASSWORD="$(openssl rand -base64 32)" \
      --restart unless-stopped pihole/pihole:latest || {
      log_error "Pi-hole container failed to start"; exit 1;
    }
    
    # Wait for Pi-hole to be ready
    local timeout=60
    local count=0
    while ! curl -s http://127.0.0.1/admin/ >/dev/null 2>&1 && [ $count -lt $timeout ]; do
      sleep 2
      ((count++))
    done
    
    if [ $count -eq $timeout ]; then
      log_warning "Pi-hole web interface took longer than expected to start"
    fi
    
    log_success "Pi-hole container is running"
    update_state PIHOLE_OK true
  else
    log "DRY RUN: Would create Pi-hole container with host networking"
    update_state PIHOLE_OK true
  fi
}

# =============================================
# NETALERTX SETUP
# =============================================
setup_netalertx() {
  [[ "$NETALERTX_OK" == true && "$FORCE" != true ]] && { log "✅ NetAlertX OK"; return; }

  if ! $DRY_RUN; then
    ensure_docker_service
    
    # Remove existing NetAlertX container if it exists
    sudo docker rm -f netalertx 2>/dev/null || true
    
    # Create data directories
    sudo mkdir -p /opt/netalertx/{config,db}
    sudo chmod 755 /opt/netalertx /opt/netalertx/config /opt/netalertx/db
    
    log "Creating NetAlertX container..."
    sudo docker run -d --name netalertx -p $NETALERTX_PORT:20211 \
      -v /opt/netalertx/config:/app/config -v /opt/netalertx/db:/app/db \
      -e TZ=UTC --restart unless-stopped jokobsk/netalertx:latest || {
      log_error "NetAlertX container failed to start"; exit 1;
    }
    
    # Wait for NetAlertX to be ready
    local timeout=30
    local count=0
    while ! curl -s http://127.0.0.1:$NETALERTX_PORT >/dev/null 2>&1 && [ $count -lt $timeout ]; do
      sleep 2
      ((count++))
    done
    
    if [ $count -eq $timeout ]; then
      log_warning "NetAlertX web interface took longer than expected to start"
    fi
    
    log_success "NetAlertX container is running"
    update_state NETALERTX_OK true
  else
    log "DRY RUN: Would create NetAlertX container on port $NETALERTX_PORT"
    update_state NETALERTX_OK true
  fi
}

# =============================================
# PYTHON SUITE SETUP
# =============================================
setup_python_suite() {
  [[ "$PY_SUITE_OK" == true && "$FORCE" != true ]] && { log "✅ Python Suite OK"; return; }

  if ! $DRY_RUN; then
    local suite_user="pihole-suite"
    local suite_group="pihole-suite"
    local suite_state_dir="/var/lib/pihole-suite"
    local suite_entrypoint="$SCRIPT_DIR/start_suite.py"

    mkdir -p "$SCRIPT_DIR/data"
    if [[ ! -f "$ENV_FILE" ]] || ! grep -q '^SUITE_API_KEY=' "$ENV_FILE"; then
      echo "SUITE_API_KEY=$(openssl rand -hex 16)" > "$ENV_FILE"
    fi
    grep -q '^SUITE_PORT=' "$ENV_FILE" 2>/dev/null || echo "SUITE_PORT=$PYTHON_SUITE_PORT" >> "$ENV_FILE"
    grep -q '^SUITE_DATA_DIR=' "$ENV_FILE" 2>/dev/null || echo "SUITE_DATA_DIR=$SCRIPT_DIR/data" >> "$ENV_FILE"
    grep -q '^SUITE_LOG_LEVEL=' "$ENV_FILE" 2>/dev/null || echo "SUITE_LOG_LEVEL=INFO" >> "$ENV_FILE"

    if ! getent group "$suite_group" >/dev/null 2>&1; then
      sudo groupadd --system "$suite_group"
    fi
    if ! id -u "$suite_user" >/dev/null 2>&1; then
      sudo useradd --system --no-create-home --shell /usr/sbin/nologin --gid "$suite_group" "$suite_user"
    fi
    sudo mkdir -p "$suite_state_dir"

    [[ ! -d "$SCRIPT_DIR/venv" ]] && python3 -m venv "$SCRIPT_DIR/venv"
    "$SCRIPT_DIR/venv/bin/pip" install -r "$SCRIPT_DIR/requirements.txt" || {
      log_error "Python requirements failed"; exit 1;
    }
    sudo chown -R "$suite_user":"$suite_group" "$suite_data_dir" "$SCRIPT_DIR/venv" "$suite_state_dir" 2>/dev/null || true
    sudo chown root:"$suite_group" "$ENV_FILE"
    sudo chmod 640 "$ENV_FILE"
    [[ -f "$suite_entrypoint" ]] || log_warning "Python Suite entrypoint missing at $suite_entrypoint (service may need code before start)"

    if [[ "$CONTAINER_MODE" == false ]]; then
      cat > /tmp/pihole-suite.service <<EOF
[Unit]
Description=Python Suite Service
After=network.target
[Service]
User=$suite_user
Group=$suite_group
WorkingDirectory=$SCRIPT_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$SCRIPT_DIR/venv/bin/python $suite_entrypoint
Restart=always
RestartSec=3
UMask=027
RuntimeDirectory=pihole-suite
StateDirectory=pihole-suite
LogsDirectory=pihole-suite
CacheDirectory=pihole-suite
ReadWritePaths=$SCRIPT_DIR $suite_state_dir
PrivateTmp=true
PrivateDevices=true
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
LockPersonality=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=true
RestrictSUIDSGID=true
MemoryDenyWriteExecute=true
SystemCallFilter=@system-service
CapabilityBoundingSet=
[Install]
WantedBy=multi-user.target
EOF
      sudo mv /tmp/pihole-suite.service /etc/systemd/system/
      sudo systemctl daemon-reload
      sudo systemctl enable --now pihole-suite.service
    fi
    log_success "Python Suite OK"
    update_state PY_SUITE_OK true
  else
    log "DRY RUN: Would set up Python Suite"
    update_state PY_SUITE_OK true
  fi
}

# =============================================
# HEALTH CHECKS
# =============================================
run_healthchecks() {
  [[ "$HEALTH_OK" == true && "$FORCE" != true ]] && { log "✅ Health OK"; return; }

  local all_healthy=true

  # Unbound
  if ! dig +short @127.0.0.1 -p $UNBOUND_PORT example.com | grep -qE '^[0-9.]+$'; then
    log_error "Unbound failed"
    all_healthy=false
  fi

  # Pi-hole
  if [[ "$CONTAINER_MODE" == true ]]; then
    sudo docker ps | grep -q pihole || { log_error "Pi-hole container missing"; all_healthy=false; }
  else
    for i in {1..10}; do
      systemctl is-active --quiet pihole-FTL 2>/dev/null && break
      sleep 1
    done
    systemctl is-active --quiet pihole-FTL 2>/dev/null || { log_error "Pi-hole service missing"; all_healthy=false; }
  fi

  # NetAlertX (only if installed)
  if [[ "$INSTALL_NETALERTX" == true ]]; then
    sudo docker ps | grep -q netalertx || { log_error "NetAlertX missing"; all_healthy=false; }
  fi

  # Python Suite (Host Mode, only if installed)
  if [[ "$CONTAINER_MODE" == false && "$INSTALL_PYTHON_SUITE" == true ]]; then
    systemctl is-active --quiet pihole-suite 2>/dev/null || { log_error "Python Suite missing"; all_healthy=false; }
  fi

  if [[ "$all_healthy" == true ]]; then
    log_success "All health checks passed"
    update_state HEALTH_OK true
  else
    log_error "Some health checks failed"
    exit 1
  fi
}

# =============================================
# MAIN
# =============================================
main() {
  parse_args "$@"
  init_runtime_paths
  init_state
  validate_state_against_system
  check_dependencies
  handle_systemd_resolved
  check_ports
  install_packages
  configure_unbound
  setup_pihole
  
  # NetAlertX Setup (conditional)
  if [[ "$INSTALL_NETALERTX" == true ]]; then
    setup_netalertx
  else
    log "⏭️  Skipping NetAlertX installation (--skip-netalertx)"
    update_state NETALERTX_OK true
  fi
  
  # Python Suite Setup (conditional)
  if [[ "$INSTALL_PYTHON_SUITE" == true ]]; then
    setup_python_suite
  else
    log "⏭️  Skipping Python API Suite installation (--skip-python-api)"
    update_state PY_SUITE_OK true
  fi
  
  run_healthchecks

  log_success "🎉 Installation complete!"
  echo ""
  echo "┌─────────────────────────────────────────────────────────────────┐"
  echo "│                    🚀 INSTALLATION COMPLETE 🚀                   │"
  echo "├─────────────────────────────────────────────────────────────────┤"
  echo "│ Services Status:                                                │"
  
  # Get IP address safely
  local host_ip
  host_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '127.0.0.1')"
  
  echo "│  • Unbound DNS:     http://127.0.0.1:$UNBOUND_PORT                         │"
  if [[ "$CONTAINER_MODE" == true ]]; then
    echo "│  • Pi-hole Admin:   http://${host_ip}:$CONTAINER_PIHOLE_WEB_PORT           │"
  else
    echo "│  • Pi-hole Admin:   http://${host_ip}                                      │"
  fi
  
  if [[ "$INSTALL_NETALERTX" == true ]]; then
    echo "│  • NetAlertX:       http://${host_ip}:$NETALERTX_PORT              │"
  else
    echo "│  • NetAlertX:       [SKIPPED]                                      │"
  fi
  
  if [[ "$INSTALL_PYTHON_SUITE" == true ]]; then
    echo "│  • Python Suite:   http://127.0.0.1:$PYTHON_SUITE_PORT                      │"
  else
    echo "│  • Python Suite:   [SKIPPED]                                       │"
  fi
  
  echo "├─────────────────────────────────────────────────────────────────┤"
  echo "│ Configuration:                                                  │"
  
  # Get API key safely
  local api_key_preview="<not_set>"
  if [[ -f "$ENV_FILE" && "$INSTALL_PYTHON_SUITE" == true ]]; then
    api_key_preview="$(grep SUITE_API_KEY "$ENV_FILE" 2>/dev/null | cut -d= -f2 | head -c20 || echo '<not_set>')"
  fi
  
  if [[ "$INSTALL_PYTHON_SUITE" == true ]]; then
    echo "│  • API Key: ${api_key_preview}...     │"
  fi
  
  if [[ "$CONTAINER_MODE" == true ]]; then
    echo "│  • Mode: Container Mode                                         │"
  else
    echo "│  • Mode: Host Mode                                              │"
  fi
  echo "│  • DNS: 127.0.0.1 (Pi-hole → Unbound → DoT)                    │"
  echo "└─────────────────────────────────────────────────────────────────┘"
  echo ""
  echo "Next steps:"
  echo "  1. Configure your router to use ${host_ip} as DNS"
  echo "  2. Test with: dig @${host_ip} google.com"
  echo "  3. Monitor with: ./check.sh"
}

main "$@"
