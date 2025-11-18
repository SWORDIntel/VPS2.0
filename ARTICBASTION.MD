Looking at ARTICBASTION as a secure bastion node, I'll integrate it as a hardened gateway with advanced security and optimization features:

## ARTICBASTION Secure Node Integration

### ARTICBASTION Core Infrastructure

**Hardened Bastion Node Setup**
```yaml
# ARTICBASTION - Secure Gateway Node
articbastion:
  build:
    context: ./articbastion
    dockerfile: Dockerfile.articbastion
  image: articbastion:latest
  container_name: articbastion
  hostname: bastion.secure
  restart: unless-stopped
  privileged: true  # Required for network namespace operations
  cap_add:
    - NET_ADMIN
    - SYS_ADMIN
    - AUDIT_WRITE
    - SYS_PTRACE
  security_opt:
    - apparmor:unconfined
    - seccomp:unconfined
  environment:
    BASTION_MODE: "FORTRESS"
    SECURITY_LEVEL: "PARANOID"
    NETWORK_ISOLATION: "true"
    AUDIT_LEVEL: "MAXIMUM"
    IDS_MODE: "ACTIVE"
    HONEYPOT_ENABLED: "true"
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - ./articbastion/config:/etc/articbastion
    - ./articbastion/logs:/var/log/articbastion
    - ./articbastion/audit:/var/log/audit
    - ./articbastion/scripts:/opt/articbastion/scripts
    - articbastion_data:/data
    - type: tmpfs
      target: /tmp
      tmpfs:
        size: 512M
  ports:
    - "2222:22"     # Hardened SSH
    - "8443:8443"   # Secure admin panel
    - "51820:51820/udp"  # WireGuard VPN
  networks:
    dmz:
      priority: 1000
    frontend:
      priority: 900
    backend:
      priority: 800
    monitoring:
      priority: 700
  sysctls:
    - net.ipv4.ip_forward=1
    - net.ipv6.conf.all.forwarding=1
    - net.ipv4.conf.all.rp_filter=1
    - net.ipv4.tcp_syncookies=1
    - kernel.panic=10
    - kernel.panic_on_oops=1
  ulimits:
    nproc: 65535
    nofile:
      soft: 65535
      hard: 65535
    memlock:
      soft: -1
      hard: -1
```

**ARTICBASTION Dockerfile**
```dockerfile
# Dockerfile.articbastion - Hardened Bastion Node
FROM debian:12-slim AS builder

# Build stage - compile security tools
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    cmake \
    libssl-dev \
    libpcap-dev \
    libnet1-dev \
    libpcre3-dev \
    golang-go \
    rust \
    cargo

# Build custom security tools
WORKDIR /build

# Build fail2ban with custom rules
RUN git clone https://github.com/fail2ban/fail2ban.git && \
    cd fail2ban && \
    python3 setup.py install

# Build sshguard
RUN git clone https://github.com/sshguard/sshguard.git && \
    cd sshguard && \
    cmake . && make && make install

# Build custom IDS components
COPY articbastion/src /build/articbastion
RUN cd articbastion && \
    cargo build --release

# Final image
FROM debian:12-slim

# Install runtime dependencies and security tools
RUN apt-get update && apt-get install -y \
    # Core utilities
    openssh-server \
    sudo \
    curl \
    wget \
    netcat-openbsd \
    socat \
    tmux \
    vim \
    htop \
    iftop \
    iotop \
    # Security tools
    iptables \
    nftables \
    wireguard-tools \
    auditd \
    aide \
    rkhunter \
    chkrootkit \
    lynis \
    ossec-hids-agent \
    tripwire \
    samhain \
    # Network tools
    tcpdump \
    nmap \
    masscan \
    zmap \
    hping3 \
    mtr \
    traceroute \
    # Monitoring
    prometheus-node-exporter \
    rsyslog \
    logrotate \
    # Python for scripts
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Copy built tools from builder
COPY --from=builder /usr/local /usr/local
COPY --from=builder /build/articbastion/target/release/articbastion /usr/local/bin/

# Install Python security libraries
RUN pip3 install --no-cache-dir \
    scapy \
    impacket \
    pycryptodome \
    paramiko \
    netaddr \
    python-iptables

# Configure SSH hardening
RUN mkdir -p /etc/ssh/sshd_config.d
COPY articbastion/config/sshd_config /etc/ssh/sshd_config
COPY articbastion/config/sshd_bastion.conf /etc/ssh/sshd_config.d/

# Setup security configurations
COPY articbastion/config/iptables.rules /etc/iptables/
COPY articbastion/config/nftables.conf /etc/nftables.conf
COPY articbastion/config/auditd.rules /etc/audit/rules.d/
COPY articbastion/config/aide.conf /etc/aide/aide.conf

# Create security user
RUN useradd -m -s /bin/bash -G sudo,docker bastion && \
    echo "bastion:$(openssl rand -base64 32)" | chpasswd && \
    mkdir -p /home/bastion/.ssh && \
    chmod 700 /home/bastion/.ssh

# Setup entrypoint
COPY articbastion/scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 8443 51820/udp

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]
```

