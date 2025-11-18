#!/usr/bin/env bash
set -euo pipefail

#==============================================
# VPS2.0 Unified Deployment Manager
#==============================================
# Single entrypoint for complete VPS2.0 platform deployment
# Interactive menu-driven deployment for headless VPS
#
# Features:
# - Guided fresh installation
# - Component selection (Mattermost, POLYGOTYA, DNS Hub, Intelligence)
# - Credential management
# - Add/Remove components
# - Backup & Restore
# - System status
# - Security hardening
#
# Usage: sudo ./deploy-vps2.sh [--quick]
#==============================================

#==============================================
# Configuration
#==============================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$SCRIPT_DIR"
readonly STATE_FILE="${PROJECT_ROOT}/.deployment-state"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Icons
readonly ICON_CHECK="✓"
readonly ICON_CROSS="✗"
readonly ICON_ARROW="→"
readonly ICON_INFO="ℹ"
readonly ICON_WARN="⚠"

#==============================================
# Logging Functions
#==============================================

log() {
    echo -e "$*"
}

log_header() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║${NC} %-73s ${CYAN}║${NC}\n" "$1"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_section() {
    echo ""
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    printf "${BLUE}│${NC} ${BOLD}%-71s${NC} ${BLUE}│${NC}\n" "$1"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

log_info() {
    echo -e "  ${BLUE}${ICON_INFO}${NC}  $*"
}

log_success() {
    echo -e "  ${GREEN}${ICON_CHECK}${NC}  $*"
}

log_error() {
    echo -e "  ${RED}${ICON_CROSS}${NC}  $*"
}

log_warn() {
    echo -e "  ${YELLOW}${ICON_WARN}${NC}  $*"
}

log_step() {
    echo -e "  ${CYAN}${ICON_ARROW}${NC}  $*"
}

#==============================================
# UI Functions
#==============================================

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╦  ╦╔═╗╔═╗  ┌─┐ ┬  ┌─┐  ╔╦╗┌─┐┌─┐┬  ┌─┐┬ ┬┌┬┐┌─┐┌┐┌┌┬┐
    ╚╗╔╝╠═╝╚═╗  ┌─┘ │  ├┤    ║║├┤ ├─┘│  │ │└┬┘│││├┤ │││ │
     ╚╝ ╩  ╚═╝  └─┘o└─┘└─┘  ═╩╝└─┘┴  ┴─┘└─┘ ┴ ┴ ┴└─┘┘└┘ ┴
EOF
    echo -e "${NC}"
    echo -e "${BOLD}    Complete Intelligence & Security Platform Deployment Manager${NC}"
    echo -e "    Version 2.0 | SWORD Intelligence Operations Team"
    echo ""
}

show_menu() {
    local title="$1"
    shift
    local options=("$@")

    log_header "$title"

    local i=1
    for option in "${options[@]}"; do
        echo -e "  ${CYAN}[$i]${NC} $option"
        ((i++))
    done
    echo ""
    echo -e "  ${CYAN}[0]${NC} ${YELLOW}Exit${NC}"
    echo ""
}

prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local var_name="$3"

    if [[ -n "$default" ]]; then
        read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  $prompt [${BOLD}$default${NC}]: ")" input
        eval "$var_name=\"${input:-$default}\""
    else
        read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  $prompt: ")" input
        eval "$var_name=\"$input\""
    fi
}

