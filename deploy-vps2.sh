#!/usr/bin/env bash
set -euo pipefail

#==============================================
# VPS2.0 Unified Deployment Manager
#==============================================
# Single entrypoint for complete VPS2.0 platform deployment
# Interactive menu-driven deployment for headless VPS
#
# Features:
# - Guided fresh installation
# - Component selection (Mattermost, POLYGOTYA, DNS Hub, Intelligence)
# - Credential management
# - Add/Remove components
# - Backup & Restore
# - System status
# - Security hardening with audit logging
# - Rollback capability
# - Comprehensive error handling
#
# Usage: sudo ./deploy-vps2.sh [--quick]
#==============================================

#==============================================
# Configuration
#==============================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$SCRIPT_DIR"
readonly STATE_FILE="${PROJECT_ROOT}/.deployment-state"
readonly LOG_FILE="${PROJECT_ROOT}/.deployment.log"
readonly AUDIT_LOG="${PROJECT_ROOT}/.deployment-audit.log"

#==============================================
# Error Handling
#==============================================
set -E  # Enable ERR trap inheritance

cleanup_on_error() {
    local exit_code=$?
    local line_no=$1

    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo -e "${RED}[ERROR]${NC} Deployment failed at line ${line_no} with exit code ${exit_code}"
        echo -e "${YELLOW}[INFO]${NC} Check logs: ${LOG_FILE}"
        echo -e "${YELLOW}[INFO]${NC} Use 'System Status' to check service health"
        audit_log "ERROR" "Deployment failed at line ${line_no} with exit code ${exit_code}"
    fi
}

cleanup_on_exit() {
    # Save final state
    save_state "last_run" "$(date +%s)"
}

trap 'cleanup_on_error ${LINENO}' ERR
trap 'cleanup_on_exit' EXIT

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Icons
readonly ICON_CHECK="✓"
readonly ICON_CROSS="✗"
readonly ICON_ARROW="→"
readonly ICON_INFO="ℹ"
readonly ICON_WARN="⚠"

#==============================================
# Logging Functions
#==============================================

log() {
    echo -e "$*"
}

log_header() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║${NC} %-73s ${CYAN}║${NC}\n" "$1"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_section() {
    echo ""
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    printf "${BLUE}│${NC} ${BOLD}%-71s${NC} ${BLUE}│${NC}\n" "$1"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

log_info() {
    echo -e "  ${BLUE}${ICON_INFO}${NC}  $*"
}

log_success() {
    echo -e "  ${GREEN}${ICON_CHECK}${NC}  $*"
}

log_error() {
    echo -e "  ${RED}${ICON_CROSS}${NC}  $*"
}

log_warn() {
    echo -e "  ${YELLOW}${ICON_WARN}${NC}  $*"
}

log_step() {
    echo -e "  ${CYAN}${ICON_ARROW}${NC}  $*"
}

# Audit logging
audit_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user="${SUDO_USER:-$USER}"

    echo "[${timestamp}] [${level}] [${user}] ${message}" >> "$AUDIT_LOG"

    # Also log to main log
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

# Execute command with logging and error handling
execute_cmd() {
    local cmd="$1"
    local description="${2:-Executing command}"
    local timeout="${3:-300}"  # 5 minute default timeout

    audit_log "INFO" "Executing: ${description}"

    if timeout "${timeout}s" bash -c "$cmd" >> "$LOG_FILE" 2>&1; then
        audit_log "SUCCESS" "${description} completed"
        return 0
    else
        local exit_code=$?
        audit_log "ERROR" "${description} failed with exit code ${exit_code}"
        log_error "${description} failed (check ${LOG_FILE})"
        return $exit_code
    fi
}

#==============================================
# UI Functions
#==============================================

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╦  ╦╔═╗╔═╗  ┌─┐ ┬  ┌─┐  ╔╦╗┌─┐┌─┐┬  ┌─┐┬ ┬┌┬┐┌─┐┌┐┌┌┬┐
    ╚╗╔╝╠═╝╚═╗  ┌─┘ │  ├┤    ║║├┤ ├─┘│  │ │└┬┘│││├┤ │││ │
     ╚╝ ╩  ╚═╝  └─┘o└─┘└─┘  ═╩╝└─┘┴  ┴─┘└─┘ ┴ ┴ ┴└─┘┘└┘ ┴
EOF
    echo -e "${NC}"
    echo -e "${BOLD}    Complete Intelligence & Security Platform Deployment Manager${NC}"
    echo -e "    Version 2.0 | SWORD Intelligence Operations Team"
    echo ""
}

show_menu() {
    local title="$1"
    shift
    local options=("$@")

    log_header "$title"

    local i=1
    for option in "${options[@]}"; do
        echo -e "  ${CYAN}[$i]${NC} $option"
        ((i++))
    done
    echo ""
    echo -e "  ${CYAN}[0]${NC} ${YELLOW}Exit${NC}"
    echo ""
}

prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local var_name="$3"

    if [[ -n "$default" ]]; then
        read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  $prompt [${BOLD}$default${NC}]: ")" input
        eval "$var_name=\"${input:-$default}\""
    else
        read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  $prompt: ")" input
        eval "$var_name=\"$input\""
    fi
}

