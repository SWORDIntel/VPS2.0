#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 DNS Intelligence Hub - Revoke WireGuard Client
# Removes client access and cleans up configurations

#==============================================
# Configuration
#==============================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly WG_CONFIG_DIR="${PROJECT_ROOT}/wireguard/config"
readonly CLIENTS_DIR="${WG_CONFIG_DIR}/clients"
readonly REVOKED_DIR="${WG_CONFIG_DIR}/revoked"
readonly CLIENT_DB="${WG_CONFIG_DIR}/clients.db"
readonly SERVER_CONFIG="${WG_CONFIG_DIR}/wg0.conf"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
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

move_to_revoked() {
    local client_name="$1"
    local config_file="${CLIENTS_DIR}/${client_name}.conf"
    local qr_file="${CLIENTS_DIR}/${client_name}.png"

    # Create revoked directory
    mkdir -p "$REVOKED_DIR"

    # Move config
    if [[ -f "$config_file" ]]; then
        mv "$config_file" "${REVOKED_DIR}/${client_name}.conf.revoked-$(date +%Y%m%d-%H%M%S)"
        log_success "Config moved to revoked directory"
    fi

    # Move QR code if exists
    if [[ -f "$qr_file" ]]; then
        mv "$qr_file" "${REVOKED_DIR}/${client_name}.png.revoked-$(date +%Y%m%d-%H%M%S)"
    fi
}

update_database() {
    local client_name="$1"

    if [[ ! -f "$CLIENT_DB" ]]; then
        log_warn "Client database not found"
        return 1
    fi

    # Update status to revoked
    sed -i "s/^\(${client_name},.*\),active$/\1,revoked/" "$CLIENT_DB"
    log_success "Client marked as revoked in database"
}

remove_from_server_config() {
    local client_name="$1"

    if [[ ! -f "$SERVER_CONFIG" ]]; then
        log_warn "Server config not found at $SERVER_CONFIG"
        return 1
    fi

    # Create backup
    cp "$SERVER_CONFIG" "${SERVER_CONFIG}.backup-$(date +%Y%m%d-%H%M%S)"

    # Remove peer block (including comment line)
    # This is a bit tricky - we need to remove from "# Client: name" to the next [Peer] or end of file
    awk -v client="$client_name" '
        BEGIN { skip = 0 }
        /^# Client:/ {
            if ($0 ~ client) {
                skip = 1
                next
            }
        }
        /^\[Peer\]/ && skip { skip = 0; next }
        /^$/ && skip { next }
        !skip { print }
    ' "$SERVER_CONFIG" > "${SERVER_CONFIG}.tmp" && mv "${SERVER_CONFIG}.tmp" "$SERVER_CONFIG"

    log_success "Peer removed from server config"
    log_warn "Restart WireGuard server to apply: docker-compose restart wireguard"
}

#==============================================
# Main
#==============================================

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║        VPS2.0 DNS Intelligence Hub - Revoke Client             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Get client name
    local client_name
    if [[ -n "${1:-}" ]]; then
        client_name="$1"
    else
        read -rp "Enter client name to revoke: " client_name
    fi

    # Check if client exists
    if [[ ! -f "${CLIENTS_DIR}/${client_name}.conf" ]]; then
        log_error "Client '$client_name' not found!"
        log_info "List clients with: ./scripts/wireguard/list-clients.sh"
        exit 1
    fi

    # Confirm revocation
    echo ""
    log_warn "This will revoke access for client: $client_name"
    echo ""
    read -rp "Are you sure you want to revoke this client? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_info "Revocation cancelled"
        exit 0
    fi

    echo ""
    log_info "Revoking client: $client_name"

    # Move configs to revoked directory
    log_info "Moving client configuration to revoked directory..."
    move_to_revoked "$client_name"

    # Update database
    log_info "Updating client database..."
    update_database "$client_name"

    # Remove from server config
    log_info "Removing peer from server configuration..."
    remove_from_server_config "$client_name"

    echo ""
    log_success "Client '$client_name' has been revoked successfully!"
    echo ""
    log_warn "IMPORTANT: Restart the WireGuard container to apply changes:"
    echo "  docker-compose -f docker-compose.dns.yml restart wireguard"
    echo ""
    log_info "The client's configuration has been moved to:"
    echo "  ${REVOKED_DIR}/"
    echo ""
}

main "$@"
