#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 Backup Script
# Performs comprehensive backup of all data and configurations

#==============================================
# Configuration
#==============================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly BACKUP_ROOT="${BACKUP_DIR:-/srv/backups}"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

# Colors for output
readonly GREEN='\033[0;32m'
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

ensure_backup_dir() {
    mkdir -p "${BACKUP_DIR}"/{databases,configs,volumes,logs}
    chmod 700 "${BACKUP_DIR}"
}

#==============================================
# Backup Functions
#==============================================

backup_databases() {
    log_info "Backing up databases..."

    cd "$PROJECT_ROOT"

    # PostgreSQL
    log_info "Backing up PostgreSQL..."
    docker-compose exec -T postgres pg_dumpall -U postgres | gzip > "${BACKUP_DIR}/databases/postgres_all.sql.gz"

    # Individual PostgreSQL databases
    for db in swordintel n8n gitlab; do
        log_info "Backing up PostgreSQL database: $db..."
        docker-compose exec -T postgres pg_dump -U postgres "$db" | gzip > "${BACKUP_DIR}/databases/postgres_${db}.sql.gz"
    done

    # Mattermost Database (if deployed)
    if docker-compose -f docker-compose.mattermost.yml ps 2>/dev/null | grep -q mattermost-db; then
        log_info "Backing up Mattermost PostgreSQL database..."
        docker-compose -f docker-compose.mattermost.yml exec -T mattermost-db pg_dump -U mmuser mattermost | gzip > "${BACKUP_DIR}/databases/mattermost_postgres.sql.gz"
    fi

    # POLYGOTYA SQLite Database (if deployed)
    if docker ps --format '{{.Names}}' | grep -q polygotya; then
        log_info "Backing up POLYGOTYA SQLite database..."
        docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db ".backup /data/polygotya_backup.db"
        docker cp polygotya:/data/polygotya_backup.db "${BACKUP_DIR}/databases/polygotya.db"
        gzip "${BACKUP_DIR}/databases/polygotya.db"
        docker exec polygotya rm -f /data/polygotya_backup.db
    fi

    # Neo4j
    log_info "Backing up Neo4j..."
    docker-compose exec -T neo4j neo4j-admin database dump neo4j --to-stdout | gzip > "${BACKUP_DIR}/databases/neo4j.dump.gz"

    # Redis
    log_info "Backing up Redis..."
    docker-compose exec -T redis-stack redis-cli --rdb /tmp/dump.rdb SAVE
    docker cp "$(docker-compose ps -q redis-stack):/tmp/dump.rdb" "${BACKUP_DIR}/databases/redis.rdb"
    gzip "${BACKUP_DIR}/databases/redis.rdb"

    # MISP MariaDB
    if docker-compose -f docker-compose.intelligence.yml ps | grep -q misp-db; then
        log_info "Backing up MISP MariaDB..."
        docker-compose -f docker-compose.intelligence.yml exec -T misp-db mysqldump -u root -p"${MISP_DB_ROOT_PASSWORD}" --all-databases | gzip > "${BACKUP_DIR}/databases/misp_mariadb.sql.gz"
    fi

    # OpenCTI Elasticsearch
    if docker-compose -f docker-compose.intelligence.yml ps | grep -q opencti-elasticsearch; then
        log_info "Backing up OpenCTI Elasticsearch..."
        docker-compose -f docker-compose.intelligence.yml exec -T opencti-elasticsearch curl -X PUT "localhost:9200/_snapshot/vps2.0_backup" -H 'Content-Type: application/json' -d'{"type":"fs","settings":{"location":"/usr/share/elasticsearch/backups"}}'
        docker-compose -f docker-compose.intelligence.yml exec -T opencti-elasticsearch curl -X PUT "localhost:9200/_snapshot/vps2.0_backup/snapshot_${TIMESTAMP}?wait_for_completion=true"
    fi

    log_success "Database backups complete"
}

backup_volumes() {
    log_info "Backing up Docker volumes..."

    cd "$PROJECT_ROOT"

    # List of important volumes to backup
    local volumes=(
        "portainer_data"
        "grafana_data"
        "caddy_data"
        "swordintel_uploads"
        "misp_data"
        "opencti_data"
        "gitlab_data"
        "gitlab_config"
        "n8n_data"
        "mattermost_data"
        "mattermost_config"
        "mattermost_logs"
        "mattermost_plugins"
        "mattermost_client_plugins"
        "mattermost-minio_data"
    )

    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            log_info "Backing up volume: $volume..."
            docker run --rm \
                -v "${volume}:/data:ro" \
                -v "${BACKUP_DIR}/volumes:/backup" \
                alpine tar czf "/backup/${volume}.tar.gz" -C /data .
        fi
    done

    log_success "Volume backups complete"
}

