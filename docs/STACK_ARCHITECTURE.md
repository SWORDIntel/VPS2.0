# VPS2.0 Complete Software Stack Architecture

## Overview

This document defines the complete production-ready software stack for the VPS2.0 intelligence and security platform. The architecture is designed for rapid deployment on a single Debian VPS with Docker, emphasizing security, performance, and intelligence gathering capabilities.

## Architecture Principles

- **Defense in Depth**: Multiple layers of security controls
- **Least Privilege**: Minimal permissions for all components
- **Zero Trust**: Verify all connections and requests
- **Immutable Infrastructure**: Container-based deployments
- **Observability**: Comprehensive logging, metrics, and tracing
- **Automation**: GitOps-driven deployment and updates

## Network Architecture

```
Internet
    │
    ├─[Firewall/nftables]
    │
    ├─[Optional: HURRICANE IPv6 Proxy]
    │
    ├─[Caddy Reverse Proxy] (TLS termination)
    │
    ├─[DMZ Network] - ARTICBASTION, exposed services
    │
    ├─[Frontend Network] - Web applications
    │
    ├─[Backend Network] - Databases, internal services
    │
    └─[Monitoring Network] - Prometheus, Grafana, logging
```

## Service Catalog

### 1. Infrastructure Services

#### 1.1 Container Management
- **Portainer CE** (`portainer/portainer-ce:latest`)
  - Web UI for Docker management
  - Stack deployment and monitoring
  - User access control
  - Template catalog
  - **Network**: frontend, backend
  - **Port**: 9000 (via Caddy)
  - **Volumes**: portainer_data

- **Watchtower** (`containrrr/watchtower:latest`)
  - Automated container updates
  - Schedule: Weekly with notification
  - **Network**: backend
  - **Volumes**: /var/run/docker.sock