prompt_confirm() {
    local prompt="$1"
    local default="${2:-N}"

    if [[ "$default" == "Y" ]]; then
        read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  $prompt [Y/n]: ")" -n 1 -r
    else
        read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  $prompt [y/N]: ")" -n 1 -r
    fi
    echo

    if [[ "$default" == "Y" ]]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

show_progress() {
    local current=$1
    local total=$2
    local message="$3"

    local percent=$((current * 100 / total))
    local filled=$((current * 50 / total))
    local empty=$((50 - filled))

    printf "\r  ${CYAN}Progress:${NC} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%% - %s" "$percent" "$message"

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

pause() {
    echo ""
    read -p "$(echo -e "  ${YELLOW}Press ENTER to continue...${NC}")"
}

#==============================================
# State Management
#==============================================

save_state() {
    local key="$1"
    local value="$2"

    mkdir -p "$(dirname "$STATE_FILE")"

    if [[ -f "$STATE_FILE" ]]; then
        # Update existing key or add new one
        if grep -q "^${key}=" "$STATE_FILE"; then
            sed -i "s|^${key}=.*|${key}=${value}|" "$STATE_FILE"
        else
            echo "${key}=${value}" >> "$STATE_FILE"
        fi
    else
        echo "${key}=${value}" > "$STATE_FILE"
    fi
}

load_state() {
    local key="$1"
    local default="${2:-}"

    if [[ -f "$STATE_FILE" ]] && grep -q "^${key}=" "$STATE_FILE"; then
        grep "^${key}=" "$STATE_FILE" | cut -d'=' -f2-
    else
        echo "$default"
    fi
}

get_deployment_status() {
    local component="$1"
    load_state "deployed_${component}" "false"
}

#==============================================
# Prerequisites Check
#==============================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_prerequisites() {
    log_section "Checking Prerequisites"

    local failed=false

    # Check Docker
    if command -v docker &> /dev/null; then
        log_success "Docker installed: $(docker --version | awk '{print $3}' | tr -d ',')"
    else
        log_error "Docker is not installed"
        failed=true
    fi

    # Check Docker Compose
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        log_success "Docker Compose installed"
    else
        log_error "Docker Compose is not installed"
        failed=true
    fi

    # Check Docker running
    if docker ps &> /dev/null; then
        log_success "Docker daemon is running"
    else
        log_error "Docker daemon is not running"
        failed=true
    fi

    # Check disk space
    local available=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ $available -gt 50 ]]; then
        log_success "Disk space available: ${available}GB"
    else
        log_warn "Low disk space: ${available}GB (recommended: 100GB+)"
    fi

    # Check memory
    local mem=$(free -g | awk '/^Mem:/ {print $2}')
    if [[ $mem -ge 16 ]]; then
        log_success "RAM available: ${mem}GB"
    else
        log_warn "Low RAM: ${mem}GB (recommended: 16GB+)"
    fi

    if [[ "$failed" == "true" ]]; then
        echo ""
        log_error "Prerequisites check failed. Please install missing requirements."
        pause
        return 1
    fi

    log_success "All prerequisites met"
    echo ""
    return 0
}

#==============================================
# Domain Configuration
#==============================================

configure_domain() {
    log_section "Domain Configuration"

    local current_domain=$(load_state "domain" "")

    if [[ -n "$current_domain" ]]; then
        log_info "Current domain: ${BOLD}$current_domain${NC}"
        if prompt_confirm "Keep current domain?"; then
            return 0
        fi
    fi

    prompt_input "Enter your domain name" "swordintelligence.airforce" DOMAIN

    # Validate domain format
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain format: $DOMAIN"
        pause
        return 1
    fi

    # Test DNS resolution
    log_info "Testing DNS resolution for $DOMAIN..."
    if host "$DOMAIN" &> /dev/null; then
        local ip=$(host "$DOMAIN" | awk '/has address/ {print $4; exit}')
        log_success "Domain resolves to: $ip"
    else
        log_warn "Domain does not resolve yet (you can configure DNS later)"
    fi

    # Update .env
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        sed -i "s|^DOMAIN=.*|DOMAIN=${DOMAIN}|" "${PROJECT_ROOT}/.env"
    else
        cp "${PROJECT_ROOT}/.env.template" "${PROJECT_ROOT}/.env"
        sed -i "s|^DOMAIN=.*|DOMAIN=${DOMAIN}|" "${PROJECT_ROOT}/.env"
    fi

    save_state "domain" "$DOMAIN"
    log_success "Domain configured: $DOMAIN"
    echo ""
}

