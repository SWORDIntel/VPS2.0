#!/usr/bin/env bash
#
# VPS2.0 One-Liner Installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash
#   OR
#   wget -qO- https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash
#   OR (with verbose logging)
#   curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash -s -- --verbose
#   OR (with debug mode)
#   curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash -s -- --debug
#
# This script:
# - Detects OS and architecture
# - Installs prerequisites (Docker, Docker Compose, Git)
# - Clones VPS2.0 repository
# - Launches interactive setup wizard
#

set -euo pipefail

# Logging Levels
VERBOSE=false
DEBUG=false
INTERACTIVE=true

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Configuration
readonly REPO_URL="https://github.com/SWORDIntel/VPS2.0.git"
readonly INSTALL_DIR="/opt/vps2.0"
readonly MIN_DOCKER_VERSION="24.0.0"
readonly MIN_COMPOSE_VERSION="2.20.0"

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="VPS2.0 Installer"

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

log_verbose() {
    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
        echo -e "${CYAN}[VERBOSE]${NC} $*"
    fi
}

log_debug() {
    if [[ "$DEBUG" == true ]]; then
        echo -e "${YELLOW}[DEBUG]${NC} $*" >&2
    fi
}

log_command() {
    local cmd="$*"
    log_debug "Executing: $cmd"

    if [[ "$DEBUG" == true ]]; then
        # Show full command output in debug mode
        eval "$cmd"
    elif [[ "$VERBOSE" == true ]]; then
        # Show command but suppress output in verbose mode
        eval "$cmd" 2>&1 | while IFS= read -r line; do
            log_verbose "$line"
        done
    else
        # Silent execution in normal mode
        eval "$cmd" > /dev/null 2>&1
    fi
}

#############################################
# Progress Spinner
#############################################

spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    if [[ "$INTERACTIVE" != true ]]; then
        wait "$pid"
        return $?
    fi

    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " ${CYAN}[%c]${NC} %s" "$spinstr" "$message"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done

    wait "$pid"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        printf " ${GREEN}[✓]${NC} %s\n" "$message"
    else
        printf " ${RED}[✗]${NC} %s\n" "$message"
    fi

    return $exit_code
}

run_with_spinner() {
    local message="$1"
    shift
    local cmd="$*"

    log_debug "Command: $cmd"

    if [[ "$DEBUG" == true ]] || [[ "$VERBOSE" == true ]]; then
        # No spinner in debug/verbose mode
        log_info "$message"
        log_command "$cmd"
    else
        # Use spinner in normal mode
        eval "$cmd" > /tmp/vps2-install-$$.tmp 2>&1 &
        local pid=$!
        spinner "$pid" "$message"
        local exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            log_error "Failed: $message"
            if [[ -f /tmp/vps2-install-$$.tmp ]]; then
                log_error "Output:"
                cat /tmp/vps2-install-$$.tmp >&2
            fi
            return $exit_code
        fi
    fi
}

#############################################
# Progress Bar
#############################################

show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local width=50

    if [[ "$INTERACTIVE" != true ]]; then
        return
    fi

    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    printf "\r${CYAN}["
    printf "%${filled}s" '' | tr ' ' '='
    printf "%${empty}s" '' | tr ' ' ' '
    printf "]${NC} %3d%% - %s" "$percentage" "$message"

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

#############################################
# Help Function
#############################################

