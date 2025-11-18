# VPS2.0 Deployment Script Enhancements

## Overview

The unified deployment script (`deploy-vps2.sh`) has been comprehensively polished and hardened with enterprise-grade error handling, security features, and operational capabilities.

## Major Enhancements

### 1. **Comprehensive Error Handling**

#### Error Traps
```bash
trap 'cleanup_on_error ${LINENO}' ERR
trap 'cleanup_on_exit' EXIT
```

- **ERR Trap**: Captures any command failure, logs line number and exit code
- **EXIT Trap**: Ensures state is saved on exit (normal or abnormal)
- **Inheritance**: `set -E` ensures traps work in functions and subshells

#### Cleanup Functions
- Automatic error logging to both console and log files
- User-friendly error messages with log file references
- Audit trail of all failures for post-mortem analysis

### 2. **Audit Logging System**

All deployment operations are logged to two files:

#### `.deployment.log` - Technical Operations Log
- All command outputs (stdout/stderr)
- Timestamp, operation, and status for each action
- Used for troubleshooting technical issues

#### `.deployment-audit.log` - Security Audit Trail
- Timestamp, user (SUDO_USER), level, and action
- Immutable record of who did what and when
- Compliance-ready audit trail

Example audit entry:
```
[2025-11-18 21:14:32] [INFO] [admin] Starting core services deployment
[2025-11-18 21:15:45] [SUCCESS] [admin] Core services deployment completed
```

### 3. **Enhanced Prerequisite Checks**

#### New Validations Added
- **Docker Version Check**: Warns if < 20.10.0
- **Docker Seccomp**: Verifies security profile is enabled
- **Port Availability**: Checks 80, 443, 5432, 6379, 7687, 9000
- **Internet Connectivity**: Pings 8.8.8.8 to verify network
- **Required Commands**: curl, wget, openssl, sed, awk, grep
- **CPU Cores**: Recommends 4+ cores, warns if less
- **Detailed Resource Checks**:
  - Disk: Error if < 50GB, warn if < 100GB
  - RAM: Error if < 8GB, warn if < 16GB

#### Output Improvements
- Color-coded status (green=good, yellow=warning, red=error)
- Summary with warning count
- Fails fast on critical issues, continues with warnings

### 4. **Container Health Verification**

#### `verify_container_health()`
```bash
verify_container_health "postgres" 60  # 60 second timeout
```

Features:
- Polls Docker healthcheck status every 5 seconds
- Supports: `healthy`, `unhealthy`, `starting`, `no-healthcheck`
- Automatic timeout after specified duration
- Logs container output on failure
- Audit log entry for each verification

#### `verify_service_endpoint()`
```bash
verify_service_endpoint "https://example.com/health" "My Service"
```

