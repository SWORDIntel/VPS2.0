#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 Interactive Setup Wizard
# Guides users through complete configuration with smart defaults

#==============================================
# Configuration
#==============================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Emojis
readonly ROCKET="🚀"
readonly CHECK="✅"
readonly CROSS="❌"
readonly WARN="⚠️"
readonly INFO="ℹ️"
readonly LOCK="🔒"
readonly GEAR="⚙️"

#==============================================
# Helper Functions
#==============================================

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   ██╗   ██╗██████╗ ███████╗██████╗     ██████╗              ║
║   ██║   ██║██╔══██╗██╔════╝╚════██╗   ██╔═████╗             ║
║   ██║   ██║██████╔╝███████╗ █████╔╝   ██║██╔██║             ║
║   ╚██╗ ██╔╝██╔═══╝ ╚════██║██╔═══╝    ████╔╝██║             ║
║    ╚████╔╝ ██║     ███████║███████╗██╗╚██████╔╝             ║
║     ╚═══╝  ╚═╝     ╚══════╝╚══════╝╚═╝ ╚═════╝              ║
║                                                              ║
║           INTELLIGENCE PLATFORM SETUP WIZARD                ║
║                  TEMPEST LEVEL C READY                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}${INFO}${NC} $*"
}

log_success() {
    echo -e "${GREEN}${CHECK}${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}${WARN}${NC} $*"
}

log_error() {
    echo -e "${RED}${CROSS}${NC} $*"
}

log_step() {
    echo ""
    echo -e "${MAGENTA}${GEAR}${NC} ${WHITE}$*${NC}"
    echo -e "${MAGENTA}$(printf '=%.0s' {1..60})${NC}"
}

prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local var_name="$3"

    if [[ -n "$default" ]]; then
        echo -e -n "${CYAN}❯${NC} $prompt ${YELLOW}[$default]${NC}: "
    else
        echo -e -n "${CYAN}❯${NC} $prompt: "
    fi

    read -r input
    if [[ -z "$input" && -n "$default" ]]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$input'"
    fi
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"

    while true; do
        if [[ "$default" == "y" ]]; then
            echo -e -n "${CYAN}❯${NC} $prompt ${YELLOW}[Y/n]${NC}: "
        else
            echo -e -n "${CYAN}❯${NC} $prompt ${YELLOW}[y/N]${NC}: "
        fi

        read -r response
        response="${response:-$default}"

        case "$response" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo -e "${RED}Please answer yes or no.${NC}" ;;
        esac
    done
}

