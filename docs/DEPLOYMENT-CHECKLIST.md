# VPS2.0 Deployment Checklist

**Complete step-by-step checklist for VPS2.0 deployment**

Use this checklist to ensure a smooth, complete deployment of the SWORD Intelligence Platform.

---

## Pre-Deployment Phase

### Server Preparation

- [ ] VPS provisioned with minimum 16GB RAM, 100GB SSD
- [ ] Debian 11/12 or Ubuntu 22.04 LTS installed
- [ ] Server accessible via SSH (port 22)
- [ ] Root or sudo access confirmed
- [ ] Server IP address documented: `__________________`
- [ ] Domain name acquired: `__________________`

### DNS Configuration

- [ ] Created A record: `*.swordintelligence.airforce` → Server IP
- [ ] OR created specific subdomain A records:
  - [ ] `mattermost.swordintelligence.airforce`
  - [ ] `polygotya.swordintelligence.airforce`
  - [ ] `grafana.swordintelligence.airforce`
  - [ ] `portainer.swordintelligence.airforce`
- [ ] DNS propagation verified (nslookup/dig)

### Software Prerequisites

- [ ] Docker installed (20.10+)
  ```bash
  curl -fsSL https://get.docker.com | sh
  ```
- [ ] Docker Compose installed (2.0+)
- [ ] User added to docker group
  ```bash
  sudo usermod -aG docker $USER
  newgrp docker
  ```
- [ ] Verified Docker works without sudo
  ```bash
  docker ps
  ```

---

## Deployment Phase

### Step 1: Repository Setup

- [ ] Cloned VPS2.0 repository
  ```bash
  cd /home/user
  git clone https://github.com/SWORDIntel/VPS2.0.git
  cd VPS2.0
  ```
- [ ] Repository at correct path: `/home/user/VPS2.0`
- [ ] Branch checked out: `main` or `__________________`

### Step 2: Environment Configuration

- [ ] Copied `.env.template` to `.env`
  ```bash
  cp .env.template .env
  ```
- [ ] Set `DOMAIN=swordintelligence.airforce`
- [ ] Generated and set secure passwords for:
  - [ ] `POSTGRES_PASSWORD` (openssl rand -base64 32)
  - [ ] `REDIS_PASSWORD` (openssl rand -base64 32)
  - [ ] `GRAFANA_ADMIN_PASSWORD` (openssl rand -base64 32)
  - [ ] `MATTERMOST_DB_PASSWORD` (openssl rand -base64 32)
  - [ ] `MATTERMOST_REDIS_PASSWORD` (openssl rand -base64 32)
  - [ ] `MATTERMOST_MINIO_ACCESS_KEY` (openssl rand -base64 32)
  - [ ] `MATTERMOST_MINIO_SECRET_KEY` (openssl rand -base64 32)
  - [ ] `POLYGOTYA_API_KEY` (openssl rand -base64 32)
  - [ ] `POLYGOTYA_SECRET_KEY` (openssl rand -hex 32)
  - [ ] `POLYGOTYA_ADMIN_PASSWORD` (openssl rand -base64 24)
- [ ] Enabled desired services:
  - [ ] `DEPLOY_DNS_HUB=true` (if using DNS Hub)
  - [ ] `DEPLOY_MATTERMOST=true`
  - [ ] `DEPLOY_POLYGOTYA=true`
  - [ ] `DEPLOY_GRAFANA=true`
- [ ] Verified NO `CHANGE_ME` values remain
  ```bash
  grep "CHANGE_ME" .env
  ```
- [ ] Saved `.env` file securely (backup to password manager)

### Step 3: Initial Deployment

- [ ] Made deployment script executable
  ```bash
  chmod +x scripts/deploy.sh
  ```
- [ ] Ran deployment script
  ```bash
  sudo ./scripts/deploy.sh
  ```
- [ ] Monitored deployment progress (10-15 minutes)
- [ ] Saved `credentials.txt` to password manager
- [ ] **DELETED `credentials.txt` from server**
  ```bash
  rm credentials.txt
  ```

### Step 4: Verify Deployment

- [ ] Ran verification script
  ```bash
  ./scripts/verify-deployment.sh
  ```
- [ ] All core services running:
  - [ ] Caddy
  - [ ] PostgreSQL
  - [ ] Redis
  - [ ] Grafana
- [ ] Mattermost services running (if deployed):
  - [ ] Mattermost
  - [ ] Mattermost-DB
  - [ ] Mattermost-Redis
  - [ ] Mattermost-MinIO
- [ ] POLYGOTYA running (if deployed)
- [ ] No unhealthy containers
  ```bash
  docker ps
  ```

---

## Post-Deployment Phase

### Firewall Configuration

- [ ] UFW installed and enabled
- [ ] Port 22 (SSH) allowed and verified
  ```bash
  sudo ufw status | grep 22
  ```
- [ ] Port 80 (HTTP) allowed
- [ ] Port 443 (HTTPS) allowed
- [ ] Firewall enabled
  ```bash
  sudo ufw enable
  ```
