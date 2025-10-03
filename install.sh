#!/bin/bash
set -euo pipefail

# Pi-hole + Unbound + NetAlertX + Python Suite One-Click Installer
# Author: TimInTech | License: MIT
# Repository: https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup

# 🔧 Configuration
readonly UNBOUND_PORT=5335
readonly NETALERTX_PORT=20211
readonly PYTHON_SUITE_PORT=8090
readonly NETALERTX_IMAGE="jokobsk/netalertx:latest"
readonly SUITE_API_KEY_ENV="${SUITE_API_KEY:-}"
readonly SUITE_LOG_LEVEL_ENV="${SUITE_LOG_LEVEL:-INFO}"
readonly INSTALL_USER=${SUDO_USER:-$(whoami)}
readonly PROJECT_DIR="$(pwd)"
readonly RESOLV_CONF="/etc/resolv.conf"
readonly RESOLV_CONF_BACKUP="/etc/resolv.conf.pi-hole-installer.bak"
readonly -a FALLBACK_RESOLVERS=("1.1.1.1" "9.9.9.9")

# 🎨 Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# 📝 Logging helpers
log()      { echo -e "${BLUE}[INFO]${NC} $*"; }
success()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()     { echo -e "${YELLOW}[⚠]${NC} $*"; }
error()    { echo -e "${RED}[✗]${NC} $*"; }
step()     { echo -e "\n${YELLOW}[STEP]${NC} $*"; }

# 🛡️ Error handler
trap 'error "Installation failed. See logs above."; exit 1' ERR

# ---------------------------------------------------------------------------
# 🧪 Helpers
write_resolv_conf() {
    local file="$1"; shift
    : >"$file"
    for resolver in "$@"; do
        printf 'nameserver %s\n' "$resolver" >>"$file"
    done
}

extract_env_value() {
    local key="$1" file="$2"
    if [[ -f "$file" ]]; then
        grep -E "^${key}=" "$file" | tail -n1 | cut -d= -f2-
    fi
}

# ---------------------------------------------------------------------------
# 🔍 System checks
check_system() {
    step "Performing system checks"
    [[ $EUID -eq 0 ]] || { error "Run as root or with sudo"; exit 1; }
    command -v apt-get >/dev/null || { error "Debian/Ubuntu required"; exit 1; }
    [[ -f requirements.txt ]] || { error "Run script in project directory"; exit 1; }
    success "System checks passed"
}

# 🧰 Ubuntu resolver handling (Port 53)
handle_systemd_resolved() {
    step "Checking systemd-resolved on Ubuntu (port 53)"
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [[ "${ID:-}" == ubuntu* || "${ID_LIKE:-}" == *ubuntu* ]]; then
            if systemctl list-unit-files | grep -q '^systemd-resolved\\.service'; then
                if systemctl is-active --quiet systemd-resolved; then
                    warn "systemd-resolved is active; stopping to free port 53"
                    systemctl stop systemd-resolved || true
                fi
                systemctl disable systemd-resolved || true
                if [[ -L $RESOLV_CONF ]]; then
                    warn "$RESOLV_CONF is a symlink; replacing with static resolver"
                    if [[ ! -e $RESOLV_CONF_BACKUP ]]; then
                        mv -f "$RESOLV_CONF" "$RESOLV_CONF_BACKUP"
                    else
                        rm -f "$RESOLV_CONF"
                    fi
                fi
                write_resolv_conf "$RESOLV_CONF" "${FALLBACK_RESOLVERS[@]}"
            fi
        fi
    fi
    success "Resolver prepared with external fallbacks"
}

finalize_resolver_configuration() {
    log "Pointing system resolver to Pi-hole"
    local resolvers=("127.0.0.1" "${FALLBACK_RESOLVERS[@]}")
    write_resolv_conf "$RESOLV_CONF" "${resolvers[@]}"
    success "System resolver now prefers Pi-hole on 127.0.0.1"
}

# 🔌 Port conflicts
check_ports() {
    step "Checking ports"
    local ports=($UNBOUND_PORT $NETALERTX_PORT $PYTHON_SUITE_PORT 53)
    if command -v ss >/dev/null; then
        for port in "${ports[@]}"; do
            if ss -tuln | grep -q ":$port "; then
                warn "Port $port already in use"
            fi
        done
    elif command -v netstat >/dev/null; then
        for port in "${ports[@]}"; do
            if netstat -tuln | grep -q ":$port "; then
                warn "Port $port already in use"
            fi
        done
    else
        warn "Neither ss nor netstat available; skipping port checks"
    fi
}

# 📦 Packages
install_packages() {
    step "Installing system packages"
    apt-get update -qq
    apt-get install -y unbound ca-certificates curl dnsutils \
        python3 python3-venv python3-pip git docker.io openssl systemd sqlite3 iproute2
    success "System packages installed"
}

