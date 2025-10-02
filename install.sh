#!/bin/bash
set -euo pipefail

# Pi-hole + Unbound + NetAlertX + Python Suite One-Click Installer
# ================================================================
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
    
    # Security settings
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-below-nxdomain: yes
    harden-referral-path: yes
    use-caps-for-id: no
    
    # Cache settings
    cache-min-ttl: 60
    cache-max-ttl: 86400
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
    
    # Create data directory with proper ownership
    mkdir -p "$PROJECT_DIR/data"
    chown -R "$INSTALL_USER:$INSTALL_USER" "$PROJECT_DIR/data"
    
    # Enable and start the service
    systemctl daemon-reload
    systemctl enable pihole-suite.service
    systemctl start pihole-suite.service
    
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
    echo "=============================================="
    echo "        Installation Complete!"
    echo "=============================================="
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
    echo "======================================================"
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
    
    log_info "Running health checks..."
    run_health_checks
    
    show_summary
    
    log_success "Installation completed successfully!"
    echo "You can now configure your devices to use $(hostname -I | awk '{print $1}') as their DNS server."
}

# Run main function
main "$@"