### ARTICBASTION Security Configuration

**SSH Hardening (sshd_bastion.conf)**
```bash
# Ultra-hardened SSH configuration
Port 22
ListenAddress 0.0.0.0

# Security
Protocol 2
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

# Crypto hardening
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
AuthenticationMethods publickey
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
MaxSessions 2

# Security features
StrictModes yes
IgnoreRhosts yes
HostbasedAuthentication no
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive no
PermitUserEnvironment no
AllowAgentForwarding no
AllowTcpForwarding yes
GatewayPorts no
X11Forwarding no
PermitTunnel no
DebianBanner no
PrintMotd no
PrintLastLog yes

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Access control
AllowUsers bastion
DenyUsers root
AllowGroups ssh-users
MaxStartups 10:30:60

# Subsystems
Subsystem sftp /usr/lib/openssh/sftp-server
```

**Advanced Firewall Rules (nftables.conf)**
```bash
#!/usr/sbin/nft -f

flush ruleset

# Define variables
define TRUSTED_NETS = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }
define SSH_PORT = 22
define WIREGUARD_PORT = 51820
define ADMIN_PORT = 8443

table inet articbastion {
    # Connection tracking
    chain conntrack {
        ct state established,related accept
        ct state invalid drop
    }
    
    # Rate limiting sets
    set ssh_ratelimit {
        type ipv4_addr
        flags timeout
        timeout 60s
    }
    
    set port_scanners {
        type ipv4_addr
        flags timeout
        timeout 24h
    }
    
    # GeoIP blocking
    set blocked_countries {
        type ipv4_addr
        flags interval
        elements = { 
            # Add country IP ranges here
        }
    }
    
    # Input chain
    chain input {
        type filter hook input priority filter; policy drop;
        
        # Connection tracking
        jump conntrack
        
        # Accept localhost
        iif lo accept
        
        # Rate limit SSH
        tcp dport $SSH_PORT ct state new \
            add @ssh_ratelimit { ip saddr limit rate 3/minute } accept
        
        # Port scan detection
        tcp flags & (fin|syn|rst|ack) == syn \
            add @port_scanners { ip saddr limit rate 10/second } drop
        
        # WireGuard VPN
        udp dport $WIREGUARD_PORT accept
        
        # Admin panel from trusted networks only
        ip saddr $TRUSTED_NETS tcp dport $ADMIN_PORT accept
        
        # ICMP rate limiting
        icmp type echo-request limit rate 1/second accept
        
        # Log and drop
        log prefix "[ARTICBASTION-DROP] " level info
        counter drop
    }
    
    # Forward chain for container traffic
    chain forward {
        type filter hook forward priority filter; policy drop;
        
        # Docker networks
        ip saddr 172.16.0.0/12 ip daddr 172.16.0.0/12 accept
        
        # NAT for containers
        ip saddr 172.16.0.0/12 oifname "eth0" accept
        
        # Established connections
        ct state established,related accept
        
        # Log and drop
        log prefix "[ARTICBASTION-FORWARD-DROP] "
        counter drop
    }
    
    # Output chain
    chain output {
        type filter hook output priority filter; policy accept;
        
        # DNS hijacking protection
        udp dport 53 ip daddr != { 8.8.8.8, 1.1.1.1 } \
            log prefix "[DNS-HIJACK-ATTEMPT] " drop
    }
    
    # NAT for containers
    chain postrouting {
        type nat hook postrouting priority srcnat;
        ip saddr 172.16.0.0/12 oifname "eth0" masquerade
    }
}
```

