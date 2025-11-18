# VPS2.0 Quick Start Guide

**SWORD Intelligence Platform - Complete Deployment Guide**

---

## Prerequisites

### Server Requirements

- **OS**: Debian 11/12 or Ubuntu 22.04 LTS
- **RAM**: 16GB minimum (32GB+ recommended)
- **Disk**: 100GB+ SSD storage
- **CPU**: 4+ cores recommended
- **Network**: Public IPv4 address, ports 22/80/443 open

### Software Requirements

- Docker 20.10+
- Docker Compose 2.0+
- Root or sudo access

### Domain Requirements

- Domain name (e.g., `swordintelligence.airforce`)
- DNS access to create A records for subdomains

---

## 5-Minute Deployment

### Step 1: Install Docker

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Add user to docker group
sudo usermod -aG docker $USER

# Start Docker
sudo systemctl enable --now docker

# Verify
docker --version
docker-compose --version
```

### Step 2: Clone Repository

```bash
# Clone VPS2.0
cd /home/user
git clone https://github.com/SWORDIntel/VPS2.0.git
cd VPS2.0
```

### Step 3: Configure Environment

```bash
# Copy environment template
cp .env.template .env

# Generate secure keys
./scripts/generate-keys.sh  # (if available)

# OR manually edit .env
nano .env

# Required changes:
#   - Set DOMAIN=swordintelligence.airforce
#   - Replace all CHANGE_ME values with secure passwords
#   - Set DEPLOY_MATTERMOST=true (if desired)
#   - Set DEPLOY_POLYGOTYA=true (if desired)
```

**Critical .env Settings:**

```bash
# Domain
DOMAIN=swordintelligence.airforce

# Enable services
DEPLOY_DNS_HUB=true
DEPLOY_MATTERMOST=true
DEPLOY_POLYGOTYA=true
DEPLOY_GRAFANA=true

# Generate with: openssl rand -base64 32
POSTGRES_PASSWORD=<secure-password>
REDIS_PASSWORD=<secure-password>
GRAFANA_ADMIN_PASSWORD=<secure-password>

# Mattermost
MATTERMOST_DB_PASSWORD=<secure-password>
MATTERMOST_REDIS_PASSWORD=<secure-password>

# POLYGOTYA
POLYGOTYA_API_KEY=<openssl rand -base64 32>
POLYGOTYA_SECRET_KEY=<openssl rand -hex 32>
POLYGOTYA_ADMIN_PASSWORD=<secure-password>
POLYGOTYA_DGA_SEED=insovietrussiawehackyou
```

### Step 4: Deploy

```bash
# Run deployment script
sudo ./scripts/deploy.sh

# This will:
#   1. Check prerequisites
#   2. Create directory structure
#   3. Generate secure passwords
#   4. Deploy services in phases
#   5. Configure firewall
#   6. Set up systemd service
```

**Deployment takes ~10-15 minutes**

### Step 5: Configure DNS

While services are deploying, configure DNS:

```
Type: A
Host: *
Value: YOUR_VPS_IP
TTL: 300

OR create specific subdomains:
mattermost.swordintelligence.airforce  → YOUR_VPS_IP
polygotya.swordintelligence.airforce   → YOUR_VPS_IP
grafana.swordintelligence.airforce     → YOUR_VPS_IP
```

### Step 6: Verify Deployment

```bash
# Run verification script
./scripts/verify-deployment.sh

# Check running services
docker ps

# Check logs
docker-compose logs -f
```

---

## Post-Deployment Setup

### Mattermost Initial Setup

```bash
# 1. Create admin account
# Visit: https://mattermost.swordintelligence.airforce
# Create first admin user

# 2. Run security hardening
./scripts/mattermost/initial-setup.sh

# 3. Install plugins
./scripts/mattermost/install-plugins.sh

# 4. Import board templates
# Go to Boards → Import
# Upload templates from: mattermost/boards/
```

### POLYGOTYA Setup

```bash
# 1. Get admin password
docker logs polygotya | grep "DEFAULT ADMIN"

# 2. Login
# Visit: https://polygotya.swordintelligence.airforce
# Username: admin
# Password: (from logs)

# 3. CHANGE PASSWORD IMMEDIATELY