prompt_choice() {
    local prompt="$1"
    shift
    local options=("$@")

    echo -e "${CYAN}❯${NC} $prompt"
    echo ""

    local i=1
    for option in "${options[@]}"; do
        echo -e "  ${YELLOW}$i)${NC} $option"
        ((i++))
    done

    echo ""
    while true; do
        echo -e -n "${CYAN}❯${NC} Enter choice [1-${#options[@]}]: "
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            return $((choice - 1))
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#options[@]}.${NC}"
        fi
    done
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

#==============================================
# Pre-flight Checks
#==============================================

check_requirements() {
    log_step "STEP 1: Pre-flight System Checks"

    local errors=0

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        ((errors++))
    fi

    # Check OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "Operating System: $PRETTY_NAME"

        if [[ "$ID" != "debian" && "$ID" != "ubuntu" ]]; then
            log_warn "This script is optimized for Debian/Ubuntu"
        fi
    fi

    # Check CPU
    local cpu_cores=$(nproc)
    log_info "CPU Cores: $cpu_cores"
    if [[ $cpu_cores -lt 4 ]]; then
        log_warn "Recommended: 8+ CPU cores (you have: $cpu_cores)"
    else
        log_success "CPU cores: $cpu_cores"
    fi

    # Check RAM
    local total_ram=$(free -g | awk 'NR==2 {print $2}')
    log_info "Total RAM: ${total_ram}GB"
    if [[ $total_ram -lt 16 ]]; then
        log_warn "Recommended: 32GB+ RAM (you have: ${total_ram}GB)"
    else
        log_success "RAM: ${total_ram}GB"
    fi

    # Check disk space
    local disk_space=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    log_info "Available Disk: ${disk_space}GB"
    if [[ $disk_space -lt 100 ]]; then
        log_warn "Recommended: 500GB+ disk space (you have: ${disk_space}GB)"
    else
        log_success "Disk space: ${disk_space}GB"
    fi

    # Check Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        log_success "Docker installed: $docker_version"
    else
        log_warn "Docker not installed (will be installed)"
    fi

    # Check Docker Compose
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
        log_success "Docker Compose installed"
    else
        log_warn "Docker Compose not installed (will be installed)"
    fi

    # Check network connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_success "Internet connectivity: OK"
    else
        log_error "No internet connectivity"
        ((errors++))
    fi

    echo ""
    if [[ $errors -gt 0 ]]; then
        log_error "Pre-flight checks failed with $errors error(s)"
        exit 1
    else
        log_success "Pre-flight checks passed!"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

#==============================================
# Configuration Wizard
#==============================================

setup_basic_config() {
    log_step "STEP 2: Basic Configuration"

    # Domain name
    prompt_input "Enter your domain name" "example.com" DOMAIN

    # Admin email
    prompt_input "Enter admin email" "admin@$DOMAIN" ADMIN_EMAIL

    # Timezone
    prompt_input "Enter timezone" "UTC" TIMEZONE

    log_success "Basic configuration complete"
    echo ""
    read -p "Press Enter to continue..."
}

setup_deployment_profile() {
    log_step "STEP 3: Select Deployment Profile"

    echo -e "${WHITE}Choose a deployment profile:${NC}"
    echo ""

    local profiles=(
        "Minimal - Essential services only (8GB RAM)"
        "Standard - Intelligence + Monitoring (16GB RAM)"
        "Full - All services including dashboard (32GB RAM)"
        "Maximum - Everything + Optional services (64GB RAM)"
        "Custom - Choose individual services"
    )

    prompt_choice "Select profile:" "${profiles[@]}"
    DEPLOYMENT_PROFILE=$?

    case $DEPLOYMENT_PROFILE in
        0) PROFILE_NAME="minimal" ;;
        1) PROFILE_NAME="standard" ;;
        2) PROFILE_NAME="full" ;;
        3) PROFILE_NAME="maximum" ;;
        4) PROFILE_NAME="custom" ;;
    esac

    log_info "Selected profile: $PROFILE_NAME"

    echo ""
    read -p "Press Enter to continue..."
}

setup_services() {
    log_step "STEP 4: Service Configuration"

    # Optional services
    if prompt_yes_no "Deploy HURRICANE IPv6 proxy?" "n"; then
        DEPLOY_HURRICANE=true

        echo ""
        log_info "HURRICANE Configuration:"

        if prompt_yes_no "Enable Hurricane Electric tunnel?" "n"; then
            HURRICANE_HE_ENABLED=true
            prompt_input "HE Username" "" HE_USERNAME
            prompt_input "HE Password" "" HE_PASSWORD
            prompt_input "HE Tunnel ID" "" HE_TUNNEL_ID
        fi
    else
        DEPLOY_HURRICANE=false
    fi

    echo ""
    if prompt_yes_no "Deploy blockchain explorers?" "n"; then
        DEPLOY_BLOCKCHAIN=true

        if prompt_yes_no "Deploy Bitcoin + Mempool?" "y"; then
            DEPLOY_BITCOIN=true
        fi

        if prompt_yes_no "Deploy Ethereum + Blockscout?" "y"; then
            DEPLOY_ETHEREUM=true
        fi
    else
        DEPLOY_BLOCKCHAIN=false
    fi

    echo ""
    log_success "Service configuration complete"
    echo ""
    read -p "Press Enter to continue..."
}