- [ ] **Verified SSH still works before closing session**

### SSL/TLS Verification

- [ ] Accessed services via HTTPS (not HTTP)
- [ ] Caddy obtained Let's Encrypt certificates automatically
- [ ] No browser SSL warnings
- [ ] Verified TLS 1.3 in use
  ```bash
  curl -vI https://mattermost.swordintelligence.airforce 2>&1 | grep "TLSv1.3"
  ```

### Mattermost Setup

- [ ] Accessed: `https://mattermost.swordintelligence.airforce`
- [ ] Created first admin account
  - Username: `__________________`
  - Email: `intel@swordintelligence.airforce`
- [ ] Ran initial security setup
  ```bash
  ./scripts/mattermost/initial-setup.sh
  ```
- [ ] Configured SMTP email settings (System Console → Email)
  - SMTP Server: `__________________`
  - SMTP Port: `587` or `__________________`
  - Username: `intel@swordintelligence.airforce`
  - Password: (from password manager)
- [ ] Enabled MFA in System Console
- [ ] Disabled open user registration
- [ ] Installed plugins
  ```bash
  ./scripts/mattermost/install-plugins.sh
  ```
- [ ] Verified plugins installed:
  - [ ] Playbooks
  - [ ] Boards (Focalboard)
  - [ ] GitLab
  - [ ] Jira
  - [ ] Remind
- [ ] Imported board templates:
  - [ ] CVE Vulnerability Tracker
  - [ ] Threat Intelligence Database
  - [ ] Investigation Case Tracker
- [ ] Created incident response playbooks from templates

### POLYGOTYA Setup

- [ ] Retrieved admin password
  ```bash
  docker logs polygotya | grep "DEFAULT ADMIN"
  ```
- [ ] Accessed: `https://polygotya.swordintelligence.airforce`
- [ ] Logged in with admin account
- [ ] **Changed admin password immediately**
- [ ] Verified health endpoint
  ```bash
  curl https://polygotya.swordintelligence.airforce/health
  ```
- [ ] Verified PQC enabled in health response
- [ ] Tested encrypted callback (optional)
- [ ] Saved API key from `.env` to password manager
  ```bash
  grep POLYGOTYA_API_KEY .env
  ```

### Grafana Setup

- [ ] Accessed: `https://grafana.swordintelligence.airforce`
- [ ] Logged in with default credentials (admin/admin)
- [ ] **Changed admin password**
- [ ] Configured data sources:
  - [ ] Prometheus
  - [ ] Loki
  - [ ] Victoria Metrics
- [ ] Imported dashboards
- [ ] Set up alert rules (optional)
- [ ] Configured AlertManager → Mattermost webhook (optional)

### DNS Hub Setup (if deployed)

- [ ] Accessed Technitium DNS: `http://SERVER_IP:5380`
- [ ] Changed default password (admin/admin)
- [ ] Configured DNS zones
- [ ] Set up WireGuard VPN
  - [ ] Generated client configs
  - [ ] Tested VPN connection
  - [ ] Verified DNS queries through VPN

---

## Security Hardening Phase

### Password Security

- [ ] All default passwords changed
- [ ] All passwords stored in password manager
- [ ] Passwords meet complexity requirements:
  - [ ] 12+ characters
  - [ ] Uppercase, lowercase, numbers, symbols
- [ ] No passwords stored in plaintext on server
- [ ] `.env` file permissions set to 600
  ```bash
  chmod 600 .env
  ```

### MFA Configuration

- [ ] MFA enabled for Mattermost admin account
- [ ] MFA enforced for all Mattermost users (optional)
- [ ] MFA tested and recovery codes saved

### Network Security

- [ ] Firewall configured and tested
- [ ] SSH key authentication enabled (optional but recommended)
- [ ] SSH password authentication disabled (optional)
- [ ] Fail2ban installed and configured (optional)
  ```bash
  sudo apt install fail2ban
  ```
- [ ] Rate limiting verified in Caddy logs

### Audit Logging

- [ ] Mattermost audit logging enabled
- [ ] POLYGOTYA audit logging verified
  ```bash
  docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db "SELECT COUNT(*) FROM audit_log;"
  ```
- [ ] Docker logs configured (log rotation)
- [ ] Centralized logging set up (optional)

---

## Backup & Recovery Phase

### Backup Configuration

- [ ] Backup directory created: `/srv/backups/`
- [ ] Backup script tested
  ```bash
  ./scripts/backup.sh
  ```
- [ ] Backup includes:
  - [ ] PostgreSQL databases
  - [ ] Mattermost data
  - [ ] POLYGOTYA database
  - [ ] Configuration files (.env, docker-compose files)
  - [ ] Caddy certificates
- [ ] Automated backup cron job configured
  ```bash
  0 2 * * * /home/user/VPS2.0/scripts/backup.sh
  ```
- [ ] Backups compressed and encrypted
- [ ] Off-site backup location configured (optional)
- [ ] Backup retention policy set (keep 30 days)

### Recovery Testing

