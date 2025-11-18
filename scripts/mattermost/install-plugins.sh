#!/usr/bin/env bash
set -euo pipefail

# VPS2.0 Mattermost - Plugin Installation Script
# Installs the minimal v1 stack for incident response & DevSecOps

#==============================================
# Configuration
#==============================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly MATTERMOST_URL="${MATTERMOST_URL:-https://mattermost.swordintelligence.airforce}"
readonly ADMIN_TOKEN_FILE="${PROJECT_ROOT}/.mattermost_admin_token"

# Plugin URLs (from Mattermost Marketplace)
readonly PLUGIN_PLAYBOOKS="https://github.com/mattermost/mattermost-plugin-playbooks/releases/latest/download/com.mattermost.plugin-incident-management.tar.gz"
readonly PLUGIN_GITLAB="https://github.com/mattermost/mattermost-plugin-gitlab/releases/latest/download/com.github.manland.mattermost-plugin-gitlab.tar.gz"
readonly PLUGIN_JIRA="https://github.com/mattermost/mattermost-plugin-jira/releases/latest/download/jira-plugin.tar.gz"
readonly PLUGIN_REMIND="https://github.com/scottleedavis/mattermost-plugin-remind/releases/latest/download/com.github.scottleedavis.mattermost-plugin-remind.tar.gz"

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

get_admin_token() {
    if [[ -f "$ADMIN_TOKEN_FILE" ]]; then
        cat "$ADMIN_TOKEN_FILE"
    else
        log_error "Admin token not found at: $ADMIN_TOKEN_FILE"
        exit 1
    fi
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

install_plugin_from_url() {
    local plugin_name="$1"
    local plugin_url="$2"
    local temp_file="/tmp/${plugin_name}.tar.gz"

    log_info "Downloading $plugin_name..."
    curl -sL "$plugin_url" -o "$temp_file"

    log_info "Installing $plugin_name..."
    local token
    token=$(get_admin_token)

    curl -s -X POST \
        -H "Authorization: Bearer $token" \
        -F "plugin=@${temp_file}" \
        "${MATTERMOST_URL}/api/v4/plugins" > /dev/null

    rm -f "$temp_file"

    log_success "$plugin_name installed"
}

enable_plugin() {
    local plugin_id="$1"

    log_info "Enabling $plugin_id..."

    mmapi POST "/plugins/$plugin_id/enable" > /dev/null

    log_success "$plugin_id enabled"
}

install_via_marketplace() {
    local plugin_id="$1"
    local filter="$2"

    log_info "Installing $plugin_id from marketplace..."

    mmapi POST "/plugins/marketplace" "{
        \"id\": \"$plugin_id\",
        \"version\": \"latest\"
    }" > /dev/null

    log_success "$plugin_id installed from marketplace"
}

#==============================================
# Plugin Installation Functions
#==============================================

install_playbooks() {
    log_step "Installing Playbooks (Incident Collaboration)"

    # Playbooks is often pre-installed, check first
    local plugins
    plugins=$(mmapi GET "/plugins")

    if echo "$plugins" | grep -q "playbooks"; then
        log_info "Playbooks already installed"
        enable_plugin "playbooks"
    else
        install_via_marketplace "playbooks" "incident"
        enable_plugin "playbooks"
    fi

    log_success "Playbooks ready for incident response workflows"
}

install_boards() {
    log_step "Installing Mattermost Boards (Focalboard)"

    # Boards/Focalboard is often pre-installed in modern Mattermost
    local plugins
    plugins=$(mmapi GET "/plugins")

    if echo "$plugins" | grep -q -E "focalboard|boards"; then
        log_info "Boards already installed"
        # Try enabling with both possible plugin IDs
        enable_plugin "focalboard" 2>/dev/null || enable_plugin "boards" 2>/dev/null || true
    else
        install_via_marketplace "focalboard" "boards"
        enable_plugin "focalboard"
    fi

    log_success "Boards ready for investigation knowledge base"
    log_info "Use cases:"
    log_info "  • Investigation tracking (CVE analysis, threat intel)"
    log_info "  • Vulnerability management boards"
    log_info "  • Threat actor profiles and IOC databases"
    log_info "  • Post-incident knowledge capture"
}

install_gitlab_plugin() {
    log_step "Installing GitLab Plugin"

    install_via_marketplace "com.github.manland.mattermost-plugin-gitlab" "gitlab"
    enable_plugin "com.github.manland.mattermost-plugin-gitlab"

    log_success "GitLab plugin installed"
    log_warn "Configuration required:"
    log_info "  1. Go to System Console → Plugins → GitLab"
    log_info "  2. Set GitLab URL: https://gitlab.${DOMAIN:-localhost}"
    log_info "  3. Create OAuth app in GitLab"
    log_info "  4. Configure webhook secret"
}

install_jira_plugin() {
    log_step "Installing Jira Plugin"

    install_via_marketplace "jira" "jira"
    enable_plugin "jira"

    log_success "Jira plugin installed"
    log_warn "Configuration required (when Jira is deployed):"
    log_info "  1. Go to System Console → Plugins → Jira"
    log_info "  2. Set Jira URL"
    log_info "  3. Configure OAuth or Personal Access Token"
    log_info "  4. Set up webhook in Jira"
}

