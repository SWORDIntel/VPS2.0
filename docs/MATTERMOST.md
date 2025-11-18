# Mattermost Secure Team Collaboration

VPS2.0 integration of Mattermost with enterprise-grade security hardening.

---

## Overview

**Deployment:** `mattermost.swordintelligence.airforce`

**Architecture:**
- **Mattermost Application** - Team collaboration platform
- **PostgreSQL 16** - Dedicated database
- **Redis** - Session caching & job queues
- **MinIO** - S3-compatible object storage for files
- **Caddy** - TLS 1.3 termination with AES-256-GCM-SHA384

**Security Posture:**
- TLS 1.3 only, strong ciphers
- Network isolation (internal Docker networks)
- MFA-ready (configurable enforcement)
- Rate limiting & DDoS protection
- Audit logging enabled
- No public database/storage exposure

---

## Quick Start

### 1. Deploy Mattermost

```bash
cd /home/user/VPS2.0

# Configure environment
cp .env.template .env
nano .env  # Set DEPLOY_MATTERMOST=true and passwords

# Deploy stack
docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d

# Check health
docker ps | grep mattermost
docker logs mattermost
```

### 2. Initial Setup

1. **Access:** `https://mattermost.swordintelligence.airforce`
2. **Create first admin account** (first user becomes sysadmin)
3. **System Console** → Go to admin panel
4. **Configure:**
   - Email/SMTP settings
   - MFA enforcement
   - User creation policies
   - Team settings

###3. Security Hardening Checklist

**Immediate actions:**
- [ ] Change all default passwords in `.env`
- [ ] Configure SMTP for email notifications
- [ ] Enable MFA for all users
- [ ] Disable open user registration
- [ ] Review and restrict team creation
- [ ] Configure session timeouts
- [ ] Enable audit logging

**Recommended:**
- [ ] Set up SSO/SAML (if available)
- [ ] Configure IP restrictions (via Caddy)
- [ ] Enable compliance exports
- [ ] Set up backup automation
- [ ] Configure webhook integrations securely

---

## Architecture & Network Topology

### Components

| Service | Container | Port | Network | Purpose |
|---------|-----------|------|---------|---------|
| Mattermost | `mattermost` | 8065 | frontend, mattermost_backend | Application |
| PostgreSQL | `mattermost-db` | 5432 | mattermost_backend (internal) | Database |
| Redis | `mattermost-redis` | 6379 | mattermost_backend (internal) | Cache |
| MinIO | `mattermost-minio` | 9000, 9001 | mattermost_backend, frontend | Object storage |
| Caddy | `caddy` | 443 | frontend | TLS termination |

### Network Isolation

**Frontend Network** (`br-frontend`):
- Caddy ↔ Mattermost only
- Public-facing

**Mattermost Backend** (`br-mattermost` - **internal only**):
- Mattermost ↔ PostgreSQL
- Mattermost ↔ Redis
- Mattermost ↔ MinIO
- **No external exposure**

**VPS Firewall:**
- Allow: 22/tcp (SSH), 80/tcp (ACME), 443/tcp (HTTPS)
- Deny: Direct access to 8065, 5432, 6379, 9000

---

## Security Configuration

### TLS & Transport Security

**Caddy TLS Settings:**
- TLS 1.3 only
- Cipher preference: AES-256-GCM-SHA384
- HSTS enabled (2-year max-age)
- OCSP stapling
- Secure cookies only

**Mattermost TLS Configuration:**
```bash
# Enforced via environment variables
MM_SERVICESETTINGS_TLSMINVER=1.3
MM_SERVICESETTINGS_TLSSTRICTRANSPORT=true
MM_SERVICESETTINGS_TLSSTRICTTRANSPORTMAXAGE=63072000
```

### Authentication & Access Control

**Password Policy:**
- Minimum length: 12 characters
- Requires: lowercase, uppercase, number, symbol
- Lockout after 10 failed attempts

**MFA (Multi-Factor Authentication):**
```bash
# Enable MFA
MM_SERVICESETTINGS_ENABLEMULTIFACTORAUTHENTICATION=true

# Enforce MFA for all users (optional)
MATTERMOST_ENFORCE_MFA=true
```

**Session Management:**
- Web session: 7 days
- Mobile session: 30 days
- Idle timeout: 60 minutes
- Session cache: 10 minutes

**User Creation:**
```bash
# Disable open registration
MATTERMOST_ENABLE_USER_CREATION=false

# Restrict to specific email domains
MATTERMOST_RESTRICT_EMAIL_DOMAINS=example.com,company.com
```

### Rate Limiting

**Application-level:**
- 10 requests/second per client
- Burst: 100 requests
- Memory store: 10,000 entries

**Caddy-level:**
- API endpoints: 60 req/min
- Standard routes: 100 req/min
- Strict routes (admin): 30 req/min

### Audit Logging

**Enable Compliance Exports:**
```bash
MATTERMOST_COMPLIANCE_ENABLE=true
```