- [ ] Documented recovery procedure
- [ ] Tested database restore (in test environment if possible)
- [ ] Verified backup integrity
- [ ] Recovery time objective (RTO) documented
- [ ] Recovery point objective (RPO) documented

---

## Monitoring & Alerting Phase

### Health Monitoring

- [ ] Grafana dashboards configured
- [ ] Container health checks enabled
- [ ] Disk space monitoring configured (alert at 80%)
- [ ] Memory usage monitoring configured
- [ ] CPU usage monitoring configured
- [ ] Service uptime monitoring configured

### Alerting

- [ ] AlertManager configured
- [ ] Mattermost #alerts channel created
- [ ] Alert rules configured:
  - [ ] Container down
  - [ ] High CPU usage (>80%)
  - [ ] High memory usage (>90%)
  - [ ] Low disk space (<10GB)
  - [ ] Failed login attempts
  - [ ] Certificate expiration (30 days)
- [ ] Test alert sent to Mattermost
- [ ] On-call rotation configured (if applicable)

---

## Integration Phase

### GitLab Integration (if deployed)

- [ ] GitLab OAuth app created
- [ ] Mattermost GitLab plugin configured
- [ ] Test repository subscribed to Mattermost channel
- [ ] Webhooks tested (issue creation, MR, pipeline)

### Prometheus Integration

- [ ] AlertManager configured
- [ ] Webhook created in Mattermost #alerts channel
- [ ] Test alert sent successfully
- [ ] Alert routing configured

### Email Integration

- [ ] SMTP configured in Mattermost
- [ ] Test email sent successfully
- [ ] Email templates customized (optional)
- [ ] Email notifications configured per user preference

---

## Documentation Phase

### System Documentation

- [ ] Network topology documented
- [ ] Service URLs documented
- [ ] Admin credentials documented (in password manager only)
- [ ] Firewall rules documented
- [ ] Backup procedures documented
- [ ] Recovery procedures documented

### Operational Runbooks

- [ ] Incident response playbook created
- [ ] Service restart procedures documented
- [ ] Troubleshooting guide created
- [ ] Escalation procedures defined

### User Documentation

- [ ] Mattermost user guide created (optional)
- [ ] Board templates documented
- [ ] Playbook usage guide created
- [ ] Training materials prepared (if needed)

---

## Production Readiness Phase

### Final Checks

- [ ] All services accessible from internet
- [ ] SSL certificates valid and not expiring soon
- [ ] No security vulnerabilities in deployed containers
  ```bash
  docker scan caddy
  ```
- [ ] No exposed secrets in logs or environment
- [ ] All critical data encrypted at rest
- [ ] All communications encrypted in transit (TLS 1.3)
- [ ] Compliance requirements met (TEMPEST Level C for POLYGOTYA)

### Performance Testing

- [ ] Load testing performed (optional)
- [ ] Response times acceptable (<2s for web UI)
- [ ] Database query performance acceptable
- [ ] No memory leaks observed over 24 hours
- [ ] No disk space leaks observed

### Disaster Recovery

- [ ] Disaster recovery plan documented
- [ ] Backup restore tested
- [ ] Failover procedures documented (if applicable)
- [ ] Business continuity plan created
- [ ] RTO/RPO defined and communicated

---

## Team Onboarding Phase

### User Accounts

- [ ] Mattermost accounts created for team members
- [ ] Roles and permissions assigned
- [ ] MFA enrollment confirmed for all users
- [ ] User training scheduled

### Workspace Setup

- [ ] Teams created in Mattermost
- [ ] Channels created:
  - [ ] #general
  - [ ] #p0-incidents
  - [ ] #alerts
  - [ ] #playbook-runs
- [ ] Board templates imported and configured
- [ ] Playbooks created from templates:
  - [ ] P0 Incident Response
  - [ ] Security Patch Deployment

### Integration Testing

- [ ] End-to-end incident response workflow tested
- [ ] Board creation and updates tested
- [ ] Playbook execution tested
- [ ] Alert flow tested (Prometheus → Mattermost)
- [ ] POLYGOTYA callback tested

---

## Sign-Off

### Deployment Lead

- [ ] Deployment completed successfully
- [ ] All checklist items completed
- [ ] System handed over to operations team
- [ ] Post-deployment review scheduled

**Name**: `__________________`  
**Date**: `__________________`  
**Signature**: `__________________`

### Operations Lead

- [ ] Handover received
- [ ] System documentation reviewed
- [ ] Access credentials verified
- [ ] Monitoring and alerting verified
- [ ] Backup and recovery procedures understood

**Name**: `__________________`  
**Date**: `__________________`  
**Signature**: `__________________`

---

## Post-Deployment Notes

**Issues Encountered**:
```
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```

**Deviations from Standard**:
```
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```

**Recommendations**:
```
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```

---

**Deployment Status**: ☐ Complete ☐ Partial ☐ Failed  
**Production Ready**: ☐ Yes ☐ No ☐ Pending  
**Sign-Off Date**: `__________________`

---

**Version**: 2.0  
**Last Updated**: 2025-11-18  
**Document Owner**: SWORD Intelligence Operations Team