#### 1.2 Reverse Proxy & TLS
- **Caddy v2** (`caddy:2-alpine` with plugins)
  - Automatic HTTPS (Let's Encrypt + ZeroSSL)
  - HTTP/3 support
  - Advanced routing and middleware
  - Rate limiting
  - CrowdSec bouncer integration
  - Prometheus metrics endpoint
  - **Network**: frontend, dmz
  - **Ports**: 80, 443, 443/udp (HTTP/3)
  - **Volumes**: caddy_data, caddy_config, caddy_logs
  - **Plugins**:
    - github.com/caddy-dns/cloudflare
    - github.com/mholt/caddy-ratelimit
    - github.com/greenpau/caddy-security
    - github.com/hslatman/caddy-crowdsec

#### 1.3 Secrets Management
- **HashiCorp Vault** (`hashicorp/vault:latest`)
  - Dev mode for single-node setup (upgradeable to production)
  - API key storage
  - Certificate management
  - Database credential rotation
  - **Network**: backend
  - **Port**: 8200
  - **Volumes**: vault_data, vault_config

### 2. Secure Gateway (ARTICBASTION)

- **ARTICBASTION** (custom build)
  - Hardened SSH bastion (ed25519 keys)
  - WireGuard VPN server (port 51820)
  - Advanced nftables firewall
  - Real-time threat detection (ML-based)
  - Performance optimization scripts
  - Audit logging (auditd, aide, tripwire)
  - Integration with MISP for threat intel
  - **Network**: dmz, frontend, backend, monitoring
  - **Ports**: 2222 (SSH), 8443 (admin panel), 51820/udp (WireGuard)
  - **Volumes**: articbastion_data, articbastion_logs, articbastion_audit
  - **Privileged**: true (for network operations)

### 3. Optional: HURRICANE IPv6 Proxy

- **HURRICANE** (custom build from https://github.com/SWORDIntel/HURRICANE)
  - IPv6-over-IPv4 tunneling daemon
  - Multiple tunnel backends (HE.net, Mullvad, WireGuard)
  - REST API for tunnel management
  - Web UI with real-time metrics
  - SOCKS5 proxy mode
  - IPv6 port scanner (FASTPORT)
  - Prometheus metrics export
  - **Network**: dmz, frontend
  - **Ports**: 8080 (API), 8081 (Web UI), 1080 (SOCKS5)
  - **Volumes**: hurricane_data, hurricane_config
  - **Capabilities**: NET_ADMIN, NET_RAW

### 4. Database Layer

#### 4.1 PostgreSQL
- **PostgreSQL 16** (`postgres:16-alpine`)
  - SSL/TLS enabled
  - Extensions: uuid-ossp, pgcrypto, pg_trgm, PostGIS, pgaudit, pg_cron
  - Connection pooling via PgBouncer
  - Automated backups
  - **Network**: backend
  - **Port**: 5432 (internal only)
  - **Volumes**: postgres_data, postgres_backups
  - **Databases**: swordintel, misp, gitlab, opencti

- **PgBouncer** (`edoburu/pgbouncer:latest`)
  - Connection pooling
  - **Network**: backend
  - **Port**: 6432

#### 4.2 Graph Databases
- **Neo4j Community 5** (`neo4j:5-community`)
  - Bolt encryption enabled
  - APOC and Graph Data Science plugins
  - **Network**: backend
  - **Ports**: 7687 (Bolt), 7474 (HTTP)
  - **Volumes**: neo4j_data, neo4j_logs

- **EdgeDB** (`edgedb/edgedb:latest`)
  - Next-gen graph-relational database
  - **Network**: backend
  - **Port**: 5656
  - **Volumes**: edgedb_data

#### 4.3 Redis Stack
- **Redis Stack** (`redis/redis-stack-server:latest`)
  - Includes: RediSearch, RedisJSON, RedisGraph, RedisTimeSeries, RedisBloom
  - ACL authentication
  - AOF persistence
  - **Network**: backend
  - **Port**: 6379 (internal only)
  - **Volumes**: redis_data

### 5. Intelligence & Analysis Platform

#### 5.1 SWORDINTELLIGENCE
- **SWORDINTELLIGENCE** (custom ASP.NET Core 8.0)
  - Main intelligence platform
  - SignalR for real-time updates
  - JWT authentication
  - Integration with MISP, Neo4j, Redis
  - **Network**: frontend, backend
  - **Port**: 5000
  - **Volumes**: swordintel_uploads, swordintel_logs, certs
  - **Source**: https://github.com/SWORDOps/SWORDINTELLIGENCE

#### 5.2 Threat Intelligence
- **MISP** (`coolacid/misp-docker:latest`)
  - Malware Information Sharing Platform
  - Threat feed ingestion
  - YARA, VirusTotal, Shodan modules
  - **Network**: frontend, backend
  - **Port**: 443 (via Caddy)
  - **Volumes**: misp_data, misp_mysql, misp_redis
  - **Dependencies**: mariadb, redis

- **OpenCTI** (`opencti/platform:latest`)
  - Structured threat intelligence
  - STIX 2.1 support
  - **Network**: frontend, backend
  - **Port**: 8080
  - **Volumes**: opencti_data
  - **Dependencies**: elasticsearch, redis, rabbitmq

- **Cortex** (`thehiveproject/cortex:latest`)
  - Observable analysis engine
  - Custom analyzers support
  - **Network**: backend
  - **Port**: 9001
  - **Volumes**: cortex_data, cortex_analyzers

#### 5.3 Workflow Automation
- **n8n** (`n8nio/n8n:latest`)
  - Workflow automation
  - MISP → Cortex → TheHive integration
  - **Network**: frontend, backend
  - **Port**: 5678
  - **Volumes**: n8n_data

### 6. Malware Analysis

#### 6.1 Static Analysis
- **YARA Scanner** (custom alpine build)
  - YARA pattern matching
  - Community rules from Yara-Rules/rules
  - Custom rule management
  - **Network**: backend
  - **Volumes**: yara_rules, yara_samples

- **ClamAV** (`clamav/clamav:stable`)
  - Antivirus scanning
  - FreshClam auto-updates
  - **Network**: backend
  - **Volumes**: clamav_data
  - **Resources**: 4GB RAM

#### 6.2 Dynamic Analysis
- **Cuckoo Sandbox** (`blacktop/cuckoo:latest`)
  - Automated malware analysis
  - VM management
  - **Network**: backend, isolated
  - **Privileged**: true (for KVM)
  - **Volumes**: cuckoo_conf, cuckoo_storage
  - **Devices**: /dev/kvm

### 7. Network Security Monitoring

#### 7.1 Intrusion Detection
- **Suricata** (`jasonish/suricata:latest`)
  - Network IDS/IPS
  - EVE JSON logging
  - ET Open ruleset
  - **Network**: host mode
  - **Capabilities**: NET_ADMIN, NET_RAW
  - **Volumes**: suricata_rules, suricata_logs

- **Zeek** (`zeek/zeek:latest`)
  - Network analysis framework
  - Protocol analyzers
  - **Network**: host mode
  - **Capabilities**: NET_ADMIN, NET_RAW
  - **Volumes**: zeek_logs, zeek_scripts

#### 7.2 Packet Capture
- **Arkime** (`arkime/arkime:latest`)
  - Full packet capture and analysis
  - Web interface
  - **Network**: frontend, backend
  - **Port**: 8005
  - **Volumes**: arkime_pcaps, arkime_config
  - **Dependencies**: elasticsearch

### 8. Security Services

#### 8.1 Runtime Security
- **Falco** (`falcosecurity/falco:latest`)
  - Container runtime security
  - Kernel event monitoring
  - Custom rules
  - **Privileged**: true
  - **Volumes**: /var/run/docker.sock, /proc, /boot, /lib/modules

- **CrowdSec** (`crowdsecurity/crowdsec:latest`)
  - Community-powered IPS
  - Integration with Caddy
  - **Network**: backend
  - **Port**: 8080 (API)
  - **Volumes**: crowdsec_data, crowdsec_config

#### 8.2 Vulnerability Scanning
- **Trivy** (`aquasec/trivy:latest`)
  - Container image scanning
  - Filesystem scanning
  - SBOM generation
  - **Network**: backend
  - **Volumes**: /var/run/docker.sock, trivy_cache

### 9. Blockchain Analysis

#### 9.1 Bitcoin
- **Bitcoin Core** (`btcpayserver/bitcoin:25.0`)
  - Full node with txindex
  - RPC enabled
  - **Network**: backend
  - **Ports**: 8332 (RPC), 8333 (P2P)
  - **Volumes**: bitcoin_data

- **Electrs** (`blockstream/electrs:latest`)
  - Electrum server
  - Blockchain indexing
  - **Network**: backend
  - **Port**: 50001
  - **Dependencies**: bitcoin

- **Mempool Explorer** (`mempool/mempool:latest`)
  - Bitcoin blockchain explorer
  - Mempool visualizer
  - **Network**: frontend, backend
  - **Port**: 4200
  - **Dependencies**: bitcoin, electrs

#### 9.2 Ethereum
- **Erigon** (`thorax/erigon:latest`)
  - Ethereum full node (efficient)
  - JSON-RPC enabled
  - **Network**: backend
  - **Ports**: 8545 (RPC), 30303 (P2P)
  - **Volumes**: erigon_data

- **Blockscout** (`blockscout/blockscout:latest`)
  - EVM blockchain explorer
  - Multi-chain support
  - **Network**: frontend, backend
  - **Port**: 4000
  - **Dependencies**: erigon, postgres

### 10. Observability Stack

#### 10.1 Metrics
- **VictoriaMetrics** (`victoriametrics/victoria-metrics:latest`)
  - Prometheus-compatible time-series DB
  - Efficient storage
  - 90-day retention
  - **Network**: monitoring
  - **Port**: 8428
  - **Volumes**: victoriametrics_data

- **Prometheus Node Exporter** (`prom/node-exporter:latest`)
  - Host metrics collection
  - **Network**: monitoring
  - **Port**: 9100

- **cAdvisor** (`gcr.io/cadvisor/cadvisor:latest`)
  - Container metrics
  - **Network**: monitoring
  - **Port**: 8080
  - **Volumes**: /var/run/docker.sock, /sys, /var/lib/docker

#### 10.2 Logging
- **Vector** (`timberio/vector:latest-alpine`)
  - Log aggregation and routing
  - Docker log collection
  - **Network**: monitoring, backend
  - **Volumes**: /var/run/docker.sock, vector_data

- **Loki** (`grafana/loki:latest`)
  - Lightweight log aggregation
  - **Network**: monitoring
  - **Port**: 3100
  - **Volumes**: loki_data

#### 10.3 Visualization
- **Grafana** (`grafana/grafana:latest`)
  - Metrics and logs visualization
  - Pre-configured dashboards
  - AlertManager integration
  - **Network**: frontend, monitoring
  - **Port**: 3000 (via Caddy)
  - **Volumes**: grafana_data, grafana_dashboards

- **Uptrace** (`uptrace/uptrace:latest`)
  - APM and distributed tracing
  - OpenTelemetry support
  - **Network**: monitoring
  - **Port**: 14318
  - **Dependencies**: clickhouse

- **ClickHouse** (`clickhouse/clickhouse-server:latest`)
  - For Uptrace storage
  - **Network**: backend
  - **Port**: 9000
  - **Volumes**: clickhouse_data

### 11. Development & CI/CD

#### 11.1 GitLab
- **GitLab CE** (`gitlab/gitlab-ce:latest`)
  - Source code management
  - CI/CD pipelines
  - Container registry
  - GitLab Pages
  - **Network**: frontend, backend
  - **Ports**: 2222 (SSH), 5050 (registry)
  - **Volumes**: gitlab_config, gitlab_logs, gitlab_data, gitlab_backups
  - **Resources**: 4GB RAM

- **GitLab Runner** (`gitlab/gitlab-runner:alpine`)
  - CI/CD job execution
  - Docker executor
  - **Network**: backend
  - **Volumes**: /var/run/docker.sock, gitlab_runner_config
  - **Dependencies**: gitlab

### 12. Supporting Services

#### 12.1 Message Queue
- **RabbitMQ** (`rabbitmq:3-management-alpine`)
  - For OpenCTI, n8n
  - Management UI
  - **Network**: backend
  - **Ports**: 5672, 15672
  - **Volumes**: rabbitmq_data

#### 12.2 Search Engine
- **Elasticsearch** (`docker.elastic.co/elasticsearch/elasticsearch:8.11.0`)
  - For Arkime, OpenCTI, MISP
  - Single-node mode
  - **Network**: backend
  - **Port**: 9200
  - **Volumes**: elasticsearch_data
  - **Resources**: 4GB RAM

#### 12.3 Database (MariaDB for MISP)
- **MariaDB** (`mariadb:10.11`)
  - For MISP
  - **Network**: backend
  - **Port**: 3306
  - **Volumes**: mariadb_data

## Resource Allocation

### Minimum VPS Requirements
- **CPU**: 8 cores (16 recommended)
- **RAM**: 32GB minimum (64GB recommended)
- **Storage**: 500GB SSD (1TB recommended)
- **Network**: 1Gbps

### Resource Limits per Service Category

| Category | Memory Limit | CPU Limit | Priority |
|----------|--------------|-----------|----------|
| Critical (Caddy, Postgres, Redis) | No limit | No limit | High |
| Intelligence (SWORDINTELLIGENCE, MISP) | 4GB | 2 cores | High |
| Analysis (Cuckoo, Suricata) | 4GB | 2 cores | Medium |
| Blockchain (Bitcoin, Erigon) | 8GB | 4 cores | Medium |
| GitLab | 4GB | 2 cores | Medium |
| Monitoring (Grafana, Prometheus) | 2GB | 1 core | Low |
| Supporting (RabbitMQ, Elasticsearch) | 4GB | 2 cores | Medium |

## Network Segmentation

### DMZ Network (172.30.0.0/24)
- ARTICBASTION
- HURRICANE
- Exposed services only

### Frontend Network (172.20.0.0/24)
- Caddy
- SWORDINTELLIGENCE
- MISP
- Grafana
- Portainer
- GitLab (web)

### Backend Network (172.21.0.0/24) - Internal Only
- PostgreSQL
- Neo4j
- Redis
- MariaDB
- Elasticsearch
- RabbitMQ
- All analysis tools
- All internal services

### Monitoring Network (172.22.0.0/24) - Internal Only
- VictoriaMetrics
- Loki
- Vector
- Node Exporter
- cAdvisor

### Isolated Network (172.23.0.0/24) - Air-gapped
- Cuckoo Sandbox
- Malware analysis VMs

## Security Controls

### 1. Host Security
- Unattended security updates
- UFW firewall (allow 22, 80, 443, 2222, 51820/udp)
- Fail2ban (SSH, Caddy admin panels)
- Rootless Docker (optional, recommended)
- AppArmor/SELinux enabled
- Kernel hardening (sysctl.conf)
- SSH key-only authentication
- Disable root login

### 2. Container Security
- Non-root users in containers
- Read-only filesystems where possible
- No-new-privileges security option
- AppArmor profiles
- Seccomp profiles
- Capability dropping (drop ALL, add specific)
- Resource limits (memory, CPU)
- Health checks
- Automated vulnerability scanning (Trivy)
- Image signing and verification

### 3. Network Security
- TLS everywhere (mTLS where possible)
- Internal networks isolated
- No exposed database ports
- Encrypted inter-service communication
- Rate limiting on all public endpoints
- DDoS protection (nftables, CrowdSec)
- GeoIP blocking (optional)
- Certificate pinning

### 4. Access Control
- WireGuard VPN for admin access
- Client certificate authentication for bastion
- RBAC in all services
- Vault-based secret management
- MFA for critical services
- Audit logging
- Session management

### 5. Data Protection
- Encrypted volumes (LUKS optional)
- Automated backups (daily)
- Backup encryption
- Off-site backup replication
- Database encryption at rest
- TLS for data in transit
- Secure credential storage

## Deployment Strategy

### Phase 1: Foundation (Priority 1)
1. Host hardening
2. Docker installation and configuration
3. Network creation
4. Caddy reverse proxy
5. PostgreSQL, Redis
6. Portainer
7. Basic monitoring (Grafana, VictoriaMetrics)

### Phase 2: Security Layer (Priority 1)
1. ARTICBASTION deployment
2. WireGuard VPN setup
3. Firewall configuration
4. Fail2ban setup
5. Vault deployment
6. CrowdSec deployment

### Phase 3: Core Intelligence (Priority 2)
1. SWORDINTELLIGENCE deployment
2. MISP deployment
3. Neo4j deployment
4. GitLab deployment

### Phase 4: Analysis Tools (Priority 2)
1. YARA scanner
2. ClamAV
3. Suricata IDS
4. OpenCTI
5. Cortex

### Phase 5: Advanced Features (Priority 3)
1. HURRICANE proxy (optional)
2. Blockchain nodes and explorers
3. Cuckoo Sandbox
4. Arkime/Zeek
5. n8n automation
6. Uptrace APM

## Backup Strategy

### Daily Backups
- PostgreSQL databases (pg_dump)
- GitLab (built-in backup)
- MISP data
- Configuration files
- Uploaded files/samples

### Weekly Backups
- Full volume snapshots
- Neo4j dumps
- Redis persistence files
- Complete configuration backup

### Monthly Backups
- Blockchain data checkpoints
- Complete system image
- Off-site replication

### Backup Retention
- Daily: 7 days
- Weekly: 4 weeks
- Monthly: 12 months

## Monitoring & Alerting

### Critical Alerts
- Service failures
- High CPU/memory usage (>85%)
- Disk space critical (<10%)
- Security events (Falco, Suricata)
- Certificate expiration (<7 days)
- Failed backups
- Authentication failures

### Warning Alerts
- High resource usage (>70%)
- Slow query performance
- Disk space warning (<20%)
- Update available
- Unusual network patterns

### Metrics Collection
- System metrics (CPU, memory, disk, network)
- Container metrics (per-container resources)
- Application metrics (request rates, errors, latency)
- Security metrics (threats detected, IPs blocked)
- Business metrics (samples analyzed, alerts generated)

## Maintenance Procedures

### Daily
- Check alert dashboard
- Review security logs
- Monitor resource usage

### Weekly
- Update check and apply
- Backup verification
- Log rotation
- Certificate check

### Monthly
- Full security audit (Lynis)
- Vulnerability scan (Trivy)
- Performance review
- Capacity planning
- Cleanup old data

### Quarterly
- Disaster recovery test
- Security penetration test
- Documentation update
- Service optimization

## Disaster Recovery

### Recovery Time Objectives (RTO)
- Critical services (Caddy, Postgres, SWORDINTELLIGENCE): 15 minutes
- Intelligence services (MISP, OpenCTI): 30 minutes
- Analysis tools: 1 hour
- Blockchain nodes: 24 hours (sync time)

### Recovery Point Objectives (RPO)
- Databases: 1 hour (continuous replication optional)
- Files: 24 hours (daily backup)
- Logs: Real-time (shipped to external storage)

### Recovery Procedures
1. Provision new VPS
2. Restore host configuration
3. Restore Docker volumes from backup
4. Start containers in priority order
5. Verify service functionality
6. Update DNS (if IP changed)
7. Restore WireGuard VPN
8. Resume operations

## Cost Optimization

### Resource Right-Sizing
- Start with minimum viable services
- Monitor actual usage
- Scale up as needed
- Use spot/reserved instances where available

### Storage Optimization
- Compress logs
- Implement data retention policies
- Use object storage for cold data
- Deduplication where applicable

### Network Optimization
- CDN for static assets
- Compress responses
- Connection pooling
- Keep-alive connections

## Scalability Path

### Single Node → Multi-Node
When single node reaches limits:
1. Database cluster (PostgreSQL HA, Redis Cluster)
2. Application replicas (load balanced)
3. Separate analysis node
4. Separate blockchain node
5. Kubernetes migration (optional)

### Horizontal Scaling Priorities
1. SWORDINTELLIGENCE (stateless)
2. Analysis workers
3. Web services
4. Background jobs

## Compliance & Governance

### Data Handling
- Classification (public, internal, confidential, restricted)
- Retention policies
- Deletion procedures
- Access logging

### Regulatory Considerations
- GDPR compliance (if applicable)
- Data sovereignty
- Encryption requirements
- Audit trails

## Conclusion

This architecture provides a comprehensive, secure, and scalable platform for intelligence gathering and analysis. The modular design allows for phased deployment while maintaining security and operational excellence. All components are containerized for easy deployment, scaling, and maintenance.

## Next Steps

1. Review and approve architecture
2. Prepare deployment environment
3. Execute Phase 1 deployment
4. Test and validate
5. Proceed with subsequent phases
6. Document as-built configuration
7. Train operations team
8. Go live

---

**Document Version**: 1.0
**Last Updated**: 2025-11-18
**Author**: VPS2.0 Architecture Team
**Status**: Ready for Implementation