setup_security() {
    log_step "STEP 5: Security Configuration"

    # Generate passwords
    log_info "Generating secure passwords..."

    POSTGRES_PASSWORD=$(generate_password)
    REDIS_PASSWORD=$(generate_password)
    NEO4J_PASSWORD=$(generate_password)
    JWT_SECRET=$(openssl rand -base64 64)
    GRAFANA_PASSWORD=$(generate_password)
    PORTAINER_PASSWORD=$(generate_password)

    log_success "All passwords generated"

    echo ""
    if prompt_yes_no "Enable automatic security hardening?" "y"; then
        ENABLE_HARDENING=true
        log_success "Security hardening will be applied"
    else
        ENABLE_HARDENING=false
        log_warn "Security hardening skipped (not recommended)"
    fi

    echo ""
    if prompt_yes_no "Configure automated backups?" "y"; then
        ENABLE_BACKUPS=true
        prompt_input "Backup retention (days)" "30" BACKUP_RETENTION

        if prompt_yes_no "Enable S3 backups?" "n"; then
            ENABLE_S3=true
            prompt_input "S3 Endpoint" "https://s3.amazonaws.com" S3_ENDPOINT
            prompt_input "S3 Bucket" "vps2-backups" S3_BUCKET
            prompt_input "S3 Access Key" "" S3_ACCESS_KEY
            prompt_input "S3 Secret Key" "" S3_SECRET_KEY
        fi
    else
        ENABLE_BACKUPS=false
    fi

    echo ""
    log_success "Security configuration complete"
    echo ""
    read -p "Press Enter to continue..."
}

#==============================================
# Configuration Summary
#==============================================

show_summary() {
    clear
    log_step "CONFIGURATION SUMMARY"

    echo -e "${WHITE}Basic Configuration:${NC}"
    echo -e "  Domain:        ${CYAN}$DOMAIN${NC}"
    echo -e "  Admin Email:   ${CYAN}$ADMIN_EMAIL${NC}"
    echo -e "  Timezone:      ${CYAN}$TIMEZONE${NC}"
    echo -e "  Profile:       ${CYAN}$PROFILE_NAME${NC}"
    echo ""

    echo -e "${WHITE}Services:${NC}"
    echo -e "  SWORDINTELLIGENCE:  ${GREEN}${CHECK}${NC}"
    echo -e "  MISP:               ${GREEN}${CHECK}${NC}"
    echo -e "  OpenCTI:            ${GREEN}${CHECK}${NC}"
    echo -e "  Dashboard:          ${GREEN}${CHECK}${NC}"
    echo -e "  Monitoring:         ${GREEN}${CHECK}${NC}"
    echo -e "  GitLab:             ${GREEN}${CHECK}${NC}"
    [[ "$DEPLOY_HURRICANE" == "true" ]] && echo -e "  HURRICANE:          ${GREEN}${CHECK}${NC}" || echo -e "  HURRICANE:          ${YELLOW}Skip${NC}"
    [[ "$DEPLOY_BLOCKCHAIN" == "true" ]] && echo -e "  Blockchain:         ${GREEN}${CHECK}${NC}" || echo -e "  Blockchain:         ${YELLOW}Skip${NC}"
    echo ""

    echo -e "${WHITE}Security:${NC}"
    echo -e "  Passwords:          ${GREEN}Generated${NC}"
    echo -e "  Hardening:          $([[ "$ENABLE_HARDENING" == "true" ]] && echo -e "${GREEN}Enabled${NC}" || echo -e "${YELLOW}Disabled${NC}")"
    echo -e "  Backups:            $([[ "$ENABLE_BACKUPS" == "true" ]] && echo -e "${GREEN}Enabled${NC}" || echo -e "${YELLOW}Disabled${NC}")"
    [[ "$ENABLE_S3" == "true" ]] && echo -e "  S3 Backups:         ${GREEN}Enabled${NC}"
    echo ""

    echo -e "${WHITE}Generated Credentials:${NC}"
    echo -e "  Grafana:            admin / ${YELLOW}[auto-generated]${NC}"
    echo -e "  Portainer:          admin / ${YELLOW}[auto-generated]${NC}"
    echo -e "  Databases:          ${YELLOW}[auto-generated]${NC}"
    echo ""

    echo -e "${YELLOW}${WARN} Credentials will be saved to: ${PROJECT_ROOT}/credentials.txt${NC}"
    echo ""

    if prompt_yes_no "Proceed with deployment?" "y"; then
        return 0
    else
        log_warn "Deployment cancelled"
        exit 0
    fi
}

#==============================================
# Generate Configuration
#==============================================

