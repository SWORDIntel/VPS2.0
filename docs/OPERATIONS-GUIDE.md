# VPS2.0 Operations Guide

**Complete operational reference for VPS2.0 platform management**

Version: 2.0
Last Updated: 2025-11-18
Document Owner: SWORD Intelligence Operations Team

---

## Table of Contents

- [Overview](#overview)
- [Daily Operations](#daily-operations)
- [Management Scripts](#management-scripts)
- [Service Management](#service-management)
- [Backup & Recovery](#backup--recovery)
- [Monitoring & Alerting](#monitoring--alerting)
- [Troubleshooting](#troubleshooting)
- [Security Operations](#security-operations)
- [Maintenance Tasks](#maintenance-tasks)
- [Emergency Procedures](#emergency-procedures)

---

## Overview

This guide covers day-to-day operations, maintenance, and troubleshooting for the VPS2.0 platform. For initial deployment, see [QUICKSTART.md](../QUICKSTART.md) and [DEPLOYMENT-CHECKLIST.md](./DEPLOYMENT-CHECKLIST.md).

### Platform Components

**Core Services:**
- Caddy (Reverse Proxy with TLS 1.3)
- PostgreSQL (Primary database)
- Redis Stack (Caching & queuing)
- Neo4j (Graph database)
- Grafana (Metrics & dashboards)
- Portainer (Container management)

**Collaboration Services:**
- Mattermost (Team chat + Boards + Playbooks)
- Mattermost MinIO (Object storage)
- Mattermost Redis (Caching)

**Security Operations:**
- POLYGOTYA (SSH Callback Server with PQC)
- POLYGOTYA SQLite (Callback database)

**Intelligence Platform:**
- MISP (Threat intel sharing)
- OpenCTI (Threat intel platform)

---

## Daily Operations

### Morning Health Check

```bash
# Quick status overview
./scripts/status.sh quick

# Check all services
./scripts/status.sh services

# Review recent logs
./scripts/status.sh logs
```

### Check Service URLs

```bash
# Display all service URLs
./scripts/status.sh urls

# Test critical endpoints
curl -sSf https://portainer.swordintelligence.airforce/api/status
curl -sSf https://grafana.swordintelligence.airforce/api/health
curl -sSf https://polygotya.swordintelligence.airforce/health
curl -sSf https://mattermost.swordintelligence.airforce/api/v4/system/ping
```

### Review Alerts

```bash
# Check Mattermost #alerts channel
# Check Grafana dashboards
# Review POLYGOTYA audit logs

docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  "SELECT * FROM audit_log WHERE timestamp > datetime('now', '-24 hours') ORDER BY timestamp DESC;"
```

---

## Management Scripts

### System Status & Health

**Quick Status Check:**
```bash
./scripts/status.sh quick
```
Shows: System info, quick stats, core services

**Full Status Report:**
```bash
./scripts/status.sh full
```
Shows: Complete system status including resources, all services, networks

**Service Status Only:**
```bash
./scripts/status.sh services
```
Shows: Detailed status of all deployed services

**Service URLs:**
```bash
./scripts/status.sh urls
```
Shows: All service URLs based on configured domain

**Recent Logs:**
```bash
./scripts/status.sh logs
```
Shows: Last 10 lines from each critical service

### Deployment Verification

```bash
# Comprehensive health check
./scripts/verify-deployment.sh
```

Checks:
- Docker environment
- Network configuration
- Core services health
- Mattermost stack (if deployed)
- POLYGOTYA (if deployed)
- DNS Hub (if deployed)
- System resources
- Firewall status

### Backup Operations

**Create Full Backup:**
```bash
sudo ./scripts/backup.sh
```

Backs up:
- All databases (PostgreSQL, Neo4j, Redis, Mattermost, POLYGOTYA SQLite)
- Docker volumes
- Configuration files
- Docker Compose files
- System configs

Output: `/srv/backups/TIMESTAMP.tar.gz`

**Mattermost-Specific Backup:**
```bash
./scripts/mattermost/backup.sh
```

### Restore Operations

**Restore from Backup:**
```bash
sudo ./scripts/restore.sh /srv/backups/20251118_020000.tar.gz
```

Interactive process that:
1. Verifies backup integrity
2. Stops all services
3. Restores configurations
4. Restores databases
5. Restores volumes
6. Starts services
7. Verifies restoration

### POLYGOTYA Management

**Quick Setup:**
```bash
./scripts/polygotya-quickstart.sh
```

Performs:
- Prerequisites check
- Credential generation
- Container deployment
- Firewall configuration
- Displays access information

**Manual Operations:**
```bash
# Get admin password
docker logs polygotya | grep "DEFAULT ADMIN"

# Check health
curl https://polygotya.swordintelligence.airforce/health

# View callbacks
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  "SELECT * FROM ssh_callbacks ORDER BY timestamp DESC LIMIT 10;"

# Backup database
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  ".backup /data/backup.db"
docker cp polygotya:/data/backup.db ./polygotya-backup-$(date +%Y%m%d).db

# Check PQC status
curl -s https://polygotya.swordintelligence.airforce/health | jq '.pqc_enabled'
```

### Mattermost Management

**Initial Setup:**
```bash
./scripts/mattermost/initial-setup.sh
```

**Install Plugins:**
```bash
./scripts/mattermost/install-plugins.sh
```

Installs:
- Playbooks (incident response)
- Boards/Focalboard (knowledge base)
- GitLab integration
- Jira integration
- Remind bot

**Import Board Templates:**
```bash
# Templates available in mattermost/boards/
# - CVE Vulnerability Tracker
# - Threat Intelligence Database
# - Investigation Case Tracker

# Import via Mattermost UI: Boards → Import
```

---

## Service Management

### Start/Stop Services

**All Services:**
```bash
# Start all
docker-compose up -d

# Stop all
docker-compose down

# Restart all
docker-compose restart
```

**Specific Service Stacks:**
```bash
# Mattermost stack
docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d
docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml down

# POLYGOTYA
docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml up -d
docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml down
```

**Individual Services:**
```bash
# Restart single service
docker-compose restart caddy

# View logs
docker-compose logs -f caddy

# Execute command in container
docker-compose exec postgres psql -U postgres -l
```

### Update Services

**Pull Latest Images:**
```bash
docker-compose pull
```

**Rebuild and Deploy:**
```bash
docker-compose up -d --build
```

**Update Single Service:**
```bash
docker-compose up -d --force-recreate --no-deps caddy
```

---

## Backup & Recovery

### Backup Strategy

**Automated Daily Backups:**
```bash
# Add to crontab (run as root)
sudo crontab -e

# Daily backup at 2 AM
0 2 * * * /home/user/VPS2.0/scripts/backup.sh
```

**Backup Retention:**
- Default: 30 days
- Configure via `.env`: `BACKUP_RETENTION_DAYS=30`

**Backup Contents:**
```
/srv/backups/TIMESTAMP/
├── databases/
│   ├── postgres_all.sql.gz
│   ├── neo4j.dump.gz
│   ├── redis.rdb.gz
│   ├── mattermost_postgres.sql.gz
│   └── polygotya.db.gz
├── volumes/
│   ├── portainer_data.tar.gz
│   ├── grafana_data.tar.gz
│   ├── mattermost_data.tar.gz
│   └── ...
├── configs/
│   ├── docker-compose*.yml
│   ├── caddy/
│   ├── mattermost/
│   └── polygotya/
├── logs/
│   └── [container-name].log
└── MANIFEST.txt
```

### Disaster Recovery

**Recovery Time Objective (RTO):** 1-2 hours
**Recovery Point Objective (RPO):** 24 hours (daily backups)

**Disaster Recovery Steps:**

1. **Provision New Server**
   - Same specs as original
   - Debian 11/12 or Ubuntu 22.04 LTS
   - Docker + Docker Compose installed

2. **Restore VPS2.0:**
   ```bash
   # Clone repository
   git clone https://github.com/SWORDIntel/VPS2.0.git
   cd VPS2.0

   # Copy backup to server
   scp backup.tar.gz user@newserver:/tmp/

   # Run restore
   sudo ./scripts/restore.sh /tmp/backup.tar.gz
   ```

3. **Update DNS Records**
   - Point all subdomains to new server IP
   - Wait for DNS propagation

4. **Verify Services**
   ```bash
   ./scripts/verify-deployment.sh
   ./scripts/status.sh full
   ```

5. **Restore Secrets**
   - Update `.env` with passwords from password manager
   - Restart affected services

### S3 Backup (Optional)

Configure in `.env`:
```bash
S3_BACKUP_ENABLED=true
S3_BUCKET=vps2.0-backups
S3_ENDPOINT=https://s3.amazonaws.com
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key
```

Backups will automatically upload to S3 after local backup.

---

## Monitoring & Alerting

### Grafana Dashboards

Access: `https://grafana.swordintelligence.airforce`

**Pre-configured Dashboards:**
- Docker Container Metrics
- System Resources
- Application Performance
- Database Performance

**Key Metrics to Watch:**
- CPU usage > 80% (sustained)
- Memory usage > 90%
- Disk space < 10GB free
- Container restart count
- Database connection pool usage

### Alert Configuration

**Mattermost Integration:**
```bash
# Create incoming webhook in Mattermost
# System Console → Integrations → Incoming Webhooks
# Copy webhook URL

# Configure in Grafana
# Alerting → Contact Points → Add contact point
# Type: Webhook
# URL: [Mattermost webhook URL]
```

**Alert Rules:**
- Container down (P0 - immediate)
- High CPU usage > 80% for 5min (P1)
- High memory usage > 90% for 5min (P1)
- Disk space < 10GB (P1)
- Failed login attempts > 10/hour (P2)
- Certificate expiring in 30 days (P2)

### Log Management

**View Logs:**
```bash
# All services
docker-compose logs -f

# Specific service
docker logs -f caddy

# Last 100 lines
docker logs --tail 100 mattermost

# Since timestamp
docker logs --since "2025-11-18T12:00:00" polygotya
```

**Log Rotation:**
Configured via Docker daemon (`/etc/docker/daemon.json`):
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

---

## Troubleshooting

### Common Issues

**Service Won't Start:**
```bash
# Check logs
docker logs [container-name]

# Check configuration
docker-compose config

# Verify .env variables
grep -E "^[A-Z]" .env | grep -v "CHANGE_ME"

# Rebuild container
docker-compose up -d --force-recreate --no-deps [service]
```

**Database Connection Errors:**
```bash
# Check PostgreSQL
docker-compose exec postgres pg_isready

# Check connections
docker-compose exec postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Restart database
docker-compose restart postgres
```

**SSL/TLS Issues:**
```bash
# Check Caddy logs
docker logs caddy

# Verify DNS
dig polygotya.swordintelligence.airforce

# Test TLS
curl -vI https://polygotya.swordintelligence.airforce

# Force certificate renewal
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

**High Resource Usage:**
```bash
# Check container stats
docker stats

# Find resource hogs
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | sort -k 2 -rh

# Restart heavy service
docker-compose restart [service]
```

**POLYGOTYA Not Accessible:**
```bash
# Check container
docker ps | grep polygotya

# Check health
curl http://localhost:5000/health

# Check logs
docker logs polygotya

# Verify environment
docker exec polygotya env | grep API_KEY

# Restart
docker-compose -f docker-compose.polygotya.yml restart polygotya
```

**Mattermost Not Loading:**
```bash
# Check all Mattermost containers
docker ps | grep mattermost

# Check database connection
docker-compose -f docker-compose.mattermost.yml logs mattermost | grep -i database

# Restart stack
docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml restart
```

---

## Security Operations

### Security Hardening

**Run Hardening Script:**
```bash
sudo ./scripts/harden.sh
```

Applies:
- Kernel parameter tuning (sysctl)
- Firewall configuration (UFW)
- Fail2ban setup
- SSH hardening
- Docker security options
- File permissions

### Security Audits

**Weekly Security Checks:**
```bash
# Check for failed login attempts
sudo journalctl -u ssh | grep "Failed password"

# Review POLYGOTYA audit log
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  "SELECT * FROM audit_log WHERE action='LOGIN_FAILED' AND timestamp > datetime('now', '-7 days');"

# Check for suspicious activity
docker logs caddy | grep -E "(404|403|500)" | tail -50

# Scan containers for vulnerabilities (requires Docker scan)
docker scan caddy
```

**Monthly Security Tasks:**
- Review firewall rules
- Update all containers
- Review access logs
- Audit user accounts
- Check certificate expiration
- Review alert configurations

### Incident Response

**P0 Incident (Critical):**
1. Acknowledge in #p0-incidents channel
2. Start Mattermost Playbook: "P0 Incident Response"
3. Assess impact and scope
4. Implement containment
5. Document all actions
6. Communicate status updates every 30min

**Security Breach Response:**
1. Isolate affected systems
2. Preserve evidence (logs, backups)
3. Run forensic analysis
4. Implement remediation
5. Document lessons learned
6. Update security controls

---

## Maintenance Tasks

### Weekly Maintenance

**Every Monday:**
```bash
# System updates
sudo apt update && sudo apt upgrade -y

# Container updates
docker-compose pull
docker-compose up -d

# Disk cleanup
docker system prune -af --volumes --filter "until=168h"

# Backup verification
ls -lh /srv/backups/ | tail -7
```

### Monthly Maintenance

**First Day of Month:**
```bash
# Full system backup (ad-hoc)
sudo ./scripts/backup.sh

# Certificate check
echo | openssl s_client -servername polygotya.swordintelligence.airforce \
  -connect polygotya.swordintelligence.airforce:443 2>/dev/null | \
  openssl x509 -noout -dates

# Database optimization
docker-compose exec postgres vacuumdb -U postgres --all --analyze --verbose

# Neo4j maintenance
docker-compose exec neo4j cypher-shell "CALL gds.graph.list();"

# Review disk usage
df -h
du -sh /var/lib/docker/*
```

### Quarterly Maintenance

**Every 3 Months:**
- Review and update documentation
- Test disaster recovery procedure
- Security audit and penetration testing
- Review capacity planning
- Update dependencies
- Review and optimize Grafana dashboards
- Train team on new features

---

## Emergency Procedures

### Service Outage

**Complete Platform Down:**
```bash
# Check system health
./scripts/status.sh quick

# Review all logs
./scripts/status.sh logs

# Restart all services
docker-compose down && docker-compose up -d

# Verify restoration
./scripts/verify-deployment.sh
```

### Data Corruption

**Database Corruption:**
```bash
# Stop affected service
docker-compose stop [service]

# Restore from latest backup
sudo ./scripts/restore.sh /srv/backups/latest.tar.gz

# Verify data integrity
# (service-specific commands)

# Restart service
docker-compose start [service]
```

### Security Incident

**Suspected Breach:**
```bash
# 1. Isolate system
sudo ufw default deny incoming
sudo ufw default deny outgoing
sudo ufw allow 22/tcp  # Keep SSH for investigation

# 2. Preserve evidence
sudo ./scripts/backup.sh  # Emergency backup
docker logs --since "2025-11-18T00:00:00" > incident-logs-$(date +%Y%m%d).txt

# 3. Start incident response playbook in Mattermost

# 4. Document everything in Investigation Case Tracker board
```

---

## Support & Escalation

### Internal Support

**Tier 1:** Check this operations guide and troubleshooting section
**Tier 2:** Review deployment checklist and verification scripts
**Tier 3:** Contact VPS2.0 platform administrator

### External Support

**GitHub Issues:** https://github.com/SWORDIntel/VPS2.0/issues
**Security Issues:** security@swordintel.com
**Documentation:** https://docs.swordintel.com

### Escalation Matrix

| Severity | Response Time | Escalation | Notification |
|----------|--------------|------------|--------------|
| P0 (Critical) | < 15 min | Immediate | #p0-incidents + SMS |
| P1 (High) | < 1 hour | If unresolved in 2h | #alerts channel |
| P2 (Medium) | < 4 hours | If unresolved in 8h | #general channel |
| P3 (Low) | < 24 hours | If unresolved in 48h | Email |

---

## Appendix

### Quick Reference

**Service Ports:**
- 80/443: Caddy (HTTP/HTTPS)
- 5432: PostgreSQL
- 6379: Redis
- 7687: Neo4j
- 3000: Grafana
- 5000: POLYGOTYA (internal)
- 8065: Mattermost (internal)

**File Locations:**
- Configuration: `/home/user/VPS2.0/`
- Backups: `/srv/backups/`
- Logs: `/var/lib/docker/containers/`
- Data: Docker volumes

**Important URLs:**
- Portainer: https://portainer.swordintelligence.airforce
- Grafana: https://grafana.swordintelligence.airforce
- Mattermost: https://mattermost.swordintelligence.airforce
- POLYGOTYA: https://polygotya.swordintelligence.airforce

---

**Version:** 2.0
**Last Updated:** 2025-11-18
**Document Owner:** SWORD Intelligence Operations Team
**Review Cycle:** Quarterly
