# Email DNS Configuration Examples

Complete DNS configuration guide for VPS2.0 Email Module with production-ready examples for Njalla and other DNS providers.

## Table of Contents

1. [Required DNS Records Overview](#required-dns-records-overview)
2. [Basic Records (MX, A, PTR)](#basic-records-mx-a-ptr)
3. [Authentication (SPF, DKIM, DMARC)](#authentication-spf-dkim-dmarc)
4. [Modern Standards (MTA-STS, TLS-RPT, DANE)](#modern-standards-mta-sts-tls-rpt-dane)
5. [Njalla Configuration](#njalla-configuration)
6. [Verification & Testing](#verification--testing)

---

## Required DNS Records Overview

For production email with VPS2.0, you **MUST** configure these DNS records:

| Record Type | Purpose | Priority |
|------------|---------|----------|
| **A / AAAA** | Mail server IP address | Critical |
| **MX** | Mail routing | Critical |
| **PTR** | Reverse DNS (ISP/hosting provider) | Critical |
| **SPF** | Sender authentication | Critical |
| **DKIM** | Message signing | Critical |
| **DMARC** | Policy enforcement | Critical |
| **MTA-STS** | TLS enforcement | Recommended |
| **TLS-RPT** | TLS reporting | Recommended |
| **DANE/TLSA** | Certificate authentication | Optional |

---

## Basic Records (MX, A, PTR)

### A Record (IPv4)

Points the mail hostname to your server's IPv4 address.

```dns
; Standard zone file format
mail.swordintelligence.airforce. 3600 IN A 203.0.113.10

; Njalla interface format
Type: A
Name: mail
Value: 203.0.113.10
TTL: 3600
```

### AAAA Record (IPv6)

If you have IPv6, add an AAAA record:

```dns
; Standard zone file format
mail.swordintelligence.airforce. 3600 IN AAAA 2001:db8::10

; Njalla interface format
Type: AAAA
Name: mail
Value: 2001:db8::10
TTL: 3600
```

### MX Record

Specifies mail server for the domain. Priority 10 is standard.

```dns
; Standard zone file format
swordintelligence.airforce. 3600 IN MX 10 mail.swordintelligence.airforce.

; Njalla interface format
Type: MX
Name: @
Priority: 10
Value: mail.swordintelligence.airforce
TTL: 3600
```

**Multiple MX Records (Backup)**

For high availability, add a backup mail server:

```dns
swordintelligence.airforce. 3600 IN MX 10 mail.swordintelligence.airforce.
swordintelligence.airforce. 3600 IN MX 20 backup-mail.swordintelligence.airforce.
```

Lower priority number = higher priority (10 is checked before 20).

### PTR Record (Reverse DNS)

**CRITICAL:** PTR records are managed by your **ISP or hosting provider**, not in your DNS zone.

Contact your VPS provider (e.g., DigitalOcean, Vultr, Hetzner) to set:

```
203.0.113.10 → mail.swordintelligence.airforce
```

**Verification:**
```bash
dig -x 203.0.113.10 +short
# Should return: mail.swordintelligence.airforce.
```

**Without a correct PTR record, many mail servers will reject your mail!**

---

## Authentication (SPF, DKIM, DMARC)

### SPF (Sender Policy Framework)

Specifies which servers can send email for your domain.

**Basic SPF (only MX servers can send):**

```dns
; Standard zone file format
swordintelligence.airforce. 3600 IN TXT "v=spf1 mx -all"

; Njalla interface format
Type: TXT
Name: @
Value: v=spf1 mx -all
TTL: 3600
```

**SPF with Multiple Sources:**

If you also send email via external services:

```dns
; Include Google Workspace and your mail server
swordintelligence.airforce. IN TXT "v=spf1 mx include:_spf.google.com -all"

; Include specific IP addresses
swordintelligence.airforce. IN TXT "v=spf1 mx ip4:203.0.113.10 ip6:2001:db8::10 -all"

; Include another domain's SPF
swordintelligence.airforce. IN TXT "v=spf1 mx include:spf.example.com -all"
```

**SPF Qualifiers:**

- `+all` - Allow all (NOT recommended, reduces security)
- `~all` - Soft fail (allow but mark as suspicious)
- `-all` - Hard fail (reject) - **RECOMMENDED for security**
- `?all` - Neutral (no policy)

**Recommended production SPF:**

```
v=spf1 mx -all
```

### DKIM (DomainKeys Identified Mail)

Cryptographically signs outbound email to prove authenticity.

**Generate DKIM Keys:**

```bash
cd /home/user/VPS2.0/stalwart/scripts
./generate-dkim.sh swordintelligence.airforce
```

This generates:
- `stalwart/ssl/dkim.key` - Private key (keep secret!)
- `stalwart/ssl/dkim.txt` - Public key DNS record

**DKIM DNS Record:**

```dns
; Standard zone file format (from dkim.txt)
default._domainkey.swordintelligence.airforce. 3600 IN TXT "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."

; Njalla interface format
Type: TXT
Name: default._domainkey
Value: v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
TTL: 3600
```

**IMPORTANT:**
- The public key string will be very long (~400 characters)
- Some DNS providers split long TXT records into multiple strings
- Test with `dig TXT default._domainkey.swordintelligence.airforce`

**Multiple DKIM Selectors:**

For key rotation or different signing policies:

```dns
default._domainkey.swordintelligence.airforce. IN TXT "v=DKIM1; k=rsa; p=KEY1..."
mail._domainkey.swordintelligence.airforce. IN TXT "v=DKIM1; k=rsa; p=KEY2..."
2025._domainkey.swordintelligence.airforce. IN TXT "v=DKIM1; k=rsa; p=KEY3..."
```

Update selector in `stalwart/config/config.toml`:
```toml
[smtp.dkim]
selector = "2025"
```

### DMARC (Domain-based Message Authentication)

Policy for handling SPF/DKIM failures.

**Basic DMARC (Monitoring Mode):**

```dns
; Standard zone file format
_dmarc.swordintelligence.airforce. 3600 IN TXT "v=DMARC1; p=none; rua=mailto:dmarc-reports@swordintelligence.airforce"

; Njalla interface format
Type: TXT
Name: _dmarc
Value: v=DMARC1; p=none; rua=mailto:dmarc-reports@swordintelligence.airforce
TTL: 3600
```

**Production DMARC (Quarantine):**

```dns
_dmarc.swordintelligence.airforce. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@swordintelligence.airforce; ruf=mailto:dmarc-reports@swordintelligence.airforce; fo=1; adkim=s; aspf=s; pct=100"
```

**Strict DMARC (Reject):**

```dns
_dmarc.swordintelligence.airforce. IN TXT "v=DMARC1; p=reject; rua=mailto:dmarc-reports@swordintelligence.airforce; ruf=mailto:dmarc-reports@swordintelligence.airforce; fo=1; adkim=s; aspf=s; pct=100"
```

**DMARC Tag Explanations:**

| Tag | Description | Values |
|-----|-------------|--------|
| `v` | Version | `DMARC1` (required) |
| `p` | Policy | `none`, `quarantine`, `reject` |
| `rua` | Aggregate reports email | `mailto:email@domain` |
| `ruf` | Forensic reports email | `mailto:email@domain` |
| `fo` | Forensic options | `0`, `1`, `d`, `s` |
| `adkim` | DKIM alignment | `r` (relaxed), `s` (strict) |
| `aspf` | SPF alignment | `r` (relaxed), `s` (strict) |
| `pct` | Percentage of messages | `0-100` (default: 100) |
| `sp` | Subdomain policy | `none`, `quarantine`, `reject` |

**Recommended deployment timeline:**

1. Week 1-2: `p=none` (monitor only, collect reports)
2. Week 3-4: `p=quarantine` (suspicious mail to spam folder)
3. Week 5+: `p=reject` (fully enforced)

---

## Modern Standards (MTA-STS, TLS-RPT, DANE)

### MTA-STS (SMTP TLS Enforcement)

Forces receiving servers to use TLS when delivering mail to your domain.

**Step 1: DNS Record**

```dns
; Standard zone file format
_mta-sts.swordintelligence.airforce. 3600 IN TXT "v=STSv1; id=20250120"

; Njalla interface format
Type: TXT
Name: _mta-sts
Value: v=STSv1; id=20250120
TTL: 3600
```

**Step 2: Policy File**

Create: `https://mta-sts.swordintelligence.airforce/.well-known/mta-sts.txt`

```
version: STSv1
mode: enforce
mx: mail.swordintelligence.airforce
max_age: 604800
```

**Caddy configuration** (add to Caddyfile):

```
mta-sts.swordintelligence.airforce {
    respond /.well-known/mta-sts.txt 200 {
        body `version: STSv1
mode: enforce
mx: mail.swordintelligence.airforce
max_age: 604800`
        close
    }
}
```

**Update the `id` field** whenever you change the policy (use current date: YYYYMMDD).

### TLS-RPT (TLS Reporting)

Receive reports about TLS connection issues.

```dns
; Standard zone file format
_smtp._tls.swordintelligence.airforce. 3600 IN TXT "v=TLSRPTv1; rua=mailto:tls-reports@swordintelligence.airforce"

; Njalla interface format
Type: TXT
Name: _smtp._tls
Value: v=TLSRPTv1; rua=mailto:tls-reports@swordintelligence.airforce
TTL: 3600
```

Reports are sent as JSON to the specified email address when TLS issues occur.

### DANE (DNS-Based Authentication of Named Entities)

Uses DNSSEC and TLSA records to authenticate TLS certificates.

**Prerequisites:**
1. Domain must have DNSSEC enabled
2. Hosting provider must support TLSA records

**TLSA Record (Certificate Hash):**

```bash
# Generate TLSA record from certificate
echo -n "3 1 1 " && openssl x509 -in stalwart/ssl/fullchain.pem -noout -pubkey | \
openssl pkey -pubin -outform DER | \
openssl dgst -sha256 -binary | \
xxd -p -u -c 64
```

```dns
; Standard zone file format
_25._tcp.mail.swordintelligence.airforce. 3600 IN TLSA 3 1 1 ABC123...

; Njalla interface format
Type: TLSA
Name: _25._tcp.mail
Certificate Usage: 3 (DANE-EE)
Selector: 1 (SPKI)
Matching Type: 1 (SHA-256)
Certificate Data: ABC123...
TTL: 3600
```

**Note:** DANE requires DNSSEC. Check if Njalla supports DNSSEC for your domain first.

---

## Njalla Configuration

Njalla is the recommended DNS provider for SWORD Intelligence. Here's the complete configuration:

### Full Njalla DNS Configuration

Log in to Njalla → Select Domain → DNS Records → Add:

#### 1. A Record (Mail Server)
```
Type: A
Name: mail
Value: 203.0.113.10
TTL: 3600
```

#### 2. MX Record
```
Type: MX
Name: @
Priority: 10
Value: mail.swordintelligence.airforce
TTL: 3600
```

#### 3. SPF Record
```
Type: TXT
Name: @
Value: v=spf1 mx -all
TTL: 3600
```

#### 4. DKIM Record
```
Type: TXT
Name: default._domainkey
Value: v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
TTL: 3600
```

*(Get the full public key from `stalwart/ssl/dkim.txt` after running `generate-dkim.sh`)*

#### 5. DMARC Record
```
Type: TXT
Name: _dmarc
Value: v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@swordintelligence.airforce; ruf=mailto:dmarc-reports@swordintelligence.airforce; fo=1; adkim=s; aspf=s
TTL: 3600
```

#### 6. MTA-STS Record
```
Type: TXT
Name: _mta-sts
Value: v=STSv1; id=20250120
TTL: 3600
```

#### 7. TLS-RPT Record
```
Type: TXT
Name: _smtp._tls
Value: v=TLSRPTv1; rua=mailto:tls-reports@swordintelligence.airforce
TTL: 3600
```

#### 8. Webmail CNAME (Optional)
```
Type: CNAME
Name: spiderwebmail
Value: swordintelligence.airforce
TTL: 3600
```

Or use an A record:
```
Type: A
Name: spiderwebmail
Value: 203.0.113.10
TTL: 3600
```

### Njalla DNS Screenshot Reference

Njalla interface should show:

```
┌────────────┬─────────────────────┬──────────────────────────────────┬─────┐
│ Type       │ Name                │ Value                            │ TTL │
├────────────┼─────────────────────┼──────────────────────────────────┼─────┤
│ A          │ mail                │ 203.0.113.10                     │ 3600│
│ MX         │ @                   │ 10 mail.swordintelligence.air... │ 3600│
│ TXT        │ @                   │ v=spf1 mx -all                   │ 3600│
│ TXT        │ default._domainkey  │ v=DKIM1; k=rsa; p=MIIBIjANBg... │ 3600│
│ TXT        │ _dmarc              │ v=DMARC1; p=quarantine; rua=m... │ 3600│
│ TXT        │ _mta-sts            │ v=STSv1; id=20250120             │ 3600│
│ TXT        │ _smtp._tls          │ v=TLSRPTv1; rua=mailto:tls-re... │ 3600│
│ A          │ spiderwebmail       │ 203.0.113.10                     │ 3600│
└────────────┴─────────────────────┴──────────────────────────────────┴─────┘
```

---

## Verification & Testing

### DNS Propagation Check

Wait 5-15 minutes after adding records, then verify:

```bash
# Check A record
dig A mail.swordintelligence.airforce +short

# Check MX record
dig MX swordintelligence.airforce +short

# Check SPF
dig TXT swordintelligence.airforce +short | grep spf1

# Check DKIM
dig TXT default._domainkey.swordintelligence.airforce +short

# Check DMARC
dig TXT _dmarc.swordintelligence.airforce +short

# Check PTR (reverse DNS)
dig -x 203.0.113.10 +short

# Check MTA-STS
dig TXT _mta-sts.swordintelligence.airforce +short
curl https://mta-sts.swordintelligence.airforce/.well-known/mta-sts.txt

# Check TLS-RPT
dig TXT _smtp._tls.swordintelligence.airforce +short
```

### Online Testing Tools

**MXToolbox** - Comprehensive email diagnostics
```
https://mxtoolbox.com/SuperTool.aspx?action=mx:swordintelligence.airforce
```

**Mail Tester** - Spam score and configuration check
```
https://www.mail-tester.com/
```
Send a test email to the provided address.

**DMARC Analyzer**
```
https://www.dmarcanalyzer.com/dmarc-check/
```

**Google Admin Toolbox**
```
https://toolbox.googleapps.com/apps/checkmx/
```

### Test Email Delivery

**1. Send test email:**
```bash
# From Stalwart container
docker exec -it stalwart stalwart-cli message send \
  --from admin@swordintelligence.airforce \
  --to check-auth@verifier.port25.com \
  --subject "Authentication Test" \
  --body "Testing SPF, DKIM, DMARC"
```

**2. Check results:**

Port25 will reply with a detailed report showing:
- SPF: pass/fail
- DKIM: pass/fail
- DMARC: pass/fail
- Reverse DNS: pass/fail

### Common Issues

#### "SPF PermError"
- SPF record has syntax error
- Multiple SPF records (only one TXT record with `v=spf1` allowed)
- Too many DNS lookups (max 10)

#### "DKIM neutral/fail"
- DKIM key not published in DNS
- DNS record has syntax error
- Private key doesn't match public key
- Selector mismatch

#### "DMARC not found"
- Missing `_dmarc` subdomain
- TXT record syntax error

#### "Reverse DNS mismatch"
- PTR record not set by hosting provider
- PTR doesn't match A record hostname

---

## Advanced Configurations

### Multiple Domains

To host email for multiple domains on the same server:

**Domain: example.com**

```dns
example.com. IN MX 10 mail.swordintelligence.airforce.
example.com. IN TXT "v=spf1 mx -all"
default._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=KEY..."
_dmarc.example.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"
```

**Domain: another-domain.org**

```dns
another-domain.org. IN MX 10 mail.swordintelligence.airforce.
another-domain.org. IN TXT "v=spf1 mx -all"
default._domainkey.another-domain.org. IN TXT "v=DKIM1; k=rsa; p=KEY..."
_dmarc.another-domain.org. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@another-domain.org"
```

### Subdomains

To send email from subdomains (e.g., `alerts.swordintelligence.airforce`):

```dns
; No separate MX needed - inherits from parent
alerts.swordintelligence.airforce. IN TXT "v=spf1 include:swordintelligence.airforce -all"

; DKIM for subdomain
default._domainkey.alerts.swordintelligence.airforce. IN TXT "v=DKIM1; k=rsa; p=KEY..."

; DMARC for subdomain
_dmarc.alerts.swordintelligence.airforce. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@swordintelligence.airforce"
```

Or use subdomain policy in parent DMARC:

```dns
_dmarc.swordintelligence.airforce. IN TXT "v=DMARC1; p=reject; sp=quarantine; ..."
```

`sp=quarantine` applies to all subdomains.

---

## Quick Reference

### Minimum Required Records

For basic production email (SPF/DKIM/DMARC):

```bash
# 1. A record
mail.swordintelligence.airforce. → 203.0.113.10

# 2. MX record
swordintelligence.airforce. → 10 mail.swordintelligence.airforce.

# 3. PTR record (contact hosting provider)
203.0.113.10 → mail.swordintelligence.airforce.

# 4. SPF
swordintelligence.airforce. TXT "v=spf1 mx -all"

# 5. DKIM (run generate-dkim.sh first)
default._domainkey.swordintelligence.airforce. TXT "v=DKIM1; k=rsa; p=..."

# 6. DMARC
_dmarc.swordintelligence.airforce. TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@swordintelligence.airforce"
```

### Full Production Records

All recommended records for maximum deliverability:

- ✅ A / AAAA (mail server IP)
- ✅ MX (mail routing)
- ✅ PTR (reverse DNS via ISP)
- ✅ SPF (sender authentication)
- ✅ DKIM (message signing)
- ✅ DMARC (policy + reporting)
- ✅ MTA-STS (TLS enforcement)
- ✅ TLS-RPT (TLS reporting)
- ⚠️ DANE/TLSA (optional, requires DNSSEC)

---

## Support & Resources

- **DNS Tester:** https://dnschecker.org/
- **SPF Validator:** https://www.kitterman.com/spf/validate.html
- **DKIM Validator:** https://dkimvalidator.com/
- **DMARC Checker:** https://dmarcian.com/dmarc-inspector/
- **MTA-STS Validator:** https://aykevl.nl/apps/mta-sts/
- **Email Security:** https://www.hardenize.com/

For VPS2.0 specific issues, see `stalwart/README.md` or file a GitHub issue.
