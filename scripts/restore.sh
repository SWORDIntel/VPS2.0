#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 Restore Script
# Restores VPS2.0 from backup archive

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

usage() {
    cat <<EOF
VPS2.0 Restore Script

Usage: $0 <backup-file>

Arguments:
  <backup-file>    Path to the backup tarball (e.g., /srv/backups/20241118_120000.tar.gz)

Options:
  -h, --help       Show this help message

Examples:
  $0 /srv/backups/20241118_120000.tar.gz
  $0 backup.tar.gz

EOF
    exit 1
}

verify_backup() {
    local backup_file="$1"

    log_info "Verifying backup file..."

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi

    # Verify checksum if available
    if [[ -f "${backup_file}.sha256" ]]; then
        log_info "Verifying checksum..."
        if sha256sum -c "${backup_file}.sha256"; then
            log_success "Checksum verification passed"
        else
            log_error "Checksum verification failed!"
            exit 1
        fi
    else
        log_warn "No checksum file found, skipping verification"
    fi

    log_success "Backup file verified"
}

extract_backup() {
    local backup_file="$1"
    local extract_dir="/tmp/vps2.0-restore-$$"

    log_info "Extracting backup to $extract_dir..."

    mkdir -p "$extract_dir"
    tar xzf "$backup_file" -C "$extract_dir" --strip-components=1

    echo "$extract_dir"
}

stop_services() {
    log_warn "Stopping all VPS2.0 services..."

    cd "$PROJECT_ROOT"

    # Stop all compose stacks
    docker-compose down 2>/dev/null || true
    docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml down 2>/dev/null || true
    docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml down 2>/dev/null || true
    docker-compose -f docker-compose.intelligence.yml down 2>/dev/null || true
    docker-compose -f docker-compose.hurricane.yml down 2>/dev/null || true

    log_success "Services stopped"
}

restore_configurations() {
    local backup_dir="$1"

    log_info "Restoring configurations..."

    # Backup current configs
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        log_info "Backing up current .env to .env.pre-restore"
        cp "${PROJECT_ROOT}/.env" "${PROJECT_ROOT}/.env.pre-restore"
    fi

    # Restore docker-compose files
    cp "${backup_dir}"/configs/docker-compose*.yml "${PROJECT_ROOT}/" 2>/dev/null || true

    # Restore Caddy configuration
    if [[ -d "${backup_dir}/configs/caddy" ]]; then
        cp -r "${backup_dir}/configs/caddy" "${PROJECT_ROOT}/"
    fi

    # Restore Prometheus configuration
    if [[ -d "${backup_dir}/configs/prometheus" ]]; then
        cp -r "${backup_dir}/configs/prometheus" "${PROJECT_ROOT}/"
    fi

    # Restore Loki configuration
    if [[ -d "${backup_dir}/configs/loki" ]]; then
        cp -r "${backup_dir}/configs/loki" "${PROJECT_ROOT}/"
    fi

    # Restore Vector configuration
    if [[ -d "${backup_dir}/configs/vector" ]]; then
        cp -r "${backup_dir}/configs/vector" "${PROJECT_ROOT}/"
    fi

    # Restore HURRICANE configuration
    if [[ -d "${backup_dir}/configs/hurricane" ]]; then
        mkdir -p "${PROJECT_ROOT}/hurricane"
        cp -r "${backup_dir}/configs/hurricane" "${PROJECT_ROOT}/hurricane/config"
    fi

    # Restore Mattermost configuration
    if [[ -d "${backup_dir}/configs/mattermost" ]]; then
        mkdir -p "${PROJECT_ROOT}/mattermost"
        cp -r "${backup_dir}/configs/mattermost/boards" "${PROJECT_ROOT}/mattermost/" 2>/dev/null || true
    fi

    # Restore POLYGOTYA configuration
    if [[ -d "${backup_dir}/configs/polygotya" ]]; then
        mkdir -p "${PROJECT_ROOT}/ssh-callback-server"
        cp "${backup_dir}/configs/polygotya/"* "${PROJECT_ROOT}/ssh-callback-server/" 2>/dev/null || true
    fi

    log_success "Configurations restored"
}

restore_databases() {
    local backup_dir="$1"

    log_info "Restoring databases..."

    cd "$PROJECT_ROOT"

    # Start database services only
    log_info "Starting database services..."
    docker-compose up -d postgres redis-stack neo4j

    # Wait for databases to be ready
    log_info "Waiting for databases to be ready (30s)..."
    sleep 30

    # Restore PostgreSQL
    if [[ -f "${backup_dir}/databases/postgres_all.sql.gz" ]]; then
        log_info "Restoring PostgreSQL databases..."
        gunzip -c "${backup_dir}/databases/postgres_all.sql.gz" | docker-compose exec -T postgres psql -U postgres
    fi

    # Restore Neo4j
    if [[ -f "${backup_dir}/databases/neo4j.dump.gz" ]]; then
        log_info "Restoring Neo4j database..."
        docker-compose stop neo4j
        gunzip -c "${backup_dir}/databases/neo4j.dump.gz" | docker-compose run --rm neo4j neo4j-admin database load neo4j --from-stdin --overwrite-destination=true
        docker-compose start neo4j
    fi

    # Restore Redis
    if [[ -f "${backup_dir}/databases/redis.rdb.gz" ]]; then
        log_info "Restoring Redis database..."
        docker-compose stop redis-stack
        gunzip -c "${backup_dir}/databases/redis.rdb.gz" > /tmp/dump.rdb
        docker cp /tmp/dump.rdb "$(docker-compose ps -q redis-stack):/data/dump.rdb"
        rm /tmp/dump.rdb
        docker-compose start redis-stack
    fi

    # Restore Mattermost Database
    if [[ -f "${backup_dir}/databases/mattermost_postgres.sql.gz" ]]; then
        log_info "Restoring Mattermost PostgreSQL database..."
        docker-compose -f docker-compose.mattermost.yml up -d mattermost-db
        sleep 10
        gunzip -c "${backup_dir}/databases/mattermost_postgres.sql.gz" | docker-compose -f docker-compose.mattermost.yml exec -T mattermost-db psql -U mmuser -d mattermost
    fi

    # Restore POLYGOTYA Database
    if [[ -f "${backup_dir}/databases/polygotya.db.gz" ]]; then
        log_info "Restoring POLYGOTYA SQLite database..."
        gunzip -c "${backup_dir}/databases/polygotya.db.gz" > /tmp/polygotya.db
        docker-compose -f docker-compose.polygotya.yml up -d polygotya
        sleep 5
        docker cp /tmp/polygotya.db polygotya:/data/ssh_callbacks_secure.db
        rm /tmp/polygotya.db
        docker-compose -f docker-compose.polygotya.yml restart polygotya
    fi

    log_success "Databases restored"
}

