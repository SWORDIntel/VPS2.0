#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 Status Script
# Quick health check and status overview of all services

#==============================================
# Configuration
#==============================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

#==============================================
# Helper Functions
#==============================================

print_header() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  $1"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_service_status() {
    local name="$1"
    local status="$2"
    local details="${3:-}"

    if [[ "$status" == "running" ]]; then
        echo -e "  ${GREEN}●${NC} ${name} - ${GREEN}Running${NC} ${details}"
    elif [[ "$status" == "stopped" ]]; then
        echo -e "  ${RED}●${NC} ${name} - ${RED}Stopped${NC} ${details}"
    elif [[ "$status" == "starting" ]]; then
        echo -e "  ${YELLOW}●${NC} ${name} - ${YELLOW}Starting${NC} ${details}"
    else
        echo -e "  ${YELLOW}●${NC} ${name} - ${YELLOW}Unknown${NC} ${details}"
    fi
}

get_container_status() {
    local container="$1"

    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-health")
        if [[ "$health" == "healthy" ]]; then
            echo "running (healthy)"
        elif [[ "$health" == "unhealthy" ]]; then
            echo "running (unhealthy)"
        elif [[ "$health" == "starting" ]]; then
            echo "starting"
        else
            echo "running"
        fi
    else
        echo "stopped"
    fi
}

check_url() {
    local url="$1"
    local timeout="${2:-5}"

    if curl -sSf --max-time "$timeout" "$url" >/dev/null 2>&1; then
        echo "accessible"
    else
        echo "not accessible"
    fi
}

#==============================================
# Status Checks
#==============================================

show_system_info() {
    print_header "SYSTEM INFORMATION"

    echo "  Hostname:      $(hostname)"
    echo "  Uptime:        $(uptime -p)"
    echo "  Load Average:  $(uptime | awk -F'load average:' '{print $2}')"
    echo "  Docker:        $(docker --version | awk '{print $3}' | tr -d ',')"
    echo "  Compose:       $(docker-compose --version 2>/dev/null | awk '{print $3}' | tr -d ',' || docker compose version --short)"
}

show_resource_usage() {
    print_header "RESOURCE USAGE"

    # CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo "  CPU Usage:     ${cpu_usage}%"

    # Memory
    local mem_total=$(free -h | awk '/^Mem:/ {print $2}')
    local mem_used=$(free -h | awk '/^Mem:/ {print $3}')
    local mem_percent=$(free | awk '/^Mem:/ {printf "%.1f", ($3/$2)*100}')
    echo "  Memory:        ${mem_used} / ${mem_total} (${mem_percent}%)"

    # Disk
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    local disk_avail=$(df -h / | awk 'NR==2 {print $4}')
    echo "  Disk (/):      ${disk_usage} used, ${disk_avail} available"
}

show_core_services() {
    print_header "CORE SERVICES"

    local caddy_status=$(get_container_status "caddy")
    print_service_status "Caddy (Reverse Proxy)" "$caddy_status"

    local postgres_status=$(get_container_status "postgres")
    print_service_status "PostgreSQL" "$postgres_status"

    local redis_status=$(get_container_status "redis-stack")
    print_service_status "Redis Stack" "$redis_status"

    local neo4j_status=$(get_container_status "neo4j")
    print_service_status "Neo4j" "$neo4j_status"

    local grafana_status=$(get_container_status "grafana")
    print_service_status "Grafana" "$grafana_status"

    local portainer_status=$(get_container_status "portainer")
    print_service_status "Portainer" "$portainer_status"
}

show_intelligence_services() {
    print_header "INTELLIGENCE SERVICES"

    # Check if intelligence services are deployed
    if ! docker ps | grep -q "misp\|opencti"; then
        echo "  ${YELLOW}ℹ${NC}  Intelligence services not deployed"
        return
    fi

    local misp_status=$(get_container_status "misp-core")
    print_service_status "MISP" "$misp_status"

    local opencti_status=$(get_container_status "opencti-platform")
    print_service_status "OpenCTI" "$opencti_status"
}

show_collaboration_services() {
    print_header "COLLABORATION SERVICES"

    # Mattermost
    if docker ps | grep -q "mattermost"; then
        local mm_status=$(get_container_status "mattermost")
        print_service_status "Mattermost" "$mm_status"

        local mmdb_status=$(get_container_status "mattermost-db")
        print_service_status "Mattermost Database" "$mmdb_status"

        local mmredis_status=$(get_container_status "mattermost-redis")
        print_service_status "Mattermost Redis" "$mmredis_status"

        local mmminio_status=$(get_container_status "mattermost-minio")
        print_service_status "Mattermost MinIO" "$mmminio_status"
    else
        echo "  ${YELLOW}ℹ${NC}  Mattermost not deployed"
    fi
}

