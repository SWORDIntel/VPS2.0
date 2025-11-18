#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 DNS Intelligence Hub - Firewall Configuration
# Secures DNS port 53 to only accept queries from WireGuard VPN subnet
# CRITICAL: Keeps SSH (port 22) open to prevent lockout

#==============================================
# Configuration
#==============================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VPN_SUBNET="10.10.0.0/24"
readonly WIREGUARD_PORT="${WIREGUARD_PORT:-51820}"
readonly SSH_PORT="${SSH_PORT:-22}"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

#==============================================
# Helper Functions
#==============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_firewall() {
    if command -v nft &> /dev/null; then
        echo "nftables"
    elif command -v iptables &> /dev/null; then
        echo "iptables"
    else
        log_error "No supported firewall found (iptables or nftables required)"
        exit 1
    fi
}

#==============================================
# iptables Configuration
#==============================================

configure_iptables() {
    log_info "Configuring iptables for DNS Intelligence Hub..."

    # Create custom chains for DNS filtering
    iptables -N DNS_FILTER 2>/dev/null || iptables -F DNS_FILTER
    iptables -N VPN_FILTER 2>/dev/null || iptables -F VPN_FILTER

    # ====================
    # SSH Protection (CRITICAL - Always First!)
    # ====================
    log_info "Ensuring SSH access remains open on port ${SSH_PORT}..."
    iptables -A INPUT -p tcp --dport "${SSH_PORT}" -m state --state NEW,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -p tcp --sport "${SSH_PORT}" -m state --state ESTABLISHED -j ACCEPT
    log_success "SSH access protected"

    # ====================
    # Loopback
    # ====================
    log_info "Allowing loopback traffic..."
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # ====================
    # Established Connections
    # ====================
    log_info "Allowing established connections..."
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # ====================
    # WireGuard VPN
    # ====================
    log_info "Allowing WireGuard on UDP port ${WIREGUARD_PORT}..."
    iptables -A INPUT -p udp --dport "${WIREGUARD_PORT}" -j ACCEPT
    log_success "WireGuard access configured"

    # ====================
    # DNS Security Rules
    # ====================
    log_info "Configuring DNS security rules..."

    # Allow DNS from WireGuard subnet ONLY
    iptables -A DNS_FILTER -s "${VPN_SUBNET}" -p tcp --dport 53 -j ACCEPT
    iptables -A DNS_FILTER -s "${VPN_SUBNET}" -p udp --dport 53 -j ACCEPT

    # Allow DNS from localhost (for Docker containers)
    iptables -A DNS_FILTER -s 127.0.0.1 -p tcp --dport 53 -j ACCEPT
    iptables -A DNS_FILTER -s 127.0.0.1 -p udp --dport 53 -j ACCEPT

    # Allow DNS from Docker networks
    iptables -A DNS_FILTER -s 172.16.0.0/12 -p tcp --dport 53 -j ACCEPT
    iptables -A DNS_FILTER -s 172.16.0.0/12 -p udp --dport 53 -j ACCEPT

    # Log rejected DNS queries (rate-limited to avoid log spam)
    iptables -A DNS_FILTER -p tcp --dport 53 -m limit --limit 10/min -j LOG --log-prefix "BLOCKED_DNS_TCP: " --log-level 4
    iptables -A DNS_FILTER -p udp --dport 53 -m limit --limit 10/min -j LOG --log-prefix "BLOCKED_DNS_UDP: " --log-level 4

    # Drop all other DNS traffic
    iptables -A DNS_FILTER -p tcp --dport 53 -j DROP
    iptables -A DNS_FILTER -p udp --dport 53 -j DROP

    # Apply DNS filter to INPUT chain
    iptables -A INPUT -j DNS_FILTER

    log_success "DNS restricted to VPN subnet ${VPN_SUBNET}"

    # ====================
    # HTTP/HTTPS (for Caddy reverse proxy)
    # ====================
    log_info "Allowing HTTP/HTTPS for web services..."
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -p udp --dport 443 -j ACCEPT  # QUIC/HTTP3

    # ====================
    # ICMP (Ping)
    # ====================
    log_info "Allowing ICMP (ping)..."
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

    # ====================
    # Default Policies
    # ====================
    log_warn "Setting default DROP policy for INPUT chain..."
    # Note: We use REJECT instead of DROP for better UX (connection refused vs timeout)
    iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited
    iptables -A FORWARD -j REJECT --reject-with icmp-host-prohibited

    log_success "iptables configuration completed"
}

#==============================================
# nftables Configuration
#==============================================

