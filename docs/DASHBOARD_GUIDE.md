# VPS2.0 Dashboard & Control Center Guide

## Overview

The VPS2.0 platform includes a comprehensive **TEMPEST Level C compliant** unified dashboard system for monitoring and managing all services. The dashboard is designed for government/military-spec operations with no external dependencies.

---

## Quick Access

### Main Endpoints

| Service | URL | Description |
|---------|-----|-------------|
| **Homepage** | `https://your-domain.com` | SWORDINTELLIGENCE main platform |
| **Dashboard** | `https://dashboard.your-domain.com` | **Unified control center** ⭐ |
| **Service Status** | `https://status.your-domain.com` | Uptime monitoring |
| **Metrics** | `https://monitoring.your-domain.com` | Grafana dashboards |
| **Real-time** | `https://netdata.your-domain.com` | Live system metrics |
| **Logs** | `https://logs.your-domain.com` | Docker container logs |
| **System Monitor** | `https://glances.your-domain.com` | Advanced system stats |

---

## Dashboard Features

### TEMPEST Level C Compliance

The unified dashboard at `dashboard.your-domain.com` is compliant with TEMPEST Level C specifications:

✅ **No External Resources**
- All assets served locally
- No CDN dependencies
- No external image loading
- Air-gap ready operation

✅ **Government-Spec Styling**
- Terminal green on black color scheme
- Classification markings (top/bottom)
- Monospace fonts (Courier New)
- Minimal electromagnetic emissions

✅ **Security Features**
- Classification banners
- No analytics or tracking
- Secure by default
- No internet dependencies

---

## Dashboard Layout

### INTELLIGENCE OPERATIONS
- **SWORDINTELLIGENCE** - Main intelligence platform
- **MISP** - Threat intelligence sharing
- **OpenCTI** - Structured threat intelligence

### INFRASTRUCTURE
- **Portainer** - Container management
- **Caddy** - Reverse proxy status
- **PostgreSQL** - Database health

### SECURITY & ANALYSIS
- **Cortex** - Observable analysis
- **n8n** - Workflow automation
- **ClamAV** - Antivirus scanner

### MONITORING & LOGS
- **Grafana** - Metrics visualization
- **Uptime Kuma** - Service monitoring
- **Netdata** - Real-time metrics
- **Dozzle** - Docker logs

### DEVELOPMENT
- **GitLab** - Source code & CI/CD
- **Container Registry** - Docker images

### OPTIONAL SERVICES
- **HURRICANE** - IPv6 proxy
- **ARTICBASTION** - Secure gateway
- **Glances** - System monitor

---

## Deployment

### Deploy Dashboard Services

```bash
# Deploy all dashboard components
docker-compose -f docker-compose.yml -f docker-compose.dashboard.yml up -d

# Or include in full deployment
docker-compose \
    -f docker-compose.yml \
    -f docker-compose.intelligence.yml \
    -f docker-compose.dashboard.yml \
    up -d
```

### Verify Deployment

```bash
# Check dashboard services
docker-compose ps homepage uptime-kuma netdata dozzle glances

# View logs
docker-compose logs -f homepage

# Test dashboard access
curl -I https://dashboard.your-domain.com
```

---

## Configuration

### Environment Variables

Add to your `.env` file:

```bash
# Dashboard Configuration
HOMEPAGE_VAR_DOMAIN=your-domain.com
HOMEPAGE_VAR_PORTAINER_KEY=your-portainer-api-key
HOMEPAGE_VAR_GRAFANA_USER=admin
HOMEPAGE_VAR_GRAFANA_PASSWORD=your-grafana-password
HOMEPAGE_VAR_GITLAB_TOKEN=your-gitlab-token
```

### DNS Configuration

Add these DNS records:

```
A    dashboard     YOUR_SERVER_IP
A    status        YOUR_SERVER_IP
A    netdata       YOUR_SERVER_IP
A    logs          YOUR_SERVER_IP
A    glances       YOUR_SERVER_IP
```

---

## Widget Types

The dashboard includes real-time widgets for:

### System Resources
- CPU usage and temperature
- Memory utilization
- Disk usage (/, /srv/docker, /srv/backups)
- Network throughput
- System uptime