show_help() {
    cat << EOF
${BOLD}VPS2.0 Installer${NC} - Version $SCRIPT_VERSION

${BOLD}USAGE:${NC}
    curl -fsSL https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash
    wget -qO- https://raw.githubusercontent.com/SWORDIntel/VPS2.0/main/install.sh | sudo bash

${BOLD}OPTIONS:${NC}
    -h, --help       Show this help message
    -v, --verbose    Enable verbose logging output
    -d, --debug      Enable debug mode (very detailed output)
    -y, --yes        Non-interactive mode (auto-accept prompts)
    --no-color       Disable colored output

${BOLD}EXAMPLES:${NC}
    # Normal installation
    curl -fsSL <url> | sudo bash

    # Verbose installation
    curl -fsSL <url> | sudo bash -s -- --verbose

    # Debug mode
    curl -fsSL <url> | sudo bash -s -- --debug

    # Non-interactive mode
    curl -fsSL <url> | sudo bash -s -- --yes

${BOLD}SYSTEM REQUIREMENTS:${NC}
    - OS: Ubuntu 20.04+, Debian 11+, CentOS 8+, Rocky/AlmaLinux 8+
    - CPU: 2+ cores (8+ recommended)
    - RAM: 4GB+ (32GB+ recommended)
    - Disk: 50GB+ (500GB+ recommended)
    - Architecture: x86_64 or ARM64

${BOLD}WHAT THIS SCRIPT DOES:${NC}
    1. Detects operating system and architecture
    2. Checks system requirements
    3. Installs Docker and Docker Compose
    4. Installs required prerequisites
    5. Clones VPS2.0 repository to /opt/vps2.0
    6. Launches interactive setup wizard

${BOLD}SUPPORT:${NC}
    Issues: https://github.com/SWORDIntel/VPS2.0/issues
    Docs:   https://github.com/SWORDIntel/VPS2.0/wiki

EOF
    exit 0
}

#############################################
# Argument Parsing
#############################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                VERBOSE=true
                log_info "Verbose mode enabled"
                shift
                ;;
            -d|--debug)
                DEBUG=true
                VERBOSE=true
                set -x  # Enable bash debug mode
                log_info "Debug mode enabled"
                shift
                ;;
            -y|--yes)
                INTERACTIVE=false
                log_info "Non-interactive mode enabled"
                shift
                ;;
            --no-color)
                # Disable colors
                RED=''
                GREEN=''
                YELLOW=''
                BLUE=''
                CYAN=''
                NC=''
                BOLD=''
                shift
                ;;
            *)
                log_warn "Unknown option: $1"
                log_info "Run with --help for usage information"
                shift
                ;;
        esac
    done
}

#############################################
# Banner
#############################################

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║   VPS2.0 INTELLIGENCE PLATFORM INSTALLER                    ║
║   One-Line Deployment System                                ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "  ${BOLD}Automated Deployment & Configuration${NC}"
    echo -e "  Version: ${SCRIPT_VERSION}"

    if [[ "$VERBOSE" == true ]]; then
        echo -e "  ${CYAN}Mode: VERBOSE${NC}"
    fi
    if [[ "$DEBUG" == true ]]; then
        echo -e "  ${YELLOW}Mode: DEBUG${NC}"
    fi

    echo ""
}

#############################################
# Privilege Check
#############################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        log_info "Please run: curl -fsSL <url> | sudo bash"
        exit 1
    fi
}

#############################################
# OS Detection
#############################################

detect_os() {
    log_step "Detecting Operating System"

    log_verbose "Reading /etc/os-release..."
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_PRETTY=$PRETTY_NAME
        log_debug "OS ID: $OS"
        log_debug "OS Version: $OS_VERSION"
        log_debug "OS Pretty Name: $OS_PRETTY"
    else
        log_error "Cannot detect operating system"
        log_info "This installer supports: Ubuntu 20.04+, Debian 11+, CentOS 8+, Rocky Linux 8+, AlmaLinux 8+"
        exit 1
    fi

    log_info "Detected: $OS_PRETTY"

    # Check if OS is supported
    log_verbose "Validating OS compatibility..."
    case "$OS" in
        ubuntu)
            if [[ "${OS_VERSION%%.*}" -lt 20 ]]; then
                log_error "Ubuntu 20.04 or higher is required (detected: $OS_VERSION)"
                exit 1
            fi
            PKG_MANAGER="apt"
            log_debug "Package manager: apt"
            ;;
        debian)
            if [[ "${OS_VERSION%%.*}" -lt 11 ]]; then
                log_error "Debian 11 or higher is required (detected: $OS_VERSION)"
                exit 1
            fi
            PKG_MANAGER="apt"
            log_debug "Package manager: apt"
            ;;
        centos|rocky|almalinux|rhel)
            if [[ "${OS_VERSION%%.*}" -lt 8 ]]; then
                log_error "CentOS/Rocky/AlmaLinux 8 or higher is required (detected: $OS_VERSION)"
                exit 1
            fi
            PKG_MANAGER="dnf"
            log_debug "Package manager: dnf"
            ;;
        fedora)
            PKG_MANAGER="dnf"
            log_debug "Package manager: dnf"
            ;;
        *)
            log_error "Unsupported operating system: $OS"
            log_info "Supported: Ubuntu 20.04+, Debian 11+, CentOS 8+, Rocky Linux 8+, AlmaLinux 8+"
            exit 1
            ;;
    esac

    log_success "OS supported: $OS ($PKG_MANAGER)"
}

