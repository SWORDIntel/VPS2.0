#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 DNS Intelligence Hub - List WireGuard Clients
# Shows all configured clients and their status

#==============================================
# Configuration
#==============================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly WG_CONFIG_DIR="${PROJECT_ROOT}/wireguard/config"
readonly CLIENT_DB="${WG_CONFIG_DIR}/clients.db"
readonly CLIENTS_DIR="${WG_CONFIG_DIR}/clients"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

#==============================================
# Helper Functions
#==============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

print_table_header() {
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    WireGuard VPN - Client List                             ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    printf "%-20s %-15s %-12s %-20s %-10s\n" "CLIENT NAME" "IP ADDRESS" "TUNNEL TYPE" "CREATED" "STATUS"
    echo "──────────────────────────────────────────────────────────────────────────────"
}

list_from_database() {
    if [[ ! -f "$CLIENT_DB" ]]; then
        log_info "No clients database found. No clients configured."
        return 1
    fi

    # Skip header line
    tail -n +2 "$CLIENT_DB" | while IFS=',' read -r client_name created_at ip_address tunnel_type status; do
        local status_color="$GREEN"
        if [[ "$status" == "revoked" ]]; then
            status_color="$RED"
        elif [[ "$status" == "inactive" ]]; then
            status_color="$YELLOW"
        fi

        printf "%-20s %-15s %-12s %-20s ${status_color}%-10s${NC}\n" \
            "$client_name" "$ip_address" "$tunnel_type" "$created_at" "$status"
    done
}

list_from_configs() {
    if [[ ! -d "$CLIENTS_DIR" ]]; then
        log_info "No clients directory found. No clients configured."
        return 1
    fi

    local count=0
    for conf in "$CLIENTS_DIR"/*.conf; do
        if [[ -f "$conf" ]]; then
            local client_name
            client_name=$(basename "$conf" .conf)

            # Extract IP address from config
            local ip_address
            ip_address=$(grep "^Address" "$conf" | awk '{print $3}' | sed 's|/32||')

            # Determine tunnel type from AllowedIPs
            local tunnel_type="dns-only"
            if grep -q "AllowedIPs = 0.0.0.0/0" "$conf"; then
                tunnel_type="full"
            fi

            # Get file modification time
            local created_at
            created_at=$(stat -c %y "$conf" 2>/dev/null | cut -d'.' -f1 || echo "unknown")

            printf "%-20s %-15s %-12s %-20s ${GREEN}%-10s${NC}\n" \
                "$client_name" "$ip_address" "$tunnel_type" "$created_at" "active"

            ((count++))
        fi
    done

    if [[ $count -eq 0 ]]; then
        log_info "No client configurations found."
        return 1
    fi
}

show_summary() {
    local total_clients
    local active_clients
    local revoked_clients

    if [[ -f "$CLIENT_DB" ]]; then
        total_clients=$(tail -n +2 "$CLIENT_DB" | wc -l)
        active_clients=$(tail -n +2 "$CLIENT_DB" | grep -c ",active$" || echo 0)
        revoked_clients=$(tail -n +2 "$CLIENT_DB" | grep -c ",revoked$" || echo 0)
    else
        total_clients=$(find "$CLIENTS_DIR" -name "*.conf" 2>/dev/null | wc -l)
        active_clients=$total_clients
        revoked_clients=0
    fi

    echo ""
    echo "──────────────────────────────────────────────────────────────────────────────"
    echo -e "Summary: ${CYAN}$total_clients${NC} total | ${GREEN}$active_clients${NC} active | ${RED}$revoked_clients${NC} revoked"
    echo ""
}

show_connected_peers() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Currently Connected Peers                               ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""

    # Try to get status from WireGuard container
    if command -v docker &> /dev/null; then
        if docker ps --format '{{.Names}}' | grep -q "^wireguard$"; then
            log_info "Fetching live peer status from WireGuard container..."
            echo ""
            docker exec wireguard wg show 2>/dev/null || log_info "Unable to fetch WireGuard status"
        else
            log_info "WireGuard container not running. Start with: docker-compose up -d wireguard"
        fi
    fi
}

#==============================================
# Main
#==============================================

main() {
    print_table_header

    # Try to list from database first, fall back to configs
    if ! list_from_database; then
        list_from_configs || echo "No clients found."
    fi

    show_summary
    show_connected_peers

    echo ""
    log_info "To generate a new client: ./scripts/wireguard/generate-client.sh"
    log_info "To revoke a client: ./scripts/wireguard/revoke-client.sh <client-name>"
    echo ""
}

main "$@"
