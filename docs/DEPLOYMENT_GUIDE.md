# VPS2.0 Deployment Guide

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Pre-Deployment Planning](#pre-deployment-planning)
4. [Quick Start Deployment](#quick-start-deployment)
5. [Detailed Deployment Steps](#detailed-deployment-steps)
6. [Post-Deployment Configuration](#post-deployment-configuration)
7. [Optional Services](#optional-services)
8. [Security Hardening](#security-hardening)
9. [Backup Configuration](#backup-configuration)
10. [Troubleshooting](#troubleshooting)
11. [Maintenance](#maintenance)

---

## Overview

VPS2.0 is a comprehensive, production-ready software stack for intelligence gathering, security analysis, and threat detection. This guide will walk you through deploying the entire stack on a single Debian-based VPS.

### Architecture Components

- **Foundation**: Caddy, PostgreSQL, Redis, Neo4j, Portainer
- **Intelligence**: SWORDINTELLIGENCE, MISP, OpenCTI, Cortex, n8n
- **Analysis**: YARA, ClamAV, Suricata, Zeek, Cuckoo Sandbox
- **Monitoring**: Grafana, VictoriaMetrics, Loki, Vector
- **Development**: GitLab CE with CI/CD
- **Optional**: HURRICANE IPv6 Proxy, ARTICBASTION Secure Gateway
- **Blockchain**: Bitcoin, Ethereum explorers

---

## Prerequisites

### Minimum Hardware Requirements

- **CPU**: 8 cores (16 recommended)
- **RAM**: 32GB minimum (64GB recommended)
- **Storage**: 500GB SSD (1TB recommended)
- **Network**: 1Gbps connection

### Software Requirements

- **OS**: Debian 12 (Bookworm) or Ubuntu 22.04 LTS
- **Docker**: Version 24.0+
- **Docker Compose**: Version 2.20+
- **Root access**: Required for installation

### Network Requirements

- **Domain name**: For SSL/TLS certificates
- **Public IP address**: Static IP recommended
- **Open ports**: 80, 443, 2222 (bastion SSH), 51820/udp (WireGuard)

---

## Pre-Deployment Planning

### 1. DNS Configuration

Before deployment, configure your DNS records:

```
A       @                   YOUR_SERVER_IP
A       swordintel          YOUR_SERVER_IP
A       portainer           YOUR_SERVER_IP
A       gitlab              YOUR_SERVER_IP
A       registry            YOUR_SERVER_IP
A       monitoring          YOUR_SERVER_IP
A       misp                YOUR_SERVER_IP
A       opencti             YOUR_SERVER_IP
A       n8n                 YOUR_SERVER_IP
A       hurricane           YOUR_SERVER_IP
A       bastion             YOUR_SERVER_IP
A       mempool             YOUR_SERVER_IP
A       blockscout          YOUR_SERVER_IP
```

### 2. Email Configuration

Set up email for:
- Let's Encrypt notifications
- GitLab notifications
- Alert notifications
- System notifications

### 3. Backup Planning

Decide on:
- Local backup location (default: `/srv/backups`)
- Remote backup (S3-compatible storage)
- Backup retention policy (default: 30 days)
- Backup schedule (recommended: daily)

---

## Quick Start Deployment

For experienced users who want to deploy quickly:

```bash
# 1. Clone the repository
cd /home/user
git clone https://github.com/SWORDIntel/VPS2.0.git
cd VPS2.0

# 2. Deploy the stack
sudo ./scripts/deploy.sh

# 3. Apply security hardening
sudo ./scripts/harden.sh

# 4. Configure backups
sudo crontab -e
# Add: 0 2 * * * /home/user/VPS2.0/scripts/backup.sh

# 5. Check deployment
docker-compose ps
```

That's it! The deployment script will:
- Check system requirements
- Generate secure credentials
- Deploy all services in phases
- Configure firewall
- Set up systemd service

**IMPORTANT**: Save the credentials from `credentials.txt` before deleting it!

---

## Detailed Deployment Steps

### Step 1: Prepare the Host System

```bash
# Update system
apt-get update && apt-get upgrade -y

# Install prerequisites
apt-get install -y \
    curl \
    wget \
    git \
    ufw \
    fail2ban \
    unattended-upgrades \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

### Step 2: Clone the Repository

```bash
cd /home/user
git clone https://github.com/SWORDIntel/VPS2.0.git
cd VPS2.0
```

### Step 3: Configure Environment

```bash
# Copy environment template
cp .env.template .env

# Edit environment file
nano .env
```

**Required Configuration**:

```bash
# Your domain name
DOMAIN=your-domain.com

# Admin email for Let's Encrypt
ADMIN_EMAIL=admin@your-domain.com

# Generate strong passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
NEO4J_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 64)

# Generate Portainer password hash
PORTAINER_PASSWORD="your-secure-password"
PORTAINER_PASSWORD_HASH=$(docker run --rm httpd:2.4-alpine htpasswd -nbB admin "${PORTAINER_PASSWORD}" | cut -d ":" -f 2)

# Grafana
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 24)

# MISP
MISP_ADMIN_PASSWORD=$(openssl rand -base64 24)
MISP_DB_PASSWORD=$(openssl rand -base64 32)
MISP_DB_ROOT_PASSWORD=$(openssl rand -base64 32)

# OpenCTI
OPENCTI_ADMIN_PASSWORD=$(openssl rand -base64 24)
OPENCTI_ADMIN_TOKEN=$(uuidgen)
RABBITMQ_PASSWORD=$(openssl rand -base64 32)

# n8n
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
N8N_DB_PASSWORD=$(openssl rand -base64 32)

# Database passwords
SWORDINTEL_DB_PASSWORD=$(openssl rand -base64 32)
GITLAB_DB_PASSWORD=$(openssl rand -base64 32)
```

**IMPORTANT**: Save all passwords in a secure password manager!

### Step 4: Deploy Phase 1 - Foundation

```bash
# Deploy foundation services
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

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

Wait for all services to be healthy (check with `docker-compose ps`).

### Step 5: Initialize Databases

```bash
# Run database initialization
docker-compose exec postgres psql -U postgres -f /docker-entrypoint-initdb.d/01-create-databases.sql

# Verify databases
docker-compose exec postgres psql -U postgres -c "\l"
```

### Step 6: Deploy Phase 2 - Intelligence Services

```bash
# Deploy intelligence services
docker-compose -f docker-compose.yml -f docker-compose.intelligence.yml up -d

# Check status
docker-compose -f docker-compose.yml -f docker-compose.intelligence.yml ps

# Monitor startup (this may take several minutes)
docker-compose -f docker-compose.yml -f docker-compose.intelligence.yml logs -f
```

### Step 7: Configure Firewall

```bash
# Reset UFW (careful!)
ufw --force reset

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (change 22 if using different port)
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp  # HTTP/3

# Allow WireGuard VPN
ufw allow 51820/udp

# Allow Bastion SSH
ufw allow 2222/tcp

# Enable firewall
ufw --force enable

# Verify rules
ufw status verbose
```

### Step 8: Configure SSL/TLS Certificates

Caddy automatically obtains Let's Encrypt certificates. Verify:

```bash
# Check Caddy logs
docker-compose logs caddy | grep -i certificate

# Test HTTPS
curl -I https://portainer.your-domain.com
```

---

## Post-Deployment Configuration

### Access Web Interfaces

1. **Portainer**: `https://portainer.your-domain.com`
   - Create admin user on first login
   - Connect to local Docker environment

2. **Grafana**: `https://monitoring.your-domain.com`
   - Default: admin / (see .env GRAFANA_ADMIN_PASSWORD)
   - Add VictoriaMetrics datasource: `http://victoriametrics:8428`
   - Import dashboards from `/grafana/dashboards/`

3. **GitLab**: `https://gitlab.your-domain.com`
   - Get initial root password:
     ```bash
     docker-compose exec gitlab cat /etc/gitlab/initial_root_password
     ```
   - Register GitLab Runner:
     ```bash
     docker-compose exec gitlab-runner gitlab-runner register \
       --non-interactive \
       --url "https://gitlab.your-domain.com/" \
       --registration-token "YOUR_TOKEN" \
       --executor "docker" \
       --docker-image alpine:latest \
       --description "docker-runner"
     ```

4. **SWORDINTELLIGENCE**: `https://swordintel.your-domain.com`
   - Initial setup wizard will guide you through configuration
   - Connect to databases using internal hostnames

5. **MISP**: `https://misp.your-domain.com`
   - Default: admin@admin.test / (see .env MISP_ADMIN_PASSWORD)
   - Change email and password immediately
   - Configure API key: Administration → List Users → Your User → Auth Keys

6. **OpenCTI**: `https://opencti.your-domain.com`
   - Default: admin@opencti.io / (see .env OPENCTI_ADMIN_PASSWORD)
   - Configure connectors and feeds

7. **n8n**: `https://n8n.your-domain.com`
   - Create owner account on first login
   - Set up workflows for intelligence automation

### Configure WireGuard VPN (Optional)

For secure admin access:

```bash
# Generate WireGuard configuration
cd /home/user/VPS2.0
./scripts/setup-wireguard.sh

# Client configs will be in:
ls -la /etc/wireguard/clients/
```

### Set Up Monitoring Alerts

Configure Grafana alerts:

1. Go to Alerting → Contact Points
2. Add your notification channels (Slack, Discord, Email, etc.)
3. Create alert rules for:
   - High CPU usage (>85%)
   - High memory usage (>85%)
   - Disk space low (<10%)
   - Service failures
   - Security events

---

## Optional Services

### Deploy HURRICANE IPv6 Proxy

```bash
# Edit .env
nano .env

# Enable HURRICANE
HURRICANE_ENABLED=true

# Configure tunnel backend (example: Hurricane Electric)
HE_ENABLED=true
HE_USERNAME=your_he_username
HE_PASSWORD=your_he_password
HE_TUNNEL_ID=your_tunnel_id

# Deploy HURRICANE
docker-compose -f docker-compose.yml -f docker-compose.hurricane.yml up -d --build hurricane

# Check status
docker-compose -f docker-compose.yml -f docker-compose.hurricane.yml logs -f hurricane

# Access HURRICANE Web UI
open https://hurricane.your-domain.com
```

### Deploy ARTICBASTION Secure Gateway

```bash
# Build and deploy
docker-compose up -d articbastion

# Configure SSH keys
docker-compose exec articbastion bash
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key

# Test bastion access
ssh -p 2222 bastion@your-domain.com
```

### Deploy Blockchain Nodes

**Bitcoin + Mempool Explorer**:

```bash
# Deploy Bitcoin full node and explorer
docker-compose -f docker-compose.blockchain.yml up -d bitcoin mempool

# Monitor sync (this will take several days!)
docker-compose -f docker-compose.blockchain.yml logs -f bitcoin

# Access Mempool explorer
open https://mempool.your-domain.com
```

**Ethereum + Blockscout**:

```bash
# Deploy Ethereum node and explorer
docker-compose -f docker-compose.blockchain.yml up -d erigon blockscout

# Monitor sync
docker-compose -f docker-compose.blockchain.yml logs -f erigon

# Access Blockscout
open https://blockscout.your-domain.com
```

---

## Security Hardening

### Run Automated Hardening

```bash
# Apply all security hardening
sudo ./scripts/harden.sh

# This will:
# - Harden SSH configuration
# - Install and configure Fail2ban
# - Apply kernel hardening (sysctl)
# - Configure automatic security updates
# - Harden Docker daemon
# - Install auditd
# - Install security scanning tools (Lynis, rkhunter, etc.)
# - Configure log rotation
```

### Manual Security Enhancements

**1. SSH Key-Only Authentication**:

```bash
# On your local machine, generate SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@your-server-ip

# Test SSH key login
ssh -i ~/.ssh/id_ed25519 user@your-server-ip

# Once confirmed working, disable password authentication (already done by harden.sh)
```

**2. Configure Two-Factor Authentication**:

```bash
# Install Google Authenticator
apt-get install -y libpam-google-authenticator

# Configure for your user
google-authenticator

# Follow prompts, save backup codes

# Enable in SSH
echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
```

**3. Regular Security Scans**:

```bash
# Run Lynis system audit
lynis audit system

# Run rkhunter rootkit check
rkhunter --check --skip-keypress

# Run ClamAV virus scan
clamscan -r -i /home

# Check for vulnerable packages
apt-get install -y debian-goodies
checkrestart
```

---

## Backup Configuration

### Automated Backups

```bash
# Test backup script
sudo ./scripts/backup.sh

# Configure daily backups via cron
sudo crontab -e

# Add the following lines:
# Daily backup at 2 AM
0 2 * * * /home/user/VPS2.0/scripts/backup.sh >> /var/log/vps2.0-backup.log 2>&1

# Weekly security scan at 3 AM on Sundays
0 3 * * 0 /usr/sbin/lynis audit system --quick >> /var/log/vps2.0-audit.log 2>&1
```

### Configure S3 Backup (Optional)

```bash
# Edit .env
nano .env

# Configure S3 settings
S3_BACKUP_ENABLED=true
S3_ENDPOINT=https://s3.amazonaws.com  # or your S3-compatible endpoint
S3_BUCKET=vps2.0-backups
S3_ACCESS_KEY=your_access_key
S3_SECRET_KEY=your_secret_key

# Test S3 upload
./scripts/backup.sh
```

### Restore from Backup

```bash
# List available backups
ls -lh /srv/backups/*.tar.gz

# Extract backup
cd /srv/backups
tar xzf 20250118_020000.tar.gz

# Restore databases
gunzip -c 20250118_020000/databases/postgres_all.sql.gz | \
    docker-compose exec -T postgres psql -U postgres

# Restore volumes
docker run --rm \
    -v portainer_data:/data \
    -v /srv/backups/20250118_020000/volumes:/backup \
    alpine tar xzf /backup/portainer_data.tar.gz -C /data

# Restart services
docker-compose down && docker-compose up -d
```

---

## Troubleshooting

### Common Issues

**1. Services not starting**:

```bash
# Check logs
docker-compose logs [service_name]

# Check resource usage
docker stats

# Check disk space
df -h

# Restart service
docker-compose restart [service_name]
```

**2. Database connection errors**:

```bash
# Check database is running
docker-compose ps postgres

# Check database logs
docker-compose logs postgres

# Test connection
docker-compose exec postgres psql -U postgres -c "SELECT version();"

# Restart database
docker-compose restart postgres
```

**3. Certificate errors**:

```bash
# Check Caddy logs
docker-compose logs caddy | grep -i error

# Verify domain points to server
dig +short your-domain.com

# Test certificate manually
curl -vI https://your-domain.com

# Force certificate renewal
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

**4. Out of memory**:

```bash
# Check memory usage
free -h
docker stats

# Identify memory-hungry containers
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" | sort -k 2 -h

# Restart specific service
docker-compose restart [heavy_service]

# Consider adding swap
fallocate -l 8G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
```

**5. Port conflicts**:

```bash
# Check what's using a port
lsof -i :80
netstat -tulpn | grep :80

# Kill process
kill -9 [PID]

# Or change port in docker-compose.yml
```

### Getting Help

1. **Check logs**: `docker-compose logs -f [service]`
2. **Review documentation**: See `STACK_ARCHITECTURE.md`
3. **Check GitHub issues**: https://github.com/SWORDIntel/VPS2.0/issues
4. **System audit**: Run `lynis audit system`

---

## Maintenance

### Daily Tasks

```bash
# Check system health
docker-compose ps
docker stats --no-stream

# Review alerts in Grafana
# Check Fail2ban status
fail2ban-client status

# Monitor disk space
df -h
```

### Weekly Tasks

```bash
# Review logs
docker-compose logs --since 7d | grep -i error

# Update Docker images (test in staging first!)
docker-compose pull
docker-compose up -d

# Check for system updates
apt-get update
apt-get upgrade -y

# Verify backups
ls -lh /srv/backups/
```

### Monthly Tasks

```bash
# Run full security audit
lynis audit system

# Review and rotate credentials
# Clean up old Docker images
docker system prune -a --filter "until=720h"

# Review firewall rules
ufw status verbose

# Test disaster recovery procedure
./scripts/backup.sh
# Test restore in staging environment

# Review and update documentation
```

### Updating Services

```bash
# Pull latest images
docker-compose pull

# Recreate containers with new images
docker-compose up -d

# Check for errors
docker-compose logs -f

# Rollback if needed
docker-compose down
docker-compose up -d --force-recreate
```

---

## Performance Optimization

### Monitor Performance

```bash
# System resources
htop
iotop
iftop

# Docker metrics
docker stats

# Database performance
docker-compose exec postgres psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

### Optimize Databases

```bash
# PostgreSQL vacuum and analyze
docker-compose exec postgres vacuumdb -U postgres --all --analyze --verbose

# Neo4j consistency check
docker-compose exec neo4j neo4j-admin check-consistency

# Redis memory stats
docker-compose exec redis-stack redis-cli INFO memory
```

---

## Scaling Considerations

When your VPS reaches capacity:

1. **Vertical Scaling**: Upgrade to larger VPS
2. **Horizontal Scaling**:
   - Separate database server
   - Separate analysis workers
   - Load balancer for web services
3. **Migration to Kubernetes**: See migration guide (coming soon)

---

## Support and Documentation

- **Architecture**: See `STACK_ARCHITECTURE.md`
- **Security**: See `SECURITY.md`
- **Contributing**: See `CONTRIBUTING.md`
- **License**: See `LICENSE`
- **Issues**: https://github.com/SWORDIntel/VPS2.0/issues

---

## Quick Reference

### Useful Commands

```bash
# View all services
docker-compose ps

# View logs
docker-compose logs -f [service]

# Restart service
docker-compose restart [service]

# Stop all services
docker-compose down

# Start all services
docker-compose up -d

# Rebuild service
docker-compose up -d --build [service]

# Execute command in container
docker-compose exec [service] [command]

# View resource usage
docker stats

# Clean up
docker system prune -a
```

### Important Files

- `.env` - Environment configuration
- `docker-compose.yml` - Core services
- `docker-compose.intelligence.yml` - Intelligence services
- `docker-compose.hurricane.yml` - HURRICANE proxy
- `caddy/Caddyfile` - Reverse proxy configuration
- `credentials.txt` - Generated passwords (delete after saving)

### Default Ports

- `80/tcp` - HTTP (redirects to HTTPS)
- `443/tcp` - HTTPS
- `443/udp` - HTTP/3
- `2222/tcp` - Bastion SSH
- `51820/udp` - WireGuard VPN

---

**Deployment Version**: 1.0
**Last Updated**: 2025-11-18
**Status**: Production Ready

For questions or issues, please open an issue on GitHub or consult the documentation.

**Happy Deploying! 🚀**
