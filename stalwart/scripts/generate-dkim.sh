#!/bin/bash
#
# DKIM Key Generation Script
# VPS2.0 Email Module
#
# Generates RSA-2048 DKIM keys for email signing
# Usage: ./generate-dkim.sh <domain>
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SELECTOR="${SELECTOR:-default}"
KEY_SIZE="${KEY_SIZE:-2048}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$(dirname "$SCRIPT_DIR")/ssl"
DKIM_KEY="${SSL_DIR}/dkim.key"
DKIM_PUB="${SSL_DIR}/dkim.pub"
DKIM_DNS="${SSL_DIR}/dkim.txt"

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   DKIM Key Generator - VPS2.0 Email    ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Domain name required${NC}"
    echo "Usage: $0 <domain> [selector]"
    echo "Example: $0 swordintelligence.airforce default"
    exit 1
fi

DOMAIN="$1"
if [ $# -ge 2 ]; then
    SELECTOR="$2"
fi

echo -e "${GREEN}Domain:${NC} $DOMAIN"
echo -e "${GREEN}Selector:${NC} $SELECTOR"
echo -e "${GREEN}Key Size:${NC} $KEY_SIZE bits"
echo ""

# Check if keys already exist
if [ -f "$DKIM_KEY" ]; then
    echo -e "${YELLOW}Warning: DKIM key already exists at $DKIM_KEY${NC}"
    read -p "Overwrite existing key? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    echo ""
fi

# Create SSL directory if it doesn't exist
mkdir -p "$SSL_DIR"

# Generate private key
echo -e "${BLUE}[1/4]${NC} Generating RSA-$KEY_SIZE private key..."
openssl genrsa -out "$DKIM_KEY" "$KEY_SIZE" 2>/dev/null
chmod 600 "$DKIM_KEY"
echo -e "${GREEN}✓${NC} Private key saved to: $DKIM_KEY"
echo ""

# Extract public key
echo -e "${BLUE}[2/4]${NC} Extracting public key..."
openssl rsa -in "$DKIM_KEY" -pubout -out "$DKIM_PUB" 2>/dev/null
echo -e "${GREEN}✓${NC} Public key saved to: $DKIM_PUB"
echo ""

# Generate DNS TXT record
echo -e "${BLUE}[3/4]${NC} Generating DNS TXT record..."

# Extract the public key in DKIM format (remove headers/newlines)
PUBKEY=$(grep -v "^-----" "$DKIM_PUB" | tr -d '\n')

# Create DNS record
cat > "$DKIM_DNS" <<EOF
; DKIM DNS TXT Record
; Domain: ${DOMAIN}
; Selector: ${SELECTOR}
;
; Add this record to your DNS configuration:

${SELECTOR}._domainkey.${DOMAIN}. IN TXT "v=DKIM1; k=rsa; p=${PUBKEY}"

; For Njalla or other DNS providers, use:
; Name: ${SELECTOR}._domainkey
; Type: TXT
; Value: v=DKIM1; k=rsa; p=${PUBKEY}
EOF

echo -e "${GREEN}✓${NC} DNS record saved to: $DKIM_DNS"
echo ""

# Display DNS record
echo -e "${BLUE}[4/4]${NC} DNS Configuration Required:"
echo ""
echo -e "${YELLOW}Add this TXT record to your DNS:${NC}"
echo ""
echo -e "${GREEN}Name:${NC}  ${SELECTOR}._domainkey.${DOMAIN}."
echo -e "${GREEN}Type:${NC}  TXT"
echo -e "${GREEN}Value:${NC} v=DKIM1; k=rsa; p=${PUBKEY}"
echo ""

# Truncated display for long keys
if [ ${#PUBKEY} -gt 100 ]; then
    echo -e "${YELLOW}(Public key truncated for display - see $DKIM_DNS for full record)${NC}"
    echo ""
fi

# Verification instructions
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo ""
echo "1. Add the DNS TXT record shown above to your DNS provider (Njalla)"
echo ""
echo "2. Wait for DNS propagation (usually 5-15 minutes)"
echo ""
echo "3. Verify DKIM record is published:"
echo -e "   ${YELLOW}dig TXT ${SELECTOR}._domainkey.${DOMAIN}${NC}"
echo ""
echo "4. Test DKIM configuration:"
echo -e "   ${YELLOW}https://dkimvalidator.com/${NC}"
echo ""
echo "5. Restart Stalwart to load new keys:"
echo -e "   ${YELLOW}docker-compose -f docker-compose.yml -f docker-compose.email.yml restart stalwart${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Key fingerprint for verification
FINGERPRINT=$(openssl rsa -in "$DKIM_KEY" -pubout -outform DER 2>/dev/null | openssl dgst -sha256 | cut -d' ' -f2)
echo -e "${GREEN}Key Fingerprint (SHA256):${NC} $FINGERPRINT"
echo ""

# Security reminder
echo -e "${RED}⚠ SECURITY WARNING ⚠${NC}"
echo ""
echo "The private key ($DKIM_KEY) must be kept secure!"
echo ""
echo "- Ensure proper file permissions (600)"
echo "- Include in backups"
echo "- Never commit to version control"
echo "- Rotate keys annually"
echo ""

echo -e "${GREEN}DKIM key generation complete!${NC}"
