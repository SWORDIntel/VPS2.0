# VPS2.0 Email Module - Quick Start Guide

This guide will help you deploy and configure the VPS2.0 email module in under 30 minutes.

## Prerequisites

- VPS2.0 core services installed and running
- Valid domain name (e.g., `swordintelligence.airforce`)
- DNS management access (Njalla recommended)
- Access to VPS hosting provider for PTR record configuration
- Minimum 2GB RAM available for email services

## Quick Deployment

### Option 1: Fresh Installation (Email Included)

If you're deploying VPS2.0 from scratch:

```bash
cd /path/to/VPS2.0
sudo ./deploy-vps2.sh
```

Select **Fresh Installation** and choose **Yes** when prompted for the Email Module.

### Option 2: Add to Existing VPS2.0

If you already have VPS2.0 running:

```bash
cd /path/to/VPS2.0
sudo ./deploy-vps2.sh
```

Select **Add Components** → **Email Module (Stalwart + SnappyMail)**

## Post-Deployment Configuration (CRITICAL)

### Step 1: Configure DNS Records (5 minutes)

Email **will not work** without proper DNS configuration.

#### Minimum Required Records (Njalla):

Log in to Njalla → Select your domain → DNS Records:

```
1. A Record
   Type: A
   Name: mail
   Value: YOUR_SERVER_IP
   TTL: 3600

2. MX Record
   Type: MX
   Name: @
   Priority: 10
   Value: mail.swordintelligence.airforce
   TTL: 3600

3. SPF Record
   Type: TXT
   Name: @
   Value: v=spf1 mx -all
   TTL: 3600

4. DKIM Record (get from: cat stalwart/ssl/dkim.txt)
   Type: TXT
   Name: default._domainkey
   Value: v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w...
   TTL: 3600

5. DMARC Record
   Type: TXT
   Name: _dmarc
   Value: v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@swordintelligence.airforce
   TTL: 3600

6. Webmail subdomain
   Type: A
   Name: spiderwebmail
   Value: YOUR_SERVER_IP
   TTL: 3600
```

#### Verify DNS Propagation:

```bash
# Wait 5-15 minutes, then check:
dig MX swordintelligence.airforce +short
dig A mail.swordintelligence.airforce +short
dig TXT default._domainkey.swordintelligence.airforce +short
dig TXT _dmarc.swordintelligence.airforce +short
```

### Step 2: Set Reverse DNS / PTR Record (2 minutes)

**CRITICAL:** Contact your VPS provider to set the PTR record.

**Example (DigitalOcean):**
- Go to Networking → Droplets → Your VPS → Edit → Set hostname to `mail.swordintelligence.airforce`

**Example (Vultr):**
- Go to Settings → IPv4 → Set Reverse DNS to `mail.swordintelligence.airforce`

**Verify:**
```bash
dig -x YOUR_SERVER_IP +short
# Should return: mail.swordintelligence.airforce.
```

Without PTR, **90% of mail servers will reject your email!**

### Step 3: Create First Email Account (1 minute)

```bash
# Create admin account
docker exec -it stalwart stalwart-cli account create \
  --email admin@swordintelligence.airforce \
  --password "$(openssl rand -base64 24)" \
  --name "Administrator" \
  --quota 10G

# The password will be displayed - save it!
```

Or use a custom password:

```bash
docker exec -it stalwart stalwart-cli account create \
  --email admin@swordintelligence.airforce \
  --password "YourSecurePassword123!" \
  --name "Administrator" \
  --quota 10G
```

### Step 4: Access Webmail (30 seconds)

Open your browser:

```
https://spiderwebmail.swordintelligence.airforce
```

Login with:
- **Email:** `admin@swordintelligence.airforce`
- **Password:** (password from Step 3)

You should see the **TEMPEST Class C themed webmail interface**.

## Testing Email Delivery

### Test 1: Send Test Email

From the webmail interface, compose an email to: `check-auth@verifier.port25.com`

Port25 will reply with a detailed authentication report showing:
- ✅ SPF: pass
- ✅ DKIM: pass
- ✅ DMARC: pass
- ✅ Reverse DNS: pass

### Test 2: Check Spam Score

Send an email to yourself at a Gmail/Outlook account and check:
- Does it arrive in Inbox (not spam)?
- Does Gmail show "signed by swordintelligence.airforce"?

### Test 3: Mail-Tester

1. Go to: https://www.mail-tester.com/
2. Copy the provided test email address
3. Send an email from your webmail to that address
4. Check score (aim for 10/10)

## Troubleshooting

### Problem: Mail not sending

**Solution:**
```bash
# Check queue
docker exec stalwart stalwart-cli queue list

# Check logs
docker logs stalwart --tail 100

# Verify DNS
dig MX swordintelligence.airforce
dig TXT default._domainkey.swordintelligence.airforce
```

### Problem: Mail going to spam

**Checklist:**
- ✅ SPF record published?
- ✅ DKIM record published? (check stalwart/ssl/dkim.txt)
- ✅ DMARC record published?
- ✅ PTR record set by hosting provider?
- ✅ DKIM signing enabled in Stalwart? (check logs)

**Verify DKIM signing:**
```bash
docker logs stalwart | grep -i dkim
```

### Problem: Cannot access webmail

**Solution:**
```bash
# Check if SnappyMail is running
docker ps | grep snappymail

# Check logs
docker logs snappymail

# Verify Caddy routing
docker logs caddy | grep spiderwebmail

# Check DNS
dig spiderwebmail.swordintelligence.airforce
```

### Problem: Admin UI not accessible

Admin UI is **VPN-only** for security. Access via:

