#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 Mattermost - Backup Script
# Backs up database, config, and object storage

#==============================================
# Configuration
#==============================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly BACKUP_DIR="${BACKUP_DIR:-/srv/backups/mattermost}"
readonly DATE=$(date +%Y%m%d-%H%M%S)
readonly BACKUP_NAME="mattermost-backup-${DATE}"

# Load environment variables
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    # shellcheck disable=SC1091
    source "${PROJECT_ROOT}/.env"
fi

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
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

check_containers() {
    if ! docker ps | grep -q "mattermost-db"; then
        log_error "Mattermost database container not running"
        return 1
    fi

    if ! docker ps | grep -q "mattermost"; then
        log_error "Mattermost application container not running"
        return 1
    fi

    return 0
}

#==============================================
# Backup Functions
#==============================================

backup_database() {
    log_info "Backing up PostgreSQL database..."

    docker exec mattermost-db pg_dump -U "${MATTERMOST_DB_USER:-mattermost}" mattermost | \
        gzip > "${BACKUP_DIR}/${BACKUP_NAME}/database.sql.gz"

    log_success "Database backup complete"
}

backup_config() {
    log_info "Backing up Mattermost configuration..."

    # Copy config directory
    docker cp mattermost:/mattermost/config "${BACKUP_DIR}/${BACKUP_NAME}/config"

    log_success "Configuration backup complete"
}

backup_plugins() {
    log_info "Backing up Mattermost plugins..."

    # Copy plugins directory
    docker cp mattermost:/mattermost/plugins "${BACKUP_DIR}/${BACKUP_NAME}/plugins" || true

    log_success "Plugins backup complete"
}

backup_minio() {
    log_info "Backing up MinIO object storage..."

    # Use MinIO client to backup bucket
    docker run --rm \
        --network mattermost_backend \
        -v "${BACKUP_DIR}/${BACKUP_NAME}":/backup \
        -e MINIO_ACCESS_KEY="${MATTERMOST_MINIO_ACCESS_KEY}" \
        -e MINIO_SECRET_KEY="${MATTERMOST_MINIO_SECRET_KEY}" \
        minio/mc:latest \
        /bin/sh -c "
            mc config host add minio http://mattermost-minio:9000 \$MINIO_ACCESS_KEY \$MINIO_SECRET_KEY && \
            mc mirror minio/mattermost /backup/minio
        "

    log_success "MinIO backup complete"
}

create_manifest() {
    log_info "Creating backup manifest..."

    cat > "${BACKUP_DIR}/${BACKUP_NAME}/manifest.txt" << EOF
Mattermost Backup Manifest
==========================
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Backup Name: ${BACKUP_NAME}

Components:
- PostgreSQL Database: database.sql.gz
- Configuration: config/
- Plugins: plugins/
- Object Storage: minio/

Versions:
- Mattermost: $(docker exec mattermost mattermost version | head -1)
- PostgreSQL: $(docker exec mattermost-db psql --version | head -1)

Environment:
- VPS IP: $(curl -s ifconfig.me 2>/dev/null || echo "unknown")
- Hostname: $(hostname)
EOF

    log_success "Manifest created"
}

compress_backup() {
    log_info "Compressing backup..."

    cd "${BACKUP_DIR}"
    tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
    rm -rf "${BACKUP_NAME}"

    log_success "Backup compressed: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
}

cleanup_old_backups() {
    local retention_days="${BACKUP_RETENTION_DAYS:-30}"

    log_info "Cleaning up backups older than ${retention_days} days..."

    find "${BACKUP_DIR}" -name "mattermost-backup-*.tar.gz" -mtime +${retention_days} -delete

    log_success "Old backups cleaned up"
}

#==============================================
# Main
#==============================================

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║           VPS2.0 Mattermost - Backup Script                    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Check if containers are running
    if ! check_containers; then
        log_error "Cannot proceed with backup"
        exit 1
    fi

    # Create backup directory
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"
    log_info "Backup directory: ${BACKUP_DIR}/${BACKUP_NAME}"
    echo ""

    # Perform backups
    backup_database
    backup_config
    backup_plugins
    backup_minio

    # Create manifest
    create_manifest

    # Compress
    compress_backup

    # Cleanup old backups
    cleanup_old_backups

    echo ""
    log_success "Backup completed successfully!"
    log_info "Backup location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    echo ""
}

main "$@"