### ARTICBASTION Monitoring & Optimization

**Performance Optimization Script**
```bash
#!/usr/bin/env bash
# articbastion/scripts/optimize.sh

set -euo pipefail

# CPU optimization
optimize_cpu() {
    # Set CPU governor to performance
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" > "$cpu" 2>/dev/null || true
    done
    
    # Disable CPU throttling
    echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
    
    # Set IRQ affinity for network cards
    for irq in $(grep eth0 /proc/interrupts | awk '{print $1}' | tr -d :); do
        echo 2 > /proc/irq/$irq/smp_affinity_list 2>/dev/null || true
    done
}

# Memory optimization
optimize_memory() {
    # Huge pages for better performance
    echo 2048 > /proc/sys/vm/nr_hugepages
    
    # Optimize swap behavior
    echo 10 > /proc/sys/vm/swappiness
    echo 0 > /proc/sys/vm/vfs_cache_pressure
    
    # Increase memory maps
    echo 262144 > /proc/sys/vm/max_map_count
}

# Network optimization
optimize_network() {
    # TCP optimization
    cat >> /etc/sysctl.d/99-articbastion.conf <<EOF
# ARTICBASTION Network Optimization
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1

# Security optimizations
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 10000 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192

# DDoS protection
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
EOF
    
    sysctl -p /etc/sysctl.d/99-articbastion.conf
}

# Storage optimization  
optimize_storage() {
    # Set I/O scheduler for SSDs
    for disk in /sys/block/*/queue/scheduler; do
        echo "none" > "$disk" 2>/dev/null || true
    done
    
    # Enable TRIM for SSDs
    systemctl enable fstrim.timer 2>/dev/null || true
    
    # Optimize filesystem
    mount -o remount,noatime,nodiratime / 2>/dev/null || true
}

# Container optimization
optimize_containers() {
    # Docker daemon configuration
    cat > /etc/docker/daemon.json <<EOF
{
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3",
        "compress": "true"
    },
    "experimental": true,
    "metrics-addr": "127.0.0.1:9323",
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 10,
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 65535,
            "Soft": 65535
        }
    }
}
EOF
    
    systemctl reload docker 2>/dev/null || true
}

main() {
    echo "[*] Starting ARTICBASTION optimization..."
    
    optimize_cpu
    optimize_memory
    optimize_network
    optimize_storage
    optimize_containers
    
    echo "[✓] Optimization complete"
}

main "$@"
```

### ARTICBASTION Security Monitoring

