#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 DNS Intelligence Hub - WireGuard Client Generator
# Creates new client configurations with auto-assigned IPs

#==============================================
# Configuration
#==============================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly WG_CONFIG_DIR="${PROJECT_ROOT}/wireguard/config"
readonly CLIENTS_DIR="${WG_CONFIG_DIR}/clients"
readonly SERVER_CONFIG="${WG_CONFIG_DIR}/wg0.conf"
readonly CLIENT_DB="${WG_CONFIG_DIR}/clients.db"

# Load environment variables
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    # shellcheck disable=SC1091
    source "${PROJECT_ROOT}/.env"
fi

readonly SERVER_URL="${WIREGUARD_SERVER_URL:-38.102.87.235}"
readonly SERVER_PORT="${WIREGUARD_PORT:-51820}"
readonly VPN_SUBNET="${VPN_SUBNET:-10.10.0.0/24}"
readonly DNS_SERVER="${VPN_DNS:-10.10.0.1}"
readonly MTU="${VPN_MTU:-1420}"
readonly KEEPALIVE="${VPN_KEEPALIVE:-25}"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
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

check_dependencies() {
    local missing_deps=()

    for cmd in wg wg-quick qrencode; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warn "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: apt-get install wireguard-tools qrencode"

        # qrencode is optional
        if [[ "${missing_deps[*]}" != *qrencode* ]]; then
            return 1
        fi
    fi
    return 0
}

get_next_ip() {
    # Start from 10.10.0.2 (server is .1)
    local base_ip=2
    local subnet_prefix="10.10.0"

    # Read existing client IPs from database
    if [[ -f "$CLIENT_DB" ]]; then
        local max_ip
        max_ip=$(awk -F',' '{print $3}' "$CLIENT_DB" | sed "s/${subnet_prefix}.//g" | sort -n | tail -1)
        if [[ -n "$max_ip" ]]; then
            base_ip=$((max_ip + 1))
        fi
    fi

    echo "${subnet_prefix}.${base_ip}"
}

generate_keys() {
    local privkey pubkey psk

    privkey=$(wg genkey)
    pubkey=$(echo "$privkey" | wg pubkey)
    psk=$(wg genpsk)

    echo "${privkey}|${pubkey}|${psk}"
}

create_client_config() {
    local client_name="$1"
    local client_ip="$2"
    local client_privkey="$3"
    local client_psk="$4"
    local server_pubkey="$5"
    local tunnel_type="${6:-dns-only}"

    local allowed_ips
    if [[ "$tunnel_type" == "full" ]]; then
        allowed_ips="0.0.0.0/0, ::/0"
    else
        # DNS-only tunnel
        allowed_ips="${VPN_SUBNET}"
    fi

    cat > "${CLIENTS_DIR}/${client_name}.conf" << EOF
[Interface]
# Client: ${client_name}
# DNS Intelligence Hub - VPS2.0
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

PrivateKey = ${client_privkey}
Address = ${client_ip}/32
DNS = ${DNS_SERVER}
MTU = ${MTU}

[Peer]
# Server: ${SERVER_URL}:${SERVER_PORT}
PublicKey = ${server_pubkey}
PresharedKey = ${client_psk}
Endpoint = ${SERVER_URL}:${SERVER_PORT}
AllowedIPs = ${allowed_ips}
PersistentKeepalive = ${KEEPALIVE}
EOF

    log_success "Client config created: ${CLIENTS_DIR}/${client_name}.conf"
}

generate_qr_code() {
    local client_name="$1"
    local config_file="${CLIENTS_DIR}/${client_name}.conf"
    local qr_file="${CLIENTS_DIR}/${client_name}.png"

    if command -v qrencode &> /dev/null; then
        qrencode -t png -o "$qr_file" -r "$config_file"
        log_success "QR code generated: $qr_file"

        # Also display in terminal if possible
        if command -v qrencode &> /dev/null; then
            echo ""
            log_info "Scan this QR code with your mobile device:"
            echo ""
            qrencode -t ansiutf8 < "$config_file"
            echo ""
        fi
    else
        log_warn "qrencode not installed, skipping QR code generation"
    fi
}

add_peer_to_server() {
    local client_name="$1"
    local client_ip="$2"
    local client_pubkey="$3"
    local client_psk="$4"

    # Check if server config exists
    if [[ ! -f "$SERVER_CONFIG" ]]; then
        log_warn "Server config not found at $SERVER_CONFIG"
        log_info "You may need to manually add this peer to the server"
        return 1
    fi

    # Add peer to server config
    cat >> "$SERVER_CONFIG" << EOF

[Peer]
# Client: ${client_name}
PublicKey = ${client_pubkey}
PresharedKey = ${client_psk}
AllowedIPs = ${client_ip}/32
EOF

    log_success "Peer added to server config"
    log_warn "Restart WireGuard server to apply: docker-compose restart wireguard"
}

