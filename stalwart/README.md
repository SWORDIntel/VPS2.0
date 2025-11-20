# Stalwart Mail Server Configuration

This directory contains configuration files for the Stalwart mail server component of VPS2.0.

## Directory Structure

```
stalwart/
├── config/
│   └── config.toml          # Main Stalwart configuration
├── ssl/
│   ├── fullchain.pem        # TLS certificate (auto-generated)
│   ├── privkey.pem          # TLS private key (auto-generated)
│   └── dkim.key             # DKIM signing key (generated on setup)
├── README.md                # This file
└── scripts/
    └── generate-dkim.sh     # DKIM key generation script
```

## First-Time Setup

### 1. Generate DKIM Keys

DKIM (DomainKeys Identified Mail) is required for email authentication and deliverability.

```bash
cd stalwart/scripts
./generate-dkim.sh swordintelligence.airforce
```

This will generate:
- `stalwart/ssl/dkim.key` - Private key for signing outbound mail
- `dkim.txt` - DNS TXT record to publish

### 2. Publish DKIM DNS Record

Add the generated DKIM record to your DNS:

```dns
default._domainkey.swordintelligence.airforce. IN TXT "v=DKIM1; k=rsa; p=YOUR_PUBLIC_KEY"
```

The full record is in `stalwart/ssl/dkim.txt`

### 3. Configure TLS Certificates

Stalwart needs TLS certificates for secure SMTP/IMAP.

**Option A: Use Caddy-generated certificates** (Recommended)
```bash
# Copy certificates from Caddy's managed certs
sudo cp /path/to/caddy/certificates/mail.swordintelligence.airforce/fullchain.pem stalwart/ssl/
sudo cp /path/to/caddy/certificates/mail.swordintelligence.airforce/privkey.pem stalwart/ssl/
```

**Option B: Generate with Certbot**
```bash
certbot certonly --standalone -d mail.swordintelligence.airforce
sudo cp /etc/letsencrypt/live/mail.swordintelligence.airforce/fullchain.pem stalwart/ssl/
sudo cp /etc/letsencrypt/live/mail.swordintelligence.airforce/privkey.pem stalwart/ssl/
```

**Option C: Self-signed (Development Only)**
```bash
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout stalwart/ssl/privkey.pem \
  -out stalwart/ssl/fullchain.pem \
  -days 365 \
  -subj "/CN=mail.swordintelligence.airforce"
```

### 4. Create Initial Admin User

After starting Stalwart, create the first admin user:

```bash
# Method 1: Via Docker exec
docker exec -it stalwart stalwart-cli account create \
  --email admin@swordintelligence.airforce \
  --password "YourSecurePassword" \
  --name "Administrator" \
  --quota 10G

# Method 2: Via HTTP API
curl -X POST http://localhost:8080/api/v1/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@swordintelligence.airforce",
    "password": "YourSecurePassword",
    "name": "Administrator",
    "quota": 10737418240
  }'
```

### 5. Verify Configuration

Check that Stalwart is running correctly:

```bash
# Check SMTP
telnet mail.swordintelligence.airforce 25

# Check IMAP
openssl s_client -connect mail.swordintelligence.airforce:993

# Check admin UI
curl http://localhost:8080/health

# Check metrics
curl http://localhost:8080/metrics
```

## DNS Requirements

### Required DNS Records

For production email, you **must** configure these DNS records:

#### 1. MX Record
```dns
swordintelligence.airforce. IN MX 10 mail.swordintelligence.airforce.
mail.swordintelligence.airforce. IN A YOUR_SERVER_IP
```

#### 2. SPF Record
```dns
swordintelligence.airforce. IN TXT "v=spf1 mx -all"
```

#### 3. DKIM Record
```dns
default._domainkey.swordintelligence.airforce. IN TXT "v=DKIM1; k=rsa; p=YOUR_PUBLIC_KEY"
```

#### 4. DMARC Record
```dns
_dmarc.swordintelligence.airforce. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@swordintelligence.airforce; ruf=mailto:dmarc-reports@swordintelligence.airforce; fo=1"
```

#### 5. MTA-STS Record
```dns
_mta-sts.swordintelligence.airforce. IN TXT "v=STSv1; id=20250120"
```

#### 6. TLS-RPT Record
```dns
_smtp._tls.swordintelligence.airforce. IN TXT "v=TLSRPTv1; rua=mailto:tls-reports@swordintelligence.airforce"
```

See `docs/EMAIL_DNS_EXAMPLES.md` for complete examples with Njalla DNS configuration.