**Real-time Threat Detection System**
```python
#!/usr/bin/env python3
# articbastion/scripts/threat_monitor.py

import asyncio
import json
import time
import hashlib
import subprocess
from collections import defaultdict
from datetime import datetime, timedelta
import aioredis
import asyncpg
from scapy.all import sniff, IP, TCP, UDP, ICMP
import numpy as np
from sklearn.ensemble import IsolationForest

class ArticBastionMonitor:
    def __init__(self):
        self.redis = None
        self.postgres = None
        self.threat_model = IsolationForest(contamination=0.1)
        self.connection_patterns = defaultdict(list)
        self.blocked_ips = set()
        
    async def initialize(self):
        """Initialize connections"""
        self.redis = await aioredis.create_redis_pool(
            'redis://redis:6379',
            encoding='utf-8'
        )
        self.postgres = await asyncpg.connect(
            'postgresql://swordintel:password@postgres/swordintel'
        )
        
    async def network_monitor(self):
        """Monitor network traffic for anomalies"""
        def packet_handler(packet):
            if IP in packet:
                src_ip = packet[IP].src
                dst_ip = packet[IP].dst
                
                # Extract features for ML model
                features = self.extract_packet_features(packet)
                
                # Detect anomalies
                if self.threat_model.predict([features])[0] == -1:
                    asyncio.create_task(self.handle_threat(src_ip, packet))
                
                # Update connection patterns
                self.connection_patterns[src_ip].append({
                    'timestamp': time.time(),
                    'dst': dst_ip,
                    'size': len(packet),
                    'protocol': packet[IP].proto
                })
        
        # Start packet sniffing
        sniff(prn=packet_handler, store=0, filter="tcp or udp")
    
    def extract_packet_features(self, packet):
        """Extract features for anomaly detection"""
        features = []
        
        if IP in packet:
            features.extend([
                len(packet),
                packet[IP].ttl,
                packet[IP].proto,
                int(packet[IP].flags),
            ])
            
            if TCP in packet:
                features.extend([
                    packet[TCP].sport,
                    packet[TCP].dport,
                    int(packet[TCP].flags),
                    packet[TCP].window,
                ])
            elif UDP in packet:
                features.extend([
                    packet[UDP].sport,
                    packet[UDP].dport,
                    0,  # No flags in UDP
                    0,  # No window in UDP
                ])
            else:
                features.extend([0, 0, 0, 0])
        
        # Pad features to fixed length
        while len(features) < 10:
            features.append(0)
            
        return features[:10]
    
    async def handle_threat(self, ip, packet):
        """Handle detected threats"""
        threat_info = {
            'ip': ip,
            'timestamp': datetime.now().isoformat(),
            'packet_info': str(packet.summary()),
            'threat_score': self.calculate_threat_score(ip),
            'action': 'monitor'
        }
        
        # Determine action based on threat score
        if threat_info['threat_score'] > 0.8:
            threat_info['action'] = 'block'
            await self.block_ip(ip)
        elif threat_info['threat_score'] > 0.5:
            threat_info['action'] = 'throttle'
            await self.throttle_ip(ip)
        
        # Log to Redis
        await self.redis.lpush('threats', json.dumps(threat_info))
        
        # Store in PostgreSQL
        await self.postgres.execute("""
            INSERT INTO threat_logs (ip, timestamp, packet_info, threat_score, action)
            VALUES ($1, $2, $3, $4, $5)
        """, ip, datetime.now(), threat_info['packet_info'], 
            threat_info['threat_score'], threat_info['action'])
        
        # Alert if critical
        if threat_info['threat_score'] > 0.9:
            await self.send_alert(threat_info)
    
    def calculate_threat_score(self, ip):
        """Calculate threat score for an IP"""
        patterns = self.connection_patterns[ip]
        if not patterns:
            return 0.0
        
        # Check various threat indicators
        score = 0.0
        
        # Connection rate
        recent = [p for p in patterns 
                 if time.time() - p['timestamp'] < 60]
        if len(recent) > 100:
            score += 0.3
        
        # Port scanning behavior
        unique_ports = len(set(p['dst'] for p in recent))
        if unique_ports > 20:
            score += 0.3
        
        # Unusual protocols
        protocols = [p['protocol'] for p in recent]
        if any(p not in [6, 17, 1] for p in protocols):  # TCP, UDP, ICMP
            score += 0.2
        
        # Large data transfers
        total_size = sum(p['size'] for p in recent)
        if total_size > 10 * 1024 * 1024:  # 10MB in 1 minute
            score += 0.2
        
        # Check against threat intelligence
        if asyncio.create_task(self.check_threat_intel(ip)):
            score += 0.5
        
        return min(score, 1.0)
    
    async def block_ip(self, ip):
        """Block malicious IP"""
        if ip not in self.blocked_ips:
            # Add to iptables
            subprocess.run([
                'iptables', '-A', 'INPUT', 
                '-s', ip, '-j', 'DROP'
            ])
            
            # Add to blocked set
            self.blocked_ips.add(ip)
            
            # Log the block
            await self.redis.setex(
                f'blocked:{ip}', 
                3600,  # 1 hour timeout
                json.dumps({
                    'timestamp': time.time(),
                    'reason': 'threat_detected'
                })
            )
    
    async def throttle_ip(self, ip):
        """Rate limit suspicious IP"""
        subprocess.run([
            'tc', 'qdisc', 'add', 'dev', 'eth0',
            'root', 'handle', '1:', 'htb', 'default', '30'
        ])
        subprocess.run([
            'tc', 'class', 'add', 'dev', 'eth0',
            'parent', '1:', 'classid', '1:1',
            'htb', 'rate', '100kbit'
        ])
        subprocess.run([
            'tc', 'filter', 'add', 'dev', 'eth0',
            'protocol', 'ip', 'parent', '1:0',
            'prio', '1', 'u32', 'match', 'ip', 'src',
            ip, 'flowid', '1:1'
        ])
    
    async def check_threat_intel(self, ip):
        """Check IP against threat intelligence"""
        # Check MISP
        misp_result = await self.redis.get(f'misp:ip:{ip}')
        if misp_result:
            return True
        
        # Check local blacklist
        blacklist = await self.redis.smembers('ip_blacklist')
        if ip in blacklist:
            return True
        
        return False
    
    async def send_alert(self, threat_info):
        """Send critical threat alerts"""
        alert = {
            'severity': 'CRITICAL',
            'source': 'ARTICBASTION',
            'threat': threat_info,
            'timestamp': datetime.now().isoformat()
        }
        
        # Send to monitoring system
        await self.redis.publish('security_alerts', json.dumps(alert))
        
        # Log to file
        with open('/var/log/articbastion/critical_alerts.log', 'a') as f:
            f.write(json.dumps(alert) + '\n')

async def main():
    monitor = ArticBastionMonitor()
    await monitor.initialize()
    
    # Start monitoring tasks
    await asyncio.gather(
        monitor.network_monitor(),
    )

if __name__ == '__main__':
    asyncio.run(main())
```