record_client() {
    local client_name="$1"
    local client_ip="$2"
    local tunnel_type="$3"
    local created_at
    created_at=$(date -u +"%Y-%m-%d %H:%M:%S")

    # Create database if it doesn't exist
    if [[ ! -f "$CLIENT_DB" ]]; then
        echo "client_name,created_at,ip_address,tunnel_type,status" > "$CLIENT_DB"
    fi

    # Add client record
    echo "${client_name},${created_at},${client_ip},${tunnel_type},active" >> "$CLIENT_DB"
    log_success "Client recorded in database"
}

print_client_info() {
    local client_name="$1"
    local client_ip="$2"
    local tunnel_type="$3"
    local config_file="${CLIENTS_DIR}/${client_name}.conf"

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║           WireGuard Client Configuration Created              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${CYAN}Client Name:${NC}    $client_name"
    echo -e "${CYAN}IP Address:${NC}     $client_ip"
    echo -e "${CYAN}Tunnel Type:${NC}    $tunnel_type"
    echo -e "${CYAN}DNS Server:${NC}     $DNS_SERVER"
    echo -e "${CYAN}Config File:${NC}    $config_file"
    echo ""
    echo -e "${GREEN}Next Steps:${NC}"
    echo "  1. Copy config to client:"
    echo "     scp $config_file user@client-machine:~/wireguard.conf"
    echo ""
    echo "  2. On client machine:"
    echo "     sudo cp ~/wireguard.conf /etc/wireguard/wg0.conf"
    echo "     sudo wg-quick up wg0"
    echo ""
    echo "  3. Enable on boot (optional):"
    echo "     sudo systemctl enable wg-quick@wg0"
    echo ""
    echo "  4. Test DNS resolution:"
    echo "     dig @${DNS_SERVER} example.com"
    echo ""
    echo "  5. Access DNS Web UI:"
    echo "     https://dns.${DOMAIN:-localhost}"
    echo ""
}

#==============================================
# Main
#==============================================

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║      VPS2.0 DNS Intelligence Hub - Client Generator           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Check dependencies
    check_dependencies || exit 1

    # Create directories
    mkdir -p "$CLIENTS_DIR"

    # Get client name
    local client_name
    if [[ -n "${1:-}" ]]; then
        client_name="$1"
    else
        read -rp "Enter client name (e.g., laptop-john, phone-alice): " client_name
    fi

    # Validate client name
    if [[ ! "$client_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_warn "Invalid client name. Use only letters, numbers, hyphens, and underscores."
        exit 1
    fi

    # Check if client already exists
    if [[ -f "${CLIENTS_DIR}/${client_name}.conf" ]]; then
        log_warn "Client '$client_name' already exists!"
        read -rp "Overwrite? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            exit 0
        fi
    fi

    # Get tunnel type
    local tunnel_type
    if [[ -n "${2:-}" ]]; then
        tunnel_type="$2"
    else
        echo ""
        echo "Select tunnel type:"
        echo "  1) DNS-only (recommended) - Only DNS traffic through VPN"
        echo "  2) Full tunnel - All traffic through VPN"
        read -rp "Choice [1]: " tunnel_choice

        case "${tunnel_choice:-1}" in
            1) tunnel_type="dns-only" ;;
            2) tunnel_type="full" ;;
            *) tunnel_type="dns-only" ;;
        esac
    fi

    log_info "Generating configuration for client: $client_name ($tunnel_type)"

    # Get next available IP
    local client_ip
    client_ip=$(get_next_ip)
    log_info "Assigned IP: $client_ip"

    # Generate keys
    log_info "Generating cryptographic keys..."
    local keys
    keys=$(generate_keys)
    local client_privkey client_pubkey client_psk
    IFS='|' read -r client_privkey client_pubkey client_psk <<< "$keys"

    # Get server public key
    local server_pubkey
    if [[ -f "${WG_CONFIG_DIR}/server/publickey" ]]; then
        server_pubkey=$(cat "${WG_CONFIG_DIR}/server/publickey")
    else
        log_warn "Server public key not found. Using placeholder."
        server_pubkey="SERVER_PUBLIC_KEY_HERE"
    fi

    # Create client configuration
    log_info "Creating client configuration..."
    create_client_config "$client_name" "$client_ip" "$client_privkey" "$client_psk" "$server_pubkey" "$tunnel_type"

    # Generate QR code
    log_info "Generating QR code..."
    generate_qr_code "$client_name"

    # Add peer to server (if possible)
    log_info "Adding peer to server configuration..."
    add_peer_to_server "$client_name" "$client_ip" "$client_pubkey" "$client_psk" || true

    # Record client in database
    record_client "$client_name" "$client_ip" "$tunnel_type"

    # Print client information
    print_client_info "$client_name" "$client_ip" "$tunnel_type"
}

main "$@"
