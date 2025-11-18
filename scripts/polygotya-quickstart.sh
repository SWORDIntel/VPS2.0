#!/usr/bin/env bash
set -euo pipefail

# POLYGOTYA Quick Start Script
# Easy setup and configuration for POLYGOTYA SSH Callback Server

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

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

#==============================================
# Setup Functions
#==============================================

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check if Docker is running
    if ! docker ps >/dev/null 2>&1; then
        log_error "Docker is not running or not accessible"
        exit 1
    fi
    log_success "Docker is running"

    # Check if .env exists
    if [[ ! -f "${PROJECT_ROOT}/.env" ]]; then
        log_error ".env file not found. Please run ./scripts/deploy.sh first"
        exit 1
    fi
    log_success ".env file exists"

    # Check if POLYGOTYA is enabled
    source "${PROJECT_ROOT}/.env"
    if [[ "${DEPLOY_POLYGOTYA:-false}" != "true" ]]; then
        log_warn "POLYGOTYA is not enabled in .env"
        read -p "Enable POLYGOTYA now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sed -i "s/DEPLOY_POLYGOTYA=false/DEPLOY_POLYGOTYA=true/" "${PROJECT_ROOT}/.env"
            log_success "POLYGOTYA enabled in .env"
        else
            log_error "POLYGOTYA must be enabled to continue"
            exit 1
        fi
    else
        log_success "POLYGOTYA is enabled"
    fi
}