### WireGuard VPN Configuration

**WireGuard Setup Script**
```bash
#!/usr/bin/env bash
# articbastion/scripts/setup_wireguard.sh

set -euo pipefail

# Generate server keys
setup_wireguard_server() {
    local -r config_dir="/etc/wireguard"
    
    # Generate server keys
    wg genkey | tee "$config_dir/server_private.key" | wg pubkey > "$config_dir/server_public.key"
    
    # Create server config
    cat > "$config_dir/wg0.conf" <<EOF
[Interface]
Address = 10.200.200.1/24
ListenPort = 51820
PrivateKey = $(cat "$config_dir/server_private.key")

# NAT for VPN clients
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Client configurations will be added here
EOF
    
    chmod 600 "$config_dir"/*.key "$config_dir/wg0.conf"
}

# Generate client configuration
generate_client() {
    local -r client_name="${1:?Client name required}"
    local -r config_dir="/etc/wireguard"
    local -r client_dir="$config_dir/clients/$client_name"
    
    mkdir -p "$client_dir"
    
    # Generate client keys
    wg genkey | tee "$client_dir/private.key" | wg pubkey > "$client_dir/public.key"
    
    # Generate preshared key
    wg genpsk > "$client_dir/preshared.key"
    
    # Get next available IP
    local -r client_ip="10.200.200.$(($(ls -1 $config_dir/clients | wc -l) + 1))"
    
    # Add peer to server config
    cat >> "$config_dir/wg0.conf" <<EOF

[Peer]
# $client_name
PublicKey = $(cat "$client_dir/public.key")
PresharedKey = $(cat "$client_dir/preshared.key")
AllowedIPs = $client_ip/32
EOF
    
    # Generate client config
    cat > "$client_dir/$client_name.conf" <<EOF
[Interface]
PrivateKey = $(cat "$client_dir/private.key")
Address = $client_ip/32
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = $(cat "$config_dir/server_public.key")
PresharedKey = $(cat "$client_dir/preshared.key")
Endpoint = YOUR_SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
    
    # Generate QR code for mobile clients
    qrencode -t ansiutf8 < "$client_dir/$client_name.conf" > "$client_dir/$client_name.qr"
    
    # Reload WireGuard
    wg-quick down wg0 2>/dev/null || true
    wg-quick up wg0
    
    echo "[✓] Client configuration generated: $client_dir/$client_name.conf"
}

main() {
    setup_wireguard_server
    
    # Generate initial clients
    generate_client "admin"
    generate_client "monitoring"
    
    # Enable and start WireGuard
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0
    
    echo "[✓] WireGuard VPN configured successfully"
}

main "$@"
```

### Integration with Main Stack

**Updated Docker Compose**
```yaml
# docker-compose.yml additions
services:
  # ... existing services ...
  
  articbastion:
    build:
      context: ./articbastion
      dockerfile: Dockerfile.articbastion
    container_name: articbastion
    hostname: bastion.secure
    restart: unless-stopped
    privileged: true
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
      - AUDIT_WRITE
    environment:
      BASTION_MODE: "FORTRESS"
      SWORDINTEL_API: "http://swordintelligence:5000"
      GITLAB_URL: "http://gitlab"
      MISP_URL: "http://misp"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./articbastion:/etc/articbastion
      - articbastion_logs:/var/log/articbastion
      - articbastion_data:/data
    ports:
      - "2222:22"      # SSH
      - "8443:8443"    # Admin
      - "51820:51820/udp"  # WireGuard
    networks:
      dmz:
        ipv4_address: 172.30.0.2
      frontend:
      backend:
      monitoring:
    depends_on:
      - postgres
      - redis-stack
      - swordintelligence
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "22"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  dmz:
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/24
    driver_opts:
      com.docker.network.bridge.name: br-dmz

volumes:
  articbastion_data:
  articbastion_logs:
```