Features:
- HTTP/HTTPS endpoint verification with curl
- 5 retries with 3-second delays
- Graceful failure (warns but doesn't block)
- Useful for verifying external access

### 5. **Rollback Capability**

#### Deployment Snapshots
```bash
create_deployment_snapshot "core"  # Before deploying core services
```

- Captures docker-compose state before changes
- Stores snapshot reference in state file
- Enables easy recovery from failed deployments

#### Rollback Functionality
```bash
rollback_deployment "core"         # Rollback core services
rollback_deployment "mattermost"   # Rollback Mattermost
rollback_deployment "polygotya"    # Rollback POLYGOTYA
```

Features:
- Stops and removes containers
- Preserves data in Docker volumes
- Updates deployment state
- Audit log of rollback action

#### Rollback Menu (Main Menu Option 8)
Interactive menu for rolling back failed deployments:
1. Rollback Core Services
2. Rollback Mattermost
3. Rollback POLYGOTYA
4. View Deployment State

### 6. **Comprehensive Security Hardening**

Complete security hardening menu with 8 options:

#### Option 1: Full Hardening (All Options)
Runs all security hardening steps in sequence.

#### Option 2: Kernel Parameter Hardening
**File**: `/etc/sysctl.d/99-vps2-hardening.conf`

Network Security:
- Reverse path filtering (rp_filter)
- Disable source routing
- Disable ICMP redirects
- SYN cookie protection
- Ignore bogus ICMP errors

System Security:
- Restrict dmesg access
- Hide kernel pointers (kptr_restrict = 2)
- Restrict ptrace (yama.ptrace_scope = 1)
- Protected hardlinks and symlinks

Performance:
- Increased connection queue (somaxconn = 4096)
- SYN backlog optimization
- Reduced swappiness for better RAM usage

#### Option 3: Firewall Configuration (UFW)
**Default Policy**: Deny all incoming, allow all outgoing

Allowed Ports:
- 22/tcp (SSH)
- 80/tcp (HTTP)
- 443/tcp (HTTPS)

Features:
- Automatic UFW installation if missing
- Safe confirmation before enabling
- Warning about SSH access

#### Option 4: SSH Hardening
**File**: `/etc/ssh/sshd_config` (appended)

Configuration:
```
PermitRootLogin prohibit-password
PasswordAuthentication no
ChallengeResponseAuthentication no
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 60
```

Features:
- Disables password authentication (key-only)
- Limits root login to key authentication
- Session timeouts and limits
- Automatic backup of original config
- Safe restart confirmation

**⚠ WARNING**: Requires SSH key authentication to be set up first!

#### Option 5: Docker Security Hardening
**File**: `/etc/docker/daemon.json`

Configuration:
```json
{
  "icc": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true
}
```

Features:
- **icc: false**: Disables inter-container communication by default
- **Log limits**: 10MB per file, 3 files maximum
- **live-restore**: Containers survive Docker daemon restart
- **no-new-privileges**: Prevents privilege escalation
- Automatic backup of existing config
- Safe restart confirmation

#### Option 6: Install Fail2ban
**File**: `/etc/fail2ban/jail.local`

Configuration:
```
[DEFAULT]
bantime = 3600      # 1 hour ban
findtime = 600      # 10 minute window
maxretry = 5        # 5 failures = ban

[sshd]
enabled = true
port = 22
```

Features:
- Automatic installation if not present
- SSH brute-force protection
- Configurable ban duration and thresholds
- Auto-starts on boot

#### Option 7: Setup Audit Logging
**File**: `/etc/audit/rules.d/docker.rules`

Monitored Files/Commands:
- `/usr/bin/dockerd` (Docker daemon)
- `/usr/bin/docker` (Docker CLI)
- `/var/lib/docker` (Docker data directory)
- `/etc/docker` (Docker configuration)
- `docker.service` and `docker.socket`
- `/usr/local/bin/docker-compose`
- Container runtimes (containerd, runc)

Features:
- System-level audit logging (auditd)
- Tracks all Docker operations
- Compliance-ready audit trail
- Searchable with `ausearch -k docker`

#### Option 8: View Current Security Status
Shows current state of:
- UFW firewall status and rules
- Fail2ban status and jails
- Docker security options

### 7. **Timeout Handling**

#### `execute_cmd()` Function
```bash
execute_cmd "docker-compose up -d" "Deploy service" 120
```

Features:
- Wraps commands with timeout (default: 300s)
- Logs command output to `.deployment.log`
- Captures exit code and logs success/failure
- Audit log entry for each command

Used throughout deployment:
- Docker Compose operations: 60-600s timeout
- Health checks: 60-90s timeout
- Service endpoints: 5s per retry

### 8. **Enhanced Deployment Functions**

#### Core Services Deployment
Before:
- Sequential deployment with fixed sleeps
- No health verification
- No error recovery

After:
- Snapshot before deployment
- Execute with timeout handling
- Health verification after each service
- Critical services (postgres, caddy) trigger rollback on failure
- Non-critical services (grafana, portainer) log warnings but continue
- Final health check of all services

#### Mattermost & POLYGOTYA Deployments
Similar enhancements:
- Snapshot before deployment
- Timeout-protected execution
- Health verification
- Audit logging
- Component-specific rollback on failure

### 9. **State Management**

#### State File: `.deployment-state`
Tracks:
- Domain configuration
- Component selection (mattermost, polygotya, dnshub)
- Deployment status (deployed_core, deployed_mattermost, etc.)
- Credential generation status
- Last run timestamp
- Snapshot references

#### Functions
- `save_state key value` - Persists state
- `load_state key [default]` - Retrieves state
- `get_deployment_status component` - Check if deployed

### 10. **Enhanced Main Menu**

New menu structure (10 options):
1. Fresh Installation (Guided Setup)
2. Add Components
3. Remove Components
4. Update/Upgrade Services (with audit logging)
5. Backup & Restore
6. System Status
7. Security Hardening (comprehensive menu)
8. **Rollback Failed Deployment** (NEW)
9. Configuration
10. Show Deployment Summary

## Security Features Summary

### Authentication & Access Control
- ✅ SSH key-only authentication (no passwords)
- ✅ Root login restricted to keys
- ✅ Fail2ban brute-force protection
- ✅ Session limits and timeouts

### Network Security
- ✅ UFW firewall (default deny)
- ✅ Kernel-level packet filtering
- ✅ SYN flood protection
- ✅ ICMP redirect protection
- ✅ Source routing disabled

### Container Security
- ✅ Inter-container communication disabled
- ✅ No new privileges flag
- ✅ Seccomp security profiles
- ✅ Log size limits (prevents DoS)
- ✅ No userland proxy

### Auditing & Compliance
- ✅ System audit logging (auditd)
- ✅ Deployment audit log
- ✅ Docker operation tracking
- ✅ User attribution (SUDO_USER)
- ✅ Timestamp on all actions

### System Hardening
- ✅ Kernel pointer hiding
- ✅ Ptrace restrictions
- ✅ Protected symlinks/hardlinks
- ✅ Dmesg restrictions
- ✅ Optimized swappiness

## Error Recovery Features

### Automatic Recovery
1. **ERR Trap**: Catches failures, logs details
2. **Rollback on Critical Failures**: postgres/caddy failures trigger automatic rollback
3. **Health Checks**: Detect unhealthy containers immediately
4. **Timeouts**: Prevent hanging operations

### Manual Recovery
1. **Rollback Menu**: Interactive rollback of any component
2. **View Deployment State**: See what's deployed
3. **System Status**: Comprehensive health check
4. **Log Files**: Detailed troubleshooting information

### Data Protection
- Docker volumes preserved during rollback
- Configuration files backed up before modification
- Deployment state tracked and persisted
- Snapshots before major changes

## Usage Examples

### Fresh Installation with Full Hardening
```bash
sudo ./deploy-vps2.sh
# Select: 1 (Fresh Installation)
# Follow prompts...
# After deployment:
# Select: 7 (Security Hardening)
# Select: 1 (Full Hardening)
```

### Recover from Failed Deployment
```bash
sudo ./deploy-vps2.sh
# Select: 8 (Rollback Failed Deployment)
# Select: 1 (Rollback Core Services)
# Confirm rollback
# Then retry deployment
```

### Audit Trail Review
```bash
# View deployment operations
cat .deployment.log | tail -100

# View security audit trail
cat .deployment-audit.log | grep ERROR

# View specific user's actions
cat .deployment-audit.log | grep "\[admin\]"
```

### Verify Security Hardening
```bash
sudo ./deploy-vps2.sh
# Select: 7 (Security Hardening)
# Select: 8 (View Current Security Status)
```

## Log Files

### `.deployment.log`
- All command outputs
- Technical details
- Error stack traces
- Used for debugging

### `.deployment-audit.log`
- Who did what, when
- Success/failure of operations
- Compliance audit trail
- User attribution

### `.deployment-state`
- Current deployment configuration
- Component selection
- Deployment status
- Persistent across runs

## Best Practices

### Before Deployment
1. ✅ Ensure SSH key authentication is configured
2. ✅ Have backup access method (console/KVM)
3. ✅ Review system requirements (8GB+ RAM, 50GB+ disk)
4. ✅ Check port availability

### During Deployment
1. ✅ Monitor for errors in real-time
2. ✅ Watch health checks complete
3. ✅ Don't interrupt critical operations
4. ✅ Save credentials from .env file

### After Deployment
1. ✅ Run security hardening (Option 7 → Option 1)
2. ✅ Verify all services with status check
3. ✅ Configure automated backups
4. ✅ Test service access
5. ✅ Review audit logs

### Security Hardening Order
1. Kernel parameters (always safe)
2. Firewall (ensure SSH works first!)
3. Docker security (brief downtime)
4. Fail2ban (always safe)
5. Audit logging (always safe)
6. SSH hardening (LAST - ensure keys work!)

## Troubleshooting

### Deployment Fails
1. Check `.deployment.log` for error details
2. Check `.deployment-audit.log` for operation sequence
3. Use "Rollback Failed Deployment" menu option
4. Retry deployment after fixing issue

### Health Check Timeouts
- Increase timeout in function call
- Check container logs: `docker logs <container>`
- Verify resource availability (RAM, disk)
- Check network connectivity

### Rollback Needed
1. Main Menu → Option 8 (Rollback Failed Deployment)
2. Select component to rollback
3. Confirm rollback
4. Fix underlying issue
5. Retry deployment

### Push to GitHub Failed
- GitHub experiencing issues (502/500 errors)
- All work safely committed locally
- Manual push: `git push origin claude/plan-vps-stack-01MzBY7jHaQd3sbbAkUjuqx2`
- Work will not be lost

## Conclusion

The deployment script now provides enterprise-grade reliability with:
- ✅ Comprehensive error handling and recovery
- ✅ Full audit trail for compliance
- ✅ Security hardening capabilities
- ✅ Health verification at every step
- ✅ Easy rollback on failures
- ✅ Detailed logging for troubleshooting

All enhancements maintain backward compatibility while significantly improving robustness, security, and operational capabilities.
