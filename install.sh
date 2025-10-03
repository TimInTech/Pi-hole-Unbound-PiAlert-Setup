#!/bin/bash
set -euo pipefail

# Pi-hole + Unbound + NetAlertX + Python Suite One-Click Installer
# Modern, idempotent installer for complete DNS security stack
# 
# Author: TimInTech
# License: MIT
# Repository: https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup

# 🔧 Configuration
readonly UNBOUND_PORT=5335
readonly NETALERTX_PORT=20211
readonly PYTHON_SUITE_PORT=8090
readonly NETALERTX_IMAGE="techxartisan/netalertx:latest"

# 🎨 Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# 📝 Logging functions
log() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[⚠]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
step() { echo -e "\n${PURPLE}[STEP]${NC} $*"; }

# 🛡️ Error handler
cleanup() {
    if [[ $? -ne 0 ]]; then
        error "Installation failed! Check logs above."
        error "You can re-run this script to retry installation."
    fi
}
trap cleanup EXIT

# 🔍 System checks
check_system() {
    step "Performing system checks"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Check for Debian/Ubuntu
    if ! command -v apt-get >/dev/null 2>&1; then
        error "This installer requires Debian/Ubuntu (apt-get not found)"
        exit 1
    fi
    
    # Detect OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log "Detected: $PRETTY_NAME"
    fi
    
    # Check project directory
    if [[ ! -f requirements.txt ]]; then
        error "requirements.txt not found. Please run from project directory"
        exit 1
    fi
    
    # Check internet connectivity
    if ! curl -s --connect-timeout 5 google.com >/dev/null; then
        warn "Internet connectivity check failed - continuing anyway"
    else
        success "Internet connectivity confirmed"
    fi
    
    success "System checks passed"
}

# 🔌 Port conflict check
check_ports() {
    step "Checking port availability"
    
    local ports=($UNBOUND_PORT $NETALERTX_PORT $PYTHON_SUITE_PORT 53)
    local conflicts=()
    
    for port in "${ports[@]}"; do
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            conflicts+=($port)
        fi
    done
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        warn "Ports in use: ${conflicts[*]}"
        warn "Installation will continue but may require manual intervention"
    else
        success "All required ports available"
    fi
}

