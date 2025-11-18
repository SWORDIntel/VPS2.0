# Traffic Routing through HURRICANE and ARTICBASTION

Complete guide for routing traffic through HURRICANE IPv6 tunnel and ARTICBASTION quantum-resistant security gateway.

---

## 🌐 Overview

VPS2.0 includes two powerful services for traffic routing and tunneling:

- **HURRICANE** - IPv6-over-IPv4 tunnel with SOCKS5/HTTP(S) proxy
- **ARTICBASTION** - Quantum-resistant mesh security gateway with proxy capabilities

Both services expose proxy interfaces that allow you to route traffic through them for:
- IPv6 connectivity over IPv4-only networks
- Traffic obfuscation and privacy
- Geographic routing through different exit points
- Secure mesh networking

---

## 🚀 Quick Start

### Route Traffic through HURRICANE
```bash
# Using SOCKS5 proxy (recommended)
curl --socks5 localhost:1080 https://api.ipify.org

# Using HTTP proxy
export http_proxy=http://localhost:8888
export https_proxy=http://localhost:8889
curl https://api.ipify.org
```

### Route Traffic through ARTICBASTION
```bash
# Using SOCKS5 proxy
curl --socks5 localhost:1081 https://api.ipify.org

# Using HTTP proxy
export http_proxy=http://localhost:8890
export https_proxy=http://localhost:8891
curl https://api.ipify.org
```

---

## 📊 Exposed Proxy Interfaces

### HURRICANE Ports

| Port | Protocol | Purpose | Access |
|------|----------|---------|--------|
| **1080** | SOCKS5 | General proxy | System-wide |
| **8888** | HTTP | HTTP proxy | System-wide |
| **8889** | HTTPS | HTTPS proxy | System-wide |
| 8080 | REST API | Control API | Internal |
| 8081 | HTTP | Web UI | Internal |

### ARTICBASTION Ports

| Port | Protocol | Purpose | Access |
|------|----------|---------|--------|
| **1081** | SOCKS5 | Quantum-secure proxy | System-wide |
| **8890** | HTTP | HTTP proxy | System-wide |
| **8891** | HTTPS | HTTPS proxy | System-wide |
| 8022 | SSH | Gateway/Bastion | External |
| 7946/7947 | Mesh | Peer networking | Mesh nodes |
| 5000 | HTTP | Web dashboard | Internal |

---

## 🐳 Container-to-Container Routing

### Method 1: Environment Variables

Configure containers to route through HURRICANE or ARTICBASTION:

```yaml
services:
  my-service:
    image: my-app:latest
    environment:
      # Route through HURRICANE
      - HTTP_PROXY=http://hurricane:8888
      - HTTPS_PROXY=http://hurricane:8889
      - ALL_PROXY=socks5://hurricane:1080

      # Or route through ARTICBASTION
      - HTTP_PROXY=http://articbastion:8890
      - HTTPS_PROXY=http://articbastion:8891
      - ALL_PROXY=socks5://articbastion:1081

      # Exclude local networks
      - NO_PROXY=localhost,127.0.0.1,.local
    networks:
      - backend  # Must be on same network
```

### Method 2: Docker Compose depends_on

```yaml
services:
  my-service:
    image: my-app:latest
    depends_on:
      - hurricane
    environment:
      - ALL_PROXY=socks5://hurricane:1080
    networks:
      - backend

  hurricane:
    extends:
      file: docker-compose.hurricane.yml
      service: hurricane
```

---

## 🔧 System-Wide Configuration

### Linux/macOS

**Configure bash/zsh:**
```bash
# Add to ~/.bashrc or ~/.zshrc

# Route through HURRICANE
export http_proxy=http://localhost:8888
export https_proxy=http://localhost:8889
export all_proxy=socks5://localhost:1080

# Or route through ARTICBASTION
export http_proxy=http://localhost:8890
export https_proxy=http://localhost:8891
export all_proxy=socks5://localhost:1081

# Exclude local networks
export no_proxy=localhost,127.0.0.1,.local,172.16.0.0/12
```

**System-wide proxy (Ubuntu/Debian):**
```bash
sudo tee /etc/environment.d/proxy.conf > /dev/null <<EOF
HTTP_PROXY=http://localhost:8888
HTTPS_PROXY=http://localhost:8889
NO_PROXY=localhost,127.0.0.1,.local
EOF

# Reload
sudo systemctl daemon-reload
```