### Docker Stats
- Running containers
- Container resource usage
- Health status
- Recent events

### Service Health
- HTTP endpoint monitoring
- API availability
- Database connections
- Queue status

---

## Customization

### Modify Theme

Edit `/homepage/config/settings.yaml`:

```yaml
# Change classification level
customCSS: |
  body::before {
    content: "SECRET - YOUR CLASSIFICATION HERE";
  }
```

### Add Services

Edit `/homepage/config/services.yaml`:

```yaml
- YOUR CATEGORY:
    - Service Name:
        icon: mdi-icon-name
        href: https://service.your-domain.com
        description: SERVICE DESCRIPTION
        widget:
          type: customapi
          url: http://service:port/health
        server: docker-socket
        container: container_name
```

### Add Bookmarks

Edit `/homepage/config/bookmarks.yaml`:

```yaml
- YOUR CATEGORY:
    - Bookmark Name:
        - icon: mdi-icon-name
          href: https://link.com
          description: DESCRIPTION
```

---

## Monitoring Tools

### 1. Homepage Dashboard
**Purpose**: Unified control center
**Best For**: Quick overview, service access
**Update Frequency**: 5 seconds

### 2. Uptime Kuma
**Purpose**: Service uptime monitoring
**Best For**: Availability tracking, alerting
**Features**:
- HTTP/TCP/Ping monitors
- SSL certificate checks
- Notification integrations
- Status pages

### 3. Netdata
**Purpose**: Real-time system metrics
**Best For**: Performance troubleshooting
**Features**:
- Per-second granularity
- Auto-detection of services
- 1000+ metrics
- Anomaly detection

### 4. Dozzle
**Purpose**: Docker log viewer
**Best For**: Container debugging
**Features**:
- Real-time log streaming
- Multi-container view
- Search and filter
- No storage needed

### 5. Glances
**Purpose**: Advanced system monitor
**Best For**: Resource monitoring
**Features**:
- CPU, memory, disk, network
- Process monitoring
- Docker integration
- REST API

### 6. Grafana
**Purpose**: Metrics visualization
**Best For**: Historical analysis, dashboards
**Features**:
- Custom dashboards
- Alerting
- Multi-datasource
- Pre-configured panels

---

## Security Best Practices

### 1. Access Control

```bash
# Use WireGuard VPN for dashboard access
# Configure in .env
WIREGUARD_ENABLED=true

# Or use IP whitelisting in Caddy
# Add to Caddyfile:
dashboard.{$DOMAIN} {
    @allowed {
        remote_ip 10.0.0.0/8 172.16.0.0/12
    }
    handle @allowed {
        reverse_proxy homepage:3000
    }
    respond 403
}
```

### 2. Authentication

All dashboards support authentication:
- Homepage: No auth (use VPN/IP filtering)
- Uptime Kuma: Built-in auth
- Netdata: Can enable auth
- Dozzle: No auth (VPN recommended)
- Glances: Password protection available

### 3. TEMPEST Compliance

For maximum TEMPEST compliance:
1. Use wired connections only
2. Enable dark themes everywhere
3. Minimize external resource loading
4. Use terminal fonts
5. Disable unnecessary features

---

## Troubleshooting

### Dashboard Not Loading

```bash
# Check Homepage container
docker-compose logs homepage

# Verify configuration
docker-compose exec homepage cat /app/config/settings.yaml

# Restart dashboard
docker-compose restart homepage
```

### Widgets Not Showing Data

```bash
# Check Docker socket permissions
ls -la /var/run/docker.sock

# Verify network connectivity
docker-compose exec homepage wget -O- http://victoriametrics:8428/api/v1/status/tsdb

# Check API keys
docker-compose exec homepage env | grep HOMEPAGE_VAR
```

### Service Not Appearing

```bash
# Verify container is running
docker-compose ps [service_name]

# Check networks
docker network inspect vps20_frontend

# Test connectivity
docker-compose exec homepage ping [service_name]
```

---

## Performance Tuning

### Reduce Resource Usage

```yaml
# In docker-compose.dashboard.yml
services:
  homepage:
    deploy:
      resources:
        limits:
          memory: 256M  # Reduce from 512M
```

### Disable Unused Services