# 📦 Package installation
install_packages() {
    step "Installing system packages"
    
    log "Updating package lists..."
    apt-get update -qq
    
    log "Installing core packages..."
    apt-get install -y \
        unbound \
        unbound-anchor \
# This script installs and configures:
# - Unbound DNS resolver on 127.0.0.1:5335
# - Pi-hole using Unbound as upstream
# - NetAlertX as Docker container on port 20211
# - Python monitoring suite as systemd service

# Configuration
UNBOUND_PORT=5335
NETALERTX_PORT=20211
PYTHON_SUITE_PORT=8090
SUITE_API_KEY=${SUITE_API_KEY:-$(openssl rand -hex 16)}
INSTALL_USER=${SUDO_USER:-$(whoami)}
INSTALL_HOME=$(getent passwd "$INSTALL_USER" | cut -d: -f6)
PROJECT_DIR="$INSTALL_HOME/Pi-hole-Unbound-PiAlert-Setup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# System checks
check_system() {
    log_info "Performing system checks..."
    
    # Check if this is Debian/Ubuntu
    if ! command -v apt-get &> /dev/null; then
        log_error "This script requires a Debian/Ubuntu system with apt-get"
        exit 1
    fi
    
    # Check system version
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log_info "Detected system: $NAME $VERSION"
    fi
    
    # Check if we're in the project directory
    if [[ ! -f "start_suite.py" || ! -f "requirements.txt" ]]; then
        log_error "This script must be run from the Pi-hole-Unbound-PiAlert-Setup directory"
        log_info "Please cd to the project directory and run: sudo ./install.sh"
        exit 1
    fi
    
    PROJECT_DIR=$(pwd)
    log_info "Project directory: $PROJECT_DIR"
}

# Check for port conflicts
check_ports() {
    log_info "Checking for port conflicts..."
    
    local ports_to_check=("$UNBOUND_PORT" "$NETALERTX_PORT" "$PYTHON_SUITE_PORT")
    local conflicts=false
    
    for port in "${ports_to_check[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            log_warning "Port $port is already in use"
            conflicts=true
        fi
    done
    
    if [[ "$conflicts" == true ]]; then
        log_warning "Some ports are in use. The installer will attempt to work around this."
        log_info "You may need to stop conflicting services manually if issues arise."
    fi
}

# Install system packages
install_packages() {
    log_info "Installing system packages..."
    
    # Update package lists
    apt-get update
    
    # Install required packages
    apt-get install -y \
        unbound \
        ca-certificates \
        curl \
        dnsutils \
        python3 \
        python3-venv \
        python3-pip \
        git \
        docker.io \
        openssl \
        systemd \
        sqlite3
    
    success "System packages installed"
}

# 🔐 Unbound configuration
configure_unbound() {
    step "Configuring Unbound DNS resolver"
    
    # Create unbound directory
    install -d -m 0755 /var/lib/unbound
    
    # Download root hints
    log "Downloading DNS root hints..."
    curl -fsSL https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints
    
    # Create Pi-hole configuration
    log "Creating Unbound configuration..."
        systemctl
    
    log_success "System packages installed"
}

# Configure Unbound
configure_unbound() {
    log_info "Configuring Unbound DNS resolver..."
    
    # Create unbound directory if it doesn't exist
    install -d -m 0755 /var/lib/unbound
    
    # Download root hints
    if [[ ! -f /var/lib/unbound/root.hints ]] || [[ $(find /var/lib/unbound/root.hints -mtime +30 2>/dev/null) ]]; then
        log_info "Downloading DNS root hints..."
        curl -fsSL https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints
    fi
    
    # Create Pi-hole specific Unbound configuration
    cat > /etc/unbound/unbound.conf.d/pi-hole.conf << 'EOF'
server:
    # Basic settings
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    
    # Performance tuning
    edns-buffer-size: 1232
    prefetch: yes
    prefetch-key: yes
    # Performance settings
    edns-buffer-size: 1232
    prefetch: yes
    num-threads: 2
    so-rcvbuf: 1m
    so-sndbuf: 1m
    
    # Privacy settings
    qname-minimisation: yes
    hide-identity: yes
    hide-version: yes
    
    # Security hardening
    # Security settings
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-below-nxdomain: yes
    harden-referral-path: yes
    use-caps-for-id: no
    
    # Cache settings
    cache-min-ttl: 60
    cache-max-ttl: 86400
    msg-cache-size: 50m
    rrset-cache-size: 100m
    prefetch-key: yes
    
    # DNSSEC
    trust-anchor-file: /var/lib/unbound/root.key
    root-hints: /var/lib/unbound/root.hints
    
    # Access control
    access-control: 0.0.0.0/0 refuse
    access-control: 127.0.0.0/8 allow
    access-control: 10.0.0.0/8 allow
    access-control: 172.16.0.0/12 allow
    access-control: 192.168.0.0/16 allow

forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 9.9.9.9@853#dns.quad9.net
    forward-addr: 149.112.112.112@853#dns.quad9.net
EOF
    
    # Initialize DNSSEC trust anchor
    log "Initializing DNSSEC trust anchor..."
    unbound-anchor -a /var/lib/unbound/root.key || true
    
    # Start Unbound
    systemctl enable --now unbound
    # Use Quad9 as fallback
    forward-addr: 9.9.9.9@853#dns.quad9.net
    forward-addr: 149.112.112.112@853#dns.quad9.net
    forward-tls-upstream: yes
EOF
    
    # Initialize trust anchor if it doesn't exist
    if [[ ! -f /var/lib/unbound/root.key ]]; then
        log_info "Initializing DNSSEC trust anchor..."
        unbound-anchor -a /var/lib/unbound/root.key || true
    fi
    
    # Start and enable Unbound
    systemctl enable unbound
    systemctl restart unbound
    
    # Wait for Unbound to start
    sleep 3
    
    # Test Unbound
    if dig +short @127.0.0.1 -p $UNBOUND_PORT example.com | grep -q "93.184."; then
        success "Unbound is responding correctly"
    else
        warn "Unbound test failed - continuing anyway"
    fi
}

# 🕳️ Pi-hole installation
install_pihole() {
    step "Installing Pi-hole"
    
    if command -v pihole >/dev/null 2>&1; then
        log "Pi-hole already installed"
    else
        log "Downloading Pi-hole installer..."
        # Create minimal setupVars for unattended install
        mkdir -p /etc/pihole
        cat > /etc/pihole/setupVars.conf << EOF
PIHOLE_INTERFACE=eth0
IPV4_ADDRESS=127.0.0.1/8
IPV6_ADDRESS=
PIHOLE_DNS_1=127.0.0.1#$UNBOUND_PORT
PIHOLE_DNS_2=
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
CACHE_SIZE=10000
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSMASQ_LISTENING=local
WEBPASSWORD=
BLOCKING_ENABLED=true
EOF
        
        # Run Pi-hole installer
        curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended
    fi
    
    # Ensure Pi-hole uses Unbound
    log "Configuring Pi-hole upstream DNS..."
        log_success "Unbound is working correctly"
    else
        log_warning "Unbound test failed, but continuing..."
    fi
}

# Install Pi-hole
install_pihole() {
    log_info "Installing Pi-hole..."
    
    # Check if Pi-hole is already installed
    if command -v pihole &> /dev/null; then
        log_info "Pi-hole is already installed, configuring..."
    else
        log_info "Downloading and installing Pi-hole..."
        # Use Pi-hole's official installer
        curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended
    fi
    
    # Configure Pi-hole to use Unbound
    log_info "Configuring Pi-hole to use Unbound..."
    
    # Set upstream DNS to Unbound
    if [[ -f /etc/pihole/setupVars.conf ]]; then
        sed -i "s/^PIHOLE_DNS_1=.*/PIHOLE_DNS_1=127.0.0.1#$UNBOUND_PORT/" /etc/pihole/setupVars.conf
        sed -i "s/^PIHOLE_DNS_2=.*/PIHOLE_DNS_2=/" /etc/pihole/setupVars.conf
    fi
    
    # Restart Pi-hole
    pihole restartdns
    
    success "Pi-hole configured with Unbound upstream"
}

# 🐳 NetAlertX installation
install_netalertx() {
    step "Installing NetAlertX"
    
    # Start Docker
    systemctl enable docker
    systemctl start docker
    
    # Create data directories
    mkdir -p /opt/netalertx/{config,db}
    
    # Stop existing container
    docker stop netalertx 2>/dev/null || true
    docker rm netalertx 2>/dev/null || true
    
    # Run NetAlertX
    log "Starting NetAlertX container..."
    # Restart Pi-hole DNS
    pihole restartdns
    
    log_success "Pi-hole configured to use Unbound"
}

# Install NetAlertX
install_netalertx() {
    log_info "Installing NetAlertX..."
    
    # Start Docker service
    systemctl enable docker
    systemctl start docker
    
    # Create NetAlertX data directory
    mkdir -p /opt/netalertx/{config,db}
    chown -R "$INSTALL_USER:$INSTALL_USER" /opt/netalertx
    
    # Stop any existing NetAlertX container
    docker stop netalertx 2>/dev/null || true
    docker rm netalertx 2>/dev/null || true
    
    # Run NetAlertX container
    docker run -d \
        --name netalertx \
        --restart unless-stopped \
        -p $NETALERTX_PORT:20211 \
        -v /opt/netalertx/config:/app/config \
        -v /opt/netalertx/db:/app/db \
        -e TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC") \
        $NETALERTX_IMAGE
    
    success "NetAlertX installed on port $NETALERTX_PORT"
}

# 🐍 Python suite setup
setup_python_suite() {
    step "Setting up Python monitoring suite"
    
    local project_dir=$(pwd)
    local install_user=${SUDO_USER:-$(logname 2>/dev/null || echo "root")}
    
    # Create virtual environment
    if [[ ! -d .venv ]]; then
        log "Creating Python virtual environment..."
        python3 -m venv .venv
        chown -R $install_user:$install_user .venv 2>/dev/null || true
    fi
    
    # Install dependencies
    log "Installing Python dependencies..."
    .venv/bin/pip install -U pip
    .venv/bin/pip install -r requirements.txt
    
    # Generate API key
    local api_key=$(openssl rand -hex 16)
    
    # Create environment file
    cat > .env << EOF
# Pi-hole Suite Configuration
SUITE_API_KEY=$api_key
SUITE_DATA_DIR=$project_dir/data
SUITE_LOG_LEVEL=INFO
EOF
    
    # Create data directory
    mkdir -p data
    chown -R $install_user:$install_user . 2>/dev/null || true
    
    # Create systemd service
    log "Creating systemd service..."
    cat > /etc/systemd/system/pihole-suite.service << EOF
[Unit]
Description=Pi-hole Suite (API + monitoring)
        -e TZ=$(timedatectl show --property=Timezone --value) \
        jokobsk/netalertx:latest
    
    log_success "NetAlertX installed and running on port $NETALERTX_PORT"
}

# Setup Python suite
setup_python_suite() {
    log_info "Setting up Python monitoring suite..."
    
    # Ensure we're in the project directory
    cd "$PROJECT_DIR"
    
    # Create virtual environment
    if [[ ! -d .venv ]]; then
        sudo -u "$INSTALL_USER" python3 -m venv .venv
    fi
    
    # Install Python dependencies
    sudo -u "$INSTALL_USER" .venv/bin/pip install -U pip
    sudo -u "$INSTALL_USER" .venv/bin/pip install -r requirements.txt
    
    # Initialize database
    sudo -u "$INSTALL_USER" .venv/bin/python scripts/bootstrap.py 2>/dev/null || true
    
    # Create systemd service
    cat > /etc/systemd/system/pihole-suite.service << EOF
[Unit]
Description=Pi-hole Suite (API + workers)
After=network.target pihole-FTL.service
Wants=pihole-FTL.service

[Service]
Type=simple
User=$install_user
Group=$install_user
WorkingDirectory=$project_dir
EnvironmentFile=$project_dir/.env
ExecStart=$project_dir/.venv/bin/python start_suite.py
Restart=always
RestartSec=3

# Security hardening
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=read-only
ReadWritePaths=$project_dir/data
User=$INSTALL_USER
Group=$INSTALL_USER
WorkingDirectory=$PROJECT_DIR
Environment=SUITE_API_KEY=$SUITE_API_KEY
Environment=SUITE_DATA_DIR=$PROJECT_DIR/data
Environment=SUITE_LOG_LEVEL=INFO
ExecStart=$PROJECT_DIR/.venv/bin/python start_suite.py
Restart=always
RestartSec=10

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$PROJECT_DIR/data
PrivateTmp=yes
PrivateDevices=yes
ProtectHostname=yes
ProtectClock=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
RemoveIPC=yes
MemoryDenyWriteExecute=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    # Create data directory with proper ownership
    mkdir -p "$PROJECT_DIR/data"
    chown -R "$INSTALL_USER:$INSTALL_USER" "$PROJECT_DIR/data"
    
    # Enable and start the service
    systemctl daemon-reload
    systemctl enable pihole-suite.service
    systemctl start pihole-suite.service
    
    success "Python suite installed and started"
    log "API Key: $api_key"
}

# 🩺 Health checks
run_health_checks() {
    step "Running health checks"
    
    local failed=0
    
    # Test Unbound
    echo -n "Testing Unbound... "
    if dig +short @127.0.0.1 -p $UNBOUND_PORT example.com | grep -q "."; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        ((failed++))
    fi
    
    # Test Pi-hole
    echo -n "Testing Pi-hole... "
    if systemctl is-active --quiet pihole-FTL; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        ((failed++))
    fi
    
    # Test NetAlertX
    echo -n "Testing NetAlertX... "
    if docker ps | grep -q netalertx; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        ((failed++))
    fi
    
    # Test Python suite
    echo -n "Testing Python suite... "
    sleep 3  # Give service time to start
    if systemctl is-active --quiet pihole-suite; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        ((failed++))
    fi
    
    if [[ $failed -eq 0 ]]; then
        success "All health checks passed!"
    else
        warn "$failed health check(s) failed - manual investigation needed"
    fi
}

# 📊 Installation summary
show_summary() {
    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${GREEN}Installation Complete!${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "🔧 ${BLUE}Services installed:${NC}"
    echo -e "   • ${GREEN}Unbound${NC} DNS resolver: 127.0.0.1:$UNBOUND_PORT"
    echo -e "   • ${GREEN}Pi-hole${NC} web interface: http://$(hostname -I | awk '{print $1}')/admin"
    echo -e "   • ${GREEN}NetAlertX${NC} dashboard: http://$(hostname -I | awk '{print $1}'):$NETALERTX_PORT"
    echo -e "   • ${GREEN}Python Suite${NC} API: http://127.0.0.1:$PYTHON_SUITE_PORT"
    echo
    echo -e "🔑 ${BLUE}Configuration:${NC}"
    echo -e "   • API Key: $(grep SUITE_API_KEY .env 2>/dev/null | cut -d= -f2 || echo 'Check .env file')"
    echo -e "   • Config file: $(pwd)/.env"
    echo
    echo -e "🛠️  ${BLUE}Service management:${NC}"
    echo -e "   • systemctl status pihole-suite"
    echo -e "   • journalctl -u pihole-suite -f"
    echo -e "   • docker logs netalertx"
    echo
    echo -e "📝 ${BLUE}Next steps:${NC}"
    echo -e "   1. Configure devices to use $(hostname -I | awk '{print $1}') as DNS"
    echo -e "   2. Access Pi-hole admin to review settings"
    echo -e "   3. Check NetAlertX for network monitoring"
    echo -e "   4. Test API: curl -H \"X-API-Key: \$SUITE_API_KEY\" http://127.0.0.1:$PYTHON_SUITE_PORT/health"
    echo
}

# 🚀 Main installation
main() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        Pi-hole + Unbound + NetAlertX                         ║"
    echo "║                              One-Click Installer                             ║"
    echo "║                                                                               ║"
    echo "║  🛡️  DNS Security  •  📊 Network Monitoring  •  🔧 Python Suite             ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_system
    check_ports
    log_success "Python suite installed and running"
}

# Health checks
run_health_checks() {
    log_info "Running health checks..."
    
    local all_healthy=true
    
    # Test Unbound
    log_info "Testing Unbound..."
    if dig +short @127.0.0.1 -p $UNBOUND_PORT example.com | grep -q "."; then
        log_success "✓ Unbound is responding"
    else
        log_error "✗ Unbound is not responding"
        all_healthy=false
    fi
    
    # Test Pi-hole
    log_info "Testing Pi-hole..."
    if pihole status | grep -q "Pi-hole blocking is enabled"; then
        log_success "✓ Pi-hole is running"
    else
        log_warning "⚠ Pi-hole status unclear"
    fi
    
    # Test NetAlertX
    log_info "Testing NetAlertX..."
    if curl -s -m 5 "http://127.0.0.1:$NETALERTX_PORT" >/dev/null 2>&1; then
        log_success "✓ NetAlertX is responding"
    else
        log_warning "⚠ NetAlertX not responding (may still be starting)"
    fi
    
    # Test Python suite
    log_info "Testing Python suite..."
    sleep 5  # Give the service time to start
    if curl -s -H "X-API-Key: $SUITE_API_KEY" "http://127.0.0.1:$PYTHON_SUITE_PORT/health" | grep -q '"ok":true'; then
        log_success "✓ Python suite API is responding"
    else
        log_warning "⚠ Python suite not responding (may still be starting)"
    fi
    
    if [[ "$all_healthy" == true ]]; then
        log_success "All components are healthy!"
    else
        log_warning "Some components may need manual attention"
    fi
}

# Display summary
show_summary() {
    echo
    echo "        Installation Complete!"
    echo
    echo "🔧 Components installed:"
    echo "  • Unbound DNS resolver: 127.0.0.1:$UNBOUND_PORT"
    echo "  • Pi-hole web interface: http://$(hostname -I | awk '{print $1}')/admin"
    echo "  • NetAlertX dashboard: http://$(hostname -I | awk '{print $1}'):$NETALERTX_PORT"
    echo "  • Python suite API: http://127.0.0.1:$PYTHON_SUITE_PORT"
    echo
    echo "🔑 API Configuration:"
    echo "  • API Key: $SUITE_API_KEY"
    echo "  • Test command: curl -H \"X-API-Key: $SUITE_API_KEY\" http://127.0.0.1:$PYTHON_SUITE_PORT/health"
    echo
    echo "📁 Important paths:"
    echo "  • Project directory: $PROJECT_DIR"
    echo "  • Data directory: $PROJECT_DIR/data"
    echo "  • Unbound config: /etc/unbound/unbound.conf.d/pi-hole.conf"
    echo "  • Pi-hole config: /etc/pihole/"
    echo "  • NetAlertX data: /opt/netalertx/"
    echo
    echo "🛠️  Service management:"
    echo "  • systemctl status pihole-suite"
    echo "  • systemctl status unbound"
    echo "  • docker logs netalertx"
    echo
    echo "📝 Next steps:"
    echo "  1. Access Pi-hole admin at http://$(hostname -I | awk '{print $1}')/admin"
    echo "  2. Verify DNS settings point to 127.0.0.1#$UNBOUND_PORT"
    echo "  3. Configure your devices to use this Pi-hole as DNS server"
    echo "  4. Check NetAlertX for network device monitoring"
    echo
    echo "⚠️  Save this API key: $SUITE_API_KEY"
    echo
}

# Main installation function
main() {
    echo "Pi-hole + Unbound + NetAlertX + Python Suite Installer"
    echo
    
    check_privileges
    check_system
    check_ports
    
    log_info "Starting installation..."
    
    install_packages
    configure_unbound
    install_pihole
    install_netalertx
    setup_python_suite
    run_health_checks
    show_summary
    
    success "Installation completed successfully! 🎉"
}

# Execute main function
    
    log_info "Running health checks..."
    run_health_checks
    
    show_summary
    
    log_success "Installation completed successfully!"
    echo "You can now configure your devices to use $(hostname -I | awk '{print $1}') as their DNS server."
}

# Run main function
main "$@"