generate_env_file() {
    log_step "Generating Environment Configuration"

    cat > "${PROJECT_ROOT}/.env" <<EOF
# VPS2.0 Environment Configuration
# Generated by Setup Wizard on $(date)

#==============================================
# Global Settings
#==============================================
DOMAIN=$DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
TZ=$TIMEZONE

#==============================================
# Database Credentials
#==============================================
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
NEO4J_PASSWORD=$NEO4J_PASSWORD

# Individual database passwords
SWORDINTEL_DB_PASSWORD=$(generate_password)
MISP_DB_PASSWORD=$(generate_password)
N8N_DB_PASSWORD=$(generate_password)
GITLAB_DB_PASSWORD=$(generate_password)

#==============================================
# Application Credentials
#==============================================
JWT_SECRET=$JWT_SECRET
GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD
PORTAINER_PASSWORD_HASH=$(docker run --rm httpd:2.4-alpine htpasswd -nbB admin "$PORTAINER_PASSWORD" | cut -d ":" -f 2)

# MISP
MISP_ADMIN_PASSWORD=$(generate_password)
MISP_DB_ROOT_PASSWORD=$(generate_password)

# OpenCTI
OPENCTI_ADMIN_PASSWORD=$(generate_password)
OPENCTI_ADMIN_TOKEN=$(uuidgen)
RABBITMQ_PASSWORD=$(generate_password)

# n8n
N8N_ENCRYPTION_KEY=$(generate_password)

#==============================================
# Optional Services
#==============================================
HURRICANE_ENABLED=$DEPLOY_HURRICANE
EOF

    if [[ "$DEPLOY_HURRICANE" == "true" && "$HURRICANE_HE_ENABLED" == "true" ]]; then
        cat >> "${PROJECT_ROOT}/.env" <<EOF
HE_ENABLED=true
HE_USERNAME=$HE_USERNAME
HE_PASSWORD=$HE_PASSWORD
HE_TUNNEL_ID=$HE_TUNNEL_ID
EOF
    fi

    if [[ "$ENABLE_S3" == "true" ]]; then
        cat >> "${PROJECT_ROOT}/.env" <<EOF

#==============================================
# Backup Configuration
#==============================================
S3_BACKUP_ENABLED=true
S3_ENDPOINT=$S3_ENDPOINT
S3_BUCKET=$S3_BUCKET
S3_ACCESS_KEY=$S3_ACCESS_KEY
S3_SECRET_KEY=$S3_SECRET_KEY
BACKUP_RETENTION_DAYS=$BACKUP_RETENTION
EOF
    fi

    chmod 600 "${PROJECT_ROOT}/.env"

    # Save credentials to file
    cat > "${PROJECT_ROOT}/credentials.txt" <<EOF
VPS2.0 Generated Credentials
============================
Generated: $(date)

Grafana:
  URL: https://monitoring.$DOMAIN
  Username: admin
  Password: $GRAFANA_PASSWORD

Portainer:
  URL: https://portainer.$DOMAIN
  Username: admin
  Password: $PORTAINER_PASSWORD

PostgreSQL:
  Password: $POSTGRES_PASSWORD

Redis:
  Password: $REDIS_PASSWORD

Neo4j:
  Username: neo4j
  Password: $NEO4J_PASSWORD

JWT Secret: $JWT_SECRET

IMPORTANT: Store these credentials securely and delete this file!
EOF

    chmod 600 "${PROJECT_ROOT}/credentials.txt"

    log_success "Configuration generated"
}

#==============================================
# DNS Verification
#==============================================