```yaml
# Comment out services you don't need
services:
  # glances:
  #   image: nicolargo/glances:latest
  #   ...
```

### Optimize Widget Refresh

```yaml
# In homepage/config/settings.yaml
- resources:
    refresh: 10000  # Increase from 3000 (10 seconds)
```

---

## Grafana Dashboards

### Pre-configured Dashboards

1. **VPS2.0 Overview** (`vps2-overview`)
   - System resources (CPU, RAM, Disk)
   - Container metrics
   - Network stats
   - Alert status

2. **Docker Containers** (import ID: 193)
   - Container resource usage
   - Container health
   - Logs volume

3. **Node Exporter** (import ID: 1860)
   - Detailed system metrics
   - Hardware monitoring
   - Predictive alerts

### Import Additional Dashboards

```bash
# Via Grafana UI:
# 1. Go to Dashboards → Import
# 2. Enter dashboard ID (e.g., 193)
# 3. Select datasource: VictoriaMetrics
# 4. Click Import
```

---

## Alerts & Notifications

### Configure Uptime Kuma Alerts

1. Access: `https://status.your-domain.com`
2. Go to Settings → Notifications
3. Add notification channels:
   - Email
   - Slack
   - Discord
   - Telegram
   - Webhook

### Configure Grafana Alerts

1. Access: `https://monitoring.your-domain.com`
2. Go to Alerting → Notification channels
3. Add channels (same as above)
4. Create alert rules in dashboards

---

## Backup Dashboard Configuration

```bash
# Backup Homepage config
tar czf homepage-config-$(date +%Y%m%d).tar.gz homepage/config/

# Backup Grafana dashboards
docker-compose exec grafana grafana-cli admin export > grafana-export.json

# Backup Uptime Kuma
docker run --rm \
    -v uptime_kuma_data:/data \
    -v $(pwd):/backup \
    alpine tar czf /backup/uptime-kuma-$(date +%Y%m%d).tar.gz /data
```

---

## Integration Examples

### Homepage + Prometheus + Grafana

```yaml
# Homepage widget showing Grafana dashboard
- Grafana:
    widget:
      type: grafana
      url: http://grafana:3000
      username: admin
      password: ${GRAFANA_PASSWORD}
```

### Uptime Kuma + n8n Automation

```yaml
# n8n workflow triggered by Uptime Kuma webhook
# Automatically creates incident tickets
# Sends notifications to team
# Updates status page
```

---

## API Access

All dashboard tools provide REST APIs:

```bash
# Homepage API
curl http://homepage:3000/api/services

# Uptime Kuma API
curl http://uptime-kuma:3001/api/status-page/vps2

# Netdata API
curl http://netdata:19999/api/v1/info

# Glances API
curl http://glances:61208/api/3/cpu

# Grafana API
curl -H "Authorization: Bearer YOUR_API_KEY" \
    http://grafana:3000/api/dashboards/home
```

---

## TEMPEST Level C Checklist

- [ ] All services use local resources only
- [ ] No external CDN or image loading
- [ ] Dark theme enabled everywhere
- [ ] Monospace fonts configured
- [ ] Classification banners displayed
- [ ] VPN or IP filtering enabled
- [ ] Analytics disabled
- [ ] External searches disabled
- [ ] Minimal JavaScript usage
- [ ] Air-gap capable

---

## Quick Commands

```bash
# Deploy dashboard
docker-compose -f docker-compose.yml -f docker-compose.dashboard.yml up -d

# View all dashboard logs
docker-compose logs -f homepage uptime-kuma netdata dozzle glances

# Restart dashboards
docker-compose restart homepage uptime-kuma netdata dozzle glances

# Update dashboard images
docker-compose pull homepage uptime-kuma netdata dozzle glances
docker-compose up -d --force-recreate

# Remove dashboards
docker-compose down homepage uptime-kuma netdata dozzle glances
```

---

## Support

For issues or questions:
1. Check logs: `docker-compose logs [service]`
2. Verify configuration files
3. Test network connectivity
4. Review security settings
5. Consult main documentation

---

**Dashboard Version**: 1.0
**TEMPEST Compliance**: Level C
**Last Updated**: 2025-11-18
**Status**: Production Ready 🛡️

---

**CLASSIFIED - TEMPEST LEVEL C**