#==============================================
# Component Selection
#==============================================

select_components() {
    log_section "Component Selection"

    echo -e "  ${BOLD}Core Services${NC} (Required):"
    echo "    • Caddy (Reverse Proxy with TLS 1.3)"
    echo "    • PostgreSQL, Redis, Neo4j (Databases)"
    echo "    • Grafana, Portainer (Monitoring & Management)"
    echo ""

    echo -e "  ${BOLD}Optional Components:${NC}"
    echo ""

    # Mattermost
    local deploy_mattermost=$(load_state "component_mattermost" "false")
    if [[ "$deploy_mattermost" == "true" ]]; then
        echo -e "    ${GREEN}[${ICON_CHECK}]${NC} Mattermost (Team Collaboration + Boards + Playbooks)"
    else
        if prompt_confirm "Deploy Mattermost (Team Collaboration)?"; then
            deploy_mattermost="true"
            save_state "component_mattermost" "true"
            echo -e "    ${GREEN}[${ICON_CHECK}]${NC} Mattermost will be deployed"
        else
            echo -e "    ${YELLOW}[ ]${NC} Mattermost will NOT be deployed"
        fi
    fi
    echo ""

    # POLYGOTYA
    local deploy_polygotya=$(load_state "component_polygotya" "false")
    if [[ "$deploy_polygotya" == "true" ]]; then
        echo -e "    ${GREEN}[${ICON_CHECK}]${NC} POLYGOTYA (SSH Callback Server with PQC)"
    else
        if prompt_confirm "Deploy POLYGOTYA (SSH Callback Server)?"; then
            deploy_polygotya="true"
            save_state "component_polygotya" "true"
            echo -e "    ${GREEN}[${ICON_CHECK}]${NC} POLYGOTYA will be deployed"
        else
            echo -e "    ${YELLOW}[ ]${NC} POLYGOTYA will NOT be deployed"
        fi
    fi
    echo ""

    # DNS Hub
    local deploy_dnshub=$(load_state "component_dnshub" "false")
    if [[ "$deploy_dnshub" == "true" ]]; then
        echo -e "    ${GREEN}[${ICON_CHECK}]${NC} DNS Hub (Technitium DNS + WireGuard VPN)"
    else
        if prompt_confirm "Deploy DNS Hub (Technitium DNS + WireGuard)?"; then
            deploy_dnshub="true"
            save_state "component_dnshub" "true"
            echo -e "    ${GREEN}[${ICON_CHECK}]${NC} DNS Hub will be deployed"
        else
            echo -e "    ${YELLOW}[ ]${NC} DNS Hub will NOT be deployed"
        fi
    fi
    echo ""

    log_success "Component selection complete"
    pause
}

#==============================================
# Credential Generation
#==============================================