# 🔐 Unbound config
configure_unbound() {
    step "Configuring Unbound"
    install -d -m 0755 /var/lib/unbound
    curl -fsSL https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints

    cat > /etc/unbound/unbound.conf.d/pi-hole.conf <<'UNBOUND_EOF'
server:
    interface: 127.0.0.1
    port: $UNBOUND_PORT
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    prefetch: yes
    qname-minimisation: yes
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    cache-min-ttl: 60
    cache-max-ttl: 86400
    trust-anchor-file: /var/lib/unbound/root.key
    root-hints: /var/lib/unbound/root.hints
    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt

forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 9.9.9.9@853#dns.quad9.net
    forward-addr: 149.112.112.112@853#dns.quad9.net
# NOTE: This is DoT forwarding to Quad9 (not full recursion to the root); intended.
UNBOUND_EOF

    unbound-anchor -a /var/lib/unbound/root.key || true
    systemctl enable --now unbound
    sleep 2
    dig +short @127.0.0.1 -p $UNBOUND_PORT example.com >/dev/null \
        && success "Unbound OK" || warn "Unbound may not be working"
}

# 🕳️ Pi-hole
install_pihole() {
    step "Installing Pi-hole"
    if ! command -v pihole >/dev/null; then
        curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended
    fi

    sed -i "s/^PIHOLE_DNS_1=.*/PIHOLE_DNS_1=127.0.0.1#$UNBOUND_PORT/" /etc/pihole/setupVars.conf
    sed -i "s/^PIHOLE_DNS_2=.*/PIHOLE_DNS_2=/" /etc/pihole/setupVars.conf
    pihole restartdns
    finalize_resolver_configuration
    success "Pi-hole configured with Unbound"
}

# 🐳 NetAlertX
install_netalertx() {
    step "Installing NetAlertX"
    systemctl enable docker
    systemctl start docker
    mkdir -p /opt/netalertx/{config,db}
    docker rm -f netalertx 2>/dev/null || true
    docker run -d --name netalertx --restart unless-stopped \
        -p $NETALERTX_PORT:20211 \
        -v /opt/netalertx/config:/app/config \
        -v /opt/netalertx/db:/app/db \
        $NETALERTX_IMAGE
    success "NetAlertX running on :$NETALERTX_PORT"
}

# 🐍 Python Suite
setup_python_suite() {
    step "Setting up Python suite"
    cd "$PROJECT_DIR"
    # Ensure data directory exists and is writable by service user
    install -d -m 0755 "$PROJECT_DIR/data"
    chown -R "$INSTALL_USER:$INSTALL_USER" "$PROJECT_DIR/data"

    [[ -d .venv ]] || sudo -u "$INSTALL_USER" python3 -m venv .venv
    sudo -u "$INSTALL_USER" .venv/bin/pip install -U pip
    sudo -u "$INSTALL_USER" .venv/bin/pip install -r requirements.txt
    sudo -u "$INSTALL_USER" .venv/bin/python scripts/bootstrap.py || true

    local env_file="$PROJECT_DIR/.env"
    local suite_api_key="$SUITE_API_KEY_ENV"
    if [[ -z "$suite_api_key" ]]; then
        suite_api_key="$(extract_env_value "SUITE_API_KEY" "$env_file")"
    fi
    if [[ -z "$suite_api_key" ]]; then
        suite_api_key="$(openssl rand -hex 16)"
    fi

    cat > "$env_file" <<ENV
SUITE_API_KEY=$suite_api_key
SUITE_PORT=$PYTHON_SUITE_PORT
SUITE_DATA_DIR=$PROJECT_DIR/data
SUITE_LOG_LEVEL=$SUITE_LOG_LEVEL_ENV
ENV
    chown "$INSTALL_USER:$INSTALL_USER" "$env_file"

    cat > /etc/systemd/system/pihole-suite.service <<SERVICE_EOF
[Unit]
Description=Pi-hole Suite (API + monitoring)
After=network.target pihole-FTL.service
Wants=pihole-FTL.service

[Service]
Type=simple
User=$INSTALL_USER
Group=$INSTALL_USER
WorkingDirectory=$PROJECT_DIR
EnvironmentFile=$PROJECT_DIR/.env
ExecStart=$PROJECT_DIR/.venv/bin/python start_suite.py
Restart=always
RestartSec=5

# Security
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
PrivateTmp=yes
ReadWritePaths=$PROJECT_DIR $PROJECT_DIR/data

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    systemctl daemon-reload
    systemctl enable --now pihole-suite.service
    success "Python suite running on :$PYTHON_SUITE_PORT"
}

# 🩺 Health checks
run_health_checks() {
    step "Running health checks"
    dig +short @127.0.0.1 -p $UNBOUND_PORT example.com | grep -q "." && success "Unbound OK" || error "Unbound FAIL"
    pihole status | grep -iEq "blocking.+enabled|enabled" && success "Pi-hole OK" || warn "Pi-hole status unclear"
    docker ps | grep -q netalertx && success "NetAlertX OK" || warn "NetAlertX missing"
    systemctl is-active --quiet pihole-suite && success "Python suite OK" || warn "Python suite not active"
}

# 📊 Summary
show_summary() {
    echo
    success "Installation Complete!"
    echo "Pi-hole admin:  http://$(hostname -I | awk '{print $1}')/admin"
    echo "NetAlertX:      http://$(hostname -I | awk '{print $1}'):$NETALERTX_PORT"
    echo "Python Suite:   http://127.0.0.1:$PYTHON_SUITE_PORT"
    echo "API Key:        $(extract_env_value "SUITE_API_KEY" "$PROJECT_DIR/.env")"
}

# 🚀 Main
main() {
    check_system
    check_ports
    install_packages
    configure_unbound
    handle_systemd_resolved
    install_pihole
    install_netalertx
    setup_python_suite
    run_health_checks
    show_summary
}
main "$@"
