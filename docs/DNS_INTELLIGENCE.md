# DNS Intelligence Hub

Complete guide to the VPS2.0 DNS Intelligence Hub - a private DNS resolver and VPN gateway for centralized DNS visibility, filtering, and control.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Components](#components)
4. [Installation](#installation)
5. [Client Setup](#client-setup)
6. [Configuration](#configuration)
7. [Security Model](#security-model)
8. [Monitoring & Analytics](#monitoring--analytics)
9. [Operational Guide](#operational-guide)
10. [Troubleshooting](#troubleshooting)
11. [Advanced Topics](#advanced-topics)

---

## Overview

### What It Does

The DNS Intelligence Hub turns your VPS into a **private DNS control tower**:

- **WireGuard VPN** provides an encrypted tunnel from your devices to the VPS
- **Technitium DNS Server** acts as a private recursive resolver
- **Centralized Logging** captures every DNS query with timestamps and client IDs
- **Policy Engine** blocks malware, trackers, ads, and custom domains
- **Firewall Protection** ensures DNS is only accessible via VPN (never publicly exposed)
- **Monitoring & Dashboards** visualize DNS activity, detect anomalies, identify threats

### Key Benefits

✅ **Privacy**: ISP and local networks can't see or manipulate your DNS queries
✅ **Security**: Block malware C2 domains, phishing sites, trackers before connections are made
✅ **Visibility**: Centralized logs show every domain lookup across all your devices
✅ **Control**: Whitelist/blacklist domains, entire TLDs, or IP ranges
✅ **Analytics**: Detect DGA activity, track new domains, identify beaconing behavior
✅ **Compliance**: Audit trail for all DNS activity (useful for SOC/incident response)

---

## Architecture

### Network Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Your Devices (Clients)                         │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐   │
│  │  Laptop    │  │  Phone     │  │  Tablet    │  │  Server    │   │
│  │ 10.10.0.2  │  │ 10.10.0.3  │  │ 10.10.0.4  │  │ 10.10.0.5  │   │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘   │
│         │               │               │               │           │
│         └───────────────┴───────────────┴───────────────┘           │
│                            │                                        │
│                   WireGuard Tunnel (Encrypted)                     │
│                            │                                        │
└────────────────────────────┼────────────────────────────────────────┘
                             │
                             │  UDP 51820
                             ▼
              ┌──────────────────────────────┐
              │  VPS (38.102.87.235)         │
              │  ┌────────────────────────┐  │
              │  │  WireGuard Server      │  │
              │  │  10.10.0.1/24          │  │
              │  └───────────┬────────────┘  │
              │              │               │
              │  ┌───────────▼────────────┐  │
              │  │  Technitium DNS        │  │
              │  │  Port 53 (VPN only)    │  │
              │  │  Port 5380 (Web UI)    │  │
              │  └───────────┬────────────┘  │
              │              │               │
              │              │ Forwarding    │
              │              ▼               │
              │  ┌────────────────────────┐  │
              │  │  Upstream Resolvers    │  │
              │  │  - Cloudflare (1.1.1.1)│  │
              │  │  - Google (8.8.8.8)    │  │
              │  │  - Quad9 (9.9.9.9)     │  │
              │  └────────────────────────┘  │
              └──────────────────────────────┘
```

### Data Flow

**DNS Query Path:**

1. **Client** (e.g., laptop at 10.10.0.2) needs to resolve `example.com`
2. **OS** sends DNS query to configured DNS server: `10.10.0.1`
3. **WireGuard** encrypts the DNS packet and sends it through the tunnel to the VPS
4. **VPS** decapsulates the packet and forwards to Technitium on port 53
5. **Technitium** receives the query and:
   - Logs the query (client IP, domain, timestamp)
   - Checks blocklists/allowlists
   - If blocked → returns NXDOMAIN or sinkhole IP
   - If allowed → forwards to upstream resolvers
6. **Upstream Resolver** returns the IP address
7. **Technitium** caches the response and logs it
8. **Response** flows back through WireGuard tunnel to the client
9. **Client** connects to the resolved IP address (normal internet path)

### Network Segmentation

| Network | Subnet | Purpose |
|---------|--------|---------|
| WireGuard VPN | 10.10.0.0/24 | Client tunnel network |
| Docker vpn | 172.24.0.0/24 | DNS container network |
| Host | - | Technitium uses host networking for port 53 |

---

## Components

### 1. WireGuard VPN Server

**Container:** `linuxserver/wireguard`
**Port:** 51820/udp
**Purpose:** Secure tunnel for DNS traffic

**Key Features:**
- Modern, high-performance VPN protocol
- Cryptographically sound (ChaCha20, Poly1305)
- Low overhead (faster than OpenVPN)
- Simple configuration
- Built-in NAT traversal

**Configuration:**
- Server: `10.10.0.1/24`
- Clients: `10.10.0.2 - 10.10.0.254`
- MTU: 1420 bytes
- Keepalive: 25 seconds

### 2. Technitium DNS Server

**Container:** `technitium/dns-server`
**Ports:** 53 (DNS), 5380 (Web UI), 853 (DNS-over-TLS)
**Purpose:** Private recursive DNS resolver

**Key Features:**
- Full-featured DNS server
- Web-based management UI
- Built-in blocklists support
- Query logging with statistics
- DNS-over-HTTPS (DoH) support
- DNSSEC validation
- Response caching
- Conditional forwarding
- Custom zone management

**Security:**
- Restricted to VPN subnet only (10.10.0.0/24)
- Admin password protection
- HTTPS for web UI (via Caddy)
- Rate limiting on queries

### 3. WireGuard UI (Optional)

**Container:** `ngoduykhanh/wireguard-ui`
**Port:** 5000
**Purpose:** Web-based VPN client management

**Features:**
- Visual client management
- QR code generation
- Traffic statistics
- Peer status monitoring

### 4. Blackbox Exporter

**Container:** `prom/blackbox-exporter`
**Port:** 9115
**Purpose:** DNS health monitoring

**Probes:**
- DNS query tests (UDP/TCP)
- Technitium UI availability
- WireGuard connectivity
- DoH endpoint validation

### 5. Firewall Rules

**Script:** `scripts/dns-firewall.sh`
**Purpose:** Protect DNS port from public access

**Rules:**
- ✅ SSH (22/tcp) - Open to all
- ✅ WireGuard (51820/udp) - Open to all
- ✅ DNS (53/tcp,udp) - **Only** from 10.10.0.0/24
- ✅ HTTP/HTTPS (80/443) - Open to all
- ❌ All other DNS traffic - **Blocked & Logged**

---

## Installation

### Prerequisites

- VPS running Debian/Ubuntu
- Docker & Docker Compose installed
- Root/sudo access
- Public IP address
- Domain name (optional, for web UI)

### Quick Start

1. **Deploy DNS Intelligence Hub:**

   ```bash
   cd /path/to/VPS2.0
   ./setup.sh
   # Select "Deploy DNS Intelligence Hub" when prompted
   ```

2. **Or deploy manually:**

   ```bash
   # Copy environment template
   cp .env.template .env

   # Edit environment variables
   nano .env
   # Set: DEPLOY_DNS_INTELLIGENCE=true
   # Set: WIREGUARD_SERVER_URL=38.102.87.235
   # Set: TECHNITIUM_ADMIN_PASSWORD=<strong password>

   # Deploy DNS stack
   docker-compose -f docker-compose.yml -f docker-compose.dns.yml up -d

   # Configure firewall
   sudo ./scripts/dns-firewall.sh

   # Generate first client
   ./scripts/wireguard/generate-client.sh laptop-main dns-only
   ```

3. **Access web interfaces:**

   - **Technitium DNS UI:** https://dns.yourdomain.com
     - Username: `admin`
     - Password: (from .env `TECHNITIUM_ADMIN_PASSWORD`)

   - **WireGuard UI:** https://vpn.yourdomain.com
     - Username: `admin`
     - Password: (from .env `WIREGUARD_UI_PASSWORD`)

---

## Client Setup

### Linux

1. **Install WireGuard:**
   ```bash
   sudo apt-get install wireguard-tools
   ```

2. **Copy client config:**
   ```bash
   sudo cp laptop-main.conf /etc/wireguard/wg0.conf
   sudo chmod 600 /etc/wireguard/wg0.conf
   ```

3. **Start the tunnel:**
   ```bash
   sudo wg-quick up wg0
   ```

4. **Enable on boot:**
   ```bash
   sudo systemctl enable wg-quick@wg0
   ```

5. **Test DNS:**
   ```bash
   dig @10.10.0.1 example.com
   nslookup example.com 10.10.0.1
   ```

### macOS

1. **Install WireGuard:**
   - Download from App Store or https://www.wireguard.com/install/

2. **Import config:**
   - Open WireGuard app
   - Click "Import tunnel(s) from file"
   - Select your `.conf` file
   - Or scan QR code with mobile app

3. **Activate tunnel:**
   - Click "Activate" in WireGuard app

4. **Verify DNS:**
   ```bash
   scutil --dns | grep 10.10.0.1
   dig @10.10.0.1 example.com
   ```

### Windows

1. **Install WireGuard:**
   - Download from https://www.wireguard.com/install/

2. **Import config:**
   - Open WireGuard app
   - Click "Import tunnel(s) from file"
   - Select your `.conf` file

3. **Activate:**
   - Click "Activate"

4. **Test:**
   ```powershell
   nslookup example.com 10.10.0.1
   ```

### iOS/Android

1. **Install WireGuard app from App/Play Store**

2. **Import config:**
   - **Option A:** Scan QR code
     - Generated automatically: `wireguard/config/clients/<name>.png`
   - **Option B:** Copy config file via AirDrop/email

3. **Connect and test:**
   - Enable the VPN in the app
   - Visit https://dns.yourdomain.com to access DNS web UI

---

## Configuration

### Blocklists

Technitium supports automatic blocklist updates. Add these to `.env`:

```bash
TECHNITIUM_BLOCKLISTS="https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-agh.txt;https://v.firebog.net/hosts/Easyprivacy.txt;https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt"
```

**Recommended Lists:**

| Category | URL |
|----------|-----|
| Malware | https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-agh.txt |
| Tracking | https://v.firebog.net/hosts/Easyprivacy.txt |
| Ads | https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt |
| Phishing | https://phishing.army/download/phishing_army_blocklist.txt |

### Custom Block/Allow Rules

**Via Web UI:**
1. Go to https://dns.yourdomain.com
2. Navigate to "Zones" → "Blocked Zone"
3. Add domains manually or via import

**Via CLI:**
```bash
docker exec technitium curl -X POST "http://localhost:5380/api/zones/block?token=<api-token>&domain=evil.com"
```

### Upstream Forwarders

Edit `.env`:

```bash
# Cloudflare (privacy-focused)
TECHNITIUM_FORWARDERS=1.1.1.1,1.0.0.1

# Google (fast, but data collection)
TECHNITIUM_FORWARDERS=8.8.8.8,8.8.4.4

# Quad9 (malware filtering)
TECHNITIUM_FORWARDERS=9.9.9.9,149.112.112.112

# Custom chain (multiple providers)
TECHNITIUM_FORWARDERS=1.1.1.1,8.8.8.8,9.9.9.9
```

### DNS-over-HTTPS (DoH)

Enable DoH for additional privacy:

1. **Edit `.env`:**
   ```bash
   DNS_ENABLE_DOH=true
   DNS_DOH_PUBLIC=false  # Keep false for VPN-only access
   ```

2. **Configure client to use DoH:**
   ```
   DoH URL: https://doh.yourdomain.com/dns-query
   ```

3. **Browser setup (Firefox):**
   - Settings → Privacy & Security → DNS over HTTPS
   - Choose "Custom" and enter: `https://doh.yourdomain.com/dns-query`

---

## Security Model

### Threat Surface Analysis

**What's Protected:**
- DNS queries are encrypted end-to-end (client → VPS)
- ISP cannot see DNS traffic
- Local network cannot snoop or inject DNS responses
- DNS resolver is never exposed publicly
- Centralized logging for all queries

**What's NOT Protected:**
- Actual web traffic after DNS resolution (unless using full tunnel mode)
- VPS provider can theoretically see decrypted DNS on the server
- DNS leaks if VPN disconnects (use kill-switch features)
- Application-level DoH bypass (browsers with hard-coded DoH)

### Defense in Depth

1. **Network Layer:**
   - Firewall rules restrict DNS to VPN subnet
   - WireGuard encryption (ChaCha20-Poly1305)
   - Preshared keys for additional security

2. **Application Layer:**
   - Technitium admin password
   - Rate limiting on queries
   - DNSSEC validation
   - Blocklists for malware/phishing

3. **Monitoring Layer:**
   - Query logging with anomaly detection
   - Failed query tracking
   - DGA detection alerts
   - Metrics exported to Grafana

### Attack Scenarios & Mitigations

**Scenario 1: VPS Compromise**
- **Impact:** Attacker can see all DNS queries, manipulate responses
- **Mitigation:**
  - Harden VPS (SSH keys only, fail2ban, regular updates)
  - Enable DNSSEC validation
  - Monitor for suspicious DNS responses
  - Use canary domains (alert if queries appear)

**Scenario 2: DNS Amplification Attack**
- **Impact:** VPS used for DDoS reflection
- **Mitigation:**
  - DNS port 53 not publicly accessible
  - Firewall drops all non-VPN DNS traffic
  - Rate limiting on Technitium

**Scenario 3: Client Key Compromise**
- **Impact:** Unauthorized VPN access, DNS queries visible
- **Mitigation:**
  - Revoke client immediately: `./scripts/wireguard/revoke-client.sh <name>`
  - Monitor for unknown client IPs
  - Use preshared keys (additional layer)

**Scenario 4: DNS Leak**
- **Impact:** Queries bypass VPN, go to ISP resolver
- **Mitigation:**
  - Use kill-switch feature in WireGuard clients
  - Test for leaks: https://dnsleaktest.com
  - Block known DoH endpoints (if full tunnel)

---

## Monitoring & Analytics

### Grafana Dashboard

Access: https://monitoring.yourdomain.com or https://GRAFANA.swordintelligence.airforce

**Metrics Panels:**

1. **Query Volume**
   - Queries per second (QPS)
   - Queries per minute/hour/day
   - Peak times

2. **Top Domains**
   - Most queried domains
   - New domains (first seen)
   - Suspicious domains (high entropy)

3. **Client Activity**
   - Queries per client IP
   - Client connection status
   - Traffic volume

4. **Blocked Queries**
   - Blocked by category (malware, ads, tracking)
   - Block rate over time
   - Top blocked domains

5. **Performance**
   - Query latency (avg, p95, p99)
   - Cache hit ratio
   - Upstream response times

6. **Alerts**
   - DGA detection (randomized subdomains)
   - Beaconing behavior (regular intervals)
   - Anomalous query volume
   - New C2 domains

### Query Logs

**Location:** `dns/logs/`

**Format:** JSON with fields:
- `timestamp`: ISO 8601 UTC
- `client_ip`: Source IP (10.10.0.x)
- `query_type`: A, AAAA, MX, TXT, etc.
- `query_name`: Domain queried
- `response_code`: NOERROR, NXDOMAIN, REFUSED
- `response_ip`: Resolved IP(s)
- `latency_ms`: Query duration

**Example:**
```json
{
  "timestamp": "2025-11-18T14:32:15.123Z",
  "client_ip": "10.10.0.2",
  "query_type": "A",
  "query_name": "example.com",
  "response_code": "NOERROR",
  "response_ip": "93.184.216.34",
  "latency_ms": 12
}
```

**Analysis:**
```bash
# Count queries per client
jq -r '.client_ip' dns/logs/*.log | sort | uniq -c

# Top 20 queried domains
jq -r '.query_name' dns/logs/*.log | sort | uniq -c | sort -rn | head -20

# Find DGA suspects (high entropy domains)
jq -r 'select(.query_name | length > 30) | .query_name' dns/logs/*.log
```

---

## Operational Guide

### Client Management

**List all clients:**
```bash
./scripts/wireguard/list-clients.sh
```

**Generate new client:**
```bash
# DNS-only tunnel (recommended)
./scripts/wireguard/generate-client.sh phone-alice dns-only

# Full tunnel (all traffic through VPN)
./scripts/wireguard/generate-client.sh laptop-bob full
```

**Revoke client access:**
```bash
./scripts/wireguard/revoke-client.sh phone-alice
docker-compose -f docker-compose.dns.yml restart wireguard
```

### Updating Blocklists

**Automatic:**
- Technitium updates blocklists every 24 hours by default
- Configure in Web UI: Settings → Block Lists

**Manual:**
```bash
docker exec technitium curl -X POST "http://localhost:5380/api/blocklists/update?token=<api-token>"
```

### Backup & Restore

**Backup DNS configs:**
```bash
tar czf dns-backup-$(date +%Y%m%d).tar.gz \
  dns/config \
  wireguard/config \
  .env

# Copy off-site
scp dns-backup-*.tar.gz user@backup-server:/backups/
```

**Restore:**
```bash
tar xzf dns-backup-20251118.tar.gz
docker-compose -f docker-compose.dns.yml up -d
```

### Log Rotation

Logs are automatically rotated based on size:
- Technitium: 100MB per file, 10 files retained
- Caddy: 50MB per file, 5 files retained

**Manual cleanup:**
```bash
find dns/logs -name "*.log" -mtime +90 -delete
```

---

## Troubleshooting

### DNS Not Resolving

**Symptoms:** Client can't resolve domains

**Diagnosis:**
1. Check VPN connection:
   ```bash
   wg show
   ping 10.10.0.1
   ```

2. Test DNS directly:
   ```bash
   dig @10.10.0.1 example.com
   nslookup example.com 10.10.0.1
   ```

3. Check Technitium logs:
   ```bash
   docker logs technitium
   tail -f dns/logs/query.log
   ```

**Solutions:**
- VPN not connected: `wg-quick up wg0`
- Firewall blocking: `sudo ./scripts/dns-firewall.sh`
- Technitium down: `docker-compose -f docker-compose.dns.yml restart technitium`

### VPN Won't Connect

**Symptoms:** WireGuard fails to establish tunnel

**Diagnosis:**
```bash
# Check server status
docker ps | grep wireguard
docker logs wireguard

# Check firewall
sudo iptables -L -n | grep 51820
```

**Solutions:**
- Port blocked: Verify UDP 51820 is open
- Wrong endpoint: Check `WIREGUARD_SERVER_URL` in `.env`
- Invalid config: Regenerate client config

### DNS Leaks

**Symptoms:** Queries going to ISP instead of VPS

**Test:** Visit https://dnsleaktest.com

**Solutions:**
1. **Linux:** Ensure DNS is set correctly
   ```bash
   cat /etc/resolv.conf  # Should show 10.10.0.1
   resolvectl status  # Check VPN interface
   ```

2. **macOS:** Check DNS settings in System Preferences

3. **Windows:** Check network adapter DNS settings

4. **Enable kill-switch:** Add to WireGuard config
   ```ini
   [Interface]
   PostUp = iptables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
   PreDown = iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
   ```

### High Latency

**Symptoms:** DNS queries are slow

**Diagnosis:**
```bash
# Test query time
time dig @10.10.0.1 example.com

# Check upstream latency
docker exec technitium curl -X GET "http://localhost:5380/api/stats"
```

**Solutions:**
- Change upstream forwarders (try closer servers)
- Increase cache size in Technitium settings
- Check VPS network performance
- Reduce MTU if fragmentation occurs

### Web UI Inaccessible

**Symptoms:** Can't access DNS web UI

**Diagnosis:**
```bash
# Check Caddy
docker logs caddy | grep dns

# Test locally
curl -I http://localhost:5380
```

**Solutions:**
- Caddy not running: `docker-compose up -d caddy`
- Not connected to VPN: IP whitelist requires VPN connection
- DNS not set: Add A record for `dns.yourdomain.com`

---

## Advanced Topics

### Integration with SIEM

Forward DNS logs to your SIEM (e.g., Elastic, Splunk):

**Via Vector:**
```toml
[sources.dns_logs]
type = "file"
include = ["/path/to/dns/logs/*.log"]
read_from = "beginning"

[sinks.elasticsearch]
type = "elasticsearch"
inputs = ["dns_logs"]
endpoint = "https://elastic.yourdomain.com"
index = "dns-queries-%Y.%m.%d"
```

### Authoritative DNS

Use Technitium as authoritative nameserver for your domains:

1. **Add zone in Web UI:** Zones → Add Zone
2. **Create records:** A, AAAA, MX, TXT, etc.
3. **Update domain registrar:** Point NS records to your VPS
4. **Enable DNSSEC:** Generate keys and add DS records

### DNS RPZ (Response Policy Zones)

Block domains via RPZ feeds:

1. **Add RPZ zone:** Zones → Add RPZ Zone
2. **Configure feed URL:** e.g., abuse.ch RPZ feed
3. **Set action:** NXDOMAIN, NODATA, or custom IP

### Integration with SWORDINTELLIGENCE

Send DNS logs to SWORDINTELLIGENCE for C2 detection:

```bash
# Forward logs via webhook
curl -X POST https://yourdomain.com/api/dns/ingest \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d @dns/logs/query.log
```

### Multi-Region Deployment

Deploy secondary DNS hub for redundancy:

1. **Deploy on second VPS** in different region
2. **Configure WireGuard clients** with both endpoints:
   ```ini
   [Peer]
   Endpoint = vps1.example.com:51820
   # Fallback
   Endpoint = vps2.example.com:51821
   ```
3. **Set multiple DNS servers:**
   ```ini
   DNS = 10.10.0.1, 10.20.0.1
   ```

---

## Summary

The DNS Intelligence Hub provides:
- ✅ Private, encrypted DNS resolver accessible only via VPN
- ✅ Centralized logging and analytics for all DNS activity
- ✅ Policy-based blocking of malware, trackers, and custom domains
- ✅ Firewall protection to prevent public DNS exposure
- ✅ Real-time monitoring and anomaly detection
- ✅ Easy client management with automated config generation

**Next Steps:**
1. Generate client configs for your devices
2. Configure blocklists in Technitium UI
3. Set up Grafana dashboards for monitoring
4. Review DNS logs regularly for anomalies
5. Integrate with SWORDINTELLIGENCE for threat correlation

**Support:**
- Documentation: https://docs.technitium.com/dns/
- WireGuard: https://www.wireguard.com/
- VPS2.0 Issues: https://github.com/SWORDIntel/VPS2.0/issues