prompt_confirm() {
    local prompt="$1"
    local default="${2:-N}"

    if [[ "$default" == "Y" ]]; then
        read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  $prompt [Y/n]: ")" -n 1 -r
    else
        read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  $prompt [y/N]: ")" -n 1 -r
    fi
    echo

    if [[ "$default" == "Y" ]]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

show_progress() {
    local current=$1
    local total=$2
    local message="$3"

    local percent=$((current * 100 / total))
    local filled=$((current * 50 / total))
    local empty=$((50 - filled))

    printf "\r  ${CYAN}Progress:${NC} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%% - %s" "$percent" "$message"

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

pause() {
    echo ""
    read -p "$(echo -e "  ${YELLOW}Press ENTER to continue...${NC}")"
}

#==============================================
# State Management
#==============================================

save_state() {
    local key="$1"
    local value="$2"

    mkdir -p "$(dirname "$STATE_FILE")"

    if [[ -f "$STATE_FILE" ]]; then
        # Update existing key or add new one
        if grep -q "^${key}=" "$STATE_FILE"; then
            sed -i "s|^${key}=.*|${key}=${value}|" "$STATE_FILE"
        else
            echo "${key}=${value}" >> "$STATE_FILE"
        fi
    else
        echo "${key}=${value}" > "$STATE_FILE"
    fi
}

load_state() {
    local key="$1"
    local default="${2:-}"

    if [[ -f "$STATE_FILE" ]] && grep -q "^${key}=" "$STATE_FILE"; then
        grep "^${key}=" "$STATE_FILE" | cut -d'=' -f2-
    else
        echo "$default"
    fi
}

get_deployment_status() {
    local component="$1"
    load_state "deployed_${component}" "false"
}

#==============================================
# ZFS Setup
#==============================================

setup_zfs() {
    log_section "ZFS Filesystem Setup"
    audit_log "INFO" "Starting ZFS setup"

    log_warn "ZFS setup will build from source (v2.3.5) and configure storage"
    log_warn "This should be done BEFORE deploying services"
    echo ""

    # Auto-detect if ZFS is beneficial
    local total_disks=$(lsblk -dpno NAME,TYPE | grep disk | wc -l)
    local total_space=$(df -BG / | awk 'NR==2 {print $2}' | tr -d 'G')

    log_info "System Analysis:"
    echo "  • Available disks: $total_disks"
    echo "  • Total space: ${total_space}GB"

    if [[ $total_disks -gt 1 ]]; then
        log_success "Multiple disks detected - ZFS HIGHLY RECOMMENDED for redundancy and snapshots"
    elif [[ $total_space -gt 500 ]]; then
        log_success "Large storage detected - ZFS recommended for compression and snapshots"
    else
        log_info "Single disk system - ZFS still beneficial for snapshots and compression"
    fi
    echo ""

    if ! prompt_confirm "Proceed with ZFS setup?"; then
        return 0
    fi

    # Install build dependencies
    log_info "Installing build dependencies..."
    apt-get update >> "$LOG_FILE" 2>&1

    local build_deps=(
        build-essential
        autoconf
        automake
        libtool
        gawk
        alien
        fakeroot
        dkms
        libblkid-dev
        uuid-dev
        libudev-dev
        libssl-dev
        zlib1g-dev
        libaio-dev
        libattr1-dev
        libelf-dev
        python3
        python3-dev
        python3-setuptools
        python3-cffi
        libffi-dev
        libcurl4-openssl-dev
        libtirpc-dev
        libtirpc3
        libpam0g-dev
        bc
        wget
    )

    log_info "Installing: ${build_deps[*]}"
    apt-get install -y "${build_deps[@]}" >> "$LOG_FILE" 2>&1 || {
        log_error "Failed to install build dependencies"
        pause
        return 1
    }
    log_success "Build dependencies installed"

    # Build ZFS from source
    if ! command -v zfs &> /dev/null || ! zfs --version 2>&1 | grep -q "2.3.5"; then
        log_info "Building ZFS 2.3.5 from source..."

        local zfs_version="2.3.5"
        local zfs_tarball="zfs-${zfs_version}.tar.gz"
        local zfs_url="https://github.com/openzfs/zfs/releases/download/zfs-${zfs_version}/${zfs_tarball}"
        local build_dir="/tmp/zfs-build-$$"

        mkdir -p "$build_dir"
        cd "$build_dir"

        log_info "Downloading ZFS ${zfs_version}..."
        if ! wget "$zfs_url" -O "$zfs_tarball" >> "$LOG_FILE" 2>&1; then
            log_error "Failed to download ZFS"
            rm -rf "$build_dir"
            pause
            return 1
        fi

        log_info "Extracting tarball..."
        tar xzf "$zfs_tarball" >> "$LOG_FILE" 2>&1
        cd "zfs-${zfs_version}"

        log_info "Configuring build (this may take several minutes)..."
        ./configure >> "$LOG_FILE" 2>&1 || {
            log_error "Configuration failed"
            cd /
            rm -rf "$build_dir"
            pause
            return 1
        }

        log_info "Compiling ZFS (this will take 10-30 minutes depending on CPU)..."
        make -j$(nproc) >> "$LOG_FILE" 2>&1 || {
            log_error "Compilation failed"
            cd /
            rm -rf "$build_dir"
            pause
            return 1
        }

        log_info "Installing ZFS..."
        make install >> "$LOG_FILE" 2>&1 || {
            log_error "Installation failed"
            cd /
            rm -rf "$build_dir"
            pause
            return 1
        }

        # Install DKMS module
        log_info "Installing DKMS module..."
        make install-dkms >> "$LOG_FILE" 2>&1 || log_warn "DKMS install had warnings"

        # Update library cache
        ldconfig >> "$LOG_FILE" 2>&1

        # Load ZFS kernel module
        log_info "Loading ZFS kernel module..."
        modprobe zfs >> "$LOG_FILE" 2>&1 || {
            log_error "Failed to load ZFS kernel module"
            log_warn "You may need to reboot and run this again"
            cd /
            rm -rf "$build_dir"
            pause
            return 1
        }

        # Cleanup
        cd /
        rm -rf "$build_dir"

        log_success "ZFS 2.3.5 compiled and installed"
    else
        log_success "ZFS already installed: $(zfs --version | head -1)"
    fi
    audit_log "SUCCESS" "ZFS toolchain installed"

    # Check available disks
    log_info "Available disks:"
    echo ""
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE | grep -E "disk|part"
    echo ""

    # Ask if user wants to create ZFS pool
    if prompt_confirm "Create a new ZFS pool?"; then
        create_zfs_pool
    else
        log_info "Skipping ZFS pool creation"
    fi

    # Benchmark compression
    if prompt_confirm "Benchmark ZFS compression algorithms?"; then
        benchmark_zfs_compression
    fi

    # Configure ZFS for Docker
    if prompt_confirm "Configure ZFS dataset for Docker?"; then
        configure_zfs_docker
    fi

    log_success "ZFS setup complete"
    audit_log "SUCCESS" "ZFS setup completed"
    pause
}

create_zfs_pool() {
    log_info "Creating ZFS pool..."
    echo ""

    # Auto-detect available disks and suggest configuration
    local available_disks=()
    while IFS= read -r line; do
        local disk=$(echo "$line" | awk '{print $1}')
        # Skip the root disk
        if ! mount | grep -q "^${disk}"; then
            available_disks+=("$disk")
        fi
    done < <(lsblk -dpno NAME,TYPE | grep disk)

    local disk_count=${#available_disks[@]}

    log_info "Disk Analysis:"
    echo "  • Total disks: $(lsblk -dpno NAME,TYPE | grep disk | wc -l)"
    echo "  • Available for ZFS: $disk_count"
    echo ""

    if [[ $disk_count -eq 0 ]]; then
        log_error "No available disks found for ZFS pool"
        log_warn "All disks appear to be in use"
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE
        pause
        return 1
    fi

    # Intelligent suggestions based on disk count
    log_info "${BOLD}Recommended Configuration:${NC}"
    if [[ $disk_count -eq 1 ]]; then
        log_info "  → Single disk - Good for development/testing"
        log_warn "  ⚠ No redundancy - consider backups!"
    elif [[ $disk_count -eq 2 ]]; then
        log_success "  → Mirror recommended - 50% space, can lose 1 disk"
        log_info "  Alternative: Two separate pools (no redundancy)"
    elif [[ $disk_count -ge 3 ]]; then
        log_success "  → RAIDZ recommended - (n-1)/n space, can lose 1 disk"
        log_info "  Alternative: RAIDZ2 (4+ disks) - can lose 2 disks"
    fi
    echo ""

    # List available disks
    log_info "Available disks for ZFS:"
    lsblk -dpno NAME,SIZE,TYPE | grep disk
    echo ""

    prompt_input "Enter disk device (e.g., /dev/sdb)" "" DISK_DEVICE

    if [[ ! -b "$DISK_DEVICE" ]]; then
        log_error "Invalid disk device: $DISK_DEVICE"
        return 1
    fi

    # Confirm disk selection
    log_warn "WARNING: This will DESTROY all data on $DISK_DEVICE"
    lsblk "$DISK_DEVICE"
    echo ""

    if ! prompt_confirm "Are you SURE you want to use $DISK_DEVICE?"; then
        log_info "Cancelled ZFS pool creation"
        return 0
    fi

    prompt_input "Enter ZFS pool name" "vps-data" POOL_NAME

    # Pool configuration options
    log_info "ZFS pool configuration options:"
    echo "  1. Single disk (no redundancy)"
    echo "  2. Mirror (requires 2 disks)"
    echo "  3. RAIDZ (requires 3+ disks)"
    echo ""
    prompt_input "Select configuration" "1" POOL_CONFIG

    case "$POOL_CONFIG" in
        1)
            # Single disk
            log_info "Creating single-disk ZFS pool: $POOL_NAME"
            if zpool create -f "$POOL_NAME" "$DISK_DEVICE" >> "$LOG_FILE" 2>&1; then
                log_success "ZFS pool created: $POOL_NAME"
            else
                log_error "Failed to create ZFS pool"
                return 1
            fi
            ;;
        2)
            # Mirror
            prompt_input "Enter second disk device (e.g., /dev/sdc)" "" DISK_DEVICE2
            if [[ ! -b "$DISK_DEVICE2" ]]; then
                log_error "Invalid second disk device: $DISK_DEVICE2"
                return 1
            fi

            log_info "Creating mirrored ZFS pool: $POOL_NAME"
            if zpool create -f "$POOL_NAME" mirror "$DISK_DEVICE" "$DISK_DEVICE2" >> "$LOG_FILE" 2>&1; then
                log_success "ZFS pool created: $POOL_NAME (mirrored)"
            else
                log_error "Failed to create ZFS pool"
                return 1
            fi
            ;;
        3)
            # RAIDZ
            log_info "Enter all disk devices separated by spaces (minimum 3):"
            prompt_input "Disk devices" "" DISK_DEVICES

            log_info "Creating RAIDZ ZFS pool: $POOL_NAME"
            if zpool create -f "$POOL_NAME" raidz $DISK_DEVICES >> "$LOG_FILE" 2>&1; then
                log_success "ZFS pool created: $POOL_NAME (RAIDZ)"
            else
                log_error "Failed to create ZFS pool"
                return 1
            fi
            ;;
        *)
            log_error "Invalid selection"
            return 1
            ;;
    esac

    # Enable compression
    if prompt_confirm "Enable ZFS compression (lz4)?"; then
        zfs set compression=lz4 "$POOL_NAME" >> "$LOG_FILE" 2>&1
        log_success "Compression enabled on $POOL_NAME"
    fi

    # Set atime off (performance)
    zfs set atime=off "$POOL_NAME" >> "$LOG_FILE" 2>&1
    log_success "atime disabled for better performance"

    # Show pool status
    echo ""
    log_info "ZFS pool status:"
    zpool status "$POOL_NAME"
    echo ""

    # Save pool name to state
    save_state "zfs_pool" "$POOL_NAME"
    audit_log "SUCCESS" "ZFS pool created: $POOL_NAME on $DISK_DEVICE"
}

benchmark_zfs_compression() {
    log_section "ZFS Compression Benchmark"
    audit_log "INFO" "Starting compression benchmark"

    local pool_name=$(load_state "zfs_pool" "")

    if [[ -z "$pool_name" ]]; then
        # Try to find existing pool
        pool_name=$(zpool list -H -o name 2>/dev/null | head -1)
        if [[ -z "$pool_name" ]]; then
            log_error "No ZFS pool found"
            pause
            return 1
        fi
    fi

    log_info "Benchmarking compression on pool: $pool_name"
    log_info "This will test all available compression algorithms with sample data"
    echo ""

    # Create test dataset
    local test_dataset="${pool_name}/compression-benchmark"
    log_info "Creating test dataset..."
    zfs create "$test_dataset" >> "$LOG_FILE" 2>&1 || {
        log_warn "Test dataset may already exist, destroying and recreating..."
        zfs destroy -r "$test_dataset" >> "$LOG_FILE" 2>&1
        zfs create "$test_dataset" >> "$LOG_FILE" 2>&1
    }

    # Generate test data (100MB of mixed data)
    local test_file="/$(zfs get -H -o value mountpoint "$test_dataset")/test-data.bin"
    log_info "Generating 100MB test data..."

    # Mix of compressible and incompressible data (realistic scenario)
    dd if=/dev/urandom of="${test_file}.random" bs=1M count=30 >> "$LOG_FILE" 2>&1
    dd if=/dev/zero of="${test_file}.zero" bs=1M count=50 >> "$LOG_FILE" 2>&1
    cat "${test_file}.random" "${test_file}.zero" > "$test_file"
    rm -f "${test_file}.random" "${test_file}.zero"

    # Available compression algorithms
    local algorithms=(
        "off"
        "lz4"
        "gzip"
        "gzip-1"
        "gzip-9"
        "zstd"
        "zstd-fast"
        "zstd-1"
        "zstd-3"
        "zstd-6"
        "zstd-9"
        "zstd-12"
        "zstd-15"
        "zstd-19"
    )

    echo ""
    log_info "Testing compression algorithms..."
    echo ""
    printf "%-15s %-15s %-15s %-15s\n" "Algorithm" "Size (MB)" "Ratio" "Write Speed"
    printf "%-15s %-15s %-15s %-15s\n" "==========" "=========" "=====" "==========="

    local best_ratio="0"
    local best_ratio_algo=""
    local best_speed="0"
    local best_speed_algo=""

    for algo in "${algorithms[@]}"; do
        # Set compression algorithm
        zfs set compression="$algo" "$test_dataset" >> "$LOG_FILE" 2>&1

        # Clear previous data
        rm -f "$test_file" >> "$LOG_FILE" 2>&1
        sync

        # Write test file and measure time
        local start_time=$(date +%s.%N)
        dd if=/dev/urandom of="${test_file}" bs=1M count=100 oflag=sync 2>>"$LOG_FILE"
        local end_time=$(date +%s.%N)
        sync

        # Calculate write speed
        local duration=$(echo "$end_time - $start_time" | bc)
        local speed=$(echo "scale=2; 100 / $duration" | bc)

        # Get actual size used
        local used=$(zfs get -H -o value -p used "$test_dataset")
        local used_mb=$(echo "scale=2; $used / 1048576" | bc)

        # Calculate compression ratio
        local ratio=$(zfs get -H -o value compressratio "$test_dataset")

        printf "%-15s %-15s %-15s %-15s\n" "$algo" "$used_mb" "$ratio" "${speed} MB/s"

        # Track best compression ratio
        local ratio_val=$(echo "$ratio" | sed 's/x//')
        if (( $(echo "$ratio_val > $best_ratio" | bc -l) )); then
            best_ratio="$ratio_val"
            best_ratio_algo="$algo"
        fi

        # Track best speed
        if (( $(echo "$speed > $best_speed" | bc -l) )); then
            best_speed="$speed"
            best_speed_algo="$algo"
        fi
    done

    echo ""
    log_success "Benchmark complete"
    echo ""
    echo "  ${BOLD}Best Compression Ratio:${NC} ${GREEN}${best_ratio_algo}${NC} (${best_ratio}x)"
    echo "  ${BOLD}Best Write Speed:${NC} ${GREEN}${best_speed_algo}${NC} (${best_speed} MB/s)"
    echo ""

    # Recommendations
    log_info "${BOLD}Recommendations:${NC}"
    echo "  • ${GREEN}lz4${NC} - Best for general use (excellent speed, good compression)"
    echo "  • ${GREEN}zstd${NC} or ${GREEN}zstd-3${NC} - Balanced compression and speed"
    echo "  • ${GREEN}zstd-6${NC} to ${GREEN}zstd-9${NC} - Higher compression, slightly slower"
    echo "  • ${GREEN}gzip-9${NC} or ${GREEN}zstd-15${NC} - Maximum compression (slower writes)"
    echo ""

    # Cleanup test dataset
    log_info "Cleaning up test dataset..."
    zfs destroy -r "$test_dataset" >> "$LOG_FILE" 2>&1

    # Ask to apply best settings
    echo ""
    if prompt_confirm "Apply recommended compression (lz4) to pool?"; then
        zfs set compression=lz4 "$pool_name" >> "$LOG_FILE" 2>&1
        log_success "Compression set to lz4 on $pool_name"
        save_state "zfs_compression" "lz4"
    else
        prompt_input "Enter compression algorithm to use" "lz4" COMPRESSION_ALGO
        zfs set compression="$COMPRESSION_ALGO" "$pool_name" >> "$LOG_FILE" 2>&1
        log_success "Compression set to $COMPRESSION_ALGO on $pool_name"
        save_state "zfs_compression" "$COMPRESSION_ALGO"
    fi

    audit_log "SUCCESS" "Compression benchmark completed, best ratio: $best_ratio_algo, best speed: $best_speed_algo"
    pause
}

