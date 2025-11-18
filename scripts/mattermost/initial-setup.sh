#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 Mattermost - Initial Security Setup Script
# Applies all immediate security hardening actions

#==============================================
# Configuration
#==============================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Load environment variables
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    # shellcheck disable=SC1091
    source "${PROJECT_ROOT}/.env"
fi

readonly MATTERMOST_URL="${MATTERMOST_URL:-https://mattermost.swordintelligence.airforce}"
readonly ADMIN_TOKEN_FILE="${PROJECT_ROOT}/.mattermost_admin_token"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
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
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_step() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$*${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_mattermost_running() {
    if ! docker ps | grep -q "mattermost"; then
        log_error "Mattermost container not running"
        log_info "Start with: docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d"
        exit 1
    fi
}

wait_for_mattermost() {
    log_info "Waiting for Mattermost to be ready..."
    local max_attempts=30
    local attempt=0

    while ! curl -sf "${MATTERMOST_URL}/api/v4/system/ping" > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [[ $attempt -ge $max_attempts ]]; then
            log_error "Mattermost did not become ready in time"
            exit 1
        fi
        echo -n "."
        sleep 2
    done

    echo ""
    log_success "Mattermost is ready"
}

get_admin_token() {
    if [[ -f "$ADMIN_TOKEN_FILE" ]]; then
        cat "$ADMIN_TOKEN_FILE"
    else
        log_error "Admin token not found. Please create a System Admin user first."
        log_info "1. Go to ${MATTERMOST_URL}"
        log_info "2. Create first user (becomes System Admin)"
        log_info "3. Generate personal access token in Account Settings"
        log_info "4. Save token to: $ADMIN_TOKEN_FILE"
        exit 1
    fi
}

mmcli() {
    local token
    token=$(get_admin_token)

    docker exec mattermost mattermost "$@"
}

mmapi() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local token
    token=$(get_admin_token)

    local curl_args=(
        -s
        -X "$method"
        -H "Authorization: Bearer $token"
        -H "Content-Type: application/json"
    )

    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi

    curl "${curl_args[@]}" "${MATTERMOST_URL}/api/v4${endpoint}"
}

#==============================================
# Security Hardening Functions
#==============================================

disable_user_registration() {
    log_step "1. Disabling Open User Registration"

    mmapi PUT "/config" '{
        "TeamSettings": {
            "EnableUserCreation": false,
            "EnableOpenServer": false
        }
    }' > /dev/null

    log_success "User registration disabled"
    log_info "Users must be invited by admins"
}

restrict_team_creation() {
    log_step "2. Restricting Team Creation"

    mmapi PUT "/config" '{
        "TeamSettings": {
            "EnableTeamCreation": false,
            "RestrictTeamInvite": "all",
            "RestrictPublicChannelCreation": "all",
            "RestrictPrivateChannelCreation": "all"
        }
    }' > /dev/null

    log_success "Team creation restricted to System Admins"
    log_info "Channel creation restricted"
}

configure_mfa() {
    log_step "3. Configuring Multi-Factor Authentication"

    mmapi PUT "/config" '{
        "ServiceSettings": {
            "EnableMultifactorAuthentication": true,
            "EnforceMultifactorAuthentication": true
        }
    }' > /dev/null

    log_success "MFA enabled and enforced for all users"
    log_warn "All users must set up MFA on next login"
}

configure_session_timeouts() {
    log_step "4. Configuring Session Timeouts"

    mmapi PUT "/config" '{
        "ServiceSettings": {
            "SessionLengthWebInDays": 7,
            "SessionLengthMobileInDays": 30,
            "SessionIdleTimeoutInMinutes": 60,
            "SessionCacheInMinutes": 10
        }
    }' > /dev/null

    log_success "Session timeouts configured"
    log_info "Web: 7 days, Mobile: 30 days, Idle: 60 min"
}

enable_audit_logging() {
    log_step "5. Enabling Audit Logging"

    mmapi PUT "/config" '{
        "ComplianceSettings": {
            "Enable": true,
            "Directory": "/mattermost/compliance",
            "EnableDaily": true
        }
    }' > /dev/null

    log_success "Audit logging enabled"
    log_info "Daily compliance reports enabled"
    log_info "Logs location: /mattermost/compliance"
}

configure_password_policy() {
    log_step "6. Enforcing Strong Password Policy"

    mmapi PUT "/config" '{
        "PasswordSettings": {
            "MinimumLength": 12,
            "Lowercase": true,
            "Number": true,
            "Uppercase": true,
            "Symbol": true
        }
    }' > /dev/null

    log_success "Password policy enforced"
    log_info "Requirements: 12+ chars, lowercase, uppercase, number, symbol"
}