---

## 🌐 Application-Specific Configuration

### Git
```bash
# Via HURRICANE
git config --global http.proxy http://localhost:8888
git config --global https.proxy http://localhost:8889

# Via ARTICBASTION
git config --global http.proxy http://localhost:8890
git config --global https.proxy http://localhost:8891
```

### Docker
```bash
# Create/edit ~/.docker/config.json
{
  "proxies": {
    "default": {
      "httpProxy": "http://localhost:8888",
      "httpsProxy": "http://localhost:8889",
      "noProxy": "localhost,127.0.0.1"
    }
  }
}
```

### NPM
```bash
# Via HURRICANE
npm config set proxy http://localhost:8888
npm config set https-proxy http://localhost:8889

# Via ARTICBASTION
npm config set proxy http://localhost:8890
npm config set https-proxy http://localhost:8891
```

### Python pip
```bash
# Via HURRICANE
pip install --proxy http://localhost:8888 package-name

# Or set environment variable
export PIP_PROXY=http://localhost:8888
```

### curl
```bash
# SOCKS5 proxy (recommended)
curl --socks5 localhost:1080 https://example.com

# HTTP proxy
curl --proxy http://localhost:8888 https://example.com

# Verify your exit IP
curl --socks5 localhost:1080 https://api.ipify.org
```

### wget
```bash
# Via HURRICANE
wget -e use_proxy=yes -e http_proxy=localhost:8888 https://example.com

# Via ARTICBASTION
wget -e use_proxy=yes -e http_proxy=localhost:8890 https://example.com
```

---

## 🔐 Proxy Authentication (ARTICBASTION)

ARTICBASTION supports authenticated proxy access:

### Configure Client Certificate
```bash
# Export client certificate
export SOCKS5_USER=username
export SOCKS5_PASSWORD=password

# Or use certificate-based auth
curl --socks5 localhost:1081 \
     --cert /path/to/client.crt \
     --key /path/to/client.key \
     https://example.com
```

---

## 🎯 Use Cases

### 1. IPv6 Connectivity (HURRICANE)

Route IPv6 traffic through HURRICANE tunnel:

```bash
# Enable IPv6 via HURRICANE
export ALL_PROXY=socks5://localhost:1080

# Test IPv6 connectivity
curl -6 https://ipv6.google.com

# Access IPv6-only services
curl --socks5 localhost:1080 http://[2001:db8::1]/
```

### 2. Geographic Routing

Route traffic through different tunnel backends:

```bash
# HURRICANE with Mullvad VPN (Swedish exit)
# Configure via .env: MULLVAD_ENABLED=true

# HURRICANE with Hurricane Electric (closest PoP)
# Configure via .env: HE_ENABLED=true

# Check exit IP
curl --socks5 localhost:1080 https://api.ipify.org
```

### 3. Traffic Obfuscation (ARTICBASTION)

Use ARTICBASTION's quantum-resistant encryption:

```bash
# All traffic encrypted with post-quantum crypto
export ALL_PROXY=socks5://localhost:1081

# Traffic appears obfuscated to DPI
curl https://example.com
```

### 4. Mesh Routing (ARTICBASTION)

Route traffic through mesh network peers:

```bash
# Configure mesh peer as exit node
export ARTICBASTION_EXIT_NODE=peer-hostname

# Traffic exits through mesh peer
curl --socks5 localhost:1081 https://example.com
```

---

## 🔍 Testing and Verification

### Check Proxy is Working
```bash
# Without proxy
curl https://api.ipify.org
# Output: Your real IP

# With HURRICANE proxy
curl --socks5 localhost:1080 https://api.ipify.org
# Output: HURRICANE exit IP

# With ARTICBASTION proxy
curl --socks5 localhost:1081 https://api.ipify.org
# Output: ARTICBASTION exit IP
```

### Test IPv6 Connectivity
```bash
# Via HURRICANE
curl --socks5 localhost:1080 -6 https://ipv6.google.com

# Check IPv6 address
curl --socks5 localhost:1080 https://api6.ipify.org
```

### Verify DNS Resolution
```bash
# DNS through proxy
curl --socks5-hostname localhost:1080 https://example.com

# This resolves DNS through the proxy, preventing leaks
```

---