show_security_services() {
    print_header "SECURITY OPERATIONS"

    # POLYGOTYA
    if docker ps | grep -q "polygotya"; then
        local poly_status=$(get_container_status "polygotya")
        print_service_status "POLYGOTYA SSH Callback Server" "$poly_status"

        # Check health endpoint
        local health_check=$(check_url "https://polygotya.swordintelligence.airforce/health" 3)
        if [[ "$health_check" == "accessible" ]]; then
            echo "    ${GREEN}✓${NC} Health endpoint accessible"
        else
            echo "    ${RED}✗${NC} Health endpoint not accessible"
        fi

        # Check PQC status if accessible
        local pqc_status=$(curl -sk https://polygotya.swordintelligence.airforce/health 2>/dev/null | grep -o '"pqc_enabled":[^,]*' | cut -d':' -f2 || echo "unknown")
        echo "    ℹ  Post-Quantum Crypto: $pqc_status"
    else
        echo "  ${YELLOW}ℹ${NC}  POLYGOTYA not deployed"
    fi
}

show_network_status() {
    print_header "DOCKER NETWORKS"

    local networks=$(docker network ls --filter "name=vps2.0" --format "{{.Name}}" | wc -l)
    echo "  Total VPS2.0 Networks: $networks"

    docker network ls --filter "name=vps2.0" --format "  - {{.Name}} ({{.Driver}})"
}

show_volume_status() {
    print_header "DATA VOLUMES"

    local volumes=$(docker volume ls --filter "name=vps2.0" --format "{{.Name}}" | wc -l)
    echo "  Total VPS2.0 Volumes: $volumes"

    # Show volume sizes (requires root)
    if [[ $EUID -eq 0 ]]; then
        echo ""
        echo "  Volume Sizes:"
        docker volume ls --filter "name=vps2.0" --format "{{.Name}}" | while read -r vol; do
            local size=$(docker run --rm -v "${vol}:/data" alpine du -sh /data 2>/dev/null | cut -f1 || echo "unknown")
            echo "    ${vol}: ${size}"
        done
    fi
}

show_container_list() {
    print_header "ALL CONTAINERS"

    echo "  Total Containers: $(docker ps -a | wc -l)"
    echo "  Running: $(docker ps | wc -l)"
    echo "  Stopped: $(docker ps -a --filter "status=exited" | wc -l)"
    echo ""

    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20
}

show_service_urls() {
    print_header "SERVICE URLs"

    # Load environment
    source "${PROJECT_ROOT}/.env" 2>/dev/null || true
    local domain="${DOMAIN:-swordintelligence.airforce}"

    echo "  Core Services:"
    echo "    Portainer:  https://portainer.${domain}"
    echo "    Grafana:    https://grafana.${domain}"
    echo "    GitLab:     https://gitlab.${domain}"
    echo ""

    if docker ps | grep -q "mattermost"; then
        echo "  Collaboration:"
        echo "    Mattermost: https://mattermost.${domain}"
        echo ""
    fi

    if docker ps | grep -q "polygotya"; then
        echo "  Security Operations:"
        echo "    POLYGOTYA:  https://polygotya.${domain}"
        echo ""
    fi

    if docker ps | grep -q "misp\|opencti"; then
        echo "  Intelligence:"
        echo "    MISP:       https://misp.${domain}"
        echo "    OpenCTI:    https://opencti.${domain}"
        echo ""
    fi
}

show_quick_stats() {
    print_header "QUICK STATISTICS"

    local total_containers=$(docker ps -a | wc -l)
    local running_containers=$(docker ps | wc -l)
    local stopped_containers=$((total_containers - running_containers))

    echo "  Containers:  ${running_containers} running, ${stopped_containers} stopped"

    local total_images=$(docker images | wc -l)
    echo "  Images:      ${total_images}"

    local total_volumes=$(docker volume ls | wc -l)
    echo "  Volumes:     ${total_volumes}"

    local total_networks=$(docker network ls | wc -l)
    echo "  Networks:    ${total_networks}"

    # Check for updates
    local containers_need_update=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | while read img; do docker pull "$img" -q >/dev/null 2>&1 && echo "update" || echo "current"; done | grep "update" | wc -l 2>/dev/null || echo "0")
    if [[ $containers_need_update -gt 0 ]]; then
        echo "  ${YELLOW}⚠${NC}  Updates Available: $containers_need_update images"
    else
        echo "  ${GREEN}✓${NC}  All images up to date"
    fi
}

show_recent_logs() {
    print_header "RECENT LOGS (Last 10 lines per service)"

    local containers=("caddy" "postgres" "grafana")

    # Add optional containers if running
    docker ps | grep -q "mattermost" && containers+=("mattermost")
    docker ps | grep -q "polygotya" && containers+=("polygotya")

    for container in "${containers[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo ""
            echo -e "  ${BLUE}${container}:${NC}"
            docker logs --tail 5 "$container" 2>&1 | sed 's/^/    /'
        fi
    done
}

#==============================================
# Main Status Display
#==============================================

main() {
    local mode="${1:-full}"

    cd "$PROJECT_ROOT" || exit 1

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          VPS2.0 System Status - $(date '+%Y-%m-%d %H:%M:%S')          ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"

    case "$mode" in
        quick|q)
            show_system_info
            show_quick_stats
            show_core_services
            ;;
        services|s)
            show_core_services
            show_intelligence_services
            show_collaboration_services
            show_security_services
            ;;
        urls|u)
            show_service_urls
            ;;
        logs|l)
            show_recent_logs
            ;;
        full|f|*)
            show_system_info
            show_resource_usage
            show_core_services
            show_collaboration_services
            show_security_services
            show_service_urls
            show_network_status
            ;;
    esac

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Usage: $0 [quick|services|urls|logs|full]"
    echo ""
}

# Run main function
main "$@"