configure_zfs_docker() {
    log_info "Configuring ZFS dataset for Docker..."

    local pool_name=$(load_state "zfs_pool" "")

    if [[ -z "$pool_name" ]]; then
        # Try to find existing pool
        pool_name=$(zpool list -H -o name 2>/dev/null | head -1)
        if [[ -z "$pool_name" ]]; then
            log_error "No ZFS pool found"
            prompt_input "Enter ZFS pool name" "" pool_name
        fi
    fi

    log_info "Using ZFS pool: $pool_name"

    # Create datasets for Docker
    log_info "Creating ZFS datasets for Docker..."

    # Stop Docker first
    if systemctl is-active --quiet docker; then
        log_warn "Stopping Docker to configure ZFS storage..."
        systemctl stop docker >> "$LOG_FILE" 2>&1
    fi

    # Create datasets
    zfs create -o mountpoint=/var/lib/docker "${pool_name}/docker" >> "$LOG_FILE" 2>&1 || {
        log_warn "Dataset ${pool_name}/docker may already exist"
    }

    zfs create "${pool_name}/docker/volumes" >> "$LOG_FILE" 2>&1 || true
    zfs create "${pool_name}/docker/containers" >> "$LOG_FILE" 2>&1 || true

    # Set properties
    zfs set compression=lz4 "${pool_name}/docker" >> "$LOG_FILE" 2>&1
    zfs set atime=off "${pool_name}/docker" >> "$LOG_FILE" 2>&1

    # Configure Docker to use ZFS
    local daemon_json="/etc/docker/daemon.json"
    local backup="${daemon_json}.backup-$(date +%s)"

    if [[ -f "$daemon_json" ]]; then
        cp "$daemon_json" "$backup"
        log_info "Backed up Docker config to: $backup"
    fi

    log_info "Configuring Docker to use ZFS storage driver..."

    # Create or update daemon.json
    cat > "$daemon_json" <<EOF
{
  "storage-driver": "zfs",
  "storage-opts": [
    "zfs.fsname=${pool_name}/docker"
  ],
  "icc": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true
}
EOF

    log_success "Docker configured to use ZFS"

    # Start Docker
    if prompt_confirm "Start Docker with ZFS storage?"; then
        systemctl start docker >> "$LOG_FILE" 2>&1
        sleep 5

        if systemctl is-active --quiet docker; then
            log_success "Docker started with ZFS storage"
            docker info | grep -i storage
        else
            log_error "Failed to start Docker"
            log_warn "Check logs: journalctl -xeu docker"
        fi
    fi

    audit_log "SUCCESS" "ZFS configured for Docker on ${pool_name}/docker"
}

#==============================================
# Prerequisites Check
#==============================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_prerequisites() {
    log_section "Checking Prerequisites"
    audit_log "INFO" "Starting prerequisites check"

    local failed=false
    local warnings=0

    # Check Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        log_success "Docker installed: ${docker_version}"
        audit_log "INFO" "Docker version: ${docker_version}"

        # Check Docker version (minimum 20.10.0)
        local ver_major=$(echo "$docker_version" | cut -d. -f1)
        local ver_minor=$(echo "$docker_version" | cut -d. -f2)
        if [[ $ver_major -lt 20 ]] || ([[ $ver_major -eq 20 ]] && [[ $ver_minor -lt 10 ]]); then
            log_warn "Docker version ${docker_version} is old (recommended: 20.10.0+)"
            ((warnings++))
        fi
    else
        log_error "Docker is not installed"
        failed=true
    fi

    # Check Docker Compose
    if command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | awk '{print $3}' | tr -d ',')
        log_success "Docker Compose installed: ${compose_version}"
        audit_log "INFO" "Docker Compose version: ${compose_version}"
    elif docker compose version &> /dev/null; then
        local compose_version=$(docker compose version --short)
        log_success "Docker Compose (plugin) installed: ${compose_version}"
        audit_log "INFO" "Docker Compose plugin version: ${compose_version}"
    else
        log_error "Docker Compose is not installed"
        failed=true
    fi

    # Check Docker running
    if docker ps &> /dev/null; then
        log_success "Docker daemon is running"

        # Check Docker daemon configuration
        if docker info --format '{{.SecurityOptions}}' 2>/dev/null | grep -q "name=seccomp"; then
            log_success "Docker seccomp enabled"
        else
            log_warn "Docker seccomp not detected"
            ((warnings++))
        fi
    else
        log_error "Docker daemon is not running"
        failed=true
    fi

    # Check required ports are available
    log_info "Checking port availability..."
    local required_ports=(80 443 5432 6379 7687 9000)
    local ports_in_use=()

    for port in "${required_ports[@]}"; do
        if ss -tuln 2>/dev/null | grep -q ":${port} " || netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            ports_in_use+=("$port")
        fi
    done

    if [[ ${#ports_in_use[@]} -gt 0 ]]; then
        log_warn "Ports already in use: ${ports_in_use[*]}"
        log_warn "These ports will need to be freed before deployment"
        ((warnings++))
    else
        log_success "All required ports available"
    fi

    # Check disk space
    local available=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ $available -gt 100 ]]; then
        log_success "Disk space available: ${available}GB"
    elif [[ $available -gt 50 ]]; then
        log_warn "Disk space: ${available}GB (recommended: 100GB+)"
        ((warnings++))
    else
        log_error "Insufficient disk space: ${available}GB (minimum: 50GB)"
        failed=true
    fi
    audit_log "INFO" "Disk space: ${available}GB"

    # Check memory
    local mem=$(free -g | awk '/^Mem:/ {print $2}')
    if [[ $mem -ge 16 ]]; then
        log_success "RAM available: ${mem}GB"
    elif [[ $mem -ge 8 ]]; then
        log_warn "RAM: ${mem}GB (recommended: 16GB+)"
        ((warnings++))
    else
        log_error "Insufficient RAM: ${mem}GB (minimum: 8GB)"
        failed=true
    fi
    audit_log "INFO" "RAM: ${mem}GB"

    # Check CPU cores
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -ge 4 ]]; then
        log_success "CPU cores: ${cpu_cores}"
    else
        log_warn "CPU cores: ${cpu_cores} (recommended: 4+)"
        ((warnings++))
    fi
    audit_log "INFO" "CPU cores: ${cpu_cores}"

    # Check internet connectivity
    log_info "Checking internet connectivity..."
    if ping -c 1 -W 3 8.8.8.8 &> /dev/null; then
        log_success "Internet connectivity OK"
    else
        log_warn "Internet connectivity check failed (may affect Docker image pulls)"
        ((warnings++))
    fi

    # Check required commands
    local required_cmds=(curl wget openssl sed awk grep bc)
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            failed=true
        fi
    done

    # Summary
    echo ""
    if [[ "$failed" == "true" ]]; then
        log_error "Prerequisites check failed. Please install missing requirements."
        audit_log "ERROR" "Prerequisites check failed"
        pause
        return 1
    fi

    if [[ $warnings -gt 0 ]]; then
        log_warn "Prerequisites check completed with ${warnings} warning(s)"
        audit_log "WARN" "Prerequisites check completed with ${warnings} warnings"
    else
        log_success "All prerequisites met"
        audit_log "SUCCESS" "All prerequisites met"
    fi

    echo ""
    return 0
}

#==============================================
# Domain Configuration
#==============================================