install_prometheus_plugin() {
    log_step "Installing Prometheus AlertManager Integration"

    # AlertManager uses webhooks (no dedicated plugin needed)
    log_info "Prometheus AlertManager uses incoming webhooks"

    # Enable webhooks
    mmapi PUT "/config" '{
        "ServiceSettings": {
            "EnableIncomingWebhooks": true,
            "EnableOutgoingWebhooks": true
        }
    }' > /dev/null

    log_success "Incoming/Outgoing webhooks enabled"
    log_info "Create incoming webhook for AlertManager in System Console"
}

install_remind_plugin() {
    log_step "Installing Remind Plugin"

    install_via_marketplace "com.github.scottleedavis.mattermost-plugin-remind" "remind"
    enable_plugin "com.github.scottleedavis.mattermost-plugin-remind"

    log_success "Remind plugin installed"
    log_info "Usage: /remind me in 1 hour to rotate keys"
}

#==============================================
# Configuration Helpers
#==============================================

create_incident_team() {
    log_step "Creating Incident Response Team"

    local team_data='{
        "name": "incident-response",
        "display_name": "Incident Response",
        "type": "I"
    }'

    local team_response
    team_response=$(mmapi POST "/teams" "$team_data")

    local team_id
    team_id=$(echo "$team_response" | jq -r '.id')

    if [[ -n "$team_id" && "$team_id" != "null" ]]; then
        log_success "Incident Response team created (ID: $team_id)"

        # Create default channels
        mmapi POST "/channels" "{
            \"team_id\": \"$team_id\",
            \"name\": \"p0-incidents\",
            \"display_name\": \"P0 Incidents\",
            \"type\": \"O\",
            \"purpose\": \"Critical incidents requiring immediate response\"
        }" > /dev/null

        mmapi POST "/channels" "{
            \"team_id\": \"$team_id\",
            \"name\": \"alerts\",
            \"display_name\": \"Alerts\",
            \"type\": \"O\",
            \"purpose\": \"Prometheus, AlertManager, and monitoring alerts\"
        }" > /dev/null

        mmapi POST "/channels" "{
            \"team_id\": \"$team_id\",
            \"name\": \"playbook-runs\",
            \"display_name\": \"Playbook Runs\",
            \"type\": \"O\",
            \"purpose\": \"Active incident playbook executions\"
        }" > /dev/null

        log_success "Default channels created"
    else
        log_warn "Incident Response team may already exist or creation failed"
    fi
}

#==============================================
# Summary
#==============================================

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         Mattermost Plugins Installation Complete              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    log_success "Installed Plugins (v1 Stack):"
    echo "  ✓ Playbooks - Incident response workflows & checklists"
    echo "  ✓ Boards - Investigation knowledge base (Kanban, tables, galleries)"
    echo "  ✓ GitLab - Repo integration, MR/issue notifications"
    echo "  ✓ Jira - Ticket creation and tracking (ready for Jira deploy)"
    echo "  ✓ Remind - Schedule reminders for IR follow-ups"
    echo "  ✓ Webhooks - Enabled for Prometheus AlertManager"
    echo ""

    log_info "Teams & Channels Created:"
    echo "  • Incident Response team"
    echo "    - #p0-incidents"
    echo "    - #alerts"
    echo "    - #playbook-runs"
    echo ""

    log_warn "Next Configuration Steps:"
    echo ""
    echo "  1. GitLab Integration:"
    echo "     - System Console → Plugins → GitLab"
    echo "     - Set GitLab URL, OAuth, webhook secret"
    echo "     - Subscribe channels to repos"
    echo ""
    echo "  2. Prometheus AlertManager:"
    echo "     - Create incoming webhook for #alerts channel"
    echo "     - Configure AlertManager to POST to webhook URL"
    echo "     - See: scripts/mattermost/alertmanager-config.yml"
    echo ""
    echo "  3. Jira (when deployed):"
    echo "     - System Console → Plugins → Jira"
    echo "     - Configure Jira URL and auth"
    echo "     - Set up webhook in Jira"
    echo ""
    echo "  4. Create Incident Playbooks:"
    echo "     - Go to Playbooks → Create Playbook"
    echo "     - Import templates from: mattermost/playbooks/"
    echo "     - Customize for SWORD workflows"
    echo ""
    echo "  5. Set Up Investigation Boards:"
    echo "     - Go to Boards → Create Board"
    echo "     - Use templates from: mattermost/boards/"
    echo "     - Track CVE analysis, threat intel, vulnerability management"
    echo "     - Link boards to playbook runs for comprehensive IR"
    echo ""
}

#==============================================
# Main
#==============================================

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║      VPS2.0 Mattermost - Plugin Installation (v1 Stack)       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Check for admin token
    if [[ ! -f "$ADMIN_TOKEN_FILE" ]]; then
        log_error "Admin token required: $ADMIN_TOKEN_FILE"
        exit 1
    fi

    # Install plugins
    install_playbooks
    install_boards
    install_gitlab_plugin
    install_jira_plugin
    install_prometheus_plugin
    install_remind_plugin

    # Create incident team
    create_incident_team

    # Summary
    print_summary
}

main "$@"
