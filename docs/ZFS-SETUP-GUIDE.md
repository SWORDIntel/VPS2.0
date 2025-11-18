# ZFS Disk Setup Guide

## Overview

The VPS2.0 deployment manager now includes comprehensive ZFS filesystem setup as **Option 1** in the main menu. This should be run **BEFORE** deploying services for optimal storage management, snapshots, and compression.

## Why ZFS First?

ZFS provides several advantages for a VPS deployment:

- **Snapshots**: Instant, space-efficient snapshots of entire filesystems
- **Compression**: Transparent compression (lz4, zstd) saves disk space and improves I/O
- **Data Integrity**: Checksums on all data prevent silent corruption
- **Flexibility**: Easy dataset management, quotas, and reservations
- **Docker Integration**: Native ZFS storage driver for containers and volumes

## Installation Process

### 1. Build from Source (ZFS 2.3.5)

The script builds ZFS from the official OpenZFS release:

**Source**: https://github.com/openzfs/zfs/releases/download/zfs-2.3.5/zfs-2.3.5.tar.gz

**Build Dependencies** (28 packages installed):
```bash
build-essential autoconf automake libtool gawk alien fakeroot dkms
libblkid-dev uuid-dev libudev-dev libssl-dev zlib1g-dev libaio-dev
libattr1-dev libelf-dev python3 python3-dev python3-setuptools python3-cffi
libffi-dev libcurl4-openssl-dev libtirpc-dev libtirpc3 libpam0g-dev bc wget
```

**Build Steps**:
1. Download tarball from GitHub
2. Extract and configure (`./configure`)
3. Compile with all CPU cores (`make -j$(nproc)`)
4. Install binaries and libraries (`make install`)
5. Install DKMS kernel module (`make install-dkms`)
6. Update library cache (`ldconfig`)
7. Load ZFS kernel module (`modprobe zfs`)

**Build Time**: 10-30 minutes depending on CPU

### 2. Disk Selection and Pool Creation

**Available Configurations**:

#### Single Disk (No Redundancy)
- Best for: Development, testing, non-critical data
- Space efficiency: 100%
- Redundancy: None

```bash
zpool create -f pool-name /dev/sdb
```

#### Mirror (2 Disks)
- Best for: Production with high availability
- Space efficiency: 50%
- Redundancy: Can lose 1 disk

```bash
zpool create -f pool-name mirror /dev/sdb /dev/sdc
```

#### RAIDZ (3+ Disks)
- Best for: Large storage arrays
- Space efficiency: (n-1)/n
- Redundancy: Can lose 1 disk

```bash
zpool create -f pool-name raidz /dev/sdb /dev/sdc /dev/sdd
```

**Interactive Prompts**:
- Lists all available disks with `lsblk`
- Shows disk size and current usage
- Confirms disk selection before destroying data
- Names pool (default: `vps-data`)

### 3. Compression Benchmarking

The script benchmarks **14 compression algorithms** on your hardware:

**Algorithms Tested**:
```
off          - No compression
lz4          - Fast, good compression
gzip         - Standard gzip (level 6)
gzip-1       - Fastest gzip
gzip-9       - Maximum gzip compression
zstd         - Zstandard (level 3)
zstd-fast    - Fastest zstd
zstd-1       - Very fast
zstd-3       - Balanced (default)
zstd-6       - Higher compression
zstd-9       - High compression
zstd-12      - Very high compression
zstd-15      - Near maximum compression
zstd-19      - Maximum compression
```

**Benchmark Process**:
1. Creates temporary test dataset
2. Generates 100MB mixed data (30MB random + 50MB zeros)
3. Tests write speed for each algorithm
4. Measures actual space used
5. Calculates compression ratio
6. Identifies best performers

**Output Example**:
```
Algorithm       Size (MB)       Ratio           Write Speed
==========      =========       =====           ===========
off             100.00          1.00x           450.12 MB/s
lz4             52.34           1.91x           425.67 MB/s
gzip            48.92           2.04x           215.34 MB/s
gzip-9          45.12           2.22x           125.89 MB/s
zstd            47.23           2.12x           380.45 MB/s
zstd-3          46.01           2.17x           360.12 MB/s
zstd-9          43.56           2.30x           220.67 MB/s
zstd-15         41.23           2.43x           145.23 MB/s
...

Best Compression Ratio: zstd-15 (2.43x)
Best Write Speed: lz4 (425.67 MB/s)
```