**Log Locations:**
- **Application logs:** `docker logs mattermost`
- **PostgreSQL logs:** `docker logs mattermost-db`
- **Caddy access logs:** `caddy/logs/mattermost_access.log`

**Log Rotation:**
- Docker: 10MB max, 3 files
- Caddy: 50MB max, 5 files

---

## Configuration

### Environment Variables

**Required:**
- `MATTERMOST_DB_PASSWORD` - Database password
- `MATTERMOST_REDIS_PASSWORD` - Redis password
- `MATTERMOST_MINIO_ACCESS_KEY` - MinIO access key
- `MATTERMOST_MINIO_SECRET_KEY` - MinIO secret (32+ chars)
- `MATTERMOST_PUBLIC_LINK_SALT` - Random 32-char salt

**Email (SMTP):**
- `MATTERMOST_SMTP_SERVER` - SMTP hostname
- `MATTERMOST_SMTP_PORT` - Port (587 for STARTTLS, 465 for SSL)
- `MATTERMOST_SMTP_USERNAME` - SMTP user
- `MATTERMOST_SMTP_PASSWORD` - SMTP password
- `MATTERMOST_SMTP_SECURITY` - `STARTTLS`, `TLS`, or `NONE`

**Optional:**
- `MATTERMOST_LOG_LEVEL` - `DEBUG`, `INFO`, `WARN`, `ERROR`
- `MATTERMOST_FEEDBACK_EMAIL` - From address for system emails
- `MATTERMOST_REPLY_TO_ADDRESS` - Reply-to address

### Mattermost System Console

Access: `https://mattermost.swordintelligence.airforce/admin_console`

**Key Settings:**
1. **Site Configuration** → Site URL (must match Caddy config)
2. **Authentication** → MFA, password policies, session lengths
3. **Users and Teams** → Signup restrictions, permissions
4. **Notifications** → Email settings, push notifications
5. **Integrations** → Webhooks, slash commands, bots
6. **Plugins** → Enable/disable features
7. **Compliance** → Data retention, exports

---

## Backup & Recovery

### Automated Backup

```bash
# Run backup script
./scripts/mattermost/backup.sh

# Output: /srv/backups/mattermost/mattermost-backup-YYYYMMDD-HHMMSS.tar.gz
```

**Backup Contents:**
- PostgreSQL database dump (compressed)
- Mattermost configuration files
- Installed plugins
- MinIO object storage (files, images)
- Backup manifest

**Schedule with cron:**
```bash
# Daily at 2 AM
0 2 * * * /home/user/VPS2.0/scripts/mattermost/backup.sh
```

### Manual Backup

**Database:**
```bash
docker exec mattermost-db pg_dump -U mattermost mattermost | \
    gzip > mattermost-db-$(date +%Y%m%d).sql.gz
```

**Config:**
```bash
docker cp mattermost:/mattermost/config ./mattermost-config-backup
```

**MinIO:**
```bash
docker exec mattermost-minio mc mirror /data/mattermost /backup/minio
```

### Restore Procedure

```bash
# 1. Stop containers
docker-compose -f docker-compose.mattermost.yml down

# 2. Extract backup
tar xzf mattermost-backup-YYYYMMDD-HHMMSS.tar.gz
cd mattermost-backup-YYYYMMDD-HHMMSS

# 3. Restore database
docker-compose -f docker-compose.mattermost.yml up -d mattermost-db
gunzip < database.sql.gz | docker exec -i mattermost-db psql -U mattermost mattermost

# 4. Restore config
docker cp config/. mattermost:/mattermost/config/

# 5. Restore MinIO
docker exec -i mattermost-minio mc mirror /backup/minio /data/mattermost

# 6. Start all services
docker-compose -f docker-compose.mattermost.yml up -d
```

---

## Monitoring & Maintenance

### Health Checks

```bash
# Check all containers
docker ps | grep mattermost

# Application health
curl https://mattermost.swordintelligence.airforce/api/v4/system/ping

# Database
docker exec mattermost-db pg_isready -U mattermost

# Redis
docker exec mattermost-redis redis-cli ping

# MinIO
docker exec mattermost-minio curl -f http://localhost:9000/minio/health/live
```

### Log Monitoring

```bash
# Application logs
docker logs -f mattermost

# Database logs
docker logs -f mattermost-db

# Redis logs
docker logs -f mattermost-redis

# Caddy access logs
tail -f caddy/logs/mattermost_access.log
```

### Resource Usage

```bash
# Container stats
docker stats mattermost mattermost-db mattermost-redis mattermost-minio

# Database size
docker exec mattermost-db psql -U mattermost -c "SELECT pg_size_pretty(pg_database_size('mattermost'));"

# MinIO usage
docker exec mattermost-minio mc du minio/mattermost
```

### Updates

