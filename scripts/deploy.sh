#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 Deployment Script
# Deploys the complete software stack in phases

#==============================================
# Configuration
#==============================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly DOCKER_DIR="/srv/docker"
readonly BACKUP_DIR="/srv/backups"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

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
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

check_requirements() {
    log_info "Checking system requirements..."

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    # Check available disk space (minimum 100GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 104857600 ]]; then  # 100GB in KB
        log_warn "Less than 100GB disk space available"
    fi

    # Check available RAM (minimum 16GB)
    local total_ram=$(free -g | awk 'NR==2 {print $2}')
    if [[ $total_ram -lt 16 ]]; then
        log_warn "Less than 16GB RAM available (recommended: 32GB+)"
    fi

    log_success "System requirements check passed"
}

create_directories() {
    log_info "Creating directory structure..."

    local dirs=(
        "$DOCKER_DIR"
        "$BACKUP_DIR"
        "/var/log/vps2.0"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chmod 750 "$dir"
    done

    log_success "Directory structure created"
}

generate_env_file() {
    log_info "Generating environment configuration..."

    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        log_warn ".env file already exists, skipping generation"
        return 0
    fi

    cp "${PROJECT_ROOT}/.env.template" "${PROJECT_ROOT}/.env"

    # Generate secure passwords
    local postgres_password=$(openssl rand -base64 32)
    local redis_password=$(openssl rand -base64 32)
    local neo4j_password=$(openssl rand -base64 32)
    local jwt_secret=$(openssl rand -base64 64)
    local grafana_password=$(openssl rand -base64 24)

    # Update .env file
    sed -i "s/POSTGRES_PASSWORD=CHANGE_ME_STRONG_PASSWORD_HERE/POSTGRES_PASSWORD=${postgres_password}/" "${PROJECT_ROOT}/.env"
    sed -i "s/REDIS_PASSWORD=CHANGE_ME_STRONG_PASSWORD_HERE/REDIS_PASSWORD=${redis_password}/" "${PROJECT_ROOT}/.env"
    sed -i "s/NEO4J_PASSWORD=CHANGE_ME_STRONG_PASSWORD_HERE/NEO4J_PASSWORD=${neo4j_password}/" "${PROJECT_ROOT}/.env"
    sed -i "s/JWT_SECRET=CHANGE_ME_RANDOM_64_CHAR_STRING_HERE/JWT_SECRET=${jwt_secret}/" "${PROJECT_ROOT}/.env"
    sed -i "s/GRAFANA_ADMIN_PASSWORD=CHANGE_ME_STRONG_PASSWORD_HERE/GRAFANA_ADMIN_PASSWORD=${grafana_password}/" "${PROJECT_ROOT}/.env"

    # Generate Portainer password hash
    local portainer_password=$(openssl rand -base64 24)
    local portainer_hash=$(docker run --rm httpd:2.4-alpine htpasswd -nbB admin "$portainer_password" | cut -d ":" -f 2)
    sed -i "s|PORTAINER_PASSWORD_HASH=CHANGE_ME_BCRYPT_HASH_HERE|PORTAINER_PASSWORD_HASH=${portainer_hash}|" "${PROJECT_ROOT}/.env"

    # Store credentials securely
    cat > "${PROJECT_ROOT}/credentials.txt" <<EOF
VPS2.0 Generated Credentials
=============================
Generated on: $(date)

PostgreSQL Password: ${postgres_password}
Redis Password: ${redis_password}
Neo4j Password: ${neo4j_password}
JWT Secret: ${jwt_secret}
Grafana Admin Password: ${grafana_password}
Portainer Admin Password: ${portainer_password}

IMPORTANT: Store these credentials securely and delete this file!
EOF

    chmod 600 "${PROJECT_ROOT}/credentials.txt"

    log_success "Environment configuration generated"
    log_warn "Credentials saved to ${PROJECT_ROOT}/credentials.txt - SECURE AND DELETE THIS FILE!"
}

deploy_phase1() {
    log_info "Deploying Phase 1: Foundation Services..."

    cd "$PROJECT_ROOT"

    # Pull images
    log_info "Pulling Docker images..."
    docker-compose pull

    # Start services
    log_info "Starting foundation services..."
    docker-compose up -d \
        caddy \
        postgres \
        pgbouncer \
        redis-stack \
        neo4j \
        portainer \
        watchtower \
        victoriametrics \
        grafana \
        loki \
        vector \
        node-exporter \
        cadvisor

    # Wait for databases to be ready
    log_info "Waiting for databases to initialize..."
    sleep 30

    # Initialize databases
    log_info "Initializing databases..."
    docker-compose exec -T postgres psql -U postgres -f /docker-entrypoint-initdb.d/01-create-databases.sql

    log_success "Phase 1 deployment complete"
}

deploy_phase2() {
    log_info "Deploying Phase 2: Intelligence Services..."

    cd "$PROJECT_ROOT"

    log_info "Pulling intelligence service images..."
    docker-compose -f docker-compose.yml -f docker-compose.intelligence.yml pull

    log_info "Starting intelligence services..."
    docker-compose -f docker-compose.yml -f docker-compose.intelligence.yml up -d

    log_success "Phase 2 deployment complete"
}

deploy_hurricane() {
    log_info "Deploying HURRICANE IPv6 Proxy (optional)..."

    read -p "Do you want to deploy HURRICANE? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping HURRICANE deployment"
        return 0
    fi

    cd "$PROJECT_ROOT"

    # Update .env to enable HURRICANE
    sed -i "s/HURRICANE_ENABLED=false/HURRICANE_ENABLED=true/" "${PROJECT_ROOT}/.env"

    log_info "Building and starting HURRICANE..."
    docker-compose -f docker-compose.yml -f docker-compose.hurricane.yml up -d --build hurricane

    log_success "HURRICANE deployment complete"
}

configure_firewall() {
    log_info "Configuring firewall..."
    log_warn "Preserving port 22 for SSH - ensuring it remains accessible"

    # Check if UFW is installed
    if ! command -v ufw &> /dev/null; then
        log_warn "UFW not installed, skipping firewall configuration"
        return 0
    fi

    # Reset UFW
    ufw --force reset

    # Default policies
    ufw default deny incoming
    ufw default allow outgoing

    # CRITICAL: Allow SSH on port 22 (user requirement - DO NOT ALTER)
    ufw allow 22/tcp comment "SSH - DO NOT REMOVE"

    # Allow HTTP/HTTPS
    ufw allow 80/tcp comment "HTTP"
    ufw allow 443/tcp comment "HTTPS"
    ufw allow 443/udp comment "HTTP/3"

    # Allow WireGuard VPN
    ufw allow 51820/udp comment "WireGuard VPN"

    # Allow bastion SSH
    ufw allow 2222/tcp comment "Bastion SSH"

    # Enable UFW
    ufw --force enable

    log_success "Firewall configured"
}

setup_systemd_service() {
    log_info "Creating systemd service for VPS2.0..."

    cat > /etc/systemd/system/vps2.0.service <<'EOF'
[Unit]
Description=VPS2.0 Software Stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/user/VPS2.0
ExecStart=/usr/bin/docker-compose -f docker-compose.yml -f docker-compose.intelligence.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.yml -f docker-compose.intelligence.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable vps2.0.service

    log_success "Systemd service created and enabled"
}

print_access_info() {
    log_success "Deployment complete!"
    echo ""
    echo "=========================================="
    echo "VPS2.0 Access Information"
    echo "=========================================="
    echo ""
    echo "Portainer: https://portainer.${DOMAIN:-localhost}"
    echo "Grafana: https://monitoring.${DOMAIN:-localhost}"
    echo "GitLab: https://gitlab.${DOMAIN:-localhost}"
    echo "SWORDINTELLIGENCE: https://swordintel.${DOMAIN:-localhost}"
    echo "MISP: https://misp.${DOMAIN:-localhost}"
    echo "OpenCTI: https://opencti.${DOMAIN:-localhost}"
    echo ""
    echo "IMPORTANT:"
    echo "1. Review and secure credentials in: ${PROJECT_ROOT}/credentials.txt"
    echo "2. Configure your domain DNS to point to this server"
    echo "3. Review firewall rules: ufw status"
    echo "4. Check service health: docker-compose ps"
    echo "5. View logs: docker-compose logs -f [service]"
    echo ""
    echo "Next Steps:"
    echo "1. Run: ./scripts/harden.sh (to apply security hardening)"
    echo "2. Run: ./scripts/backup.sh (to configure backups)"
    echo "3. Configure WireGuard VPN for admin access"
    echo ""
    echo "=========================================="
}

#==============================================
# Main Deployment Flow
#==============================================

main() {
    log_info "Starting VPS2.0 deployment..."
    echo ""

    # Pre-flight checks
    check_requirements
    create_directories
    generate_env_file

    # Load environment
    source "${PROJECT_ROOT}/.env"

    # Deploy in phases
    deploy_phase1
    deploy_phase2
    deploy_hurricane

    # Post-deployment configuration
    configure_firewall
    setup_systemd_service

    # Print access information
    print_access_info

    log_success "VPS2.0 deployment completed successfully!"
}

# Run main function
main "$@"