#############################################
# Architecture Detection
#############################################

detect_arch() {
    log_step "Detecting System Architecture"

    ARCH=$(uname -m)
    log_info "Detected architecture: $ARCH"

    case "$ARCH" in
        x86_64|amd64)
            ARCH_TYPE="amd64"
            log_success "Architecture supported: x86_64"
            ;;
        aarch64|arm64)
            ARCH_TYPE="arm64"
            log_success "Architecture supported: ARM64"
            ;;
        armv7l)
            ARCH_TYPE="armv7"
            log_warn "ARM v7 detected - some services may have limited support"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            log_info "Supported architectures: x86_64, ARM64"
            exit 1
            ;;
    esac
}

#############################################
# System Requirements Check
#############################################

check_system_requirements() {
    log_step "Checking System Requirements"

    log_verbose "Gathering system information..."

    local cpu_cores=$(nproc)
    local total_ram=$(free -g | awk 'NR==2 {print $2}')
    local total_disk=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
    local available_disk=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

    log_info "CPU Cores: $cpu_cores"
    log_info "Total RAM: ${total_ram}GB"
    log_info "Root Disk: ${total_disk}GB (${available_disk}GB available)"

    log_debug "CPU Model: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
    log_debug "CPU MHz: $(lscpu | grep 'CPU MHz' | cut -d':' -f2 | xargs)"

    # Check minimum requirements
    log_verbose "Validating minimum requirements..."
    local requirements_met=true

    show_progress 1 4 "Checking CPU"
    if [[ $cpu_cores -lt 2 ]]; then
        log_error "Minimum 2 CPU cores required (detected: $cpu_cores)"
        requirements_met=false
    fi

    show_progress 2 4 "Checking RAM"
    if [[ $total_ram -lt 4 ]]; then
        log_error "Minimum 4GB RAM required (detected: ${total_ram}GB)"
        requirements_met=false
    fi

    show_progress 3 4 "Checking Disk Space"
    if [[ $total_disk -lt 50 ]]; then
        log_error "Minimum 50GB disk space required (detected: ${total_disk}GB)"
        requirements_met=false
    fi

    show_progress 4 4 "Validation Complete"

    if [[ "$requirements_met" == false ]]; then
        log_error "System does not meet minimum requirements"
        exit 1
    fi

    # Warnings for recommended specs
    log_verbose "Checking recommended specifications..."
    if [[ $cpu_cores -lt 8 ]]; then
        log_warn "Recommended: 8+ CPU cores for optimal performance"
    fi

    if [[ $total_ram -lt 32 ]]; then
        log_warn "Recommended: 32GB+ RAM for full deployment"
    fi

    if [[ $total_disk -lt 500 ]]; then
        log_warn "Recommended: 500GB+ disk space for logs and backups"
    fi

    log_success "System requirements check passed"
}

#############################################
# Install Prerequisites
#############################################

install_prerequisites_apt() {
    log_step "Installing Prerequisites (APT)"

    log_verbose "Updating package index..."
    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
        log_command "apt-get update"
    else
        run_with_spinner "Updating package index" "apt-get update -qq"
    fi

    log_verbose "Installing required packages..."
    log_debug "Package list: apt-transport-https ca-certificates curl gnupg lsb-release git wget software-properties-common ufw fail2ban unattended-upgrades jq htop net-tools dnsutils"

    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
        log_info "Installing packages (this may take a few minutes)..."
        log_command "DEBIAN_FRONTEND=noninteractive apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release \
            git \
            wget \
            software-properties-common \
            ufw \
            fail2ban \
            unattended-upgrades \
            jq \
            htop \
            net-tools \
            dnsutils"
    else
        run_with_spinner "Installing required packages" \
            "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release \
                git \
                wget \
                software-properties-common \
                ufw \
                fail2ban \
                unattended-upgrades \
                jq \
                htop \
                net-tools \
                dnsutils"
    fi

    log_success "Prerequisites installed"
}

