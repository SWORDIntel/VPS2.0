#!/usr/bin/env bash
#
# VPS2.0 Local Setup Script
#
# This script is the entry point when the VPS2.0 archive is uploaded to a server.
# Use this when you have already downloaded/extracted the repository locally.
#
# Usage:
#   sudo bash setup.sh
#   OR
#   sudo bash setup.sh --verbose
#

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE=false

#############################################
# Logging Functions
#############################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓ SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[⚠ WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗ ERROR]${NC} $*" >&2
}

log_step() {
    echo ""
    echo -e "${CYAN}${BOLD}==>${NC} ${BOLD}$*${NC}"
    echo ""
}

#############################################
# Banner
#############################################

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║   VPS2.0 INTELLIGENCE PLATFORM                              ║
║   Local Setup Script                                        ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "  ${BOLD}Setting up from local archive${NC}"
    echo -e "  Location: ${SCRIPT_DIR}"
    echo ""
}

#############################################
# Argument Parsing
#############################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                log_warn "Unknown option: $1"
                shift
                ;;
        esac
    done
}

show_help() {
    cat << EOF
${BOLD}VPS2.0 Local Setup Script${NC}

${BOLD}USAGE:${NC}
    sudo bash setup.sh [OPTIONS]

${BOLD}OPTIONS:${NC}
    -v, --verbose    Enable verbose output
    -h, --help       Show this help message

${BOLD}DESCRIPTION:${NC}
    This script sets up VPS2.0 when the repository archive has been
    uploaded directly to the server. It performs the following:

    1. Checks for root/sudo privileges
    2. Verifies Docker and Docker Compose installation
    3. Checks system requirements
    4. Launches the interactive setup wizard

${BOLD}EXAMPLES:${NC}
    # Standard setup
    sudo bash setup.sh

    # Verbose setup
    sudo bash setup.sh --verbose

${BOLD}PREREQUISITES:${NC}
    - Docker Engine 24.0+
    - Docker Compose Plugin 2.20+
    - 4GB+ RAM (32GB+ recommended)
    - 50GB+ disk space (500GB+ recommended)

${BOLD}NOTE:${NC}
    If Docker is not installed, run the remote installer first:
    curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash

EOF
    exit 0
}

#############################################
# Privilege Check
#############################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        log_info "Please run: sudo bash setup.sh"
        exit 1
    fi
    log_success "Running with root privileges"
}

#############################################
# Docker Check
#############################################

check_docker() {
    log_step "Checking Docker Installation"

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        echo ""
        log_info "Please install Docker first using one of these methods:"
        echo ""
        echo "  ${BOLD}Option 1: Remote Installer (Recommended)${NC}"
        echo "  curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash"
        echo ""
        echo "  ${BOLD}Option 2: Manual Installation${NC}"
        echo "  Visit: https://docs.docker.com/engine/install/"
        echo ""
        exit 1
    fi

    local docker_version=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
    log_success "Docker installed: $docker_version"

    # Check if Docker daemon is running
    if ! docker ps &> /dev/null; then
        log_error "Docker daemon is not running"
        log_info "Starting Docker..."
        systemctl start docker
        systemctl enable docker

        if docker ps &> /dev/null; then
            log_success "Docker daemon started"
        else
            log_error "Failed to start Docker daemon"
            log_info "Try manually: sudo systemctl start docker"
            exit 1
        fi
    else
        log_success "Docker daemon is running"
    fi
}

check_docker_compose() {
    log_step "Checking Docker Compose"

    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose plugin is not installed"
        log_info "Please install Docker Compose:"
        echo "  Visit: https://docs.docker.com/compose/install/"
        exit 1
    fi

    local compose_version=$(docker compose version --short)
    log_success "Docker Compose installed: $compose_version"
}

#############################################
# System Requirements
#############################################

check_system_requirements() {
    log_step "Checking System Requirements"

    local cpu_cores=$(nproc)
    local total_ram=$(free -g | awk 'NR==2 {print $2}')
    local total_disk=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $2}' | sed 's/G//')
    local available_disk=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')

    log_info "CPU Cores: $cpu_cores"
    log_info "Total RAM: ${total_ram}GB"
    log_info "Disk Space: ${total_disk}GB (${available_disk}GB available)"

    local warnings=false

    if [[ $cpu_cores -lt 2 ]]; then
        log_error "Minimum 2 CPU cores required (detected: $cpu_cores)"
        exit 1
    elif [[ $cpu_cores -lt 8 ]]; then
        log_warn "Recommended: 8+ CPU cores for optimal performance"
        warnings=true
    fi

    if [[ $total_ram -lt 4 ]]; then
        log_error "Minimum 4GB RAM required (detected: ${total_ram}GB)"
        exit 1
    elif [[ $total_ram -lt 32 ]]; then
        log_warn "Recommended: 32GB+ RAM for full deployment"
        warnings=true
    fi

    if [[ $available_disk -lt 50 ]]; then
        log_error "Minimum 50GB available disk space required (detected: ${available_disk}GB)"
        exit 1
    elif [[ $available_disk -lt 500 ]]; then
        log_warn "Recommended: 500GB+ disk space for logs and backups"
        warnings=true
    fi

    if [[ "$warnings" == true ]]; then
        echo ""
        log_info "System meets minimum requirements but is below recommended specs"
        log_info "Consider upgrading for optimal performance"
    fi

    log_success "System requirements check passed"
}

#############################################
# Repository Validation
#############################################

validate_repository() {
    log_step "Validating Repository Structure"

    local required_files=(
        "docker-compose.yml"
        "scripts/setup-wizard.sh"
        ".env.template"
        "caddy/Caddyfile"
    )

    local missing_files=()

    for file in "${required_files[@]}"; do
        if [[ ! -f "${SCRIPT_DIR}/${file}" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Repository validation failed - missing files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        log_info "Please ensure you have extracted the complete VPS2.0 archive"
        exit 1
    fi

    log_success "Repository structure validated"
}

#############################################
# Launch Setup Wizard
#############################################

launch_setup_wizard() {
    log_step "Launching Setup Wizard"

    local wizard_script="${SCRIPT_DIR}/scripts/setup-wizard.sh"

    if [[ ! -f "$wizard_script" ]]; then
        log_error "Setup wizard not found: $wizard_script"
        exit 1
    fi

    # Make wizard executable
    chmod +x "$wizard_script"

    log_info "Starting interactive configuration..."
    echo ""

    # Launch wizard with verbose flag if set
    if [[ "$VERBOSE" == true ]]; then
        bash "$wizard_script" --verbose
    else
        bash "$wizard_script"
    fi
}

#############################################
# Main
#############################################

main() {
    parse_arguments "$@"
    print_banner

    log_info "VPS2.0 Local Setup"
    log_info "Working directory: $SCRIPT_DIR"
    echo ""

    # Pre-flight checks
    check_root
    check_docker
    check_docker_compose
    check_system_requirements
    validate_repository

    # Success
    log_step "Prerequisites Validated"

    echo -e "${GREEN}${BOLD}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║   ALL CHECKS PASSED                                         ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    log_success "Docker: Ready"
    log_success "System: Ready"
    log_success "Repository: Valid"

    echo ""
    log_info "Launching interactive setup wizard..."
    echo ""

    sleep 2

    # Launch wizard
    launch_setup_wizard
}

main "$@"