```bash
# Pull latest images
docker-compose -f docker-compose.mattermost.yml pull

# Backup before update!
./scripts/mattermost/backup.sh

# Restart with new images
docker-compose -f docker-compose.mattermost.yml up -d

# Check logs for errors
docker logs mattermost
```

---

## Troubleshooting

### Cannot Access Web UI

**Symptoms:** 502 Bad Gateway or connection refused

**Diagnosis:**
```bash
# Check container status
docker ps | grep mattermost

# Check logs
docker logs mattermost

# Test internal connectivity
docker exec caddy curl -I http://mattermost:8065/api/v4/system/ping
```

**Solutions:**
- Container not running: `docker-compose -f docker-compose.mattermost.yml up -d`
- Database not ready: Wait for PostgreSQL to initialize
- Config error: Check `docker logs mattermost` for config validation errors

### Email Not Sending

**Diagnosis:**
```bash
# Check SMTP settings in logs
docker logs mattermost | grep -i smtp

# Test SMTP from container
docker exec -it mattermost telnet $MATTERMOST_SMTP_SERVER $MATTERMOST_SMTP_PORT
```

**Solutions:**
- Verify SMTP credentials in `.env`
- Check firewall allows outbound SMTP
- Try different SMTP security mode (STARTTLS vs TLS)
- Enable SMTP debugging: Set `MM_EMAILSETTINGS_ENABLEWEBHOOKDEBUGGING=true`

### WebSocket Connection Failed

**Symptoms:** "Trying to reconnect..." banner, delayed messages

**Diagnosis:**
```bash
# Check WebSocket upgrade in Caddy
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
    https://mattermost.swordintelligence.airforce/api/v4/websocket
```

**Solutions:**
- Verify Caddy WebSocket config (already configured)
- Check client firewall allows WebSocket
- Increase timeouts in Caddy if needed

### High Memory Usage

**Diagnosis:**
```bash
# Container stats
docker stats mattermost

# Mattermost internals
docker exec mattermost mattermost version
```

**Solutions:**
- Reduce `MM_SQLSETTINGS_MAXOPENCONNS` (currently 300)
- Increase Docker memory limits in `docker-compose.mattermost.yml`
- Check for runaway plugins
- Restart container: `docker restart mattermost`

---

## Security Hardening (Advanced)

### mTLS for Admin Panel

Add client certificate requirement for `/admin_console`:

```caddyfile
# In Caddyfile, add to mattermost.swordintelligence.airforce block:
@admin {
    path /admin_console*
}
handle @admin {
    tls {
        client_auth {
            mode require_and_verify
            trusted_ca_cert_file /config/certs/ca.crt
        }
    }
    reverse_proxy mattermost:8065
}
```

### IP Restrictions

Limit access to specific IPs/ranges:

```caddyfile
@allowed {
    remote_ip 10.10.0.0/24 203.0.113.0/24
}
handle @allowed {
    reverse_proxy mattermost:8065
}
respond 403
```

### Database Encryption

Enable PostgreSQL SSL/TLS for app ↔ DB connection:

1. Generate certs in `mattermost/db/certs/`
2. Update PostgreSQL config: `ssl = on`
3. Update Mattermost datasource: `?sslmode=require`

### Compliance & Data Retention

**Enable Compliance:**
```bash
MATTERMOST_COMPLIANCE_ENABLE=true
```

**Configure in System Console:**
- Compliance → Enable Daily Report
- Data Retention → Set retention policy
- Audits → Export audit logs

---

## Integration Examples

### Slack Migration

```bash
# Export from Slack
# Use Slack export tool

# Import to Mattermost
docker exec -it mattermost mattermost import slack /path/to/slack-export.zip
```

### Webhook Integration

**Incoming Webhook:**
1. System Console → Integrations → Enable Incoming Webhooks
2. Team → Integrations → Incoming Webhooks → Add
3. Use webhook URL in external services

**Outgoing Webhook:**
1. Enable in System Console
2. Configure trigger words and callback URLs
3. Receive POST requests from Mattermost

### Bot Accounts

```bash
# Create bot via API
curl -X POST https://mattermost.swordintelligence.airforce/api/v4/bots \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"username":"bot_name","display_name":"Bot Name"}'
```

---

## Summary

**What you get:**
- ✅ Secure team collaboration platform at `mattermost.swordintelligence.airforce`
- ✅ TLS 1.3 with strong ciphers (AES-256-GCM-SHA384)
- ✅ Network-isolated database and object storage
- ✅ MFA-ready authentication
- ✅ Automated backups
- ✅ Audit logging and compliance features
- ✅ Rate limiting and DDoS protection

**Next Steps:**
1. Complete initial setup and create admin account
2. Configure MFA and disable open registration
3. Set up SMTP for email notifications
4. Create teams and invite users
5. Configure plugins and integrations
6. Set up backup automation with cron
7. Monitor logs and performance

**Documentation:**
- Official Docs: https://docs.mattermost.com/
- Security: https://docs.mattermost.com/deploy/deployment-overview.html#security-features
- API: https://api.mattermost.com/