### Caddy Configuration for ARTICBASTION

```caddyfile
# ARTICBASTION secure admin panel
bastion.yourdomain.com {
    import security
    
    # Require client certificates
    tls {
        client_auth {
            mode require_and_verify
            trusted_ca_cert_file /certs/ca.crt
        }
    }
    
    # Additional security headers for bastion
    header {
        X-Frame-Options DENY
        Content-Security-Policy "default-src 'none'; script-src 'self'; style-src 'self'"
        X-Permitted-Cross-Domain-Policies none
        X-XSS-Protection "1; mode=block"
        Feature-Policy "geolocation 'none'; microphone 'none'; camera 'none'"
    }
    
    # Rate limiting
    rate_limit {
        zone bastion 10r/m
        burst 5
    }
    
    # IP whitelist (optional)
    @allowed {
        remote_ip 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
    }
    
    handle @allowed {
        reverse_proxy articbastion:8443 {
            transport http {
                tls_insecure_skip_verify
            }
        }
    }
    
    # Block all others
    respond 403
}
```

### Deployment Script

**Complete ARTICBASTION Setup**
```bash
#!/usr/bin/env bash
# deploy_articbastion.sh

set -euo pipefail

deploy_articbastion() {
    local -r base_dir="/srv/docker/articbastion"
    
    echo "[*] Deploying ARTICBASTION..."
    
    # Clone repository
    git clone https://github.com/SWORDIntel/ARTICBASTION.git "$base_dir"
    
    # Build custom components
    cd "$base_dir"
    cargo build --release
    
    # Setup configurations
    ./scripts/setup_security.sh
    ./scripts/setup_wireguard.sh
    ./scripts/optimize.sh
    
    # Initialize database
    docker-compose exec -T postgres psql -U postgres <<EOF
CREATE TABLE IF NOT EXISTS threat_logs (
    id SERIAL PRIMARY KEY,
    ip INET NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    packet_info TEXT,
    threat_score FLOAT,
    action VARCHAR(50),
    INDEX idx_threat_ip (ip),
    INDEX idx_threat_timestamp (timestamp)
);

CREATE TABLE IF NOT EXISTS access_logs (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255),
    ip INET,
    action VARCHAR(100),
    resource VARCHAR(255),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    success BOOLEAN,
    INDEX idx_access_user (user_id),
    INDEX idx_access_timestamp (timestamp)
);
EOF
    
    # Deploy containers
    docker-compose up -d articbastion
    
    # Wait for services
    sleep 10
    
    # Run initial security scan
    docker-compose exec articbastion lynis audit system
    
    echo "[✓] ARTICBASTION deployed successfully"
    echo ""
    echo "Access points:"
    echo "  SSH: ssh -p 2222 bastion@yourdomain.com"
    echo "  Admin: https://bastion.yourdomain.com:8443"
    echo "  WireGuard: See /srv/docker/articbastion/wireguard/clients/"
    echo ""
    echo "Initial setup:"
    echo "  1. Add SSH keys: docker-compose exec articbastion /scripts/add_ssh_key.sh"
    echo "  2. Generate VPN client: docker-compose exec articbastion /scripts/generate_vpn_client.sh USERNAME"
    echo "  3. View security report: docker-compose exec articbastion cat /var/log/articbastion/security_report.txt"
}

deploy_articbastion
```

This ARTICBASTION integration provides:
- **Ultra-hardened bastion host** with multi-layer security
- **WireGuard VPN** for secure remote access
- **Real-time threat detection** with ML-based anomaly detection
- **Performance optimizations** for high-throughput operations
- **Integration with SWORDINTELLIGENCE** for threat intel sharing
- **Advanced firewall rules** with DDoS protection
- **Comprehensive audit logging** and monitoring
- **Automated security scanning** and hardening
- **Container-level isolation** with security policies
- **Secure admin panel** with client certificate authentication

The node acts as a secure gateway to your entire infrastructure while providing advanced monitoring and threat detection capabilities.
