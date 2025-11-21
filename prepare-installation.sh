#!/usr/bin/env bash
#
# VPS2.0 Installation Preparation Script
#
# This script prepares the VPS2.0 environment for installation by:
# - Initializing all submodules to track their respective main/master branches
# - Verifying system requirements
# - Setting up necessary dependencies
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo "============================================="
echo "  VPS2.0 Installation Preparation"
echo "============================================="
echo ""

# Check if running from VPS2.0 root
if [ ! -f "docker-compose.yml" ] || [ ! -f ".gitmodules" ]; then
    log_error "This script must be run from the VPS2.0 root directory"
    exit 1
fi

log_info "Checking system requirements..."

# Check for required commands
REQUIRED_COMMANDS=("git" "docker" "docker-compose")
MISSING_COMMANDS=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_COMMANDS+=("$cmd")
    fi
done

if [ ${#MISSING_COMMANDS[@]} -ne 0 ]; then
    log_error "Missing required commands: ${MISSING_COMMANDS[*]}"
    log_info "Please install the missing dependencies before running this script"
    exit 1
fi

log_success "All required commands are available"

# Initialize and update submodules
log_info "Initializing submodules..."

if git submodule sync; then
    log_success "Submodule URLs synchronized"
else
    log_error "Failed to sync submodule URLs"
    exit 1
fi

# Update submodules to track remote branches
log_info "Updating submodules to track remote branches..."
if git submodule update --init --remote --recursive 2>&1 | tee /tmp/submodule_update.log; then
    log_success "Submodules updated successfully"
else
    if grep -q "ARTICBASTION" /tmp/submodule_update.log; then
        log_warning "ARTICBASTION submodule requires authentication"
        log_warning "This is a private repository. Please set up SSH keys or use a personal access token"
        log_info "Continuing with other submodules..."
    else
        log_error "Failed to update submodules"
        exit 1
    fi
fi

# Display submodule status
log_info "Submodule status:"
echo ""
git submodule status
echo ""

# Check for ARTICBASTION
if [ ! -d "external/ARTICBASTION/.git" ]; then
    log_warning "ARTICBASTION submodule is not initialized"
    log_info "To manually initialize ARTICBASTION, you can:"
    log_info "  1. Set up SSH authentication with GitHub"
    log_info "  2. Run: git submodule update --init --remote external/ARTICBASTION"
    echo ""
fi

# Verify branch tracking
log_info "Verifying submodule branch tracking..."
echo ""

for submodule in external/*/; do
    if [ -d "$submodule/.git" ]; then
        submodule_name=$(basename "$submodule")
        branch=$(git config -f .gitmodules submodule."$submodule".branch || echo "none")
        current_branch=$(cd "$submodule" && git rev-parse --abbrev-ref HEAD)

        if [ "$branch" != "none" ]; then
            if [ "$current_branch" == "$branch" ]; then
                log_success "$submodule_name: tracking $branch ✓"
            else
                log_warning "$submodule_name: on $current_branch, expected $branch"
            fi
        else
            log_warning "$submodule_name: no branch tracking configured"
        fi
    fi
done
echo ""

# Check Docker installation
log_info "Checking Docker installation..."
if docker --version > /dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    log_success "Docker version: $DOCKER_VERSION"
else
    log_error "Docker is not installed or not accessible"
    exit 1
fi

if docker-compose --version > /dev/null 2>&1; then
    COMPOSE_VERSION=$(docker-compose --version | awk '{print $4}' | tr -d ',')
    log_success "Docker Compose version: $COMPOSE_VERSION"
else
    log_error "Docker Compose is not installed or not accessible"
    exit 1
fi

# Check Docker daemon
if docker ps > /dev/null 2>&1; then
    log_success "Docker daemon is running"
else
    log_error "Docker daemon is not running or you don't have permission to access it"
    log_info "Try running this script with sudo or add your user to the docker group"
    exit 1
fi

# Display next steps
echo ""
echo "============================================="
echo "  Preparation Complete!"
echo "============================================="
echo ""
log_success "VPS2.0 is ready for installation"
echo ""
log_info "Next steps:"
echo "  1. Review the configuration in .env.template and create .env file"
echo "  2. Run the unified deployment manager:"
echo "     $ sudo ./deploy-vps2.sh"
echo ""
echo "  Or use specific deployment scripts:"
echo "     $ sudo ./scripts/deploy.sh              # Core services"
echo "     $ sudo ./scripts/mattermost/initial-setup.sh  # Mattermost"
echo "     $ sudo ./scripts/polygotya-quickstart.sh      # POLYGOTYA"
echo ""
log_info "For more information, see:"
echo "  - README.md"
echo "  - QUICKSTART.md"
echo "  - docs/DEPLOYMENT_GUIDE.md"
echo ""