install_prerequisites_dnf() {
    log_step "Installing Prerequisites (DNF/YUM)"

    log_info "Installing required packages..."
    dnf install -y -q \
        ca-certificates \
        curl \
        gnupg \
        git \
        wget \
        firewalld \
        fail2ban \
        jq \
        htop \
        net-tools \
        bind-utils \
        > /dev/null 2>&1

    log_success "Prerequisites installed"
}

#############################################
# Docker Installation
#############################################

version_ge() {
    # Compare versions: return 0 if $1 >= $2
    printf '%s\n%s' "$2" "$1" | sort -V -C
}

install_docker() {
    log_step "Installing Docker"

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        log_info "Docker already installed: $docker_version"

        if version_ge "$docker_version" "$MIN_DOCKER_VERSION"; then
            log_success "Docker version is sufficient"
            return 0
        else
            log_warn "Docker version $docker_version is below minimum $MIN_DOCKER_VERSION"
            log_info "Upgrading Docker..."
        fi
    fi

    case "$PKG_MANAGER" in
        apt)
            install_docker_apt
            ;;
        dnf)
            install_docker_dnf
            ;;
    esac

    # Start and enable Docker
    log_info "Starting Docker service..."
    systemctl start docker
    systemctl enable docker

    # Verify installation
    local docker_version=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
    log_success "Docker installed: $docker_version"
}

install_docker_apt() {
    log_verbose "Installing Docker via APT..."

    log_debug "Adding Docker GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    else
        run_with_spinner "Adding Docker GPG key" \
            "curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
    fi
    chmod a+r /etc/apt/keyrings/docker.gpg

    log_debug "Adding Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    log_verbose "Updating package index with Docker repository..."
    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
        log_command "apt-get update"
    else
        run_with_spinner "Updating package index" "apt-get update -qq"
    fi

    log_verbose "Installing Docker packages..."
    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
        log_command "DEBIAN_FRONTEND=noninteractive apt-get install -y \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin"
    else
        run_with_spinner "Installing Docker Engine" \
            "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
                docker-ce \
                docker-ce-cli \
                containerd.io \
                docker-buildx-plugin \
                docker-compose-plugin"
    fi
}

install_docker_dnf() {
    log_info "Installing Docker via DNF..."

    # Add Docker repository
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    # Install Docker
    dnf install -y -q \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        > /dev/null 2>&1
}

#############################################
# Docker Compose Check
#############################################

check_docker_compose() {
    log_step "Checking Docker Compose"

    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version --short)
        log_info "Docker Compose installed: $compose_version"

        if version_ge "$compose_version" "$MIN_COMPOSE_VERSION"; then
            log_success "Docker Compose version is sufficient"
        else
            log_warn "Docker Compose version $compose_version is below recommended $MIN_COMPOSE_VERSION"
        fi
    else
        log_error "Docker Compose plugin not found"
        exit 1
    fi
}

#############################################
# Clone Repository
#############################################

clone_repository() {
    log_step "Cloning VPS2.0 Repository"

    if [[ -d "$INSTALL_DIR" ]]; then
        log_warn "Installation directory already exists: $INSTALL_DIR"

        # Check if it's a git repository
        if [[ -d "$INSTALL_DIR/.git" ]]; then
            log_info "Updating existing repository..."
            log_verbose "Fetching latest changes from origin..."

            cd "$INSTALL_DIR"

            if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
                log_command "git fetch origin"
                log_command "git reset --hard origin/main"
            else
                run_with_spinner "Updating repository" "git fetch origin && git reset --hard origin/main"
            fi

            log_success "Repository updated"
        else
            log_error "Directory exists but is not a git repository"
            log_info "Please remove or rename: $INSTALL_DIR"
            exit 1
        fi
    else
        log_info "Cloning from: $REPO_URL"
        log_info "Installing to: $INSTALL_DIR"
        log_debug "Git clone command: git clone $REPO_URL $INSTALL_DIR"

        if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
            git clone "$REPO_URL" "$INSTALL_DIR"
            local clone_result=$?
        else
            run_with_spinner "Cloning VPS2.0 repository" "git clone $REPO_URL $INSTALL_DIR"
            local clone_result=$?
        fi

        if [[ $clone_result -eq 0 ]]; then
            log_success "Repository cloned successfully"
        else
            log_error "Failed to clone repository"
            exit 1
        fi
    fi

    cd "$INSTALL_DIR"
    log_debug "Working directory: $(pwd)"
}