## 📊 Monitoring Proxy Usage

### HURRICANE Metrics
```bash
# Prometheus metrics
curl http://localhost:9090/metrics

# REST API status
curl http://localhost:8080/api/status

# Web UI
# Navigate to: http://localhost:8081
```

### ARTICBASTION Metrics
```bash
# Prometheus metrics
curl http://localhost:9091/metrics

# Dashboard
# Navigate to: http://localhost:5000
```

---

## 🔧 Advanced Configuration

### Load Balancing Between Proxies

```python
import requests
import random

proxies_list = [
    {'http': 'socks5://localhost:1080', 'https': 'socks5://localhost:1080'},   # HURRICANE
    {'http': 'socks5://localhost:1081', 'https': 'socks5://localhost:1081'},   # ARTICBASTION
]

# Random proxy selection
proxies = random.choice(proxies_list)
response = requests.get('https://api.ipify.org', proxies=proxies)
print(f"Exit IP: {response.text}")
```

### Proxy Chaining

Route through ARTICBASTION then HURRICANE:

```bash
# Not directly supported - use separate network namespaces
# or configure ARTICBASTION to use HURRICANE as upstream
```

### DNS over Proxy

```bash
# Use SOCKS5 with hostname resolution
curl --socks5-hostname localhost:1080 https://example.com

# This prevents DNS leaks
```

---

## 🚨 Troubleshooting

### Proxy Connection Failed

```bash
# Check if service is running
docker ps | grep hurricane
docker ps | grep articbastion

# Check port is listening
netstat -tlnp | grep 1080
netstat -tlnp | grep 1081

# Check service logs
docker-compose logs hurricane
docker-compose logs articbastion
```

### Slow Proxy Performance

```bash
# Check tunnel health
curl http://localhost:8080/api/health  # HURRICANE
curl http://localhost:5000/health      # ARTICBASTION

# Monitor resource usage
docker stats hurricane
docker stats articbastion
```

### DNS Leaks

```bash
# Always use SOCKS5 with hostname resolution
curl --socks5-hostname localhost:1080 https://example.com

# Test for DNS leaks
curl --socks5-hostname localhost:1080 https://dnsleaktest.com
```

---

## 📚 Additional Resources

- **HURRICANE Configuration:** See `docker-compose.hurricane.yml`
- **ARTICBASTION Setup:** See `external/ARTICBASTION/README.md`
- **VPS2.0 Architecture:** See `docs/STACK_ARCHITECTURE.md`
- **Network Configuration:** See `docker-compose.yml` networks section

---

## 🔒 Security Considerations

### HURRICANE
- Traffic encrypted with WireGuard or Hurricane Electric tunnel
- IPv6 traffic encapsulated in IPv4
- SOCKS5 proxy has no authentication by default (use firewall rules)

### ARTICBASTION
- Quantum-resistant cryptography (Dilithium3 + Kyber768)
- Client certificate authentication available
- Traffic obfuscation defeats DPI
- Honeypot triggers on unauthorized access

### Best Practices
1. **Use SOCKS5 with hostname resolution** to prevent DNS leaks
2. **Configure NO_PROXY** for local networks
3. **Monitor metrics** for unusual traffic patterns
4. **Enable authentication** for production deployments
5. **Use HTTPS** for all proxied traffic

---

## 🎯 Network Topology

```
┌─────────────────────────────────────────────────────────┐
│                    VPS2.0 Platform                       │
│                                                           │
│  ┌────────────┐                    ┌─────────────────┐  │
│  │  Container │ ──SOCKS5(1080)───▶ │   HURRICANE     │  │
│  │            │ ──HTTP(8888)─────▶ │   IPv6 Tunnel   │──┼──▶ Internet (IPv6)
│  │  Services  │ ──HTTPS(8889)────▶ │   Proxy         │  │
│  └────────────┘                    └─────────────────┘  │
│         │                                                 │
│         │                           ┌─────────────────┐  │
│         └──────SOCKS5(1081)───────▶│ ARTICBASTION    │  │
│                ──HTTP(8890)───────▶│ Quantum-Secure  │──┼──▶ Mesh Network
│                ──HTTPS(8891)──────▶│ Gateway         │  │    / Internet
│                                     └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

**VPS2.0 Traffic Routing Guide**
**Version:** 1.0.0
**Last Updated:** 2025-11-18
