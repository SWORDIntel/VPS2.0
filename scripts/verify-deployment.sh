#!/usr/bin/env bash
#==============================================
# VPS2.0 - Post-Deployment Verification Script
#==============================================

set -euo pipefail

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

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*"
}

log_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$*${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_container() {
    local container_name="$1"
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        local status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")
        if [[ "$status" == "healthy" ]]; then
            log_success "$container_name (healthy)"
        elif [[ "$status" == "no-healthcheck" ]]; then
            log_success "$container_name (running)"
        else
            log_warn "$container_name ($status)"
        fi
        return 0
    else
        log_error "$container_name (not running)"
        return 1
    fi
}

check_url() {
    local url="$1"
    local service_name="$2"
    
    if curl -skL -o /dev/null -w "%{http_code}" "$url" | grep -q "^[23]"; then
        log_success "$service_name accessible"
    else
        log_warn "$service_name not accessible (may need DNS/SSL setup)"
    fi
}

#==============================================
# Verification Tests
#==============================================

verify_docker() {
    log_header "Docker Environment"
    
    # Check Docker version
    local docker_version=$(docker --version)
    log_info "Docker: $docker_version"
    
    # Check Docker Compose
    if docker-compose --version &> /dev/null; then
        local compose_version=$(docker-compose --version)
        log_info "Docker Compose: $compose_version"
    elif docker compose version &> /dev/null; then
        local compose_version=$(docker compose version)
        log_info "Docker Compose: $compose_version"
    fi
    
    # Check running containers
    local running=$(docker ps --format '{{.Names}}' | wc -l)
    log_info "Running containers: $running"
}

verify_networks() {
    log_header "Docker Networks"
    
    local networks=("frontend" "backend")
    for network in "${networks[@]}"; do
        if docker network ls | grep -q "$network"; then
            local containers=$(docker network inspect "$network" -f '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | wc -w)
            log_success "$network ($containers containers)"
        else
            log_warn "$network (not found)"
        fi
    done
}

verify_core_services() {
    log_header "Core Services"
    
    check_container "caddy"
    check_container "postgres"
    check_container "redis-stack"
    check_container "portainer"
    check_container "grafana"
}

verify_mattermost() {
    log_header "Mattermost Stack"
    
    if check_container "mattermost"; then
        check_container "mattermost-db"
        check_container "mattermost-redis"
        check_container "mattermost-minio"
        
        # Check health endpoint
        sleep 2
        check_url "https://mattermost.swordintelligence.airforce/api/v4/system/ping" "Mattermost API"
    else
        log_info "Mattermost not deployed (optional)"
    fi
}

verify_polygotya() {
    log_header "POLYGOTYA SSH Callback Server"
    
    if check_container "polygotya"; then
        # Check health endpoint
        sleep 2
        check_url "https://polygotya.swordintelligence.airforce/health" "POLYGOTYA Health"
        
        # Check PQC status
        local pqc_status=$(curl -sk https://polygotya.swordintelligence.airforce/health 2>/dev/null | grep -o '"pqc_enabled":[^,]*' || echo "unknown")
        log_info "PQC Status: $pqc_status"
    else
        log_info "POLYGOTYA not deployed (optional)"
    fi
}

verify_dns_hub() {
    log_header "DNS Intelligence Hub"
    
    if check_container "technitium"; then
        check_container "wireguard"
        log_info "Technitium DNS: http://$(hostname -I | awk '{print $1}'):5380"
    else
        log_info "DNS Hub not deployed (optional)"
    fi
}

verify_disk_space() {
    log_header "Disk Space"
    
    local available=$(df -BG / | tail -1 | awk '{print $4}')
    local used=$(df -BG / | tail -1 | awk '{print $3}')
    local percent=$(df -h / | tail -1 | awk '{print $5}')
    
    log_info "Used: $used | Available: $available | Usage: $percent"
    
    if [[ ${available%G} -lt 10 ]]; then
        log_warn "Low disk space! Less than 10GB available"
    fi
}

verify_memory() {
    log_header "Memory Usage"
    
    local total=$(free -h | awk 'NR==2 {print $2}')
    local used=$(free -h | awk 'NR==2 {print $3}')
    local available=$(free -h | awk 'NR==2 {print $7}')
    
    log_info "Total: $total | Used: $used | Available: $available"
}

verify_firewall() {
    log_header "Firewall Status"
    
    if command -v ufw &> /dev/null; then
        local status=$(ufw status | head -1)
        log_info "UFW: $status"
        
        # Check critical ports
        if ufw status | grep -q "22/tcp.*ALLOW"; then
            log_success "SSH (port 22) allowed"
        else
            log_error "SSH (port 22) NOT allowed - ACCESS MAY BE BLOCKED!"
        fi
        
        if ufw status | grep -q "443.*ALLOW"; then
            log_success "HTTPS (port 443) allowed"
        fi
    else
        log_warn "UFW not installed"
    fi
}

print_summary() {
    log_header "Deployment Summary"
    
    local total_containers=$(docker ps --format '{{.Names}}' | wc -l)
    local health_issues=$(docker ps --format '{{.Names}}' | while read container; do
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "ok")
        if [[ "$health" == "unhealthy" ]]; then
            echo "$container"
        fi
    done | wc -l)
    
    echo ""
    log_info "Total Running Containers: $total_containers"
    [[ $health_issues -gt 0 ]] && log_warn "Containers with health issues: $health_issues" || log_success "All containers healthy"
    
    echo ""
    log_info "Service URLs:"
    echo "  https://mattermost.swordintelligence.airforce"
    echo "  https://polygotya.swordintelligence.airforce"
    echo "  https://grafana.swordintelligence.airforce"
    
    echo ""
    log_info "Next Steps:"
    echo "  1. Configure DNS records for subdomains"
    echo "  2. Change all default passwords"
    echo "  3. Run: ./scripts/mattermost/initial-setup.sh"
    echo "  4. Run: ./scripts/backup.sh to set up backups"
    echo "  5. Review logs: docker-compose logs -f"
}

#==============================================
# Main
#==============================================

main() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║         VPS2.0 - Post-Deployment Verification                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF

    verify_docker
    verify_networks
    verify_core_services
    verify_mattermost
    verify_polygotya
    verify_dns_hub
    verify_disk_space
    verify_memory
    verify_firewall
    print_summary
    
    echo ""
    log_success "Verification complete!"
}

main "$@"