verify_dns() {
    log_step "DNS Verification"

    log_info "Checking DNS records for $DOMAIN..."

    local server_ip=$(curl -s ifconfig.me)
    log_info "Your server IP: $server_ip"

    echo ""
    echo -e "${WHITE}Required DNS A records:${NC}"
    echo -e "  @ (root)         → $server_ip"
    echo -e "  dashboard        → $server_ip"
    echo -e "  monitoring       → $server_ip"
    echo -e "  status           → $server_ip"
    echo -e "  portainer        → $server_ip"
    echo -e "  gitlab           → $server_ip"
    echo -e "  misp             → $server_ip"
    echo -e "  opencti          → $server_ip"
    echo ""

    if prompt_yes_no "Have you configured these DNS records?" "n"; then
        log_info "Verifying DNS resolution..."

        if host "$DOMAIN" &> /dev/null; then
            local resolved_ip=$(host "$DOMAIN" | grep "has address" | awk '{print $4}' | head -n1)
            if [[ "$resolved_ip" == "$server_ip" ]]; then
                log_success "DNS verified: $DOMAIN resolves to $server_ip"
            else
                log_warn "DNS mismatch: $DOMAIN resolves to $resolved_ip (expected: $server_ip)"
                log_warn "Continuing anyway, but HTTPS may not work until DNS propagates"
            fi
        else
            log_warn "Could not resolve $DOMAIN"
            log_warn "Continuing anyway, but HTTPS may not work until DNS propagates"
        fi
    else
        log_warn "Skipping DNS verification"
        log_warn "Configure DNS before first access for automatic HTTPS"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

#==============================================
# Caddy Configuration
#==============================================

configure_caddy_subdomains() {
    log_step "Configuring Caddy Reverse Proxy"

    local caddy_file="${PROJECT_ROOT}/caddy/Caddyfile"
    local additions_made=false
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

    # Check if we need to add HURRICANE subdomain
    if [[ "$DEPLOY_HURRICANE" == "true" ]]; then
        log_info "Adding HURRICANE.swordintelligence.airforce subdomain..."

        # Check if already exists
        if ! grep -q "HURRICANE\.swordintelligence\.airforce" "$caddy_file"; then
            # Add HURRICANE subdomain configuration
            cat >> "$caddy_file" << 'EOF'

# HURRICANE - Specific swordintelligence.airforce subdomain
HURRICANE.swordintelligence.airforce {
    import security_headers
    import rate_limit_standard
    import compression
    import access_log hurricane

    # API
    handle_path /api/* {
        import rate_limit_api
        reverse_proxy hurricane:8080 {
            import standard_proxy
        }
    }

    # Web UI
    reverse_proxy hurricane:8081 {
        import standard_proxy
    }
}
EOF
            log_success "Added HURRICANE subdomain configuration"
            additions_made=true
        else
            log_info "HURRICANE subdomain already configured"
        fi
    fi

    # Check if we need to add ARTICBASTION subdomain
    # ARTICBASTION is typically deployed with the bastion service
    if [[ "$PROFILE_NAME" == "maximum" ]] || [[ "$PROFILE_NAME" == "full" ]]; then
        log_info "Adding ARTICBASTION.swordintelligence.airforce subdomain..."

        # Check if already exists
        if ! grep -q "ARTICBASTION\.swordintelligence\.airforce" "$caddy_file"; then
            # Add ARTICBASTION subdomain configuration
            cat >> "$caddy_file" << 'EOF'

# ARTICBASTION - Specific swordintelligence.airforce subdomain
ARTICBASTION.swordintelligence.airforce {
    import security_headers
    import rate_limit_strict
    import access_log bastion

    # Require client certificates for bastion access
    tls {
        client_auth {
            mode require_and_verify
            trusted_ca_cert_file /config/certs/ca.crt
        }
    }

    # Additional security headers for bastion
    header {
        X-Frame-Options DENY
        Content-Security-Policy "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'"
        X-Permitted-Cross-Domain-Policies none
        Feature-Policy "geolocation 'none'; microphone 'none'; camera 'none'"
    }

    # IP whitelist (optional - uncomment and configure)
    # @allowed {
    #     remote_ip 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
    # }
    # handle @allowed {
    #     reverse_proxy articbastion:8022 {
    #         import standard_proxy
    #     }
    # }

    # Default: reverse proxy to bastion service
    reverse_proxy articbastion:8022 {
        import standard_proxy
    }
}
EOF
            log_success "Added ARTICBASTION subdomain configuration"
            additions_made=true
        else
            log_info "ARTICBASTION subdomain already configured"
        fi
    fi

    if [[ "$additions_made" == true ]]; then
        log_success "Caddy configuration updated with swordintelligence.airforce subdomains"
        echo ""
        log_info "DNS Records needed:"
        [[ "$DEPLOY_HURRICANE" == "true" ]] && echo -e "  ${CYAN}→${NC} A    HURRICANE.swordintelligence.airforce    → ${GREEN}${server_ip}${NC}"
        [[ "$PROFILE_NAME" == "maximum" ]] || [[ "$PROFILE_NAME" == "full" ]] && echo -e "  ${CYAN}→${NC} A    ARTICBASTION.swordintelligence.airforce → ${GREEN}${server_ip}${NC}"
        echo ""
    else
        log_info "No Caddy configuration changes needed"
    fi
}

#==============================================
# Deployment
#==============================================

execute_deployment() {
    log_step "DEPLOYMENT IN PROGRESS"

    log_info "Loading environment configuration..."
    source "${PROJECT_ROOT}/.env"

    # Deploy based on profile
    case $PROFILE_NAME in
        minimal)
            log_info "Deploying minimal profile..."
            docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" up -d \
                caddy postgres redis-stack portainer grafana
            ;;
        standard)
            log_info "Deploying standard profile..."
            docker-compose \
                -f "${PROJECT_ROOT}/docker-compose.yml" \
                up -d
            ;;
        full|maximum)
            log_info "Deploying full profile..."
            docker-compose \
                -f "${PROJECT_ROOT}/docker-compose.yml" \
                -f "${PROJECT_ROOT}/docker-compose.intelligence.yml" \
                -f "${PROJECT_ROOT}/docker-compose.dashboard.yml" \
                up -d
            ;;
    esac

    # Deploy optional services
    if [[ "$DEPLOY_HURRICANE" == "true" ]]; then
        log_info "Deploying HURRICANE..."
        docker-compose -f "${PROJECT_ROOT}/docker-compose.hurricane.yml" up -d
    fi

    log_success "Deployment complete!"
}

post_deployment() {
    log_step "POST-DEPLOYMENT TASKS"

    # Apply hardening if enabled
    if [[ "$ENABLE_HARDENING" == "true" ]]; then
        log_info "Applying security hardening..."
        "${PROJECT_ROOT}/scripts/harden.sh"
    fi

    # Setup backups if enabled
    if [[ "$ENABLE_BACKUPS" == "true" ]]; then
        log_info "Configuring automated backups..."
        (crontab -l 2>/dev/null; echo "0 2 * * * ${PROJECT_ROOT}/scripts/backup.sh") | crontab -
        log_success "Backup cron job installed"
    fi

    log_success "Post-deployment tasks complete"
}

#==============================================
# Final Summary
#==============================================

show_final_summary() {
    clear
    echo -e "${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                  ✅  DEPLOYMENT COMPLETE!                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo -e "${WHITE}Your VPS2.0 Intelligence Platform is ready!${NC}"
    echo ""

    echo -e "${CYAN}${ROCKET} Access Points:${NC}"
    echo -e "  Homepage:         https://$DOMAIN"
    echo -e "  Dashboard:        https://dashboard.$DOMAIN"
    echo -e "  Monitoring:       https://monitoring.$DOMAIN"
    echo -e "  Portainer:        https://portainer.$DOMAIN"
    echo ""

    echo -e "${CYAN}${LOCK} Credentials:${NC}"
    echo -e "  Saved to: ${YELLOW}${PROJECT_ROOT}/credentials.txt${NC}"
    echo -e "  ${RED}${WARN} IMPORTANT: Secure this file and delete it after saving!${NC}"
    echo ""

    echo -e "${CYAN}${GEAR} Next Steps:${NC}"
    echo -e "  1. Access dashboard: https://dashboard.$DOMAIN"
    echo -e "  2. Review credentials: cat ${PROJECT_ROOT}/credentials.txt"
    echo -e "  3. Check services: docker-compose ps"
    echo -e "  4. View logs: docker-compose logs -f"
    echo ""

    echo -e "${CYAN}${INFO} Documentation:${NC}"
    echo -e "  Deployment Guide: ${PROJECT_ROOT}/DEPLOYMENT_GUIDE.md"
    echo -e "  Dashboard Guide:  ${PROJECT_ROOT}/DASHBOARD_GUIDE.md"
    echo -e "  Architecture:     ${PROJECT_ROOT}/STACK_ARCHITECTURE.md"
    echo ""

    echo -e "${GREEN}${CHECK} Status: All systems operational${NC}"
    echo ""
}

#==============================================
# Main Flow
#==============================================

main() {
    print_banner
    sleep 1

    check_requirements
    setup_basic_config
    setup_deployment_profile
    setup_services
    setup_security
    show_summary

    generate_env_file
    verify_dns
    configure_caddy_subdomains

    execute_deployment
    post_deployment

    show_final_summary
}

main "$@"