backup_configurations() {
    log_info "Backing up configurations..."

    # Docker Compose files
    cp "${PROJECT_ROOT}"/docker-compose*.yml "${BACKUP_DIR}/configs/"

    # Environment file (excluding sensitive data)
    grep -v -E '(PASSWORD|SECRET|KEY|TOKEN)' "${PROJECT_ROOT}/.env" > "${BACKUP_DIR}/configs/.env.sanitized"

    # Caddy configuration
    cp -r "${PROJECT_ROOT}/caddy" "${BACKUP_DIR}/configs/"

    # PostgreSQL configuration
    cp -r "${PROJECT_ROOT}/postgres" "${BACKUP_DIR}/configs/"

    # Prometheus configuration
    cp -r "${PROJECT_ROOT}/prometheus" "${BACKUP_DIR}/configs/"

    # Loki configuration
    cp -r "${PROJECT_ROOT}/loki" "${BACKUP_DIR}/configs/"

    # Vector configuration
    cp -r "${PROJECT_ROOT}/vector" "${BACKUP_DIR}/configs/"

    # HURRICANE configuration (if exists)
    if [[ -d "${PROJECT_ROOT}/hurricane/config" ]]; then
        cp -r "${PROJECT_ROOT}/hurricane/config" "${BACKUP_DIR}/configs/hurricane/"
    fi

    # Mattermost configuration (if deployed)
    if [[ -d "${PROJECT_ROOT}/mattermost" ]]; then
        log_info "Backing up Mattermost configuration..."
        mkdir -p "${BACKUP_DIR}/configs/mattermost"
        cp -r "${PROJECT_ROOT}/mattermost/boards" "${BACKUP_DIR}/configs/mattermost/" 2>/dev/null || true
        cp "${PROJECT_ROOT}/docker-compose.mattermost.yml" "${BACKUP_DIR}/configs/" 2>/dev/null || true
    fi

    # POLYGOTYA configuration (if deployed)
    if [[ -d "${PROJECT_ROOT}/ssh-callback-server" ]]; then
        log_info "Backing up POLYGOTYA configuration..."
        mkdir -p "${BACKUP_DIR}/configs/polygotya"
        cp "${PROJECT_ROOT}/docker-compose.polygotya.yml" "${BACKUP_DIR}/configs/" 2>/dev/null || true
        cp "${PROJECT_ROOT}/ssh-callback-server/Dockerfile.secure" "${BACKUP_DIR}/configs/polygotya/" 2>/dev/null || true
        cp "${PROJECT_ROOT}/ssh-callback-server/.env.secure.example" "${BACKUP_DIR}/configs/polygotya/" 2>/dev/null || true
    fi

    # Host system configs
    cp /etc/ssh/sshd_config "${BACKUP_DIR}/configs/sshd_config"
    cp /etc/sysctl.d/99-vps2.0-hardening.conf "${BACKUP_DIR}/configs/sysctl.conf" 2>/dev/null || true
    cp /etc/fail2ban/jail.local "${BACKUP_DIR}/configs/fail2ban.conf" 2>/dev/null || true

    log_success "Configuration backups complete"
}

backup_logs() {
    log_info "Backing up logs..."

    # Docker logs
    for container in $(docker ps --format '{{.Names}}'); do
        docker logs "$container" &> "${BACKUP_DIR}/logs/${container}.log" 2>/dev/null || true
    done

    # System logs
    cp /var/log/auth.log "${BACKUP_DIR}/logs/auth.log" 2>/dev/null || true
    cp /var/log/syslog "${BACKUP_DIR}/logs/syslog" 2>/dev/null || true
    cp /var/log/fail2ban.log "${BACKUP_DIR}/logs/fail2ban.log" 2>/dev/null || true

    log_success "Log backups complete"
}

