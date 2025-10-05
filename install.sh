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
FALLBACK_RESOLVERS=("1.1.1.1" "9.9.9.9")

# Defaults (NOT readonly)
CONTAINER_MODE=false
DRY_RUN=false
FORCE=false
RESUME=false
AUTO_REMOVE_CONFLICTS=false

# Ports
UNBOUND_PORT=5335
PIHOLE_DNS_PORT=53
PIHOLE_WEB_PORT=80
NETALERTX_PORT=20211
PYTHON_SUITE_PORT=8090
CONTAINER_PIHOLE_DNS_PORT=8053
CONTAINER_PIHOLE_WEB_PORT=8080

# =============================================
# LOGGING
# =============================================
log() { 
  local msg="[\033[34m$(date +"%H:%M:%S")\033[0m] $*"
  echo -e "$msg"
  if [[ -w "$(dirname "$LOG_FILE")" ]]; then
    echo -e "$msg" >> "$LOG_FILE" 2>/dev/null || true
  fi
}
log_success() { 
  local msg="[\033[34m$(date +"%H:%M:%S")\033[0m] \033[32m✓\033[0m $*"
  echo -e "$msg"
  if [[ -w "$(dirname "$LOG_FILE")" ]]; then
    echo -e "$msg" >> "$LOG_FILE" 2>/dev/null || true
  fi
}
log_error() { 
  local msg="[\033[34m$(date +"%H:%M:%S")\033[0m] \033[31m✗\033[0m $*"
  echo -e "$msg"
  if [[ -w "$(dirname "$LOG_FILE")" ]]; then
    echo -e "$msg" >> "$LOG_FILE" 2>/dev/null || true
    echo -e "$msg" >> "$ERROR_LOG" 2>/dev/null || true
  fi
}
log_warning() { 
  local msg="[\033[34m$(date +"%H:%M:%S")\033[0m] \033[33m!\033[0m $*"
  echo -e "$msg"
  if [[ -w "$(dirname "$LOG_FILE")" ]]; then
    echo -e "$msg" >> "$LOG_FILE" 2>/dev/null || true
  fi
}

# =============================================
# STATE MANAGEMENT
# =============================================
init_state() {
  mkdir -p "${SCRIPT_DIR}/data"
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
  source "$STATE_FILE"
}

update_state() { sed -i "s/^$1=.*/$1=$2/" "$STATE_FILE"; source "$STATE_FILE"; }

# =============================================
# ARGUMENT PARSING
# =============================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --container-mode) CONTAINER_MODE=true ;;
      --dry-run) DRY_RUN=true ;;
      --force) FORCE=true ;;
      --resume) RESUME=true ;;
      --auto-remove-conflicts) AUTO_REMOVE_CONFLICTS=true ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
    shift
  done
}

