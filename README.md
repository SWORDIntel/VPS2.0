# VPS2.0 - Complete Intelligence & Security Platform

> Production-ready, Docker-based software stack for intelligence gathering, threat analysis, and security monitoring on a single VPS.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Security](https://img.shields.io/badge/Security-Hardened-green.svg)](./SECURITY.md)

---

## 🚀 Quick Start

### One-Liner Installation (Recommended)

Deploy the entire platform with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash
```

Or with verbose logging for monitoring progress:

```bash
curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash -s -- --verbose
```

**Features:**
- ✅ Automatic OS detection and prerequisites installation
- ✅ Docker and Docker Compose setup
- ✅ Interactive configuration wizard
- ✅ Security hardening and credential generation
- ✅ DNS verification and service deployment
- ✅ Post-deployment health checks

See [Quick Start Guide](./docs/QUICK_START.md) for detailed options and troubleshooting.

### Local Setup (When Archive is Uploaded)

If you've downloaded and extracted the VPS2.0 archive to your server:

```bash
# Extract the archive
tar -xzf VPS2.0.tar.gz
cd VPS2.0

# Run local setup script
sudo bash setup.sh
```

**Features:**
- ✅ Validates Docker installation
- ✅ Checks system requirements
- ✅ Verifies repository structure
- ✅ Launches interactive setup wizard

### Manual Installation (Advanced)

```bash
# Clone the repository
git clone https://github.com/SWORDIntel/VPS2.0.git
cd VPS2.0

# Run interactive setup wizard
sudo ./scripts/setup-wizard.sh

# Or deploy directly
sudo ./scripts/deploy.sh

# Apply security hardening
sudo ./scripts/harden.sh
```

**That's it!** Your complete intelligence platform is now running.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Requirements](#requirements)
- [Services](#services)
- [Security](#security)
- [Monitoring](#monitoring)
- [Support](#support)
- [Contributing](#contributing)
- [License](#license)

---

## 🔍 Overview

VPS2.0 is a comprehensive, production-grade software stack designed for intelligence operations, security analysis, and threat detection. Built with Docker and optimized for single-node deployment, it provides enterprise-level capabilities with minimal operational complexity.

### Key Highlights

- ⚡ **Rapid Deployment**: Fully automated deployment in minutes
- 🔒 **Security First**: Hardened configurations, zero-trust architecture
- 📊 **Complete Observability**: Metrics, logs, and traces with Grafana
- 🤖 **Intelligence Automation**: Integrated threat intelligence and analysis
- 🔧 **Production Ready**: Battle-tested configurations and best practices
- 🌐 **IPv6 Support**: Optional HURRICANE proxy for IPv6 connectivity
- 📦 **All-in-One**: 30+ integrated services, fully configured

---

## ✨ Features

### Core Capabilities

- **🛡️ Threat Intelligence Platform**
  - MISP (Malware Information Sharing Platform)
  - OpenCTI (Structured Threat Intelligence)
  - Cortex (Observable Analysis)
  - Custom SWORDINTELLIGENCE platform

- **🔬 Malware Analysis**
  - YARA pattern matching
  - ClamAV antivirus scanning
  - Cuckoo Sandbox (dynamic analysis)
  - Sample management and tracking

- **🌐 Network Security Monitoring**
  - Suricata IDS/IPS
  - Zeek network analysis
  - Arkime packet capture
  - Real-time threat detection

- **🔗 Blockchain Analysis**
  - Bitcoin full node + Mempool explorer
  - Ethereum node + Blockscout explorer
  - Transaction tracing and analysis

- **📊 Comprehensive Monitoring**
  - Grafana dashboards
  - VictoriaMetrics (efficient time-series DB)
  - Loki log aggregation
  - Vector log collection

- **🔐 Security Features**
  - Automatic HTTPS with Let's Encrypt
  - WireGuard VPN for admin access
  - ARTICBASTION secure gateway
  - Fail2ban intrusion prevention
  - CrowdSec community IPS
  - Falco runtime security

- **🚀 Development & CI/CD**
  - GitLab CE with integrated CI/CD
  - Container registry
  - GitLab Pages
  - Automated testing and deployment

- **🤖 Automation**
  - n8n workflow automation
  - Integration between all services
  - Automated threat response
  - Custom analysis pipelines

- **🌐 Optional: IPv6 Proxy**
  - HURRICANE IPv6-over-IPv4 tunneling
  - Multiple tunnel backends
  - SOCKS5 proxy
  - REST API and Web UI

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │  Firewall / nftables     │
        │  (UFW + Fail2ban)        │
        └────────────┬────────────┘
                     │
        ┌────────────┴────────────┐
        │  Caddy Reverse Proxy    │
        │  (Auto HTTPS, HTTP/3)   │
        └────────────┬────────────┘
                     │
     ┌───────────────┼───────────────┐
     │               │               │
┌────┴────┐    ┌────┴────┐    ┌────┴────┐
│   DMZ   │    │Frontend │    │ Backend │
│ Network │    │ Network │    │ Network │
└────┬────┘    └────┬────┘    └────┬────┘
     │              │               │
┌────┴────┐    ┌────┴────────┐ ┌───┴──────────┐
│Bastion  │    │Web Services │ │  Databases   │
│HURRICANE│    │Intelligence │ │  Analysis    │
└─────────┘    └─────────────┘ └──────────────┘
                                      │
                              ┌───────┴────────┐
                              │   Monitoring    │
                              │     Network     │
                              └────────────────┘
```

### Network Segmentation

- **DMZ Network** (`172.30.0.0/24`): Exposed services, bastion host
- **Frontend Network** (`172.20.0.0/24`): Web applications, APIs
- **Backend Network** (`172.21.0.0/24`): Databases, internal services
- **Monitoring Network** (`172.22.0.0/24`): Metrics, logs
- **Isolated Network** (`172.23.0.0/24`): Malware analysis sandbox

---

## 📚 Documentation

**[📖 Complete Documentation Index](./docs/)** - Browse all documentation

### Core Guides

- **[Quick Start Guide](./docs/QUICK_START.md)** - One-liner installation and deployment options
- **[Deployment Guide](./docs/DEPLOYMENT_GUIDE.md)** - Comprehensive deployment instructions
- **[Stack Architecture](./docs/STACK_ARCHITECTURE.md)** - Technical architecture and service catalog
- **[Dashboard Guide](./docs/DASHBOARD_GUIDE.md)** - TEMPEST Level C dashboard operations

### Technical Documentation

- **[Ease of Deployment](./docs/EASE_OF_DEPLOYMENT.md)** - Installer implementation details
- **[Implementation Summary](./docs/SUMMARY.md)** - Project overview and status

### Quick Links

- [System Requirements](#-requirements)
- [Installation Methods](#-quick-start)
- [Service Catalog](#-services)
- [Security Features](#-security)
- [Troubleshooting](./docs/QUICK_START.md#troubleshooting)

---

## 💻 Requirements

### Minimum Specifications

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 8 cores | 16 cores |
| RAM | 32 GB | 64 GB |
| Storage | 500 GB SSD | 1 TB NVMe SSD |
| Network | 1 Gbps | 10 Gbps |

### Software

- **Operating System**: Debian 12 (Bookworm) or Ubuntu 22.04 LTS
- **Docker**: Version 24.0 or later
- **Docker Compose**: Version 2.20 or later
- **Domain Name**: Required for SSL/TLS certificates

### Network

- **Public IP Address**: Static IP recommended
- **Open Ports**:
  - `80/tcp` - HTTP (auto-redirects to HTTPS)
  - `443/tcp`, `443/udp` - HTTPS and HTTP/3
  - `2222/tcp` - Bastion SSH (optional)
  - `51820/udp` - WireGuard VPN (optional)

---

## 🧩 Services

### Phase 1: Foundation (Priority 1)

| Service | Purpose | Port | Documentation |
|---------|---------|------|---------------|
| **Caddy** | Reverse proxy, auto HTTPS | 80, 443 | [Caddyfile](./caddy/Caddyfile) |
| **PostgreSQL 16** | Primary database | 5432 | [Config](./postgres/postgresql.conf) |
| **PgBouncer** | Connection pooling | 6432 | - |
| **Redis Stack** | Cache + modules | 6379 | - |
| **Neo4j** | Graph database | 7687, 7474 | - |
| **Portainer** | Container management | 9000 | - |
| **Grafana** | Visualization | 3000 | [Dashboards](./grafana/dashboards/) |
| **VictoriaMetrics** | Metrics storage | 8428 | [Config](./prometheus/prometheus.yml) |
| **Loki** | Log aggregation | 3100 | [Config](./loki/loki-config.yaml) |
| **Vector** | Log collection | - | [Config](./vector/vector.toml) |

### Phase 2: Intelligence & Analysis (Priority 2)

| Service | Purpose | Port | Access |
|---------|---------|------|--------|
| **SWORDINTELLIGENCE** | Main intelligence platform | 5000 | swordintel.domain.com |
| **MISP** | Threat intelligence sharing | 443 | misp.domain.com |
| **OpenCTI** | Structured threat intel | 8080 | opencti.domain.com |
| **Cortex** | Observable analysis | 9001 | - |
| **n8n** | Workflow automation | 5678 | n8n.domain.com |
| **YARA** | Malware pattern matching | - | - |
| **ClamAV** | Antivirus scanning | - | - |
| **GitLab CE** | Source code + CI/CD | 80 | gitlab.domain.com |

### Phase 3: Optional Services (Priority 3)

| Service | Purpose | Compose File |
|---------|---------|--------------|
| **HURRICANE** | IPv6 proxy | docker-compose.hurricane.yml |
| **ARTICBASTION** | Secure gateway | docker-compose.yml |
| **Bitcoin + Mempool** | Bitcoin blockchain | docker-compose.blockchain.yml |
| **Ethereum + Blockscout** | Ethereum blockchain | docker-compose.blockchain.yml |
| **Suricata + Zeek** | Network IDS | docker-compose.security.yml |
| **Cuckoo Sandbox** | Dynamic malware analysis | docker-compose.analysis.yml |

---

## 🔒 Security

### Security Features

- ✅ **Automatic HTTPS** with Let's Encrypt
- ✅ **Hardened SSH** configuration (key-only, ed25519)
- ✅ **Firewall** (UFW + nftables)
- ✅ **Intrusion Prevention** (Fail2ban + CrowdSec)
- ✅ **Runtime Security** (Falco)
- ✅ **Vulnerability Scanning** (Trivy)
- ✅ **Audit Logging** (auditd)
- ✅ **Container Isolation** (AppArmor, seccomp)
- ✅ **Network Segmentation** (Docker networks)
- ✅ **Automated Updates** (unattended-upgrades)
- ✅ **WireGuard VPN** for admin access
- ✅ **Client Certificate Authentication** for bastion

### Security Hardening

Run the automated hardening script:

```bash
sudo ./scripts/harden.sh
```

This applies:
- SSH hardening
- Kernel hardening (sysctl)
- Docker daemon hardening
- Fail2ban configuration
- Automatic security updates
- Audit daemon (auditd)
- Security scanning tools (Lynis, rkhunter)
- Log rotation

### Security Auditing

```bash
# Run comprehensive security audit
lynis audit system

# Check for rootkits
rkhunter --check

# Scan for viruses
clamscan -r -i /

# Review audit logs
ausearch -k docker
```

---

## 📊 Monitoring

### Built-in Monitoring

- **Grafana Dashboards**: Pre-configured dashboards for all services
- **VictoriaMetrics**: Efficient Prometheus-compatible storage
- **Loki**: Lightweight log aggregation
- **Vector**: High-performance log collection
- **cAdvisor**: Container metrics
- **Node Exporter**: Host metrics

### Access Monitoring

```
https://monitoring.your-domain.com
```

### Key Metrics

- System resources (CPU, RAM, Disk, Network)
- Container resources (per-service metrics)
- Application metrics (request rates, errors, latency)
- Security events (threats detected, IPs blocked)
- Database performance
- Network traffic

### Alerting

Configure alerts in Grafana for:
- High resource usage (>85%)
- Service failures
- Disk space critical (<10%)
- Security events
- Certificate expiration
- Backup failures

---

## 🛠️ Maintenance

### Daily

```bash
# Check service health
docker-compose ps

# Monitor resources
docker stats --no-stream

# Review Grafana dashboards
```

### Weekly

```bash
# Review logs
docker-compose logs --since 7d | grep -i error

# Check for updates
docker-compose pull

# Verify backups
ls -lh /srv/backups/
```

### Monthly

```bash
# Security audit
lynis audit system

# Update system packages
apt-get update && apt-get upgrade -y

# Clean old Docker resources
docker system prune -a --filter "until=720h"

# Test disaster recovery
./scripts/backup.sh && ./scripts/restore.sh
```

---

## 🔄 Backup & Recovery

### Automated Backups

Configure daily backups:

```bash
# Edit crontab
sudo crontab -e

# Add daily backup at 2 AM
0 2 * * * /home/user/VPS2.0/scripts/backup.sh
```

### Backup Includes

- ✅ All databases (PostgreSQL, Neo4j, Redis, MariaDB)
- ✅ Docker volumes
- ✅ Configurations
- ✅ Logs
- ✅ SSL certificates
- ✅ Uploaded files/samples

### Restore

```bash
# List backups
ls -lh /srv/backups/

# Restore from backup
./scripts/restore.sh /srv/backups/20250118_020000.tar.gz
```

### S3 Backup (Optional)

Enable remote backups to S3-compatible storage:

```bash
# Configure in .env
S3_BACKUP_ENABLED=true
S3_ENDPOINT=https://s3.amazonaws.com
S3_BUCKET=vps2.0-backups
S3_ACCESS_KEY=your_key
S3_SECRET_KEY=your_secret
```

---

## 🤝 Support

### Getting Help

1. **Documentation**: Check [Deployment Guide](./docs/DEPLOYMENT_GUIDE.md) and [Stack Architecture](./docs/STACK_ARCHITECTURE.md)
2. **Troubleshooting**: See [Quick Start Guide](./docs/QUICK_START.md#troubleshooting)
3. **Issues**: Open an issue on [GitHub](https://github.com/SWORDIntel/VPS2.0/issues)
4. **Security**: Report security issues to security@swordintel.com

### Useful Commands

```bash
# View service logs
docker-compose logs -f [service]

# Restart service
docker-compose restart [service]

# Check service health
docker-compose ps

# Execute command in container
docker-compose exec [service] [command]

# View resource usage
docker stats
```

---

## 👥 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
# Clone repository
git clone https://github.com/SWORDIntel/VPS2.0.git
cd VPS2.0

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes and test
docker-compose config
docker-compose up -d

# Submit pull request
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

---

## 🙏 Acknowledgments

- **MISP Project**: Threat intelligence platform
- **OpenCTI**: Structured threat intelligence
- **Caddy**: Modern web server with automatic HTTPS
- **Grafana Labs**: Monitoring and visualization
- **The Hive Project**: Security incident response
- **YARA**: Pattern matching for malware research
- All other open-source projects that make this possible

---

## 📞 Contact

- **Website**: https://swordintel.com
- **GitHub**: https://github.com/SWORDIntel
- **Email**: contact@swordintel.com
- **Security**: security@swordintel.com

---

## 🗺️ Roadmap

### Current (v1.0)
- ✅ Complete Docker-based stack
- ✅ Automated deployment scripts
- ✅ Security hardening
- ✅ Comprehensive monitoring
- ✅ Backup & recovery

### Future (v2.0)
- ⬜ Kubernetes migration path
- ⬜ Multi-node clustering
- ⬜ Advanced threat hunting tools
- ⬜ ML-based anomaly detection
- ⬜ API gateway integration
- ⬜ Enhanced automation workflows

---

## ⚡ Performance

Optimized for:
- **Fast Deployment**: < 30 minutes from zero to production
- **Low Latency**: Sub-second API response times
- **High Throughput**: Handles thousands of requests/second
- **Efficient Storage**: Compressed logs and metrics
- **Resource Optimized**: Runs on single VPS efficiently

---

## 📈 Statistics

- **30+ Services**: Integrated and configured
- **5 Network Zones**: Isolated and secure
- **100% Automated**: One-command deployment
- **Zero Manual Steps**: After initial configuration
- **Production Tested**: Battle-tested configurations

---

**VPS2.0** - Intelligence at Scale, Security by Design

Made with ❤️ by [SWORDIntel](https://github.com/SWORDIntel)

---

**Version**: 1.0.0
**Last Updated**: 2025-11-18
**Status**: Production Ready 🚀