1. **WireGuard VPN** (if deployed):
   ```
   Connect to VPN first
   Then: https://mailadmin.swordintelligence.airforce
   ```

2. **SSH Tunnel:**
   ```bash
   ssh -L 8080:localhost:8080 user@YOUR_SERVER_IP
   # Then visit: http://localhost:8080
   ```

3. **From server:**
   ```bash
   curl http://localhost:8080/health
   ```

## Common Operations

### Create New Email Account

```bash
docker exec -it stalwart stalwart-cli account create \
  --email user@swordintelligence.airforce \
  --password "SecurePassword123!" \
  --name "User Name" \
  --quota 5G
```

### List All Accounts

```bash
docker exec -it stalwart stalwart-cli account list
```

### Delete Account

```bash
docker exec -it stalwart stalwart-cli account delete user@swordintelligence.airforce
```

### Change Password

```bash
docker exec -it stalwart stalwart-cli account password \
  --email user@swordintelligence.airforce \
  --password "NewPassword123!"
```

### Check Disk Usage

```bash
docker exec -it stalwart stalwart-cli storage stats
```

### View Mail Queue

```bash
# List queued messages
docker exec -it stalwart stalwart-cli queue list

# Show queue statistics
docker exec -it stalwart stalwart-cli queue stats

# Clear queue (dangerous!)
docker exec -it stalwart stalwart-cli queue clear
```

### Backup Email Data

```bash
# Stop services
docker-compose -f docker-compose.yml -f docker-compose.email.yml stop

# Backup volumes
docker run --rm \
  -v stalwart_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/stalwart-$(date +%Y%m%d).tar.gz /data

# Restart services
docker-compose -f docker-compose.yml -f docker-compose.email.yml up -d
```

## Monitoring & Metrics

### View Email Metrics (Prometheus)

```
http://YOUR_SERVER_IP:8428  # VictoriaMetrics
```

Key metrics:
- `stalwart_smtp_messages_received_total` - Incoming messages
- `stalwart_smtp_messages_sent_total` - Outgoing messages
- `stalwart_smtp_messages_rejected_total` - Rejected (spam/policy)
- `stalwart_smtp_queue_size` - Messages in queue

### View Logs (Loki/Grafana)

```
https://grafana.swordintelligence.airforce
```

Query:
```logql
{container_name="stalwart"} | json
```

Filter spam rejections:
```logql
{container_name="stalwart"} | json | action="reject"
```

## Security Best Practices

### 1. Change Default Admin Password

```bash
docker exec -it stalwart stalwart-cli account password \
  --email admin@swordintelligence.airforce \
  --password "$(openssl rand -base64 32)"
```

### 2. Enable Firewall Rules

```bash
# Allow mail ports
ufw allow 25/tcp    # SMTP (MX)
ufw allow 587/tcp   # Submission
ufw allow 465/tcp   # Submissions
ufw allow 993/tcp   # IMAPS
```

### 3. Monitor for Abuse

```bash
# Check for suspicious activity
docker logs stalwart | grep -E "reject|spam|abuse"

# Monitor outbound rate
docker exec stalwart stalwart-cli queue stats
```

### 4. Rotate DKIM Keys Annually

```bash
cd stalwart/scripts
./generate-dkim.sh swordintelligence.airforce

# Update DNS with new public key from stalwart/ssl/dkim.txt
# Wait for DNS propagation
# Restart Stalwart

docker-compose -f docker-compose.yml -f docker-compose.email.yml restart stalwart
```

## Advanced Configuration

### Add Multiple Domains

Edit `stalwart/config/config.toml` to add domains, then generate DKIM keys and DNS records for each domain.

See: `docs/EMAIL_DNS_EXAMPLES.md` → "Multiple Domains" section

### Integrate with External Authentication (LDAP)

Edit `stalwart/config/config.toml`:

```toml
[auth]
type = "ldap"
url = "ldap://ldap.example.com"
bind_dn = "cn=admin,dc=example,dc=com"
bind_password = "password"
base_dn = "ou=users,dc=example,dc=com"
```

### Enable Rspamd (Advanced Spam Filtering)

Uncomment milter section in `stalwart/config/config.toml` and deploy Rspamd container.

## Support & Documentation

- **Full Setup Guide:** `stalwart/README.md`
- **DNS Examples:** `docs/EMAIL_DNS_EXAMPLES.md`
- **Stalwart Docs:** https://stalw.art/docs/
- **VPS2.0 Issues:** https://github.com/SWORDIntel/VPS2.0/issues

## Quick Reference

**Access Points:**
- Webmail: `https://spiderwebmail.swordintelligence.airforce`
- Admin UI: `https://mailadmin.swordintelligence.airforce` (VPN only)
- SMTP: `mail.swordintelligence.airforce:587` (STARTTLS)
- IMAPS: `mail.swordintelligence.airforce:993`

**Important Files:**
- Main config: `stalwart/config/config.toml`
- DKIM key: `stalwart/ssl/dkim.key`
- DNS record: `stalwart/ssl/dkim.txt`
- Theme: `snappymail/config/custom-theme.css`

**Docker Commands:**
```bash
# Start email services
docker-compose -f docker-compose.yml -f docker-compose.email.yml up -d

# Stop email services
docker-compose -f docker-compose.yml -f docker-compose.email.yml stop

# View logs
docker logs stalwart --follow
docker logs snappymail --follow

# Restart services
docker-compose -f docker-compose.yml -f docker-compose.email.yml restart
```

---

**Next Steps:**
1. ✅ Deploy email module
2. ✅ Configure DNS (MX, SPF, DKIM, DMARC, PTR)
3. ✅ Create email accounts
4. ✅ Test delivery with mail-tester.com
5. 📧 Start using your self-hosted email!