## Security Hardening

### Firewall Rules

Ensure these ports are open:

```bash
# SMTP (receiving mail from other servers)
ufw allow 25/tcp

# Submission (authenticated users sending mail)
ufw allow 587/tcp
ufw allow 465/tcp

# IMAP (users reading mail)
ufw allow 993/tcp

# ManageSieve (users managing filters)
ufw allow 4190/tcp

# Admin UI (internal only - use VPN or SSH tunnel)
# DO NOT expose to internet
```

### Rate Limiting

Stalwart includes built-in rate limiting:
- Outbound: 100 messages/hour, 500 recipients/hour per user
- Inbound: 50 messages/hour, 10 connections/minute per IP

Adjust in `config/config.toml` under `[rate-limit]`

### Spam Protection

Stalwart includes:
- DNS blocklists (Spamhaus, SpamCop, SORBS)
- Greylisting
- Bayesian filtering
- Sender reputation tracking
- Phishing detection

## Monitoring

### Prometheus Metrics

Stalwart exports metrics at `http://stalwart:8080/metrics`

Key metrics:
- `stalwart_smtp_messages_received_total` - Incoming messages
- `stalwart_smtp_messages_sent_total` - Outgoing messages
- `stalwart_smtp_messages_rejected_total` - Rejected messages (spam, policy)
- `stalwart_smtp_queue_size` - Messages in queue
- `stalwart_imap_connections_active` - Active IMAP connections
- `stalwart_storage_size_bytes` - Mailbox storage usage

### Grafana Dashboard

Import the pre-built dashboard:
```bash
cat grafana/dashboards/email-monitoring.json
```

### Logs

Structured JSON logs are shipped to Loki via Vector.

Query mail logs in Grafana:
```logql
{container_name="stalwart"} | json
```

Filter by event type:
```logql
{container_name="stalwart"} | json | action="reject"
{container_name="stalwart"} | json | spam_score > 5
```

## Troubleshooting

### Mail Not Sending

1. Check DNS records: `dig MX swordintelligence.airforce`
2. Check SPF: `dig TXT swordintelligence.airforce`
3. Check DKIM: `dig TXT default._domainkey.swordintelligence.airforce`
4. Check queue: `docker exec stalwart stalwart-cli queue list`
5. Check logs: `docker logs stalwart --tail 100`

### Mail Being Marked as Spam

1. Verify DKIM signing is working
2. Check DMARC alignment
3. Verify reverse DNS (PTR record)
4. Test with mail-tester.com
5. Check IP reputation on MXToolbox

### Admin UI Not Accessible

Admin UI is **VPN-only** for security. Access via:
- WireGuard VPN: Connect first, then visit `https://mailadmin.swordintelligence.airforce`
- SSH tunnel: `ssh -L 8080:localhost:8080 user@server`
- From internal networks: Docker networks in 172.x.x.x range

### Performance Issues

1. Check database size: `du -sh /opt/stalwart-mail/data/`
2. Vacuum database: `docker exec stalwart stalwart-cli vacuum`
3. Check queue depth: `docker exec stalwart stalwart-cli queue stats`
4. Review Prometheus metrics for bottlenecks

## Maintenance

### Backup

Critical data to backup:
```bash
# Mailbox data
/var/lib/docker/volumes/stalwart_data/

# Configuration
/home/user/VPS2.0/stalwart/config/

# DKIM keys
/home/user/VPS2.0/stalwart/ssl/dkim.key
```

### Updates

Update Stalwart:
```bash
docker-compose -f docker-compose.yml -f docker-compose.email.yml pull stalwart
docker-compose -f docker-compose.yml -f docker-compose.email.yml up -d stalwart
```

### Database Maintenance

Run weekly vacuum:
```bash
docker exec stalwart stalwart-cli vacuum
```

Or enable automatic vacuum in `config.toml`:
```toml
[maintenance]
vacuum-schedule = "0 2 * * 0"  # Every Sunday at 2 AM
```

## Additional Resources

- [Stalwart Documentation](https://stalw.art/docs/)
- [DKIM Guide](https://dkim.org/)
- [DMARC Guide](https://dmarc.org/)
- [Email Deliverability Best Practices](https://www.m3aawg.org/)

## Support

For VPS2.0-specific issues:
- GitHub: https://github.com/SWORDIntel/VPS2.0/issues

For Stalwart issues:
- GitHub: https://github.com/stalwartlabs/mail-server/issues
- Discord: https://discord.gg/stalwart