**Recommendations**:
- **lz4**: Best for general use (excellent speed, good compression)
- **zstd** or **zstd-3**: Balanced compression and speed
- **zstd-6** to **zstd-9**: Higher compression, slightly slower
- **gzip-9** or **zstd-15**: Maximum compression (slower writes)

### 4. Docker ZFS Integration

**Datasets Created**:
```
pool-name/docker              # Main Docker dataset
pool-name/docker/volumes      # Docker volumes
pool-name/docker/containers   # Container filesystems
```

**Configuration Applied**:
- Mountpoint: `/var/lib/docker`
- Compression: Inherited from pool
- atime: off (performance)

**Docker Daemon Configuration** (`/etc/docker/daemon.json`):
```json
{
  "storage-driver": "zfs",
  "storage-opts": [
    "zfs.fsname=pool-name/docker"
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
```

**Benefits**:
- Docker volumes are ZFS datasets (instant snapshots)
- Container filesystems use ZFS native features
- Automatic compression for all Docker data
- Copy-on-write for efficient layering

## Usage

### First Time Setup (New VPS)

```bash
sudo ./deploy-vps2.sh
# Select: 1 - ZFS Disk Setup
# Follow prompts:
#   - Install build dependencies? Yes
#   - Build ZFS 2.3.5? Yes (10-30 minutes)
#   - Create ZFS pool? Yes
#   - Select disk device: /dev/sdb
#   - Confirm disk selection? Yes
#   - Pool name: vps-data
#   - Configuration: 1 (single disk)
#   - Enable compression? Yes
#   - Benchmark compression? Yes (recommended)
#   - Apply lz4 compression? Yes
#   - Configure Docker ZFS? Yes
#   - Start Docker with ZFS? Yes
```

### Existing ZFS Pool

If you already have a ZFS pool:

```bash
sudo ./deploy-vps2.sh
# Select: 1 - ZFS Disk Setup
# Skip pool creation
# Select "Benchmark compression" to optimize
# Select "Configure Docker ZFS" to integrate
```

## Post-Setup Operations

### Check Pool Status
```bash
zpool status
```

### Check Dataset Compression
```bash
zfs get compression,compressratio pool-name
```

### List All Datasets
```bash
zfs list -r pool-name
```

### Create Snapshot (Before Deployment)
```bash
zfs snapshot pool-name/docker@pre-deployment
```

### Rollback to Snapshot
```bash
zfs rollback pool-name/docker@pre-deployment
```

### Check Space Usage
```bash
zfs list -o name,used,avail,refer,compressratio
```

### Scrub Pool (Data Integrity Check)
```bash
zpool scrub pool-name
zpool status pool-name
```

## Advanced Configuration

### Change Compression After Setup
```bash
# Change pool-wide
zfs set compression=zstd-9 pool-name

# Only affects new data (existing data keeps current compression)
# To recompress existing data:
zfs set compression=zstd-9 pool-name
# Then copy data to force recompression
```

### Dataset Quotas
```bash
# Limit Docker to 500GB
zfs set quota=500G pool-name/docker
```

### Dataset Reservations
```bash
# Guarantee 100GB for Docker
zfs set reservation=100G pool-name/docker
```

### Automatic Snapshots (ZFS Auto Snapshot)
```bash
apt-get install zfs-auto-snapshot

# Enable automatic snapshots
zfs set com.sun:auto-snapshot=true pool-name/docker

# Snapshots will be taken:
# - Every 15 minutes (4 kept)
# - Hourly (24 kept)
# - Daily (31 kept)
# - Weekly (8 kept)
# - Monthly (12 kept)
```

### Monitor Performance
```bash
# I/O stats
zpool iostat -v pool-name 1

# ARC stats (ZFS cache)
arc_summary

# Detailed statistics
zpool status -v pool-name
```

## Troubleshooting

### Build Failed
**Issue**: ZFS compilation failed