create_manifest() {
    log_info "Creating backup manifest..."

    cat > "${BACKUP_DIR}/MANIFEST.txt" <<EOF
VPS2.0 Backup Manifest
======================
Backup Date: $(date)
Backup Location: ${BACKUP_DIR}
Hostname: $(hostname)
Kernel: $(uname -r)
Docker Version: $(docker --version)
Docker Compose Version: $(docker-compose --version 2>/dev/null || docker compose version)

Backup Contents:
----------------
Databases:
$(ls -lh "${BACKUP_DIR}/databases/")

Volumes:
$(ls -lh "${BACKUP_DIR}/volumes/")

Configurations:
$(ls -lh "${BACKUP_DIR}/configs/")

Total Backup Size: $(du -sh "${BACKUP_DIR}" | cut -f1)

Restore Instructions:
---------------------
1. Extract configurations:
   cp -r ${BACKUP_DIR}/configs/* /path/to/vps2.0/

2. Restore PostgreSQL:
   gunzip -c ${BACKUP_DIR}/databases/postgres_all.sql.gz | docker-compose exec -T postgres psql -U postgres

3. Restore Neo4j:
   gunzip -c ${BACKUP_DIR}/databases/neo4j.dump.gz | docker-compose exec -T neo4j neo4j-admin database load neo4j --from-stdin

4. Restore volumes:
   docker run --rm -v VOLUME_NAME:/data -v ${BACKUP_DIR}/volumes:/backup alpine tar xzf /backup/VOLUME_NAME.tar.gz -C /data

5. Restart services:
   docker-compose down && docker-compose up -d

EOF

    log_success "Manifest created"
}

compress_backup() {
    log_info "Compressing backup..."

    cd "${BACKUP_ROOT}"
    tar czf "${TIMESTAMP}.tar.gz" "${TIMESTAMP}"

    # Calculate checksums
    sha256sum "${TIMESTAMP}.tar.gz" > "${TIMESTAMP}.tar.gz.sha256"

    # Remove uncompressed backup
    rm -rf "${TIMESTAMP}"

    log_success "Backup compressed: ${BACKUP_ROOT}/${TIMESTAMP}.tar.gz"
}

upload_to_s3() {
    if [[ "${S3_BACKUP_ENABLED:-false}" != "true" ]]; then
        return 0
    fi

    log_info "Uploading backup to S3..."

    # Install AWS CLI if not present
    if ! command -v aws &> /dev/null; then
        log_info "Installing AWS CLI..."
        apt-get install -y awscli
    fi

    # Configure AWS credentials
    export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}"
    export AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}"

    # Upload to S3
    aws s3 cp \
        "${BACKUP_ROOT}/${TIMESTAMP}.tar.gz" \
        "s3://${S3_BUCKET}/vps2.0/backups/${TIMESTAMP}.tar.gz" \
        --endpoint-url "${S3_ENDPOINT}"

    aws s3 cp \
        "${BACKUP_ROOT}/${TIMESTAMP}.tar.gz.sha256" \
        "s3://${S3_BUCKET}/vps2.0/backups/${TIMESTAMP}.tar.gz.sha256" \
        --endpoint-url "${S3_ENDPOINT}"

    log_success "Backup uploaded to S3"
}

cleanup_old_backups() {
    log_info "Cleaning up old backups..."

    local retention_days="${BACKUP_RETENTION_DAYS:-30}"

    # Remove local backups older than retention period
    find "${BACKUP_ROOT}" -name "*.tar.gz" -type f -mtime +"${retention_days}" -delete
    find "${BACKUP_ROOT}" -name "*.sha256" -type f -mtime +"${retention_days}" -delete

    log_success "Old backups cleaned up (retention: ${retention_days} days)"
}

#==============================================
# Main Backup Flow
#==============================================

main() {
    log_info "Starting VPS2.0 backup..."
    echo ""

    # Load environment
    source "${PROJECT_ROOT}/.env" 2>/dev/null || true

    # Create backup directory
    ensure_backup_dir

    # Perform backups
    backup_databases
    backup_volumes
    backup_configurations
    backup_logs

    # Create manifest
    create_manifest

    # Compress backup
    compress_backup

    # Upload to S3 (if configured)
    upload_to_s3

    # Cleanup old backups
    cleanup_old_backups

    echo ""
    log_success "Backup complete!"
    echo ""
    echo "Backup Location: ${BACKUP_ROOT}/${TIMESTAMP}.tar.gz"
    echo "Backup Size: $(du -sh "${BACKUP_ROOT}/${TIMESTAMP}.tar.gz" | cut -f1)"
    echo "SHA256: $(cat "${BACKUP_ROOT}/${TIMESTAMP}.tar.gz.sha256")"
    echo ""
}

# Run main function
main "$@"
