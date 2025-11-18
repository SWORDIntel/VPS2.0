# VPS2.0 Quick Start Guide

## One-Liner Installation

Deploy the entire VPS2.0 Intelligence Platform with a single command.

---

## 🚀 Standard Installation

### Using curl
```bash
curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash
```

### Using wget
```bash
wget -qO- https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash
```

---

## 📊 Installation with Verbose Logging

For detailed progress information and troubleshooting:

```bash
curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash -s -- --verbose
```

**What you'll see:**
- Detailed progress messages for each step
- Package installation details
- System command outputs
- Configuration changes
- Network operations

---

## 🐛 Installation with Debug Mode

For maximum verbosity and troubleshooting:

```bash
curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash -s -- --debug
```

**What you'll see:**
- All verbose logging (see above)
- Bash command tracing (`set -x`)
- Variable values at each step
- Function entry/exit points
- System state information
- Full command execution details

---

## 🤖 Non-Interactive Installation

For automated deployments and CI/CD pipelines:

```bash
curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash -s -- --yes
```

**Features:**
- Auto-accepts all prompts
- No user interaction required
- Perfect for automation
- Uses default values

---

## 🎨 Installation Without Colors

For log files and terminals without color support:

```bash
curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash -s -- --no-color
```

---

## 🔀 Combined Options

You can combine multiple options:

### Verbose + Non-Interactive
```bash
curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | \
    sudo bash -s -- --verbose --yes
```

### Debug + No Color (for logging)
```bash
curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | \
    sudo bash -s -- --debug --no-color 2>&1 | tee install.log
```

### All Options
```bash
curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | \
    sudo bash -s -- --verbose --yes --no-color
```

---

## 📋 System Requirements

### Minimum Requirements
| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Ubuntu 20.04, Debian 11, CentOS 8 | Ubuntu 22.04, Debian 12 |
| **CPU** | 2 cores | 8+ cores |
| **RAM** | 4 GB | 32+ GB |
| **Disk** | 50 GB | 500+ GB SSD |
| **Network** | 100 Mbps | 1 Gbps |

### Supported Architectures
- ✅ x86_64 (AMD64)
- ✅ ARM64 (aarch64)
- ⚠️ ARMv7 (limited support)

### Supported Operating Systems
- ✅ Ubuntu 20.04, 22.04, 24.04
- ✅ Debian 11, 12
- ✅ CentOS Stream 8, 9
- ✅ Rocky Linux 8, 9
- ✅ AlmaLinux 8, 9
- ✅ Fedora 38+

---

## 🎯 What Gets Installed

The one-liner installer will:

1. **Pre-flight Checks**
   - Verify root/sudo privileges
   - Detect OS and architecture
   - Check system requirements (CPU, RAM, disk)

2. **System Prerequisites**
   - curl, wget, git
   - Docker Engine (24.0+)
   - Docker Compose Plugin (2.20+)
   - UFW firewall
   - Fail2ban
   - Monitoring tools (htop, net-tools)

3. **VPS2.0 Repository**
   - Clone to `/opt/vps2.0`
   - Set up directory structure
   - Configure permissions

4. **Interactive Setup Wizard**
   - Domain configuration
   - Service selection
   - Security setup
   - Credential generation
   - Deployment execution

---

## 📖 Installation Steps

### Step 1: Pre-Installation

```bash
# Update your system (recommended)
sudo apt update && sudo apt upgrade -y  # Ubuntu/Debian
sudo dnf update -y                      # CentOS/Rocky/Alma

# Ensure you have a sudo user (not root)
adduser vps2admin
usermod -aG sudo vps2admin
su - vps2admin
```

### Step 2: Run Installer

```bash
# Standard installation
curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash
```

### Step 3: Follow Setup Wizard

The interactive wizard will guide you through:

1. **Basic Configuration**
   - Domain name
   - Admin email
   - Timezone

2. **Deployment Profile**
   - Minimal (core services only)
   - Standard (recommended)
   - Full (all services)
   - Maximum (everything + optional)
   - Custom (pick and choose)

3. **Optional Services**
   - HURRICANE IPv6 Proxy
   - Blockchain explorers
   - Additional tools

4. **Security Setup**
   - Auto-generated passwords
   - TLS/SSL certificates
   - Firewall configuration
   - SSH hardening

5. **DNS Verification**
   - Check DNS records
   - Verify domain resolution

6. **Deployment**
   - Docker Compose orchestration
   - Service health checks
   - Post-deployment verification

---

## 🔍 Verification

After installation completes:

```bash
# Check installation directory
cd /opt/vps2.0
ls -la

# View running containers
docker ps

# Check service status
docker-compose ps

# View logs
docker-compose logs -f --tail=50

# Access dashboard
# Navigate to: https://dashboard.your-domain.com
```

---

## 🎛️ Command-Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | `-h` | Show help message and exit |
| `--verbose` | `-v` | Enable verbose logging |
| `--debug` | `-d` | Enable debug mode (very detailed) |
| `--yes` | `-y` | Non-interactive mode |
| `--no-color` | - | Disable colored output |

---

## 📊 Logging Examples

### Normal Mode (Default)
```
[INFO] Starting automated installation...
[⠋] Updating package index
[✓] Updating package index
[⠋] Installing required packages
[✓] Installing required packages
[✓ SUCCESS] Prerequisites installed
```

### Verbose Mode (`--verbose`)
```
[INFO] Starting automated installation...
[VERBOSE] Updating package index...
[VERBOSE] Package list: apt-transport-https ca-certificates curl...
[INFO] Installing packages (this may take a few minutes)...
[VERBOSE] Setting up apt-transport-https (2.4.11) ...
[VERBOSE] Setting up ca-certificates (20230311) ...
[✓ SUCCESS] Prerequisites installed
```

