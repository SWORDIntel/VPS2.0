#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 Security Hardening Script
# Applies comprehensive security hardening to the host system

#==============================================
# Configuration
#==============================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

#==============================================
# Helper Functions
#==============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

#==============================================
# Hardening Functions
#==============================================

harden_ssh() {
    log_info "Hardening SSH configuration..."

    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)

    # Apply hardened SSH config
    cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
# VPS2.0 SSH Hardening

# Disable root login
PermitRootLogin no

# Only use SSH protocol 2
Protocol 2

# Use strong ciphers
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

# Authentication
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Security settings
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive no

# Disable dangerous features
X11Forwarding no
PermitUserEnvironment no
AllowAgentForwarding no
AllowTcpForwarding yes
PermitTunnel no

# Logging
LogLevel VERBOSE
SyslogFacility AUTH

# Subsystem
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

    # Restart SSH
    systemctl restart sshd

    log_success "SSH hardened"
}

configure_fail2ban() {
    log_info "Installing and configuring Fail2ban..."

    # Install Fail2ban
    apt-get install -y fail2ban

    # Create local configuration
    cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh,2222
logpath = /var/log/auth.log

[sshd-ddos]
enabled = true
port = ssh,2222
logpath = /var/log/auth.log

[caddy-auth]
enabled = true
port = http,https
logpath = /srv/docker/caddy/logs/*.log
maxretry = 5

[docker-auth]
enabled = true
logpath = /var/log/daemon.log
maxretry = 3
EOF

    # Start and enable Fail2ban
    systemctl enable fail2ban
    systemctl restart fail2ban

    log_success "Fail2ban configured"
}

configure_sysctl() {
    log_info "Applying kernel hardening..."

    cat > /etc/sysctl.d/99-vps2.0-hardening.conf <<'EOF'
# VPS2.0 Kernel Hardening

# IP Forwarding (required for Docker)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Disable source packet routing
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Disable ICMP redirect acceptance
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Enable IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP error responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

# TCP/IP stack hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# TCP Fast Open
net.ipv4.tcp_fastopen = 3

# BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Increase network performance
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Memory optimization
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# For containers
vm.max_map_count = 262144
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
kernel.pid_max = 4194304

# Security
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.kexec_load_disabled = 1
EOF

    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-vps2.0-hardening.conf

    log_success "Kernel hardening applied"
}

configure_automatic_updates() {
    log_info "Configuring automatic security updates..."

    # Install unattended-upgrades
    apt-get install -y unattended-upgrades apt-listchanges

    # Configure automatic updates
    cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
Unattended-Upgrade::Mail "root";
EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    log_success "Automatic updates configured"
}

harden_docker() {
    log_info "Hardening Docker daemon..."

    # Create Docker daemon configuration
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3",
        "compress": "true"
    },
    "storage-driver": "overlay2",
    "userland-proxy": false,
    "live-restore": true,
    "no-new-privileges": true,
    "icc": false,
    "default-ulimits": {
        "nofile": {
            "Hard": 65536,
            "Name": "nofile",
            "Soft": 65536
        }
    },
    "metrics-addr": "127.0.0.1:9323",
    "experimental": true
}
EOF

    # Restart Docker
    systemctl restart docker

    log_success "Docker hardened"
}

configure_auditd() {
    log_info "Installing and configuring audit daemon..."

    # Install auditd
    apt-get install -y auditd audispd-plugins

    # Add audit rules
    cat >> /etc/audit/rules.d/vps2.0.rules <<'EOF'
# VPS2.0 Audit Rules

# Monitor Docker daemon
-w /usr/bin/docker -p wa -k docker
-w /var/lib/docker -p wa -k docker
-w /etc/docker -p wa -k docker

# Monitor important files
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes

# Monitor network configuration
-w /etc/network/ -p wa -k network_changes
-w /etc/hosts -p wa -k hosts_changes

# Monitor system calls
-a always,exit -F arch=b64 -S execve -k exec_monitoring
-a always,exit -F arch=b64 -S connect -k network_connections
EOF

    # Restart auditd
    systemctl restart auditd

    log_success "Audit daemon configured"
}

install_security_tools() {
    log_info "Installing security scanning tools..."

    apt-get install -y \
        lynis \
        rkhunter \
        chkrootkit \
        aide \
        clamav \
        clamav-daemon

    # Initialize AIDE
    aideinit
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

    # Update ClamAV
    freshclam

    # Update rkhunter
    rkhunter --update
    rkhunter --propupd

    log_success "Security tools installed"
}

configure_logrotate() {
    log_info "Configuring log rotation..."

    cat > /etc/logrotate.d/vps2.0 <<'EOF'
/var/log/vps2.0/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/srv/docker/caddy/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
}
EOF

    log_success "Log rotation configured"
}

#==============================================
# Main Hardening Flow
#==============================================

main() {
    log_info "Starting VPS2.0 security hardening..."
    echo ""

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi

    # Update system
    log_info "Updating system packages..."
    apt-get update
    apt-get upgrade -y

    # Apply hardening
    harden_ssh
    configure_fail2ban
    configure_sysctl
    configure_automatic_updates
    harden_docker
    configure_auditd
    install_security_tools
    configure_logrotate

    # Run security scan
    log_info "Running initial security scan..."
    lynis audit system --quick --quiet

    echo ""
    log_success "Security hardening complete!"
    echo ""
    echo "Next steps:"
    echo "1. Review Lynis audit report: less /var/log/lynis.log"
    echo "2. Configure SSH key authentication"
    echo "3. Test Fail2ban: fail2ban-client status"
    echo "4. Review audit logs: ausearch -k docker"
    echo "5. Run full security scan: lynis audit system"
    echo ""
}

# Run main function
main "$@"