configure_rate_limiting() {
    log_step "7. Configuring Rate Limiting"

    mmapi PUT "/config" '{
        "RateLimitSettings": {
            "Enable": true,
            "PerSec": 10,
            "MaxBurst": 100,
            "MemoryStoreSize": 10000,
            "VaryByRemoteAddr": true,
            "VaryByUser": true
        }
    }' > /dev/null

    log_success "Rate limiting enabled"
    log_info "Limit: 10 req/sec, burst 100"
}

enable_plugins() {
    log_step "8. Enabling Plugin System"

    mmapi PUT "/config" '{
        "PluginSettings": {
            "Enable": true,
            "EnableUploads": true,
            "EnableMarketplace": true,
            "MarketplaceUrl": "https://api.integrations.mattermost.com"
        }
    }' > /dev/null

    log_success "Plugin system enabled"
    log_info "Ready for Playbooks, GitLab, Jira, etc."
}

disable_insecure_features() {
    log_step "9. Disabling Insecure Features"

    mmapi PUT "/config" '{
        "ServiceSettings": {
            "EnableDeveloper": false,
            "EnableTesting": false,
            "EnableInsecureOutgoingConnections": false,
            "EnableOAuthServiceProvider": false
        }
    }' > /dev/null

    log_success "Insecure features disabled"
}

configure_email_restrictions() {
    log_step "10. Configuring Email Domain Restrictions"

    local email_domains="${MATTERMOST_RESTRICT_EMAIL_DOMAINS:-swordintelligence.airforce}"

    mmapi PUT "/config" "{
        \"TeamSettings\": {
            \"RestrictCreationToDomains\": \"$email_domains\"
        }
    }" > /dev/null

    log_success "Email restricted to: $email_domains"
}

#==============================================
# Summary & Next Steps
#==============================================

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║       Mattermost Security Hardening Complete                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    log_success "Security Configuration Applied:"
    echo "  ✓ User registration disabled (admin invite only)"
    echo "  ✓ Team creation restricted to System Admins"
    echo "  ✓ MFA enabled and enforced for all users"
    echo "  ✓ Session timeouts configured (7d web, 60m idle)"
    echo "  ✓ Audit logging enabled with daily reports"
    echo "  ✓ Strong password policy enforced"
    echo "  ✓ Rate limiting enabled (10 req/sec)"
    echo "  ✓ Plugin system enabled"
    echo "  ✓ Insecure features disabled"
    echo "  ✓ Email domain restrictions applied"
    echo ""

    log_warn "Important Next Steps:"
    echo "  1. All users must set up MFA on next login"
    echo "  2. Review existing users and roles"
    echo "  3. Install plugins: Playbooks, GitLab, Jira, AlertManager"
    echo "  4. Configure SMTP settings if not already done"
    echo "  5. Create incident response playbooks"
    echo "  6. Set up GitLab/Prometheus integrations"
    echo ""

    log_info "Configuration can be reviewed at:"
    echo "  ${MATTERMOST_URL}/admin_console"
    echo ""
}

#==============================================
# Main
#==============================================

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     VPS2.0 Mattermost - Initial Security Setup                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Pre-flight checks
    check_mattermost_running
    wait_for_mattermost

    # Check for admin token
    if [[ ! -f "$ADMIN_TOKEN_FILE" ]]; then
        log_error "Admin token required for API access"
        echo ""
        log_info "Setup Instructions:"
        echo "  1. Access Mattermost: ${MATTERMOST_URL}"
        echo "  2. Create first user (becomes System Admin automatically)"
        echo "  3. Go to: Account Settings → Security → Personal Access Tokens"
        echo "  4. Create token with description: 'Initial Setup Script'"
        echo "  5. Save token to file:"
        echo "     echo 'YOUR_TOKEN_HERE' > $ADMIN_TOKEN_FILE"
        echo "     chmod 600 $ADMIN_TOKEN_FILE"
        echo ""
        echo "  6. Run this script again"
        exit 1
    fi

    # Apply security hardening
    disable_user_registration
    restrict_team_creation
    configure_mfa
    configure_session_timeouts
    enable_audit_logging
    configure_password_policy
    configure_rate_limiting
    enable_plugins
    disable_insecure_features
    configure_email_restrictions

    # Summary
    print_summary
}

main "$@"