### Debug Mode (`--debug`)
```
[DEBUG] Script version: 1.0.0
[DEBUG] Install directory: /opt/vps2.0
[DEBUG] Repository URL: https://github.com/SWORDIntel/VPS2.0.git
[VERBOSE] Beginning pre-flight checks...
[DEBUG] OS ID: ubuntu
[DEBUG] OS Version: 22.04
[DEBUG] OS Pretty Name: Ubuntu 22.04.3 LTS
[DEBUG] Package manager: apt
[DEBUG] Executing: apt-get update
+ apt-get update
Hit:1 http://archive.ubuntu.com/ubuntu jammy InRelease
...
```

---

## 🔧 Troubleshooting

### Installation Fails

1. **Check logs in verbose mode:**
   ```bash
   curl -fsSL <url> | sudo bash -s -- --verbose 2>&1 | tee install.log
   ```

2. **Review error messages:**
   ```bash
   grep -i error install.log
   grep -i fail install.log
   ```

3. **Verify system requirements:**
   ```bash
   # CPU
   nproc

   # RAM
   free -h

   # Disk
   df -h

   # OS
   cat /etc/os-release
   ```

### Docker Installation Issues

```bash
# Check if Docker is already installed
docker --version

# Check Docker service status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Check Docker permissions
sudo usermod -aG docker $USER
```

### Network Issues

```bash
# Test internet connectivity
ping -c 3 8.8.8.8

# Test DNS resolution
nslookup github.com

# Check firewall
sudo ufw status

# Temporarily disable firewall for testing
sudo ufw disable
```

### Repository Clone Fails

```bash
# Manually clone
sudo git clone https://github.com/SWORDIntel/VPS2.0.git /opt/vps2.0

# Check git installation
git --version

# Check GitHub connectivity
curl -I https://github.com
```

---

## 🚀 Quick Deployment Scenarios

### Scenario 1: Development Environment
```bash
# Minimal installation for testing
curl -fsSL <url> | sudo bash
# Select "Minimal" profile in wizard
# Deploy core services only
```

### Scenario 2: Production Deployment
```bash
# Full installation with all security features
curl -fsSL <url> | sudo bash -s -- --verbose
# Select "Full" profile in wizard
# Enable all security options
```

### Scenario 3: Automated CI/CD
```bash
# Non-interactive installation
curl -fsSL <url> | sudo bash -s -- --yes
# Uses defaults for all prompts
# Perfect for automation
```

### Scenario 4: Air-Gapped Environment
```bash
# Download installer first
wget https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh

# Transfer to air-gapped system
# Run locally
sudo bash install.sh --verbose
```

---

## 📚 Next Steps

After successful installation:

1. **Access Dashboard**
   - Navigate to: `https://dashboard.your-domain.com`
   - View all services and metrics

2. **Configure Services**
   - Edit `.env` file in `/opt/vps2.0`
   - Restart services: `docker-compose restart`

3. **Set Up Monitoring**
   - Configure Grafana dashboards
   - Set up alerts in Uptime Kuma
   - Review logs in Dozzle

4. **Security Hardening**
   - Run: `/opt/vps2.0/scripts/harden.sh`
   - Configure WireGuard VPN
   - Set up Fail2ban rules

5. **Backup Configuration**
   - Run: `/opt/vps2.0/scripts/backup.sh`
   - Configure automated backups
   - Test restore procedures

6. **Scale Services**
   - Deploy intelligence services
   - Enable optional components
   - Configure load balancing

---

## 🆘 Getting Help

### Documentation
- Main Guide: [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- Dashboard Guide: [DASHBOARD_GUIDE.md](./DASHBOARD_GUIDE.md)
- Architecture: [STACK_ARCHITECTURE.md](./STACK_ARCHITECTURE.md)

### Support Channels
- GitHub Issues: https://github.com/SWORDIntel/VPS2.0/issues
- Documentation Wiki: https://github.com/SWORDIntel/VPS2.0/wiki

### Common Issues
- Port conflicts: Check existing services on ports 80, 443
- Docker socket: Ensure `/var/run/docker.sock` is accessible
- DNS resolution: Verify A records point to your server IP
- TLS certificates: Wait 60 seconds for Let's Encrypt

---

## 🔒 Security Considerations

### Before Installation
1. Update your system: `sudo apt update && sudo apt upgrade -y`
2. Configure SSH keys (disable password auth)
3. Set up firewall rules
4. Document your network topology

### During Installation
1. Use strong passwords (auto-generated recommended)
2. Note all credentials displayed
3. Save `.env` file securely
4. Verify TLS certificate generation

### After Installation
1. Run security hardening: `/opt/vps2.0/scripts/harden.sh`
2. Enable automatic updates
3. Set up monitoring and alerts
4. Review firewall rules
5. Configure backup encryption

---

## 📋 Installation Checklist

- [ ] System meets minimum requirements
- [ ] Domain DNS configured
- [ ] Firewall ports open (80, 443)
- [ ] Root/sudo access available
- [ ] Internet connectivity verified
- [ ] Run one-liner installer
- [ ] Complete setup wizard
- [ ] Verify all services running
- [ ] Access dashboard successfully
- [ ] Run security hardening
- [ ] Configure backups
- [ ] Set up monitoring alerts
- [ ] Document credentials securely

---

## 🎉 Success!

You're now running the VPS2.0 Intelligence Platform!

**Access Points:**
- Homepage: `https://your-domain.com`
- Dashboard: `https://dashboard.your-domain.com`
- Monitoring: `https://monitoring.your-domain.com`
- Status: `https://status.your-domain.com`

**TEMPEST Level C Compliant** 🛡️

---

**Version:** 1.0.0
**Last Updated:** 2025-11-18
**Status:** Production Ready