# 4. Get API key from .env
grep POLYGOTYA_API_KEY .env
```

### Grafana Setup

```bash
# Visit: https://grafana.swordintelligence.airforce
# Default: admin/admin
# Change password on first login
```

---

## Service URLs

After deployment, access services at:

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| **Mattermost** | https://mattermost.swordintelligence.airforce | Create on first visit |
| **POLYGOTYA** | https://polygotya.swordintelligence.airforce | admin/(from logs) |
| **Grafana** | https://grafana.swordintelligence.airforce | admin/admin |
| **Portainer** | https://portainer.swordintelligence.airforce | Create on first visit |
| **Technitium DNS** | http://YOUR_IP:5380 | admin/admin |

---

## Common Tasks

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker logs mattermost -f
docker logs polygotya -f
docker logs caddy -f
```

### Restart Service

```bash
# Restart single service
docker-compose restart mattermost

# Restart all
docker-compose restart
```

### Update Services

```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d
```

### Backup

```bash
# Run backup
./scripts/backup.sh

# Backups stored in: /srv/backups/
```

### Check Health

```bash
# POLYGOTYA
curl https://polygotya.swordintelligence.airforce/health

# Mattermost
curl https://mattermost.swordintelligence.airforce/api/v4/system/ping

# Container health
docker ps
docker inspect <container> | grep -A5 Health
```

---

## Troubleshooting

### Services Not Starting

```bash
# Check logs
docker-compose logs <service>

# Check .env file
cat .env | grep -v "^#" | grep "CHANGE_ME"

# Restart service
docker-compose restart <service>
```

### Can't Access Services (403/502)

**Check DNS:**
```bash
# Verify DNS resolves to your VPS IP
dig mattermost.swordintelligence.airforce
```

**Check Caddy:**
```bash
# View Caddy logs
docker logs caddy

# Check Caddy config
docker exec caddy caddy fmt --overwrite /etc/caddy/Caddyfile
```

**Check Firewall:**
```bash
sudo ufw status
# Ensure 80/443 are allowed
```

### Mattermost Won't Start

```bash
# Check database
docker logs mattermost-db

# Check MinIO
docker logs mattermost-minio

# Reset Mattermost
docker-compose down
docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d
```

### POLYGOTYA Can't Login

```bash
# Get password from logs
docker logs polygotya | grep "DEFAULT ADMIN"

# Reset admin account
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  "UPDATE users SET locked_until = NULL, failed_attempts = 0 WHERE username = 'admin';"
```

### Low Disk Space

```bash
# Clean Docker
docker system prune -a

# Remove old images
docker image prune -a

# Check disk usage
df -h
du -sh /var/lib/docker
```

---

## Security Checklist

After deployment:

- [ ] Changed all default passwords
- [ ] Deleted `credentials.txt`
- [ ] Configured firewall (port 22/80/443 only)
- [ ] Enabled MFA on Mattermost
- [ ] Changed Grafana admin password
- [ ] Changed POLYGOTYA admin password
- [ ] Configured SMTP for Mattermost
- [ ] Set up automated backups
- [ ] Configured WireGuard VPN (optional)
- [ ] Reviewed audit logs
- [ ] Set up monitoring alerts

---

## Next Steps

1. **Configure Mattermost**
   - Enable MFA for all users
   - Disable user registration
   - Set up SMTP email
   - Import board templates

2. **Set Up Monitoring**
   - Configure Grafana dashboards
   - Set up alert rules
   - Connect Prometheus AlertManager to Mattermost

3. **Configure Backups**
   - Run `./scripts/backup.sh`
   - Set up automated backups with cron
   - Test restore procedure

4. **Team Onboarding**
   - Create Mattermost accounts
   - Set up investigation boards
   - Create incident response playbooks
   - Configure GitLab integration

---

## Support & Documentation

- **Main Documentation**: `docs/`
- **Mattermost Guide**: `docs/MATTERMOST.md`
- **POLYGOTYA Guide**: `docs/POLYGOTYA.md`
- **Deployment Checklist**: `docs/DEPLOYMENT-CHECKLIST.md`

---

## Emergency Contacts

**Issues?**

1. Check logs: `docker-compose logs -f`
2. Run verification: `./scripts/verify-deployment.sh`
3. Review troubleshooting section above
4. Check individual service documentation

---

**Status**: Production Ready  
**Version**: 2.0  
**Last Updated**: 2025-11-18