restore_volumes() {
    local backup_dir="$1"

    log_info "Restoring Docker volumes..."

    # Get list of volume backups
    local volumes=()
    while IFS= read -r -d '' file; do
        local volume_name=$(basename "$file" .tar.gz)
        volumes+=("$volume_name")
    done < <(find "${backup_dir}/volumes" -name "*.tar.gz" -print0 2>/dev/null)

    for volume in "${volumes[@]}"; do
        if [[ -f "${backup_dir}/volumes/${volume}.tar.gz" ]]; then
            log_info "Restoring volume: $volume..."

            # Create volume if it doesn't exist
            docker volume create "$volume" >/dev/null 2>&1 || true

            # Restore volume data
            docker run --rm \
                -v "${volume}:/data" \
                -v "${backup_dir}/volumes:/backup" \
                alpine sh -c "cd /data && tar xzf /backup/${volume}.tar.gz"
        fi
    done

    log_success "Volumes restored"
}

start_services() {
    log_info "Starting all services..."

    cd "$PROJECT_ROOT"

    # Load environment
    source "${PROJECT_ROOT}/.env" 2>/dev/null || true

    # Start core services
    docker-compose up -d

    # Start optional services based on .env
    if [[ "${DEPLOY_MATTERMOST:-false}" == "true" ]]; then
        log_info "Starting Mattermost services..."
        docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d
    fi

    if [[ "${DEPLOY_POLYGOTYA:-false}" == "true" ]]; then
        log_info "Starting POLYGOTYA services..."
        docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml up -d
    fi

    if [[ "${HURRICANE_ENABLED:-false}" == "true" ]]; then
        log_info "Starting HURRICANE services..."
        docker-compose -f docker-compose.hurricane.yml up -d
    fi

    log_success "Services started"
}

verify_restoration() {
    log_info "Verifying restoration..."

    cd "$PROJECT_ROOT"

    # Wait for services to be healthy
    log_info "Waiting for services to be healthy (30s)..."
    sleep 30

    # Check running containers
    local running_containers=$(docker ps --format '{{.Names}}' | wc -l)
    log_info "Running containers: $running_containers"

    # Run verification script if available
    if [[ -x "${SCRIPT_DIR}/verify-deployment.sh" ]]; then
        log_info "Running deployment verification..."
        "${SCRIPT_DIR}/verify-deployment.sh" || true
    fi

    log_success "Restoration verification complete"
}

display_manifest() {
    local backup_dir="$1"

    if [[ -f "${backup_dir}/MANIFEST.txt" ]]; then
        echo ""
        log_info "Backup Manifest:"
        echo "========================================"
        cat "${backup_dir}/MANIFEST.txt"
        echo "========================================"
        echo ""
    fi
}

#==============================================
# Main Restore Flow
#==============================================

main() {
    local backup_file="${1:-}"

    # Check arguments
    if [[ -z "$backup_file" ]] || [[ "$backup_file" == "-h" ]] || [[ "$backup_file" == "--help" ]]; then
        usage
    fi

    # Expand path
    backup_file=$(realpath "$backup_file")

    log_info "Starting VPS2.0 restoration from: $backup_file"
    echo ""

    # Verify backup
    verify_backup "$backup_file"

    # Extract backup
    local backup_dir=$(extract_backup "$backup_file")
    log_info "Backup extracted to: $backup_dir"

    # Display manifest
    display_manifest "$backup_dir"

    # Confirm restoration
    log_warn "This will STOP all running services and REPLACE current data!"
    read -p "Are you sure you want to proceed? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Restoration cancelled"
        rm -rf "$backup_dir"
        exit 0
    fi

    # Perform restoration
    stop_services
    restore_configurations "$backup_dir"
    restore_databases "$backup_dir"
    restore_volumes "$backup_dir"
    start_services
    verify_restoration

    # Cleanup
    log_info "Cleaning up temporary files..."
    rm -rf "$backup_dir"

    echo ""
    log_success "VPS2.0 restoration complete!"
    echo ""
    echo "IMPORTANT POST-RESTORE STEPS:"
    echo "1. Verify all services are running: docker ps"
    echo "2. Check service health: ./scripts/verify-deployment.sh"
    echo "3. Review logs for any errors: docker-compose logs"
    echo "4. Restore .env secrets from your password manager"
    echo "5. Test service access via web browser"
    echo ""
}

# Run main function
main "$@"