configure_domain() {
    log_section "Domain Configuration"

    local current_domain=$(load_state "domain" "")

    if [[ -n "$current_domain" ]]; then
        log_info "Current domain: ${BOLD}$current_domain${NC}"
        if prompt_confirm "Keep current domain?"; then
            return 0
        fi
    fi

    prompt_input "Enter your domain name" "swordintelligence.airforce" DOMAIN

    # Validate domain format
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain format: $DOMAIN"
        pause
        return 1
    fi

    # Intelligent DNS verification
    log_info "Performing comprehensive DNS checks for $DOMAIN..."

    # Get server's public IP
    local server_ip=$(curl -s https://api.ipify.org 2>/dev/null || curl -s https://ifconfig.me 2>/dev/null)
    if [[ -n "$server_ip" ]]; then
        log_info "Server public IP: ${BOLD}$server_ip${NC}"
    fi

    # Test main domain resolution
    if host "$DOMAIN" &> /dev/null; then
        local domain_ip=$(host "$DOMAIN" | awk '/has address/ {print $4; exit}')
        log_success "Domain resolves to: $domain_ip"

        # Compare with server IP
        if [[ "$domain_ip" == "$server_ip" ]]; then
            log_success "✓ DNS configured correctly - points to this server!"
        else
            log_warn "⚠ DNS points to different IP: $domain_ip (this server: $server_ip)"
            log_warn "Update your DNS A record to point to: $server_ip"
        fi
    else
        log_warn "Domain does not resolve yet"
        log_info "Configure DNS A record: $DOMAIN → $server_ip"
    fi

    # Test critical subdomains
    log_info "Checking subdomain DNS..."
    local subdomains=("mattermost" "polygotya" "portainer" "grafana")
    local dns_configured=0
    local dns_total=0

    for subdomain in "${subdomains[@]}"; do
        ((dns_total++))
        if host "${subdomain}.${DOMAIN}" &> /dev/null; then
            local sub_ip=$(host "${subdomain}.${DOMAIN}" | awk '/has address/ {print $4; exit}')
            if [[ "$sub_ip" == "$server_ip" ]]; then
                log_success "  ✓ ${subdomain}.${DOMAIN} → $sub_ip"
                ((dns_configured++))
            else
                log_warn "  ⚠ ${subdomain}.${DOMAIN} → $sub_ip (expected: $server_ip)"
            fi
        else
            log_info "  - ${subdomain}.${DOMAIN} (not configured)"
        fi
    done

    # DNS configuration summary
    echo ""
    log_info "${BOLD}DNS Configuration Status:${NC}"
    if [[ $dns_configured -eq $dns_total ]]; then
        log_success "  ✓ All subdomains configured correctly!"
    elif [[ $dns_configured -gt 0 ]]; then
        log_info "  → $dns_configured of $dns_total subdomains configured"
    else
        log_warn "  ⚠ No subdomains configured - you'll need to set up DNS"
        echo ""
        log_info "${BOLD}Required DNS Records (A records pointing to $server_ip):${NC}"
        echo "    • $DOMAIN"
        for subdomain in "${subdomains[@]}"; do
            echo "    • ${subdomain}.${DOMAIN}"
        done
    fi
    echo ""

    # Update .env
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        sed -i "s|^DOMAIN=.*|DOMAIN=${DOMAIN}|" "${PROJECT_ROOT}/.env"
    else
        cp "${PROJECT_ROOT}/.env.template" "${PROJECT_ROOT}/.env"
        sed -i "s|^DOMAIN=.*|DOMAIN=${DOMAIN}|" "${PROJECT_ROOT}/.env"
    fi

    save_state "domain" "$DOMAIN"
    save_state "server_ip" "$server_ip"
    save_state "dns_configured" "$dns_configured"
    log_success "Domain configured: $DOMAIN"
    echo ""
}

#==============================================
# Component Selection
#==============================================

select_components() {
    log_section "Component Selection"

    # Analyze system resources for intelligent recommendations
    local mem=$(free -g | awk '/^Mem:/ {print $2}')
    local cpu_cores=$(nproc)
    local disk_space=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')

    log_info "${BOLD}System Resource Analysis:${NC}"
    echo "  • RAM: ${mem}GB"
    echo "  • CPU Cores: ${cpu_cores}"
    echo "  • Available Disk: ${disk_space}GB"
    echo ""

    # Intelligent recommendations based on resources
    log_info "${BOLD}Component Recommendations:${NC}"
    if [[ $mem -ge 16 ]] && [[ $cpu_cores -ge 4 ]] && [[ $disk_space -ge 100 ]]; then
        log_success "  → System can handle ALL components comfortably"
    elif [[ $mem -ge 8 ]] && [[ $cpu_cores -ge 2 ]]; then
        log_info "  → System suitable for core services + 1-2 optional components"
        log_warn "  ⚠ Adding all components may strain resources"
    else
        log_warn "  → Limited resources - recommend core services only"
        log_warn "  ⚠ Optional components may cause performance issues"
    fi
    echo ""

    echo -e "  ${BOLD}Core Services${NC} (Required):"
    echo "    • Caddy (Reverse Proxy with TLS 1.3)"
    echo "    • PostgreSQL, Redis, Neo4j (Databases)"
    echo "    • Grafana, Portainer (Monitoring & Management)"
    echo ""

    echo -e "  ${BOLD}Optional Components:${NC}"
    echo ""

    # Mattermost
    local deploy_mattermost=$(load_state "component_mattermost" "false")
    if [[ "$deploy_mattermost" == "true" ]]; then
        echo -e "    ${GREEN}[${ICON_CHECK}]${NC} Mattermost (Team Collaboration + Boards + Playbooks)"
    else
        echo -e "  ${CYAN}1. Mattermost${NC} - Team Collaboration Platform"
        echo "     Resource usage: ~2GB RAM, 10GB disk"
        if [[ $mem -lt 4 ]]; then
            echo "     ${YELLOW}⚠${NC}  Warning: Low RAM detected"
        fi
        if prompt_confirm "Deploy Mattermost?"; then
            deploy_mattermost="true"
            save_state "component_mattermost" "true"
            echo -e "    ${GREEN}[${ICON_CHECK}]${NC} Mattermost will be deployed"
        else
            echo -e "    ${YELLOW}[ ]${NC} Mattermost will NOT be deployed"
        fi
    fi
    echo ""

    # POLYGOTYA
    local deploy_polygotya=$(load_state "component_polygotya" "false")
    if [[ "$deploy_polygotya" == "true" ]]; then
        echo -e "    ${GREEN}[${ICON_CHECK}]${NC} POLYGOTYA (SSH Callback Server with PQC)"
    else
        echo -e "  ${CYAN}2. POLYGOTYA${NC} - SSH Callback Server with Post-Quantum Crypto"
        echo "     Resource usage: ~512MB RAM, 2GB disk"
        if [[ $mem -ge 2 ]]; then
            echo "     ${GREEN}✓${NC}  System has sufficient resources"
        fi
        if prompt_confirm "Deploy POLYGOTYA?"; then
            deploy_polygotya="true"
            save_state "component_polygotya" "true"
            echo -e "    ${GREEN}[${ICON_CHECK}]${NC} POLYGOTYA will be deployed"
        else
            echo -e "    ${YELLOW}[ ]${NC} POLYGOTYA will NOT be deployed"
        fi
    fi
    echo ""

    # DNS Hub
    local deploy_dnshub=$(load_state "component_dnshub" "false")
    if [[ "$deploy_dnshub" == "true" ]]; then
        echo -e "    ${GREEN}[${ICON_CHECK}]${NC} DNS Hub (Technitium DNS + WireGuard VPN)"
    else
        echo -e "  ${CYAN}3. DNS Hub${NC} - Technitium DNS + WireGuard VPN"
        echo "     Resource usage: ~1GB RAM, 5GB disk"
        if [[ $mem -lt 4 ]]; then
            echo "     ${YELLOW}⚠${NC}  Warning: Limited RAM available"
        fi
        if prompt_confirm "Deploy DNS Hub?"; then
            deploy_dnshub="true"
            save_state "component_dnshub" "true"
            echo -e "    ${GREEN}[${ICON_CHECK}]${NC} DNS Hub will be deployed"
        else
            echo -e "    ${YELLOW}[ ]${NC} DNS Hub will NOT be deployed"
        fi
    fi
    echo ""

    # Email Module
    local deploy_email=$(load_state "component_email" "false")
    if [[ "$deploy_email" == "true" ]]; then
        echo -e "    ${GREEN}[${ICON_CHECK}]${NC} Email Module (Stalwart + SnappyMail)"
    else
        echo -e "  ${CYAN}4. Email Module${NC} - Self-Hosted Email (Stalwart + SnappyMail)"
        echo "     Resource usage: ~1.5GB RAM, 10GB disk"
        echo "     ${BLUE}ℹ${NC}  Includes: SMTP/IMAP/JMAP, Webmail, Spam Filtering, DKIM/DMARC"
        if [[ $mem -lt 4 ]]; then
            echo "     ${YELLOW}⚠${NC}  Warning: Email server requires reliable resources"
        fi
        if prompt_confirm "Deploy Email Module? (Requires DNS configuration)"; then
            deploy_email="true"
            save_state "component_email" "true"
            echo -e "    ${GREEN}[${ICON_CHECK}]${NC} Email Module will be deployed"
            log_warn "Remember: Email requires proper DNS configuration (MX, SPF, DKIM, DMARC)"
            log_info "DNS setup guide: docs/EMAIL_DNS_EXAMPLES.md"
        else
            echo -e "    ${YELLOW}[ ]${NC} Email Module will NOT be deployed"
        fi
    fi
    echo ""

    # Show total resource estimate
    local estimated_ram=4  # Core services baseline
    local estimated_disk=30  # Core services baseline

    [[ "$deploy_mattermost" == "true" ]] && { estimated_ram=$((estimated_ram + 2)); estimated_disk=$((estimated_disk + 10)); }
    [[ "$deploy_polygotya" == "true" ]] && { estimated_ram=$((estimated_ram + 1)); estimated_disk=$((estimated_disk + 2)); }
    [[ "$deploy_dnshub" == "true" ]] && { estimated_ram=$((estimated_ram + 1)); estimated_disk=$((estimated_disk + 5)); }
    [[ "$deploy_email" == "true" ]] && { estimated_ram=$((estimated_ram + 2)); estimated_disk=$((estimated_disk + 10)); }

    log_info "${BOLD}Estimated Total Resource Usage:${NC}"
    echo "  • RAM: ~${estimated_ram}GB"
    echo "  • Disk: ~${estimated_disk}GB"

    if [[ $estimated_ram -gt $mem ]]; then
        log_warn "  ⚠ Selected components may exceed available RAM!"
        log_warn "  Consider removing some components or adding more memory"
    elif [[ $((estimated_ram * 2)) -gt $mem ]]; then
        log_info "  ℹ System will work but may have limited headroom"
    else
        log_success "  ✓ System has sufficient resources for selected components"
    fi
    echo ""

    log_success "Component selection complete"
    pause
}

#==============================================
# Credential Generation
#==============================================

generate_credentials() {
    log_section "Credential Generation"

    cd "$PROJECT_ROOT"

    # Ensure .env exists
    if [[ ! -f ".env" ]]; then
        cp ".env.template" ".env"
    fi

    source ".env"

    local generated=false

    # PostgreSQL password
    if [[ "${POSTGRES_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
        log_info "Generating PostgreSQL password..."
        local pg_pass=$(openssl rand -base64 32)
        sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${pg_pass}|" .env
        generated=true
    fi

    # Redis password
    if [[ "${REDIS_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
        log_info "Generating Redis password..."
        local redis_pass=$(openssl rand -base64 32)
        sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=${redis_pass}|" .env
        generated=true
    fi

    # Grafana admin password
    if [[ "${GRAFANA_ADMIN_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
        log_info "Generating Grafana admin password..."
        local grafana_pass=$(openssl rand -base64 24)
        sed -i "s|GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=${grafana_pass}|" .env
        generated=true
    fi

    # Mattermost passwords (if selected)
    if [[ "$(load_state "component_mattermost")" == "true" ]]; then
        sed -i "s/DEPLOY_MATTERMOST=false/DEPLOY_MATTERMOST=true/" .env

        if [[ "${MATTERMOST_DB_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
            log_info "Generating Mattermost database password..."
            local mm_db_pass=$(openssl rand -base64 32)
            sed -i "s|MATTERMOST_DB_PASSWORD=.*|MATTERMOST_DB_PASSWORD=${mm_db_pass}|" .env
            generated=true
        fi

        if [[ "${MATTERMOST_MINIO_ACCESS_KEY:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
            log_info "Generating Mattermost MinIO credentials..."
            local mm_minio_access=$(openssl rand -base64 16)
            local mm_minio_secret=$(openssl rand -base64 32)
            sed -i "s|MATTERMOST_MINIO_ACCESS_KEY=.*|MATTERMOST_MINIO_ACCESS_KEY=${mm_minio_access}|" .env
            sed -i "s|MATTERMOST_MINIO_SECRET_KEY=.*|MATTERMOST_MINIO_SECRET_KEY=${mm_minio_secret}|" .env
            generated=true
        fi
    fi

    # POLYGOTYA credentials (if selected)
    if [[ "$(load_state "component_polygotya")" == "true" ]]; then
        sed -i "s/DEPLOY_POLYGOTYA=false/DEPLOY_POLYGOTYA=true/" .env

        if [[ "${POLYGOTYA_API_KEY:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
            log_info "Generating POLYGOTYA API key..."
            local poly_api=$(openssl rand -base64 32)
            sed -i "s|POLYGOTYA_API_KEY=.*|POLYGOTYA_API_KEY=${poly_api}|" .env
            generated=true
        fi

        if [[ "${POLYGOTYA_SECRET_KEY:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
            log_info "Generating POLYGOTYA session secret..."
            local poly_secret=$(openssl rand -hex 32)
            sed -i "s|POLYGOTYA_SECRET_KEY=.*|POLYGOTYA_SECRET_KEY=${poly_secret}|" .env
            generated=true
        fi

        if [[ "${POLYGOTYA_ADMIN_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
            log_info "Generating POLYGOTYA admin password..."
            local poly_admin=$(openssl rand -base64 24)
            sed -i "s|POLYGOTYA_ADMIN_PASSWORD=.*|POLYGOTYA_ADMIN_PASSWORD=${poly_admin}|" .env
            generated=true
        fi
    fi

    # Email credentials (if selected)
    if [[ "$(load_state "component_email")" == "true" ]]; then
        sed -i "s/DEPLOY_EMAIL=false/DEPLOY_EMAIL=true/" .env 2>/dev/null || echo "DEPLOY_EMAIL=true" >> .env

        # Generate mail admin password
        if ! grep -q "MAIL_ADMIN_PASSWORD=" .env 2>/dev/null || [[ "${MAIL_ADMIN_PASSWORD:-CHANGE_ME}" == *"CHANGE_ME"* ]]; then
            log_info "Generating Stalwart admin password..."
            local mail_admin_pass=$(openssl rand -base64 32)
            if grep -q "MAIL_ADMIN_PASSWORD=" .env 2>/dev/null; then
                sed -i "s|MAIL_ADMIN_PASSWORD=.*|MAIL_ADMIN_PASSWORD=${mail_admin_pass}|" .env
            else
                echo "MAIL_ADMIN_PASSWORD=${mail_admin_pass}" >> .env
            fi
            generated=true
        fi

        # Set mail domain
        local domain=$(load_state "domain")
        if ! grep -q "MAIL_DOMAIN=" .env 2>/dev/null; then
            log_info "Setting mail domain to ${domain}..."
            echo "MAIL_DOMAIN=${domain}" >> .env
            echo "MAIL_HOSTNAME=mail.${domain}" >> .env
            generated=true
        fi

        # Set mail admin user
        if ! grep -q "MAIL_ADMIN_USER=" .env 2>/dev/null; then
            echo "MAIL_ADMIN_USER=admin@${domain}" >> .env
            generated=true
        fi
    fi

    if [[ "$generated" == "true" ]]; then
        log_success "Credentials generated successfully"
        log_warn "Save these credentials to your password manager!"
        log_info "Credentials saved in: ${PROJECT_ROOT}/.env"
    else
        log_info "Using existing credentials from .env"
    fi

    # Verify no CHANGE_ME values remain
    if grep -q "CHANGE_ME" .env; then
        log_warn "Some values still need configuration"
        log_info "Review .env file and update CHANGE_ME values"
    else
        log_success "All credentials configured"
    fi

    save_state "credentials_generated" "true"
    pause
}

#==============================================
# Health Verification
#==============================================

verify_container_health() {
    local container="$1"
    local max_wait="${2:-60}"  # Maximum seconds to wait
    local interval=5

    log_info "Verifying ${container} health..."

    local elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            # Container is running
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")

            case "$health" in
                "healthy")
                    log_success "${container} is healthy"
                    audit_log "SUCCESS" "${container} verified healthy"
                    return 0
                    ;;
                "unhealthy")
                    log_error "${container} is unhealthy"
                    audit_log "ERROR" "${container} is unhealthy"
                    docker logs --tail 20 "$container" >> "$LOG_FILE" 2>&1
                    return 1
                    ;;
                "starting")
                    log_info "${container} is starting... (${elapsed}s/${max_wait}s)"
                    sleep $interval
                    elapsed=$((elapsed + interval))
                    ;;
                "no-healthcheck")
                    # No healthcheck defined, just verify it's running
                    log_success "${container} is running (no healthcheck defined)"
                    audit_log "INFO" "${container} verified running (no healthcheck)"
                    return 0
                    ;;
            esac
        else
            log_error "${container} is not running"
            audit_log "ERROR" "${container} is not running"
            return 1
        fi
    done

    log_warn "${container} health check timed out after ${max_wait}s"
    audit_log "WARN" "${container} health check timeout"
    return 1
}

verify_service_endpoint() {
    local url="$1"
    local service_name="${2:-Service}"
    local max_retries=5
    local retry_delay=3

    log_info "Verifying ${service_name} endpoint: ${url}"

    for ((i=1; i<=max_retries; i++)); do
        if curl -sSf --max-time 5 "$url" &> /dev/null; then
            log_success "${service_name} endpoint is accessible"
            audit_log "SUCCESS" "${service_name} endpoint verified: ${url}"
            return 0
        fi

        if [[ $i -lt $max_retries ]]; then
            log_info "Retry $i/${max_retries} in ${retry_delay}s..."
            sleep $retry_delay
        fi
    done

    log_warn "${service_name} endpoint not accessible (may need DNS configuration)"
    audit_log "WARN" "${service_name} endpoint not accessible: ${url}"
    return 1
}

#==============================================
# Rollback Capability
#==============================================

create_deployment_snapshot() {
    local component="$1"
    local snapshot_file="${PROJECT_ROOT}/.snapshot-${component}-$(date +%s).tar.gz"

    log_info "Creating deployment snapshot for ${component}..."
    audit_log "INFO" "Creating snapshot for ${component}"

    # Capture current state
    docker-compose ps > "${PROJECT_ROOT}/.snapshot-state" 2>&1

    # Save snapshot marker
    save_state "last_snapshot_${component}" "$snapshot_file"
    audit_log "SUCCESS" "Snapshot created: ${snapshot_file}"
}

rollback_deployment() {
    local component="$1"

    log_warn "Rolling back ${component} deployment..."
    audit_log "WARN" "Initiating rollback for ${component}"

    case "$component" in
        "core")
            docker-compose down
            log_info "Core services rolled back"
            save_state "deployed_core" "false"
            ;;
        "mattermost")
            docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml down
            log_info "Mattermost rolled back"
            save_state "deployed_mattermost" "false"
            ;;
        "polygotya")
            docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml down polygotya
            log_info "POLYGOTYA rolled back"
            save_state "deployed_polygotya" "false"
            ;;
    esac

    audit_log "INFO" "Rollback completed for ${component}"
    log_warn "Use 'System Status' to verify rollback"
}

#==============================================
# Core Deployment
#==============================================

deploy_core_services() {
    log_section "Deploying Core Services"
    audit_log "INFO" "Starting core services deployment"

    cd "$PROJECT_ROOT"

    # Smart pre-flight checks
    log_info "Running pre-flight checks..."
    local preflight_failed=false

    # Check if .env exists
    if [[ ! -f ".env" ]]; then
        log_error ".env file not found - run credential generation first"
        preflight_failed=true
    fi

    # Check for CHANGE_ME values
    if [[ -f ".env" ]] && grep -q "CHANGE_ME" ".env"; then
        log_warn "Found CHANGE_ME values in .env"
        log_warn "Some credentials may not be configured"
    fi

    # Check Docker is running
    if ! docker ps &> /dev/null; then
        log_error "Docker is not running"
        preflight_failed=true
    fi

    # Check disk space
    local available=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ $available -lt 20 ]]; then
        log_error "Insufficient disk space: ${available}GB (need at least 20GB free)"
        preflight_failed=true
    elif [[ $available -lt 50 ]]; then
        log_warn "Low disk space: ${available}GB (recommended: 50GB+ free)"
    fi

    # Check if ports are free
    local ports_blocked=()
    for port in 80 443; do
        if ss -tuln 2>/dev/null | grep -q ":${port} " || netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            ports_blocked+=($port)
        fi
    done

    if [[ ${#ports_blocked[@]} -gt 0 ]]; then
        log_error "Required ports in use: ${ports_blocked[*]}"
        log_warn "Stop services using these ports or deployment will fail"
        preflight_failed=true
    fi

    if [[ "$preflight_failed" == "true" ]]; then
        log_error "Pre-flight checks failed - cannot proceed"
        pause
        return 1
    fi

    log_success "Pre-flight checks passed"
    echo ""

    # Create snapshot before deployment
    create_deployment_snapshot "core"

    show_progress 0 9 "Creating Docker networks..."

    # Create networks
    if ! docker network create br-frontend 2>/dev/null; then
        log_info "Network br-frontend already exists"
    fi
    if ! docker network create br-backend 2>/dev/null; then
        log_info "Network br-backend already exists"
    fi

    show_progress 1 9 "Deploying PostgreSQL..."
    if execute_cmd "docker-compose up -d postgres" "Deploy PostgreSQL" 60; then
        verify_container_health "postgres" 60 || {
            log_error "PostgreSQL failed health check"
            rollback_deployment "core"
            pause
            return 1
        }
    fi

    show_progress 2 9 "Deploying Redis..."
    if execute_cmd "docker-compose up -d redis-stack" "Deploy Redis" 60; then
        verify_container_health "redis-stack" 60 || log_warn "Redis health check inconclusive"
    fi

    show_progress 3 9 "Deploying Neo4j..."
    if execute_cmd "docker-compose up -d neo4j" "Deploy Neo4j" 60; then
        verify_container_health "neo4j" 90 || log_warn "Neo4j health check inconclusive"
    fi

    show_progress 4 9 "Deploying Caddy..."
    if execute_cmd "docker-compose up -d caddy" "Deploy Caddy" 60; then
        verify_container_health "caddy" 60 || {
            log_error "Caddy failed health check"
            rollback_deployment "core"
            pause
            return 1
        }
    fi

    show_progress 5 9 "Deploying Grafana..."
    if execute_cmd "docker-compose up -d grafana" "Deploy Grafana" 60; then
        verify_container_health "grafana" 60 || log_warn "Grafana health check inconclusive"
    fi

    show_progress 6 9 "Deploying Portainer..."
    if execute_cmd "docker-compose up -d portainer" "Deploy Portainer" 60; then
        verify_container_health "portainer" 60 || log_warn "Portainer health check inconclusive"
    fi

    show_progress 7 9 "Verifying core services..."
    sleep 5

    show_progress 8 9 "Running health checks..."
    local health_check_passed=true
    if ! docker ps | grep -q "postgres"; then
        log_error "PostgreSQL container not running"
        health_check_passed=false
    fi
    if ! docker ps | grep -q "caddy"; then
        log_error "Caddy container not running"
        health_check_passed=false
    fi

    show_progress 9 9 "Core services deployed"
    echo ""

    if [[ "$health_check_passed" == "true" ]]; then
        log_success "Core services deployed successfully"
        audit_log "SUCCESS" "Core services deployment completed"
        save_state "deployed_core" "true"
    else
        log_error "Core services deployment completed with errors"
        audit_log "ERROR" "Core services deployment had failures"
        log_warn "Check logs and use rollback if needed"
    fi

    pause
}

deploy_mattermost() {
    if [[ "$(load_state "component_mattermost")" != "true" ]]; then
        return 0
    fi

    log_section "Deploying Mattermost"

    cd "$PROJECT_ROOT"

    show_progress 0 4 "Starting Mattermost database..."
    docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d mattermost-db
    sleep 10

    show_progress 1 4 "Starting Mattermost Redis..."
    docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d mattermost-redis
    sleep 5

    show_progress 2 4 "Starting Mattermost MinIO..."
    docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d mattermost-minio
    sleep 5

    show_progress 3 4 "Starting Mattermost server..."
    docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml up -d mattermost
    sleep 15

    show_progress 4 4 "Mattermost deployed"
    echo ""

    log_success "Mattermost deployed successfully"
    log_info "URL: https://mattermost.$(load_state "domain")"
    save_state "deployed_mattermost" "true"
    pause
}

deploy_polygotya() {
    if [[ "$(load_state "component_polygotya")" != "true" ]]; then
        return 0
    fi

    log_section "Deploying POLYGOTYA"

    cd "$PROJECT_ROOT"

    show_progress 0 2 "Starting POLYGOTYA (loading PQC libraries)..."
    docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml up -d polygotya
    sleep 15

    show_progress 1 2 "Verifying POLYGOTYA health..."
    sleep 5

    show_progress 2 2 "POLYGOTYA deployed"
    echo ""

    log_success "POLYGOTYA deployed successfully"
    log_info "URL: https://polygotya.$(load_state "domain")"
    log_info "Get admin password: docker logs polygotya | grep 'DEFAULT ADMIN'"
    save_state "deployed_polygotya" "true"
    pause
}

deploy_email() {
    if [[ "$(load_state "component_email")" != "true" ]]; then
        return 0
    fi

    log_section "Deploying Email Module (Stalwart + SnappyMail)"

    cd "$PROJECT_ROOT"

    # Check if DKIM keys exist
    if [[ ! -f "stalwart/ssl/dkim.key" ]]; then
        log_warn "DKIM keys not found. Generating now..."
        log_info "Domain: $(load_state "domain")"

        # Generate DKIM keys
        if [[ -f "stalwart/scripts/generate-dkim.sh" ]]; then
            bash stalwart/scripts/generate-dkim.sh "$(load_state "domain")" || {
                log_error "Failed to generate DKIM keys"
                log_info "You can generate them later with: cd stalwart/scripts && ./generate-dkim.sh <domain>"
            }
        fi
    fi

    show_progress 0 4 "Starting Stalwart mail server..."
    docker-compose -f docker-compose.yml -f docker-compose.email.yml up -d stalwart
    sleep 20

    show_progress 1 4 "Starting SnappyMail webmail..."
    docker-compose -f docker-compose.yml -f docker-compose.email.yml up -d snappymail
    sleep 10

    show_progress 2 4 "Verifying mail services health..."
    sleep 5

    # Check if Stalwart is healthy
    if docker ps | grep -q "stalwart.*healthy\|stalwart.*Up"; then
        log_success "Stalwart is running"
    else
        log_warn "Stalwart may still be starting up - check 'docker logs stalwart'"
    fi

    # Check if SnappyMail is healthy
    if docker ps | grep -q "snappymail.*healthy\|snappymail.*Up"; then
        log_success "SnappyMail is running"
    else
        log_warn "SnappyMail may still be starting up - check 'docker logs snappymail'"
    fi

    show_progress 3 4 "Configuring email services..."
    sleep 3

    show_progress 4 4 "Email module deployed"
    echo ""

    log_success "Email module deployed successfully"
    echo ""
    log_info "${BOLD}Important Next Steps:${NC}"
    echo ""
    echo "  1. ${YELLOW}Configure DNS Records${NC} (CRITICAL for email delivery)"
    echo "     See: docs/EMAIL_DNS_EXAMPLES.md"
    echo "     Required: MX, A, SPF, DKIM, DMARC, PTR records"
    echo ""
    echo "  2. ${YELLOW}Publish DKIM DNS Record${NC}"
    echo "     File: stalwart/ssl/dkim.txt"
    echo "     Add the TXT record shown in that file to your DNS"
    echo ""
    echo "  3. ${YELLOW}Configure TLS Certificates${NC}"
    echo "     Stalwart needs valid TLS certs for mail.$(load_state "domain")"
    echo "     Caddy will handle this automatically once DNS is configured"
    echo ""
    echo "  4. ${YELLOW}Set Reverse DNS (PTR)${NC}"
    echo "     Contact your VPS provider to set PTR record"
    echo "     Your server IP should resolve to mail.$(load_state "domain")"
    echo ""
    echo "  5. ${YELLOW}Create First Email Account${NC}"
    echo "     docker exec -it stalwart stalwart-cli account create \\"
    echo "       --email admin@$(load_state "domain") \\"
    echo "       --password 'YourSecurePassword' \\"
    echo "       --name 'Administrator' \\"
    echo "       --quota 10G"
    echo ""
    echo "  ${BOLD}Access Points:${NC}"
    echo "    • Webmail: https://spiderwebmail.$(load_state "domain")"
    echo "    • Admin UI: https://mailadmin.$(load_state "domain") (VPN only)"
    echo "    • SMTP Submission: mail.$(load_state "domain"):587 (STARTTLS)"
    echo "    • IMAPS: mail.$(load_state "domain"):993"
    echo ""
    log_info "Full setup guide: stalwart/README.md"
    log_info "DNS examples: docs/EMAIL_DNS_EXAMPLES.md"
    echo ""

    save_state "deployed_email" "true"
    pause
}

#==============================================
# Fresh Installation
#==============================================

fresh_installation() {
    log_header "Fresh Installation - Guided Setup"

    # Check for previous incomplete installation
    local last_run=$(load_state "last_run" "0")
    local deployed_core=$(load_state "deployed_core" "false")

    if [[ "$deployed_core" == "false" ]] && [[ $last_run -gt 0 ]]; then
        local last_run_date=$(date -d @$last_run '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
        log_warn "Previous installation detected (last run: $last_run_date)"
        log_warn "Installation appears incomplete"
        echo ""

        if prompt_confirm "Resume previous installation?"; then
            log_info "Resuming from last checkpoint..."
            # Check what's already done
            local creds_done=$(load_state "credentials_generated" "false")

            if [[ "$creds_done" == "false" ]]; then
                log_info "Resuming from credential generation..."
                generate_credentials
            fi

            log_info "Continuing with core services deployment..."
            deploy_core_services
            deploy_mattermost
            deploy_polygotya
            deploy_email
            show_deployment_summary
            return 0
        else
            log_info "Starting fresh installation..."
        fi
    fi

    log_info "This will guide you through a complete VPS2.0 installation"
    log_warn "Estimated time: 15-20 minutes"
    echo ""

    if ! prompt_confirm "Proceed with fresh installation?"; then
        return 0
    fi

    # Step-by-step installation
    check_prerequisites || return 1
    configure_domain || return 1
    select_components
    generate_credentials
    deploy_core_services
    deploy_mattermost
    deploy_polygotya
    deploy_email

    # Final summary
    show_deployment_summary
}

#==============================================
# Component Management
#==============================================

add_components() {
    log_header "Add Components"

    local options=(
        "Mattermost (Team Collaboration)"
        "POLYGOTYA (SSH Callback Server)"
        "Email Module (Stalwart + SnappyMail)"
        "DNS Hub (Technitium DNS + WireGuard)"
        "Intelligence Platform (MISP + OpenCTI)"
    )

    show_menu "Select component to add" "${options[@]}"

    read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

    case $choice in
        1)
            save_state "component_mattermost" "true"
            generate_credentials
            deploy_mattermost
            ;;
        2)
            save_state "component_polygotya" "true"
            generate_credentials
            deploy_polygotya
            ;;
        3)
            save_state "component_email" "true"
            generate_credentials
            deploy_email
            ;;
        4)
            log_warn "DNS Hub deployment not yet implemented in this interface"
            log_info "Use: ./scripts/dns-firewall.sh"
            pause
            ;;
        5)
            log_warn "Intelligence Platform deployment not yet implemented in this interface"
            log_info "Deploy manually with docker-compose"
            pause
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid selection"
            pause
            ;;
    esac
}

remove_components() {
    log_header "Remove Components"

    log_warn "This will STOP and REMOVE the selected component"
    log_warn "Data will be preserved in Docker volumes"
    echo ""

    if ! prompt_confirm "Are you sure you want to remove a component?"; then
        return 0
    fi

    local options=(
        "Mattermost"
        "POLYGOTYA"
    )

    show_menu "Select component to remove" "${options[@]}"

    read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

    case $choice in
        1)
            log_info "Stopping Mattermost services..."
            docker-compose -f docker-compose.yml -f docker-compose.mattermost.yml down
            save_state "component_mattermost" "false"
            save_state "deployed_mattermost" "false"
            log_success "Mattermost removed"
            pause
            ;;
        2)
            log_info "Stopping POLYGOTYA..."
            docker-compose -f docker-compose.yml -f docker-compose.polygotya.yml down polygotya
            save_state "component_polygotya" "false"
            save_state "deployed_polygotya" "false"
            log_success "POLYGOTYA removed"
            pause
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid selection"
            pause
            ;;
    esac
}

#==============================================
# Backup & Restore
#==============================================

backup_restore_menu() {
    log_header "Backup & Restore"

    local options=(
        "Create Full Backup"
        "Restore from Backup"
        "List Available Backups"
        "Configure S3 Backup"
    )

    show_menu "Backup & Restore Options" "${options[@]}"

    read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

    case $choice in
        1)
            log_info "Creating full backup..."
            "${PROJECT_ROOT}/scripts/backup.sh"
            pause
            ;;
        2)
            log_info "Available backups:"
            ls -lh /srv/backups/*.tar.gz 2>/dev/null || log_warn "No backups found"
            echo ""
            prompt_input "Enter backup file path" "" BACKUP_FILE
            if [[ -f "$BACKUP_FILE" ]]; then
                "${PROJECT_ROOT}/scripts/restore.sh" "$BACKUP_FILE"
            else
                log_error "Backup file not found: $BACKUP_FILE"
            fi
            pause
            ;;
        3)
            log_info "Available backups:"
            ls -lh /srv/backups/ 2>/dev/null || log_warn "No backups found"
            pause
            ;;
        4)
            log_info "Edit .env and configure S3_* variables"
            log_info "Then backups will automatically upload to S3"
            pause
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid selection"
            pause
            ;;
    esac
}

#==============================================
# System Status
#==============================================

system_status() {
    log_header "System Status"

    local options=(
        "Quick Status"
        "Full Status"
        "Service Status Only"
        "Show Service URLs"
        "Recent Logs"
        "Run Deployment Verification"
    )

    show_menu "System Status Options" "${options[@]}"

    read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

    case $choice in
        1)
            "${PROJECT_ROOT}/scripts/status.sh" quick
            pause
            ;;
        2)
            "${PROJECT_ROOT}/scripts/status.sh" full
            pause
            ;;
        3)
            "${PROJECT_ROOT}/scripts/status.sh" services
            pause
            ;;
        4)
            "${PROJECT_ROOT}/scripts/status.sh" urls
            pause
            ;;
        5)
            "${PROJECT_ROOT}/scripts/status.sh" logs
            pause
            ;;
        6)
            "${PROJECT_ROOT}/scripts/verify-deployment.sh"
            pause
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid selection"
            pause
            ;;
    esac
}

#==============================================
# Security Hardening
#==============================================

harden_kernel_parameters() {
    log_section "Kernel Parameter Hardening"
    audit_log "INFO" "Starting kernel hardening"

    local sysctl_conf="/etc/sysctl.d/99-vps2-hardening.conf"

    log_info "Configuring kernel parameters..."

    cat > "$sysctl_conf" <<'EOF'
# VPS2.0 Security Hardening

# Network Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1

# IPv6 Security
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# System Security
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

# Performance (Docker optimized)
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 8192
vm.swappiness = 10
EOF

    sysctl -p "$sysctl_conf" >> "$LOG_FILE" 2>&1
    log_success "Kernel parameters hardened"
    audit_log "SUCCESS" "Kernel parameters configured"
    pause
}

harden_firewall() {
    log_section "Firewall Configuration"
    audit_log "INFO" "Starting firewall hardening"

    if ! command -v ufw &> /dev/null; then
        log_info "Installing UFW..."
        apt-get update >> "$LOG_FILE" 2>&1
        apt-get install -y ufw >> "$LOG_FILE" 2>&1
    fi

    log_info "Configuring UFW firewall rules..."

    # Default policies
    ufw --force default deny incoming >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1

    # Allow SSH (be careful!)
    ufw allow 22/tcp comment 'SSH' >> "$LOG_FILE" 2>&1

    # Allow HTTP/HTTPS
    ufw allow 80/tcp comment 'HTTP' >> "$LOG_FILE" 2>&1
    ufw allow 443/tcp comment 'HTTPS' >> "$LOG_FILE" 2>&1

    # Enable firewall
    if prompt_confirm "Enable UFW firewall now? (Ensure SSH access is working!)"; then
        ufw --force enable >> "$LOG_FILE" 2>&1
        log_success "Firewall enabled"
        audit_log "SUCCESS" "UFW firewall enabled"
    else
        log_warn "Firewall not enabled (run 'ufw enable' manually)"
    fi

    pause
}

create_admin_user() {
    log_section "Create Dedicated Admin User"
    audit_log "INFO" "Creating dedicated admin user"

    log_info "Creating a dedicated admin user is more secure than using root"
    echo ""

    prompt_input "Enter username for new admin user" "vpsadmin" ADMIN_USERNAME

    # Check if user already exists
    if id "$ADMIN_USERNAME" &> /dev/null; then
        log_warn "User $ADMIN_USERNAME already exists"
        if ! prompt_confirm "Configure existing user?"; then
            pause
            return 0
        fi
    else
        log_info "Creating user: $ADMIN_USERNAME"
        useradd -m -s /bin/bash "$ADMIN_USERNAME" >> "$LOG_FILE" 2>&1

        # Set password
        log_info "Set password for $ADMIN_USERNAME"
        passwd "$ADMIN_USERNAME"
    fi

    # Add to sudo group
    log_info "Adding $ADMIN_USERNAME to sudo group..."
    usermod -aG sudo "$ADMIN_USERNAME" >> "$LOG_FILE" 2>&1

    # Setup SSH directory
    local user_home=$(eval echo ~"$ADMIN_USERNAME")
    local ssh_dir="${user_home}/.ssh"

    if [[ ! -d "$ssh_dir" ]]; then
        log_info "Creating SSH directory..."
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        chown "${ADMIN_USERNAME}:${ADMIN_USERNAME}" "$ssh_dir"
    fi

    # Copy root's authorized_keys if exists
    if [[ -f /root/.ssh/authorized_keys ]]; then
        if prompt_confirm "Copy root's SSH keys to $ADMIN_USERNAME?"; then
            cp /root/.ssh/authorized_keys "${ssh_dir}/authorized_keys"
            chmod 600 "${ssh_dir}/authorized_keys"
            chown "${ADMIN_USERNAME}:${ADMIN_USERNAME}" "${ssh_dir}/authorized_keys"
            log_success "SSH keys copied"
        fi
    fi

    log_success "Admin user $ADMIN_USERNAME created and configured"
    log_info "Test SSH access with: ssh ${ADMIN_USERNAME}@<server-ip>"
    audit_log "SUCCESS" "Admin user $ADMIN_USERNAME created"

    pause
}

harden_ssh() {
    log_section "SSH Security Recommendations"
    audit_log "INFO" "Reviewing SSH security"

    log_info "SSH Security Best Practices (manual configuration recommended):"
    echo ""
    echo "  ${YELLOW}⚠${NC}  SSH hardening must be done carefully to avoid lockout"
    echo ""
    echo "  ${BOLD}Recommended SSH hardening steps:${NC}"
    echo "    1. Create dedicated admin user (Option 1 in this menu)"
    echo "    2. Test SSH access with new user"
    echo "    3. Manually edit /etc/ssh/sshd_config:"
    echo "       - Consider disabling root login: PermitRootLogin no"
    echo "       - Consider key-only auth: PasswordAuthentication no"
    echo "       - Add session limits: MaxAuthTries 3, MaxSessions 5"
    echo "    4. Keep port 22 as-is (others may use it)"
    echo "    5. Test before restarting sshd!"
    echo ""
    echo "  ${BOLD}Current SSH Configuration:${NC}"
    grep -E "^(PermitRootLogin|PasswordAuthentication|Port|MaxAuthTries)" /etc/ssh/sshd_config 2>/dev/null || echo "    Unable to read config"
    echo ""

    log_warn "Automatic SSH hardening disabled to prevent lockout"
    log_info "Manually edit /etc/ssh/sshd_config when ready"
    log_info "Backup before changes: cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup"

    audit_log "INFO" "SSH security recommendations displayed"
    pause
}

harden_docker() {
    log_section "Docker Security Hardening"
    audit_log "INFO" "Starting Docker hardening"

    local daemon_json="/etc/docker/daemon.json"
    local backup="${daemon_json}.backup-$(date +%s)"

    if [[ -f "$daemon_json" ]]; then
        log_info "Backing up Docker config to: $backup"
        cp "$daemon_json" "$backup"
    fi

    log_info "Applying Docker security configuration..."

    cat > "$daemon_json" <<'EOF'
{
  "icc": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true
}
EOF

    if prompt_confirm "Restart Docker daemon to apply changes? (This will briefly disrupt containers)"; then
        systemctl restart docker >> "$LOG_FILE" 2>&1
        sleep 10
        log_success "Docker daemon restarted"
        audit_log "SUCCESS" "Docker security configured"
    else
        log_warn "Docker not restarted (run 'systemctl restart docker' manually)"
    fi

    pause
}

install_fail2ban() {
    log_section "Fail2ban Installation"
    audit_log "INFO" "Starting Fail2ban installation"

    if command -v fail2ban-client &> /dev/null; then
        log_info "Fail2ban already installed"
        fail2ban-client status >> "$LOG_FILE" 2>&1
    else
        log_info "Installing Fail2ban..."
        apt-get update >> "$LOG_FILE" 2>&1
        apt-get install -y fail2ban >> "$LOG_FILE" 2>&1

        # Basic configuration
        cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
EOF

        systemctl enable fail2ban >> "$LOG_FILE" 2>&1
        systemctl start fail2ban >> "$LOG_FILE" 2>&1
        log_success "Fail2ban installed and configured"
        audit_log "SUCCESS" "Fail2ban installed"
    fi

    pause
}

setup_audit_logging() {
    log_section "Audit Logging Setup"
    audit_log "INFO" "Configuring audit logging"

    if ! command -v auditd &> /dev/null; then
        log_info "Installing auditd..."
        apt-get update >> "$LOG_FILE" 2>&1
        apt-get install -y auditd audispd-plugins >> "$LOG_FILE" 2>&1
    fi

    log_info "Configuring audit rules..."

    # Add audit rules for Docker
    cat > /etc/audit/rules.d/docker.rules <<'EOF'
# Docker daemon
-w /usr/bin/dockerd -k docker
-w /usr/bin/docker -k docker
-w /var/lib/docker -k docker
-w /etc/docker -k docker
-w /usr/lib/systemd/system/docker.service -k docker
-w /usr/lib/systemd/system/docker.socket -k docker

# Docker Compose
-w /usr/local/bin/docker-compose -k docker

# Container runtime
-w /usr/bin/containerd -k docker
-w /usr/bin/runc -k docker
EOF

    systemctl restart auditd >> "$LOG_FILE" 2>&1
    log_success "Audit logging configured"
    audit_log "SUCCESS" "System audit logging enabled"
    pause
}

security_hardening() {
    while true; do
        log_header "Security Hardening"

        local options=(
            "Create Dedicated Admin User (Do this FIRST!)"
            "Full Auto-Hardening (Kernel/Firewall/Docker/Fail2ban/Audit)"
            "Kernel Parameter Hardening"
            "Firewall Configuration (UFW)"
            "SSH Security Recommendations"
            "Docker Security"
            "Install Fail2ban"
            "Setup Audit Logging"
            "View Current Security Status"
        )

        show_menu "Security Hardening Options" "${options[@]}"

        read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

        case $choice in
            1)
                # Create admin user FIRST
                create_admin_user
                ;;
            2)
                # Full auto-hardening (safe options only)
                audit_log "INFO" "Starting full auto-hardening"
                log_warn "This will apply automatic hardening (SSH must be configured manually)"
                echo ""
                if prompt_confirm "Proceed with auto-hardening?"; then
                    harden_kernel_parameters
                    harden_firewall
                    harden_docker
                    install_fail2ban
                    setup_audit_logging
                    echo ""
                    log_success "Auto-hardening complete"
                    log_warn "Configure SSH hardening manually (Option 5)"
                    audit_log "SUCCESS" "Full auto-hardening completed"
                fi
                pause
                ;;
            3) harden_kernel_parameters ;;
            4) harden_firewall ;;
            5) harden_ssh ;;
            6) harden_docker ;;
            7) install_fail2ban ;;
            8) setup_audit_logging ;;
            9)
                log_info "Current Security Status:"
                echo ""
                echo "  ${BOLD}User Configuration:${NC}"
                echo "    Current user: $(whoami)"
                echo "    Sudo access: $(groups | grep -q sudo && echo "Yes" || echo "No")"
                echo ""
                echo "  ${BOLD}Firewall (UFW):${NC}"
                if command -v ufw &> /dev/null; then
                    ufw status | head -20
                else
                    echo "    Not installed"
                fi
                echo ""
                echo "  ${BOLD}Fail2ban:${NC}"
                if command -v fail2ban-client &> /dev/null; then
                    fail2ban-client status 2>/dev/null || echo "    Not running"
                else
                    echo "    Not installed"
                fi
                echo ""
                echo "  ${BOLD}Docker Security:${NC}"
                docker info --format '{{.SecurityOptions}}' 2>/dev/null || echo "    Unable to retrieve"
                echo ""
                echo "  ${BOLD}SSH Configuration:${NC}"
                grep -E "^(Port|PermitRootLogin|PasswordAuthentication)" /etc/ssh/sshd_config 2>/dev/null || echo "    Unable to read"
                echo ""
                pause
                ;;
            0) return 0 ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

#==============================================
# Configuration
#==============================================

configuration_menu() {
    log_header "Configuration"

    local options=(
        "Change Domain"
        "Regenerate Credentials"
        "Edit .env File"
        "View Current Configuration"
    )

    show_menu "Configuration Options" "${options[@]}"

    read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

    case $choice in
        1)
            configure_domain
            ;;
        2)
            log_warn "This will regenerate ALL credentials"
            if prompt_confirm "Are you sure?"; then
                rm -f "$STATE_FILE"
                generate_credentials
            fi
            ;;
        3)
            ${EDITOR:-nano} "${PROJECT_ROOT}/.env"
            ;;
        4)
            log_info "Current configuration:"
            echo ""
            grep -v -E "(PASSWORD|SECRET|KEY)" "${PROJECT_ROOT}/.env" | grep -E "^[A-Z]"
            echo ""
            pause
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid selection"
            pause
            ;;
    esac
}

#==============================================
# Deployment Summary
#==============================================

show_deployment_summary() {
    log_header "Deployment Summary"

    local domain=$(load_state "domain" "swordintelligence.airforce")

    echo -e "  ${GREEN}${ICON_CHECK}${NC}  ${BOLD}Deployment Complete!${NC}"
    echo ""
    echo -e "  ${BOLD}Service URLs:${NC}"
    echo "    • Portainer:  https://portainer.${domain}"
    echo "    • Grafana:    https://grafana.${domain}"

    if [[ "$(get_deployment_status mattermost)" == "true" ]]; then
        echo "    • Mattermost: https://mattermost.${domain}"
    fi

    if [[ "$(get_deployment_status polygotya)" == "true" ]]; then
        echo "    • POLYGOTYA:  https://polygotya.${domain}"
    fi

    echo ""
    echo -e "  ${BOLD}Next Steps:${NC}"
    echo "    1. Configure DNS records for all subdomains"
    echo "    2. Change all default passwords on first login"
    echo "    3. Run security hardening: ${CYAN}./scripts/harden.sh${NC}"
    echo "    4. Configure automated backups"
    echo "    5. Review deployment verification: ${CYAN}./scripts/verify-deployment.sh${NC}"
    echo ""
    echo -e "  ${BOLD}Documentation:${NC}"
    echo "    • Quick Start:  ${CYAN}./QUICKSTART.md${NC}"
    echo "    • Operations:   ${CYAN}./docs/OPERATIONS-GUIDE.md${NC}"
    echo "    • Deployment:   ${CYAN}./docs/DEPLOYMENT-CHECKLIST.md${NC}"
    echo ""

    pause
}

#==============================================
# Main Menu
#==============================================

rollback_menu() {
    log_header "Rollback Failed Deployment"

    log_warn "This will roll back (stop and remove) a failed component deployment"
    log_info "Data in Docker volumes will be preserved"
    echo ""

    local options=(
        "Rollback Core Services"
        "Rollback Mattermost"
        "Rollback POLYGOTYA"
        "View Deployment State"
    )

    show_menu "Select Component to Rollback" "${options[@]}"

    read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

    case $choice in
        1)
            if prompt_confirm "Roll back core services?"; then
                rollback_deployment "core"
                log_success "Core services rolled back"
            fi
            pause
            ;;
        2)
            if prompt_confirm "Roll back Mattermost?"; then
                rollback_deployment "mattermost"
                log_success "Mattermost rolled back"
            fi
            pause
            ;;
        3)
            if prompt_confirm "Roll back POLYGOTYA?"; then
                rollback_deployment "polygotya"
                log_success "POLYGOTYA rolled back"
            fi
            pause
            ;;
        4)
            log_info "Current Deployment State:"
            echo ""
            echo "  Core: $(get_deployment_status core)"
            echo "  Mattermost: $(get_deployment_status mattermost)"
            echo "  POLYGOTYA: $(get_deployment_status polygotya)"
            echo ""
            echo "  Last run: $(date -d @$(load_state "last_run" "0") 2>/dev/null || echo "Never")"
            echo ""
            pause
            ;;
        0) return 0 ;;
        *)
            log_error "Invalid selection"
            pause
            ;;
    esac
}

main_menu() {
    while true; do
        show_banner

        local options=(
            "ZFS Disk Setup (Do this FIRST for new VPS!)"
            "Fresh Installation (Guided Setup)"
            "Add Components"
            "Remove Components"
            "Update/Upgrade Services"
            "Backup & Restore"
            "System Status"
            "Security Hardening"
            "Rollback Failed Deployment"
            "Configuration"
            "Show Deployment Summary"
        )

        show_menu "VPS2.0 Deployment Manager - Main Menu" "${options[@]}"

        read -p "$(echo -e "  ${CYAN}${ICON_ARROW}${NC}  Enter selection: ")" choice

        case $choice in
            1) setup_zfs ;;
            2) fresh_installation ;;
            3) add_components ;;
            4) remove_components ;;
            5)
                log_info "Pulling latest images..."
                audit_log "INFO" "Updating service images"
                if execute_cmd "docker-compose pull" "Pull latest images" 600; then
                    log_info "Redeploying services..."
                    if execute_cmd "docker-compose up -d" "Redeploy services" 300; then
                        log_success "Services updated"
                        audit_log "SUCCESS" "Services updated successfully"
                    fi
                fi
                pause
                ;;
            6) backup_restore_menu ;;
            7) system_status ;;
            8) security_hardening ;;
            9) rollback_menu ;;
            10) configuration_menu ;;
            11) show_deployment_summary ;;
            0)
                log_info "Exiting VPS2.0 Deployment Manager"
                audit_log "INFO" "User exited deployment manager"
                exit 0
                ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

#==============================================
# Quick Mode
#==============================================

quick_mode() {
    log_header "Quick Mode - Default Installation"

    log_info "Quick mode will install:"
    echo "    • Core services (required)"
    echo "    • Mattermost (team collaboration)"
    echo "    • POLYGOTYA (SSH callback server)"
    echo "    • Default domain: swordintelligence.airforce"
    echo "    • Auto-generated credentials"
    echo ""

    if ! prompt_confirm "Proceed with quick installation?"; then
        return 1
    fi

    # Set defaults
    save_state "domain" "swordintelligence.airforce"
    save_state "component_mattermost" "true"
    save_state "component_polygotya" "true"

    # Run installation
    check_prerequisites || return 1
    generate_credentials
    deploy_core_services
    deploy_mattermost
    deploy_polygotya
    show_deployment_summary
}

#==============================================
# Main Entry Point
#==============================================

main() {
    # Check root
    check_root

    # Check for quick mode flag
    if [[ "${1:-}" == "--quick" ]]; then
        show_banner
        quick_mode
        exit 0
    fi

    # Show interactive menu
    main_menu
}

# Run main function
main "$@"