**Solution**:
```bash
# Check build log
tail -100 .deployment.log

# Common issues:
# - Missing kernel headers: apt-get install linux-headers-$(uname -r)
# - Insufficient memory: Reduce make jobs
# - Outdated system: apt-get update && apt-get upgrade
```

### Module Not Loading
**Issue**: `modprobe zfs` fails

**Solution**:
```bash
# Check kernel version compatibility
uname -r

# Rebuild module
cd /usr/src/zfs-2.3.5
dkms uninstall zfs/2.3.5
dkms install zfs/2.3.5

# Reboot if needed
reboot
```

### Pool Import Failed
**Issue**: Pool not importing after reboot

**Solution**:
```bash
# Force import
zpool import -f pool-name

# Enable automatic import
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs.target
```

### Docker Won't Start with ZFS
**Issue**: Docker fails with ZFS storage driver

**Solution**:
```bash
# Check Docker logs
journalctl -xeu docker

# Verify ZFS dataset exists
zfs list | grep docker

# Check daemon.json syntax
cat /etc/docker/daemon.json | jq .

# Recreate Docker dataset
zfs destroy -r pool-name/docker
zfs create -o mountpoint=/var/lib/docker pool-name/docker

# Restart Docker
systemctl restart docker
```

### Slow Performance
**Issue**: ZFS performance is slow

**Solution**:
```bash
# Check compression overhead
zfs get compression pool-name

# Disable compression if too slow
zfs set compression=off pool-name

# Or use faster compression
zfs set compression=lz4 pool-name

# Increase ARC size (cache)
# Add to /etc/modprobe.d/zfs.conf:
options zfs zfs_arc_max=8589934592  # 8GB

# Reboot or reload module
```

## Best Practices

### 1. **Set Up ZFS First**
- Always configure ZFS before deploying services
- Easier to migrate later if needed
- Ensures optimal Docker integration

### 2. **Use LZ4 Compression by Default**
- Excellent balance of speed and compression
- Nearly no performance penalty
- Saves 30-50% disk space on average

### 3. **Regular Scrubs**
- Run monthly: `zpool scrub pool-name`
- Detects and repairs silent corruption
- Verifies data integrity

### 4. **Monitor Pool Health**
- Check status weekly: `zpool status`
- Watch for errors or degraded state
- Alert on capacity > 80%

### 5. **Snapshot Before Major Changes**
```bash
zfs snapshot pool-name/docker@before-upgrade
# Do deployment/upgrade
# If issues:
zfs rollback pool-name/docker@before-upgrade
```

### 6. **Automate Snapshots**
- Use zfs-auto-snapshot for regular snapshots
- Keep snapshots for disaster recovery
- Test restoration process

### 7. **Plan Disk Layout**
- Use dedicated disks for ZFS if possible
- Don't mix ZFS with other filesystems on same disk
- Consider RAID controller in HBA mode

### 8. **Capacity Planning**
- Don't exceed 80% pool capacity
- Reserve space for snapshots
- Monitor compression ratios

## Integration with VPS2.0

After ZFS setup, proceed with normal deployment:

1. **ZFS Disk Setup** ✓
2. **Fresh Installation** - Deploys on ZFS-backed Docker
3. **Security Hardening** - Standard security applies
4. **Deploy Components** - All use ZFS datasets

All Docker volumes and containers will automatically use ZFS with:
- Transparent compression
- Instant snapshots
- Data integrity verification
- Efficient space usage

## References

- OpenZFS Documentation: https://openzfs.github.io/openzfs-docs/
- ZFS on Linux: https://zfsonlinux.org/
- Docker ZFS Driver: https://docs.docker.com/storage/storagedriver/zfs-driver/
- ZFS Best Practices: https://pthree.org/2012/12/04/zfs-administration-part-i-vdevs/

## Summary

ZFS setup provides enterprise-grade storage management for your VPS2.0 deployment:

✅ **Built from source** (ZFS 2.3.5) with full optimization
✅ **Benchmarked compression** for your specific hardware
✅ **Docker integration** with ZFS native storage driver
✅ **Instant snapshots** for backup and recovery
✅ **Data integrity** with checksums on all data
✅ **Transparent compression** saving disk space and improving I/O

Run as **Option 1** in the deployment manager before deploying services.