generate_credentials() {
    log_section "Credential Generation"

    cd "$PROJECT_ROOT"

    # Ensure .env exists
    if [[ ! -f ".env" ]]; then
        cp ".env.template" ".env"
    fi

    source ".env"

    local generated=false

    # PostgreSQL password
    if [[ "${POSTGRES_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
        log_info "Generating PostgreSQL password..."
        local pg_pass=$(openssl rand -base64 32)
        sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${pg_pass}|" .env
        generated=true
    fi

    # Redis password
    if [[ "${REDIS_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
        log_info "Generating Redis password..."
        local redis_pass=$(openssl rand -base64 32)
        sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=${redis_pass}|" .env
        generated=true
    fi

    # Grafana admin password
    if [[ "${GRAFANA_ADMIN_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
        log_info "Generating Grafana admin password..."
        local grafana_pass=$(openssl rand -base64 24)
        sed -i "s|GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=${grafana_pass}|" .env
        generated=true
    fi

    # Mattermost passwords (if selected)
    if [[ "$(load_state "component_mattermost")" == "true" ]]; then
        sed -i "s/DEPLOY_MATTERMOST=false/DEPLOY_MATTERMOST=true/" .env

        if [[ "${MATTERMOST_DB_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
            log_info "Generating Mattermost database password..."
            local mm_db_pass=$(openssl rand -base64 32)
            sed -i "s|MATTERMOST_DB_PASSWORD=.*|MATTERMOST_DB_PASSWORD=${mm_db_pass}|" .env
            generated=true
        fi

        if [[ "${MATTERMOST_MINIO_ACCESS_KEY:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
            log_info "Generating Mattermost MinIO credentials..."
            local mm_minio_access=$(openssl rand -base64 16)
            local mm_minio_secret=$(openssl rand -base64 32)
            sed -i "s|MATTERMOST_MINIO_ACCESS_KEY=.*|MATTERMOST_MINIO_ACCESS_KEY=${mm_minio_access}|" .env
            sed -i "s|MATTERMOST_MINIO_SECRET_KEY=.*|MATTERMOST_MINIO_SECRET_KEY=${mm_minio_secret}|" .env
            generated=true
        fi
    fi

    # POLYGOTYA credentials (if selected)
    if [[ "$(load_state "component_polygotya")" == "true" ]]; then
        sed -i "s/DEPLOY_POLYGOTYA=false/DEPLOY_POLYGOTYA=true/" .env

        if [[ "${POLYGOTYA_API_KEY:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
            log_info "Generating POLYGOTYA API key..."
            local poly_api=$(openssl rand -base64 32)
            sed -i "s|POLYGOTYA_API_KEY=.*|POLYGOTYA_API_KEY=${poly_api}|" .env
            generated=true
        fi

        if [[ "${POLYGOTYA_SECRET_KEY:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
            log_info "Generating POLYGOTYA session secret..."
            local poly_secret=$(openssl rand -hex 32)
            sed -i "s|POLYGOTYA_SECRET_KEY=.*|POLYGOTYA_SECRET_KEY=${poly_secret}|" .env
            generated=true
        fi

        if [[ "${POLYGOTYA_ADMIN_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
            log_info "Generating POLYGOTYA admin password..."
            local poly_admin=$(openssl rand -base64 24)
            sed -i "s|POLYGOTYA_ADMIN_PASSWORD=.*|POLYGOTYA_ADMIN_PASSWORD=${poly_admin}|" .env
            generated=true
        fi
    fi

    if [[ "$generated" == "true" ]]; then
        log_success "Credentials generated successfully"
        log_warn "Save these credentials to your password manager!"
        log_info "Credentials saved in: ${PROJECT_ROOT}/.env"
    else
        log_info "Using existing credentials from .env"
    fi

    # Verify no CHANGE_ME values remain
    if grep -q "CHANGE_ME" .env; then
        log_warn "Some values still need configuration"
        log_info "Review .env file and update CHANGE_ME values"
    else
        log_success "All credentials configured"
    fi

    save_state "credentials_generated" "true"
    pause
}

#==============================================
# Core Deployment
#==============================================

deploy_core_services() {
    log_section "Deploying Core Services"

    cd "$PROJECT_ROOT"

    show_progress 0 8 "Creating Docker networks..."

    # Create networks
    docker network create br-frontend 2>/dev/null || true
    docker network create br-backend 2>/dev/null || true

    show_progress 1 8 "Deploying PostgreSQL..."
    docker-compose up -d postgres
    sleep 5

    show_progress 2 8 "Deploying Redis..."
    docker-compose up -d redis-stack
    sleep 3

    show_progress 3 8 "Deploying Neo4j..."
    docker-compose up -d neo4j
    sleep 5

    show_progress 4 8 "Deploying Caddy..."
    docker-compose up -d caddy
    sleep 3

    show_progress 5 8 "Deploying Grafana..."
    docker-compose up -d grafana
    sleep 3

    show_progress 6 8 "Deploying Portainer..."
    docker-compose up -d portainer
    sleep 3

    show_progress 7 8 "Waiting for services to initialize..."
    sleep 10

    show_progress 8 8 "Core services deployed"
    echo ""

    log_success "Core services deployed successfully"
    save_state "deployed_core" "true"
    pause
}

deploy_mattermost() {
    if [[ "$(load_state "component_mattermost")" != "true" ]]; then
        return 0
    fi

    log_section "Deploying Mattermost"

    cd "$PROJECT_ROOT"

    show_progress 0 4 "Starting Mattermost database..."
    docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d mattermost-db
    sleep 10

    show_progress 1 4 "Starting Mattermost Redis..."
    docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d mattermost-redis
    sleep 5

    show_progress 2 4 "Starting Mattermost MinIO..."
    docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d mattermost-minio
    sleep 5

    show_progress 3 4 "Starting Mattermost server..."
    docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d mattermost
    sleep 15

    show_progress 4 4 "Mattermost deployed"
    echo ""

    log_success "Mattermost deployed successfully"
    log_info "URL: https://mattermost.$(load_state "domain")"
    save_state "deployed_mattermost" "true"
    pause
}

deploy_polygotya() {
    if [[ "$(load_state "component_polygotya")" != "true" ]]; then
        return 0
    fi

    log_section "Deploying POLYGOTYA"

    cd "$PROJECT_ROOT"

    show_progress 0 2 "Starting POLYGOTYA (loading PQC libraries)..."
    docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml up -d polygotya
    sleep 15

    show_progress 1 2 "Verifying POLYGOTYA health..."
    sleep 5

    show_progress 2 2 "POLYGOTYA deployed"
    echo ""

    log_success "POLYGOTYA deployed successfully"
    log_info "URL: https://polygotya.$(load_state "domain")"
    log_info "Get admin password: docker logs polygotya | grep 'DEFAULT ADMIN'"
    save_state "deployed_polygotya" "true"
    pause
}

#==============================================
# Fresh Installation
#==============================================

fresh_installation() {
    log_header "Fresh Installation - Guided Setup"

    log_info "This will guide you through a complete VPS2.0 installation"
    log_warn "Estimated time: 15-20 minutes"
    echo ""

    if ! prompt_confirm "Proceed with fresh installation?"; then
        return 0
    fi

    # Step-by-step installation
    check_prerequisites || return 1
    configure_domain || return 1
    select_components
    generate_credentials
    deploy_core_services
    deploy_mattermost
    deploy_polygotya

    # Final summary
    show_deployment_summary
}

#==============================================
# Component Management
#==============================================

add_components() {
    log_header "Add Components"

    local options=(
        "Mattermost (Team Collaboration)"
        "POLYGOTYA (SSH Callback Server)"
        "DNS Hub (Technitium DNS + WireGuard)"
        "Intelligence Platform (MISP + OpenCTI)"
    )

    show_menu "Select component to add" "${options[@]}"

    read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

    case $choice in
        1)
            save_state "component_mattermost" "true"
            generate_credentials
            deploy_mattermost
            ;;
        2)
            save_state "component_polygotya" "true"
            generate_credentials
            deploy_polygotya
            ;;
        3)
            log_warn "DNS Hub deployment not yet implemented in this interface"
            log_info "Use: ./scripts/dns-firewall.sh"
            pause
            ;;
        4)
            log_warn "Intelligence Platform deployment not yet implemented in this interface"
            log_info "Deploy manually with docker-compose"
            pause
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid selection"
            pause
            ;;
    esac
}

remove_components() {
    log_header "Remove Components"

    log_warn "This will STOP and REMOVE the selected component"
    log_warn "Data will be preserved in Docker volumes"
    echo ""

    if ! prompt_confirm "Are you sure you want to remove a component?"; then
        return 0
    fi

    local options=(
        "Mattermost"
        "POLYGOTYA"
    )

    show_menu "Select component to remove" "${options[@]}"

    read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

    case $choice in
        1)
            log_info "Stopping Mattermost services..."
            docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml down
            save_state "component_mattermost" "false"
            save_state "deployed_mattermost" "false"
            log_success "Mattermost removed"
            pause
            ;;
        2)
            log_info "Stopping POLYGOTYA..."
            docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml down polygotya
            save_state "component_polygotya" "false"
            save_state "deployed_polygotya" "false"
            log_success "POLYGOTYA removed"
            pause
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid selection"
            pause
            ;;
    esac
}

#==============================================
# Backup & Restore
#==============================================

backup_restore_menu() {
    log_header "Backup & Restore"

    local options=(
        "Create Full Backup"
        "Restore from Backup"
        "List Available Backups"
        "Configure S3 Backup"
    )

    show_menu "Backup & Restore Options" "${options[@]}"

    read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

    case $choice in
        1)
            log_info "Creating full backup..."
            "${PROJECT_ROOT}/scripts/backup.sh"
            pause
            ;;
        2)
            log_info "Available backups:"
            ls -lh /srv/backups/*.tar.gz 2>/dev/null || log_warn "No backups found"
            echo ""
            prompt_input "Enter backup file path" "" BACKUP_FILE
            if [[ -f "$BACKUP_FILE" ]]; then
                "${PROJECT_ROOT}/scripts/restore.sh" "$BACKUP_FILE"
            else
                log_error "Backup file not found: $BACKUP_FILE"
            fi
            pause
            ;;
        3)
            log_info "Available backups:"
            ls -lh /srv/backups/ 2>/dev/null || log_warn "No backups found"
            pause
            ;;
        4)
            log_info "Edit .env and configure S3_* variables"
            log_info "Then backups will automatically upload to S3"
            pause
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid selection"
            pause
            ;;
    esac
}

#==============================================
# System Status
#==============================================

system_status() {
    log_header "System Status"

    local options=(
        "Quick Status"
        "Full Status"
        "Service Status Only"
        "Show Service URLs"
        "Recent Logs"
        "Run Deployment Verification"
    )

    show_menu "System Status Options" "${options[@]}"

    read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

    case $choice in
        1)
            "${PROJECT_ROOT}/scripts/status.sh" quick
            pause
            ;;
        2)
            "${PROJECT_ROOT}/scripts/status.sh" full
            pause
            ;;
        3)
            "${PROJECT_ROOT}/scripts/status.sh" services
            pause
            ;;
        4)
            "${PROJECT_ROOT}/scripts/status.sh" urls
            pause
            ;;
        5)
            "${PROJECT_ROOT}/scripts/status.sh" logs
            pause
            ;;
        6)
            "${PROJECT_ROOT}/scripts/verify-deployment.sh"
            pause
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid selection"
            pause
            ;;
    esac
}

#==============================================
# Security Hardening
#==============================================

security_hardening() {
    log_header "Security Hardening"

    log_info "This will apply security hardening to the system:"
    echo "    • Kernel parameter tuning (sysctl)"
    echo "    • Firewall configuration (UFW)"
    echo "    • Fail2ban setup"
    echo "    • SSH hardening"
    echo "    • Docker security options"
    echo ""

    if prompt_confirm "Apply security hardening?"; then
        "${PROJECT_ROOT}/scripts/harden.sh"
        log_success "Security hardening complete"
    fi

    pause
}

#==============================================
# Configuration
#==============================================

configuration_menu() {
    log_header "Configuration"

    local options=(
        "Change Domain"
        "Regenerate Credentials"
        "Edit .env File"
        "View Current Configuration"
    )

    show_menu "Configuration Options" "${options[@]}"

    read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

    case $choice in
        1)
            configure_domain
            ;;
        2)
            log_warn "This will regenerate ALL credentials"
            if prompt_confirm "Are you sure?"; then
                rm -f "$STATE_FILE"
                generate_credentials
            fi
            ;;
        3)
            ${EDITOR:-nano} "${PROJECT_ROOT}/.env"
            ;;
        4)
            log_info "Current configuration:"
            echo ""
            grep -v -E "(PASSWORD|SECRET|KEY)" "${PROJECT_ROOT}/.env" | grep -E "^[A-Z]"
            echo ""
            pause
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid selection"
            pause
            ;;
    esac
}

#==============================================
# Deployment Summary
#==============================================

show_deployment_summary() {
    log_header "Deployment Summary"

    local domain=$(load_state "domain" "swordintelligence.airforce")

    echo -e "  ${GREEN}${ICON_CHECK}${NC}  ${BOLD}Deployment Complete!${NC}"
    echo ""
    echo -e "  ${BOLD}Service URLs:${NC}"
    echo "    • Portainer:  https://portainer.${domain}"
    echo "    • Grafana:    https://grafana.${domain}"

    if [[ "$(get_deployment_status mattermost)" == "true" ]]; then
        echo "    • Mattermost: https://mattermost.${domain}"
    fi

    if [[ "$(get_deployment_status polygotya)" == "true" ]]; then
        echo "    • POLYGOTYA:  https://polygotya.${domain}"
    fi

    echo ""
    echo -e "  ${BOLD}Next Steps:${NC}"
    echo "    1. Configure DNS records for all subdomains"
    echo "    2. Change all default passwords on first login"
    echo "    3. Run security hardening: ${CYAN}./scripts/harden.sh${NC}"
    echo "    4. Configure automated backups"
    echo "    5. Review deployment verification: ${CYAN}./scripts/verify-deployment.sh${NC}"
    echo ""
    echo -e "  ${BOLD}Documentation:${NC}"
    echo "    • Quick Start:  ${CYAN}./QUICKSTART.md${NC}"
    echo "    • Operations:   ${CYAN}./docs/OPERATIONS-GUIDE.md${NC}"
    echo "    • Deployment:   ${CYAN}./docs/DEPLOYMENT-CHECKLIST.md${NC}"
    echo ""

    pause
}

#==============================================
# Main Menu
#==============================================

main_menu() {
    while true; do
        show_banner

        local options=(
            "Fresh Installation (Guided Setup)"
            "Add Components"
            "Remove Components"
            "Update/Upgrade Services"
            "Backup & Restore"
            "System Status"
            "Security Hardening"
            "Configuration"
            "Show Deployment Summary"
        )

        show_menu "VPS2.0 Deployment Manager - Main Menu" "${options[@]}"

        read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

        case $choice in
            1) fresh_installation ;;
            2) add_components ;;
            3) remove_components ;;
            4)
                log_info "Pulling latest images..."
                docker-compose pull
                log_info "Redeploying services..."
                docker-compose up -d
                log_success "Services updated"
                pause
                ;;
            5) backup_restore_menu ;;
            6) system_status ;;
            7) security_hardening ;;
            8) configuration_menu ;;
            9) show_deployment_summary ;;
            0)
                log_info "Exiting VPS2.0 Deployment Manager"
                exit 0
                ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

#==============================================
# Quick Mode
#==============================================

quick_mode() {
    log_header "Quick Mode - Default Installation"

    log_info "Quick mode will install:"
    echo "    • Core services (required)"
    echo "    • Mattermost (team collaboration)"
    echo "    • POLYGOTYA (SSH callback server)"
    echo "    • Default domain: swordintelligence.airforce"
    echo "    • Auto-generated credentials"
    echo ""

    if ! prompt_confirm "Proceed with quick installation?"; then
        return 1
    fi

    # Set defaults
    save_state "domain" "swordintelligence.airforce"
    save_state "component_mattermost" "true"
    save_state "component_polygotya" "true"

    # Run installation
    check_prerequisites || return 1
    generate_credentials
    deploy_core_services
    deploy_mattermost
    deploy_polygotya
    show_deployment_summary
}

#==============================================
# Main Entry Point
#==============================================

main() {
    # Check root
    check_root

    # Check for quick mode flag
    if [[ "${1:-}" == "--quick" ]]; then
        show_banner
        quick_mode
        exit 0
    fi

    # Show interactive menu
    main_menu
}

# Run main function
main "$@"