generate_credentials() {
    print_header "Generating Credentials"

    source "${PROJECT_ROOT}/.env"

    # Check if credentials need to be generated
    local need_update=false

    if [[ "${POLYGOTYA_API_KEY:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
        log_info "Generating API key..."
        local api_key=$(openssl rand -base64 32)
        sed -i "s|POLYGOTYA_API_KEY=.*|POLYGOTYA_API_KEY=${api_key}|" "${PROJECT_ROOT}/.env"
        log_success "API key generated"
        need_update=true
    else
        log_info "API key already set"
    fi

    if [[ "${POLYGOTYA_SECRET_KEY:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
        log_info "Generating session secret..."
        local secret_key=$(openssl rand -hex 32)
        sed -i "s|POLYGOTYA_SECRET_KEY=.*|POLYGOTYA_SECRET_KEY=${secret_key}|" "${PROJECT_ROOT}/.env"
        log_success "Session secret generated"
        need_update=true
    else
        log_info "Session secret already set"
    fi

    if [[ "${POLYGOTYA_ADMIN_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
        log_info "Generating admin password..."
        local admin_pass=$(openssl rand -base64 24)
        sed -i "s|POLYGOTYA_ADMIN_PASSWORD=.*|POLYGOTYA_ADMIN_PASSWORD=${admin_pass}|" "${PROJECT_ROOT}/.env"
        log_success "Admin password generated"
        need_update=true
    else
        log_info "Admin password already set"
    fi

    if [[ "$need_update" == "true" ]]; then
        log_warn "New credentials generated. Please save these to your password manager!"
    fi
}

deploy_polygotya() {
    print_header "Deploying POLYGOTYA"

    cd "$PROJECT_ROOT"

    log_info "Starting POLYGOTYA container..."
    docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml up -d polygotya

    log_info "Waiting for POLYGOTYA to initialize (15s)..."
    sleep 15

    # Check if container is running
    if docker ps | grep -q polygotya; then
        log_success "POLYGOTYA container is running"
    else
        log_error "POLYGOTYA container failed to start"
        log_info "Showing logs:"
        docker logs polygotya --tail 50
        exit 1
    fi

    # Check health endpoint
    log_info "Checking health endpoint..."
    sleep 5
    if curl -sSf http://localhost:5000/health >/dev/null 2>&1; then
        log_success "Health endpoint is responding"
    else
        log_warn "Health endpoint not yet ready (may need DNS configuration)"
    fi
}

display_credentials() {
    print_header "POLYGOTYA Access Information"

    source "${PROJECT_ROOT}/.env"

    echo "  Dashboard URL:"
    echo -e "    ${CYAN}https://polygotya.swordintelligence.airforce${NC}"
    echo ""

    echo "  Admin Credentials:"
    echo "    Username: admin"
    echo -e "    Password: ${GREEN}${POLYGOTYA_ADMIN_PASSWORD}${NC}"
    echo ""

    echo "  API Key (for callbacks):"
    echo -e "    ${GREEN}${POLYGOTYA_API_KEY}${NC}"
    echo ""

    echo "  DGA Seed (for encryption):"
    echo -e "    ${POLYGOTYA_DGA_SEED:-insovietrussiawehackyou}"
    echo ""

    echo "  Callback URL:"
    echo -e "    ${CYAN}${POLYGOTYA_CALLBACK_URL:-https://polygotya.swordintelligence.airforce}${NC}"
    echo ""
}

show_usage_examples() {
    print_header "Usage Examples"

    source "${PROJECT_ROOT}/.env"

    echo "  1. Test Health Endpoint:"
    echo -e "     ${CYAN}curl https://polygotya.swordintelligence.airforce/health${NC}"
    echo ""

    echo "  2. Send Test Callback (Encrypted):"
    echo -e "     ${CYAN}cd ${PROJECT_ROOT}/ssh-callback-server${NC}"
    echo -e "     ${CYAN}python3 client_callback.py --api-key ${POLYGOTYA_API_KEY} --auto-detect${NC}"
    echo ""

    echo "  3. Send Test Callback (Unencrypted - Legacy):"
    echo -e "     ${CYAN}curl -X POST -H 'Content-Type: application/json' \\${NC}"
    echo -e "     ${CYAN}  -d '{\"api_key\":\"${POLYGOTYA_API_KEY}\",\"hostname\":\"test-host\",\"os_type\":\"linux\"}' \\${NC}"
    echo -e "     ${CYAN}  https://polygotya.swordintelligence.airforce/api/register${NC}"
    echo ""

    echo "  4. View Container Logs:"
    echo -e "     ${CYAN}docker logs -f polygotya${NC}"
    echo ""

    echo "  5. Backup POLYGOTYA Database:"
    echo -e "     ${CYAN}docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \".backup /data/backup.db\"${NC}"
    echo -e "     ${CYAN}docker cp polygotya:/data/backup.db ./polygotya-backup-\$(date +%Y%m%d).db${NC}"
    echo ""
}

show_next_steps() {
    print_header "Next Steps"

    echo "  1. ${YELLOW}⚠  CHANGE ADMIN PASSWORD${NC}"
    echo "     - Login to https://polygotya.swordintelligence.airforce"
    echo "     - Use admin credentials shown above"
    echo "     - Change password immediately"
    echo ""

    echo "  2. ${GREEN}✓${NC}  Configure DNS"
    echo "     - Ensure polygotya.swordintelligence.airforce points to this server"
    echo "     - Caddy will automatically obtain SSL certificate"
    echo ""

    echo "  3. ${GREEN}✓${NC}  Test Encrypted Callbacks"
    echo "     - Use client_callback.py with --api-key flag"
    echo "     - Verify encryption works (check logs for 'encrypted' field)"
    echo ""

    echo "  4. ${GREEN}✓${NC}  Save Credentials Securely"
    echo "     - Store API key in password manager"
    echo "     - Store admin password in password manager"
    echo "     - Store DGA seed securely (needed for client-side encryption)"
    echo ""

    echo "  5. ${GREEN}✓${NC}  Set Up Backup Automation"
    echo "     - Add to crontab: 0 2 * * * ${PROJECT_ROOT}/scripts/backup.sh"
    echo "     - Backups include POLYGOTYA database and configuration"
    echo ""

    echo "  6. ${GREEN}✓${NC}  Configure Client Systems"
    echo "     - Deploy client_callback.py to target systems"
    echo "     - Set API key and DGA seed (must match server)"
    echo "     - Configure callback URL if different from default"
    echo ""
}

check_firewall() {
    print_header "Firewall Check"

    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_info "UFW Firewall Status:"
            ufw status | grep -E "(80|443)" || log_warn "Ports 80/443 not explicitly allowed"

            if ! ufw status | grep -qE "(80|443)"; then
                log_warn "HTTPS (443) may not be allowed through firewall"
                read -p "Allow HTTP (80) and HTTPS (443) through firewall? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    ufw allow 80/tcp
                    ufw allow 443/tcp
                    log_success "Firewall rules added"
                fi
            fi
        else
            log_info "UFW is installed but not active"
        fi
    else
        log_info "UFW not installed (firewall check skipped)"
    fi
}

#==============================================
# Main Setup Flow
#==============================================

main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              POLYGOTYA Quick Start Setup                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        SSH Callback Server with Post-Quantum Crypto          ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Run setup steps
    check_prerequisites
    generate_credentials
    deploy_polygotya
    check_firewall

    # Display information
    display_credentials
    show_usage_examples
    show_next_steps

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}              POLYGOTYA Setup Complete!                        ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Documentation:"
    echo "    - Full docs: ${PROJECT_ROOT}/docs/POLYGOTYA.md"
    echo "    - Secure README: ${PROJECT_ROOT}/ssh-callback-server/README_SECURE.md"
    echo "    - Client script: ${PROJECT_ROOT}/ssh-callback-server/client_callback.py"
    echo ""
}

# Run main function
main "$@"