# =============================================
# SYSTEM CHECKS
# =============================================
check_dependencies() {
  local missing=()
  for cmd in curl openssl; do
    command -v "$cmd" >/dev/null || missing+=("$cmd")
  done
  
  # Only check for sudo if not running in dry-run mode
  if [[ "$DRY_RUN" != true ]]; then
    command -v sudo >/dev/null || missing+=("sudo")
  fi
  
  if [[ ${#missing[@]} -gt 0 ]]; then 
    log_error "Missing: ${missing[*]}"
    exit 1
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
  
  local ports=($UNBOUND_PORT $NETALERTX_PORT $PYTHON_SUITE_PORT 53)
  [[ "$CONTAINER_MODE" == true ]] && ports+=($CONTAINER_PIHOLE_DNS_PORT $CONTAINER_PIHOLE_WEB_PORT)

  for port in "${ports[@]}"; do
    if command -v ss &>/dev/null && ss -tuln | grep -q ":$port "; then
      log_error "Port $port in use"
      return 1
    elif command -v netstat &>/dev/null && netstat -tuln | grep -q ":$port "; then
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

  for attempt in {1..3}; do
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
    sudo mkdir -p /var/lib/unbound
    
    # Download root hints for DNS resolution
    sudo curl -fsSL https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints || {
      log_error "Failed to download root.hints"; exit 1;
    }
    
    # Update DNSSEC trust anchor
    if command -v unbound-anchor >/dev/null 2>&1; then
      sudo unbound-anchor -a /var/lib/unbound/root.key || {
        log_warning "unbound-anchor failed, but continuing..."
      }
    else
      log_warning "unbound-anchor command not found, using alternative method..."
      # Create a minimal root.key if unbound-anchor is not available
      if [[ ! -f /var/lib/unbound/root.key ]]; then
        sudo curl -fsSL https://data.iana.org/root-anchors/icannbundle.pem -o /tmp/icannbundle.pem || {
          log_warning "Failed to download DNSSEC trust anchor, using built-in defaults"
          sudo touch /var/lib/unbound/root.key
        }
        [[ -f /tmp/icannbundle.pem ]] && sudo mv /tmp/icannbundle.pem /var/lib/unbound/root.key
      fi
    fi
    
    # Verify TLS certificate bundle exists
    if [[ ! -f /etc/ssl/certs/ca-certificates.crt ]]; then
      log_error "TLS certificate bundle missing at /etc/ssl/certs/ca-certificates.crt"
      exit 1
    fi

    # Create Unbound configuration directory if missing
    sudo mkdir -p /etc/unbound/unbound.conf.d

    # Create comprehensive Unbound configuration
    sudo bash -c 'cat > /etc/unbound/unbound.conf.d/forward.conf' <<EOF
server:
    # Network interface and port
    interface: 127.0.0.1
    port: $UNBOUND_PORT
    
    # TLS configuration for DNS-over-TLS
    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt
    
    # DNSSEC validation
    trust-anchor-file: /var/lib/unbound/root.key
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
      curl -sSL https://install.pi-hole.net | sudo PIHOLE_SKIP_OS_CHECK=true \
        PIHOLE_INSTALL_AUTO=true DNS1=127.0.0.1#$UNBOUND_PORT DNS2=no bash || {
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
      sudo pihole restartdns
    else
      log_warning "Pi-hole setupVars.conf not found, DNS configuration may need manual setup"
    fi
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
    mkdir -p "$SCRIPT_DIR/data"
    if [[ ! -f "$ENV_FILE" ]] || ! grep -q '^SUITE_API_KEY=' "$ENV_FILE"; then
      echo "SUITE_API_KEY=$(openssl rand -hex 16)" > "$ENV_FILE"
      echo "SUITE_PORT=$PYTHON_SUITE_PORT" >> "$ENV_FILE"
    fi

    [[ ! -d "$SCRIPT_DIR/venv" ]] && python3 -m venv "$SCRIPT_DIR/venv"
    "$SCRIPT_DIR/venv/bin/pip" install -r "$SCRIPT_DIR/requirements.txt" || {
      log_error "Python requirements failed"; exit 1;
    }

    if [[ "$CONTAINER_MODE" == false ]]; then
      cat > /tmp/pihole-suite.service <<EOF
[Unit]
Description=Python Suite Service
After=network.target
[Service]
User=root
WorkingDirectory=$SCRIPT_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$SCRIPT_DIR/venv/bin/python $SCRIPT_DIR/start_suite.py
Restart=always
PrivateTmp=true
ProtectSystem=full
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

  # NetAlertX
  sudo docker ps | grep -q netalertx || { log_error "NetAlertX missing"; all_healthy=false; }

  # Python Suite (Host Mode)
  [[ "$CONTAINER_MODE" == false ]] && {
    systemctl is-active --quiet pihole-suite 2>/dev/null || { log_error "Python Suite missing"; all_healthy=false; }
  }

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
  init_state
  check_dependencies
  handle_systemd_resolved
  check_ports
  install_packages
  configure_unbound
  setup_pihole
  setup_netalertx
  setup_python_suite
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
  echo "│  • NetAlertX:       http://${host_ip}:$NETALERTX_PORT              │"
  echo "│  • Python Suite:   http://127.0.0.1:$PYTHON_SUITE_PORT                      │"
  echo "├─────────────────────────────────────────────────────────────────┤"
  echo "│ Configuration:                                                  │"
  
  # Get API key safely
  local api_key_preview="<not_set>"
  if [[ -f "$ENV_FILE" ]]; then
    api_key_preview="$(grep SUITE_API_KEY "$ENV_FILE" 2>/dev/null | cut -d= -f2 | head -c20 || echo '<not_set>')"
  fi
  
  echo "│  • API Key: ${api_key_preview}...     │"
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