#############################################
# Setup Permissions
#############################################

setup_permissions() {
    log_step "Setting Up Permissions"

    # Make scripts executable
    chmod +x "$INSTALL_DIR"/scripts/*.sh

    # Create required directories
    mkdir -p "$INSTALL_DIR"/{caddy,grafana,homepage,loki,prometheus,postgres,redis,neo4j,vector}

    log_success "Permissions configured"
}

#############################################
# Launch Setup Wizard
#############################################

launch_setup_wizard() {
    log_step "Launching Interactive Setup Wizard"

    echo ""
    log_info "Starting VPS2.0 Setup Wizard..."
    echo ""

    sleep 2

    if [[ -f "$INSTALL_DIR/scripts/setup-wizard.sh" ]]; then
        bash "$INSTALL_DIR/scripts/setup-wizard.sh"
    else
        log_error "Setup wizard not found: $INSTALL_DIR/scripts/setup-wizard.sh"
        log_info "You can manually configure and deploy:"
        echo ""
        echo "  cd $INSTALL_DIR"
        echo "  cp .env.template .env"
        echo "  nano .env  # Configure your settings"
        echo "  bash scripts/deploy.sh"
        exit 1
    fi
}

#############################################
# Error Handler
#############################################

error_handler() {
    local line_number=$1
    log_error "Installation failed at line $line_number"
    log_info "Please check the error messages above and try again"
    log_info "For support, visit: https://github.com/SWORDIntel/VPS2.0/issues"
    exit 1
}

trap 'error_handler ${LINENO}' ERR

#############################################
# Cleanup on Exit
#############################################

cleanup() {
    # Remove temporary files if any
    rm -f /tmp/vps2-install-*.tmp 2>/dev/null || true
}

trap cleanup EXIT

#############################################
# Main Installation Flow
#############################################

main() {
    # Parse command line arguments
    parse_arguments "$@"

    print_banner

    log_info "Starting automated installation..."
    log_debug "Script version: $SCRIPT_VERSION"
    log_debug "Install directory: $INSTALL_DIR"
    log_debug "Repository URL: $REPO_URL"
    echo ""

    # Pre-flight checks
    log_verbose "Beginning pre-flight checks..."
    check_root
    detect_os
    detect_arch
    check_system_requirements

    # Install components
    log_verbose "Installing system components..."
    case "$PKG_MANAGER" in
        apt)
            install_prerequisites_apt
            ;;
        dnf)
            install_prerequisites_dnf
            ;;
    esac

    install_docker
    check_docker_compose

    # Setup VPS2.0
    log_verbose "Setting up VPS2.0..."
    clone_repository
    setup_permissions

    # Success summary
    log_step "Installation Prerequisites Complete"

    echo -e "${GREEN}${BOLD}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║   PREREQUISITES INSTALLED SUCCESSFULLY                      ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    log_success "Docker Engine: Installed"
    log_success "Docker Compose: Installed"
    log_success "VPS2.0 Repository: Cloned"
    log_success "Installation Directory: $INSTALL_DIR"

    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
        log_verbose "Docker version: $(docker --version)"
        log_verbose "Docker Compose version: $(docker compose version --short)"
        log_verbose "Git version: $(git --version)"
    fi

    echo ""
    log_info "Next: Interactive Setup Wizard"
    echo ""

    # Launch wizard
    launch_setup_wizard
}

#############################################
# Execute Main
#############################################

main "$@"
