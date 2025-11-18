# VPS2.0 External Submodules

This directory contains git submodules for external SWORDIntel projects integrated into the VPS2.0 platform.

---

## 📦 Included Submodules

### 1. HURRICANE
**Repository:** https://github.com/SWORDIntel/HURRICANE
**Purpose:** IPv6-over-IPv4 tunnel daemon with multiple backend support

**Features:**
- Hurricane Electric (HE) tunnel support
- Mullvad VPN integration
- WireGuard VPN support
- REST API (port 8080)
- Web UI (port 8081)
- SOCKS5 proxy (port 1080)
- Prometheus metrics (port 9090)

**Integration:**
- Docker Compose: `docker-compose.hurricane.yml`
- Caddy routes:
  - `hurricane.{DOMAIN}`
  - `HURRICANE.swordintelligence.airforce`
- Optional service in setup wizard

---

### 2. ARTICBASTION
**Repository:** https://github.com/SWORDIntel/ARTICBASTION (Private)
**Purpose:** Secure gateway and bastion host for administrative access

**Features:**
- Secure SSH gateway
- Multi-factor authentication
- Session recording
- Access control and audit logging

**Integration:**
- Caddy route: `ARTICBASTION.swordintelligence.airforce`
- Client certificate authentication required
- IP whitelist support
- Strict rate limiting

---

### 3. CLOUDCLEAR
**Repository:** https://github.com/SWORDIntel/CLOUDCLEAR
**Purpose:** Cloud provider detection and intelligence platform

**Features:**
- Detects 12+ CDN/WAF providers (Cloudflare, Akamai, AWS CloudFront, etc.)
- Integrates with 3 intelligence services (Shodan, Censys, VirusTotal)
- TEMPEST Level C security-focused web UI
- Real-time WebSocket scan updates
- HTTP header analysis
- DNS/CNAME resolution
- SSL/TLS certificate inspection
- IP range detection
- WAF signature detection

**Integration:**
- Docker Compose: `docker-compose.cloudclear.yml`
- Caddy routes:
  - `cloudclear.{DOMAIN}`
  - `CLOUDCLEAR.swordintelligence.airforce`
- Optional service in setup wizard
- API port: 8080
- WebSocket support for live updates

---

## 🔧 Working with Submodules

### Initialize Submodules (First Time)
```bash
git submodule init
git submodule update
```

### Update All Submodules to Latest
```bash
git submodule update --remote --merge
```

### Update Specific Submodule
```bash
git submodule update --remote external/HURRICANE
git submodule update --remote external/CLOUDCLEAR
git submodule update --remote external/ARTICBASTION
```

### Clone Repository with Submodules
```bash
git clone --recurse-submodules https://github.com/SWORDIntel/VPS2.0.git
```

### Pull Latest Changes (Including Submodules)
```bash
git pull --recurse-submodules
```

---

## 📝 Deployment

### Enable in Setup Wizard

During the interactive setup wizard, you'll be prompted to deploy optional services:

**HURRICANE:**
```
Deploy HURRICANE IPv6 proxy? [y/N]: y
  Enable Hurricane Electric tunnel? [y/N]: y
  HE Username: your-username
  HE Password: your-password
  HE Tunnel ID: 12345
```

**CLOUDCLEAR:**
```
Deploy CLOUDCLEAR cloud provider detection? [y/N]: y
  Configure intelligence API keys now? [y/N]: y
  Shodan API Key (optional): your-api-key
  Censys API ID (optional): your-api-id
  Censys API Secret (optional): your-api-secret
  VirusTotal API Key (optional): your-api-key
```

### Manual Deployment

**HURRICANE:**
```bash
docker-compose -f docker-compose.hurricane.yml up -d
```

**CLOUDCLEAR:**
```bash
docker-compose -f docker-compose.cloudclear.yml up -d
```

---

## 🌐 DNS Configuration

### Required DNS Records

**For HURRICANE:**
```
A    HURRICANE.swordintelligence.airforce    → YOUR_SERVER_IP
```

**For ARTICBASTION:**
```
A    ARTICBASTION.swordintelligence.airforce → YOUR_SERVER_IP
```

**For CLOUDCLEAR:**
```
A    cloudclear.yourdomain.com               → YOUR_SERVER_IP
A    CLOUDCLEAR.swordintelligence.airforce   → YOUR_SERVER_IP
```

---

## 🔐 Security Considerations

### ARTICBASTION
- **Private repository** - Requires access token for cloning
- Client certificates required for access
- IP whitelisting recommended
- Strict rate limiting enabled

### CLOUDCLEAR
- TEMPEST Level C compliant interface
- No external resources loaded
- API keys stored in environment variables
- Optional cloud provider credentials (for enhanced detection)

### HURRICANE
- Requires `NET_ADMIN` capability
- Tunneling protocols may need firewall rules
- VPN credentials stored securely

---

## 📊 Resource Usage

| Service | Memory | CPU | Disk | Network |
|---------|--------|-----|------|---------|
| **HURRICANE** | ~256MB | Low | ~100MB | High (tunneling) |
| **ARTICBASTION** | ~128MB | Low | ~50MB | Low |
| **CLOUDCLEAR** | ~512MB | Medium | ~200MB | Medium (scanning) |

---

## 🔗 Integration Points

### Network Integration
- All services connect to VPS2.0 frontend/backend networks
- Isolated from each other except through Caddy proxy
- No direct container-to-container communication

### Caddy Integration
- Automatic HTTPS via Let's Encrypt
- WebSocket support for CLOUDCLEAR
- Rate limiting on all endpoints
- Security headers (TEMPEST Level C)

### Monitoring Integration
- Services expose health check endpoints
- Prometheus metrics available
- Logs integrated with VPS2.0 logging stack

---

## 🛠️ Troubleshooting

### Submodule Not Initialized
```bash
cd /opt/vps2.0
git submodule init
git submodule update
```

### Submodule Update Failed
```bash
# Reset submodule to tracked commit
git submodule update --init --force external/HURRICANE
```

### ARTICBASTION Clone Failed (Private Repo)
Use personal access token:
```bash
# Configure git to use token
git config --global url."https://TOKEN@github.com/".insteadOf "https://github.com/"
```

### Container Build Failed
```bash
# Rebuild from scratch
docker-compose -f docker-compose.cloudclear.yml build --no-cache cloudclear
```

---

## 📚 Additional Documentation

- **HURRICANE:** See `external/HURRICANE/README.md`
- **ARTICBASTION:** See `external/ARTICBASTION/README.md` (if accessible)
- **CLOUDCLEAR:** See `external/CLOUDCLEAR/README.md`

For VPS2.0 integration details:
- `docs/STACK_ARCHITECTURE.md` - Complete architecture
- `docs/DEPLOYMENT_GUIDE.md` - Deployment instructions
- `docs/QUICK_START.md` - Quick start guide

---

## 🔄 Update Policy

Submodules are pinned to specific commits for stability. To update:

1. Test updates in development environment
2. Update submodule reference:
   ```bash
   cd external/HURRICANE
   git pull origin main
   cd ../..
   git add external/HURRICANE
   git commit -m "Update HURRICANE submodule"
   ```
3. Deploy and verify
4. Push changes

---

**VPS2.0 Intelligence Platform**
**Submodules Version:** 1.0.0
**Last Updated:** 2025-11-18