configure_nftables() {
    log_info "Configuring nftables for DNS Intelligence Hub..."

    # Create nftables configuration
    cat > /etc/nftables.d/dns-intelligence.nft << 'EOF'
#!/usr/sbin/nft -f

# VPS2.0 DNS Intelligence Hub - nftables rules
# Secures DNS to VPN subnet only

table inet dns_filter {
    # Sets for dynamic IP management
    set vpn_clients {
        type ipv4_addr
        flags interval
        elements = { 10.10.0.0/24 }
    }

    set docker_networks {
        type ipv4_addr
        flags interval
        elements = { 172.16.0.0/12 }
    }

    # DNS query logging
    chain dns_log {
        type filter hook input priority -1; policy accept;

        # Log rejected DNS queries (rate-limited)
        tcp dport 53 ip saddr != @vpn_clients ip saddr != @docker_networks ip saddr != 127.0.0.1 limit rate 10/minute log prefix "BLOCKED_DNS_TCP: " level warn
        udp dport 53 ip saddr != @vpn_clients ip saddr != @docker_networks ip saddr != 127.0.0.1 limit rate 10/minute log prefix "BLOCKED_DNS_UDP: " level warn
    }

    # Main input chain
    chain input {
        type filter hook input priority 0; policy drop;

        # CRITICAL: Always allow SSH first
        tcp dport 22 ct state new,established accept

        # Allow established/related connections
        ct state established,related accept

        # Allow loopback
        iif lo accept

        # Allow ICMP
        ip protocol icmp accept
        meta l4proto ipv6-icmp accept

        # WireGuard VPN
        udp dport 51820 accept

        # DNS - Only from VPN subnet, localhost, and Docker networks
        ip saddr @vpn_clients tcp dport 53 accept
        ip saddr @vpn_clients udp dport 53 accept
        ip saddr 127.0.0.1 tcp dport 53 accept
        ip saddr 127.0.0.1 udp dport 53 accept
        ip saddr @docker_networks tcp dport 53 accept
        ip saddr @docker_networks udp dport 53 accept

        # Drop all other DNS (logged above)
        tcp dport 53 drop
        udp dport 53 drop

        # HTTP/HTTPS for web services
        tcp dport 80 accept
        tcp dport 443 accept
        udp dport 443 accept

        # Default reject
        reject with icmp type host-prohibited
    }

    # Forward chain
    chain forward {
        type filter hook forward priority 0; policy drop;

        # Allow VPN forwarding
        ip saddr @vpn_clients accept
        ip daddr @vpn_clients ct state established,related accept

        # Reject all other forwards
        reject with icmp type host-prohibited
    }

    # Output chain (allow all outbound by default)
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

    # Load nftables configuration
    log_info "Loading nftables rules..."
    if nft -f /etc/nftables.d/dns-intelligence.nft; then
        log_success "nftables configuration loaded"
    else
        log_error "Failed to load nftables rules"
        return 1
    fi

    # Enable nftables service
    if command -v systemctl &> /dev/null; then
        systemctl enable nftables 2>/dev/null || true
        log_info "nftables service enabled"
    fi

    log_success "nftables configuration completed"
}

#==============================================
# Persistence
#==============================================

make_persistent_iptables() {
    log_info "Making iptables rules persistent..."

    # Debian/Ubuntu
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
        systemctl enable netfilter-persistent
        log_success "Rules saved with netfilter-persistent"
        return 0
    fi

    # iptables-persistent (older systems)
    if command -v iptables-save &> /dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4
        log_success "Rules saved to /etc/iptables/rules.v4"

        # Create systemd service to restore on boot
        cat > /etc/systemd/system/iptables-restore.service << 'EOF'
[Unit]
Description=Restore iptables rules
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        systemctl enable iptables-restore.service
        log_success "iptables-restore service enabled"
        return 0
    fi

    log_warn "Could not find method to persist rules. Install iptables-persistent or netfilter-persistent"
    return 1
}

#==============================================
# Main
#==============================================

main() {
    check_root

    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║    VPS2.0 DNS Intelligence Hub - Firewall Configuration       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    local firewall_type
    firewall_type=$(detect_firewall)

    log_info "Detected firewall: ${firewall_type}"
    echo ""

    case "${firewall_type}" in
        nftables)
            configure_nftables
            ;;
        iptables)
            configure_iptables
            make_persistent_iptables
            ;;
        *)
            log_error "Unsupported firewall type: ${firewall_type}"
            exit 1
            ;;
    esac

    echo ""
    log_success "Firewall configuration complete!"
    echo ""
    log_info "Summary:"
    echo "  ✓ SSH (port ${SSH_PORT}): OPEN to all"
    echo "  ✓ WireGuard (UDP ${WIREGUARD_PORT}): OPEN to all"
    echo "  ✓ DNS (port 53): RESTRICTED to ${VPN_SUBNET}"
    echo "  ✓ HTTP/HTTPS (80/443): OPEN to all"
    echo "  ✓ All other traffic: BLOCKED"
    echo ""
    log_warn "IMPORTANT: Test your firewall rules before disconnecting!"
    log_info "Review logs with: journalctl -k | grep BLOCKED_DNS"
    echo ""
}

main "$@"
