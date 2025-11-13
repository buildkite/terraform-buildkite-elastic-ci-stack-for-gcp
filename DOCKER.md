# Docker Support

The Buildkite Elastic CI Stack for GCP includes comprehensive Docker support with automatic cleanup and disk space management.

## What's Included

### Docker Engine & Tools

- **Docker Engine**: Installed from the official Docker repository for Debian
- **Docker Compose v2** (2.38.2): Installed as a Docker CLI plugin at `/usr/libexec/docker/cli-plugins/docker-compose`
- **Docker Buildx** (0.26.1): Installed as a Docker CLI plugin for advanced build capabilities
- **Backward Compatibility**: Symlink at `/usr/local/bin/docker-compose` for Docker Compose v1 command compatibility

### Multi-Architecture Support

- **QEMU User-Static**: Enables emulation of different CPU architectures
- **Binfmt Support**: Automatically configured to allow cross-platform builds
- **Supported Architectures**: Build ARM images on x86_64 and vice versa

### Storage Configuration

- **Storage Driver**: `overlay2` (configured in `/etc/docker/daemon.json`)
- **User Access**: `buildkite-agent` user is added to the `docker` group for permission-less Docker access

## Automated Cleanup System

The stack includes a sophisticated multi-layered cleanup system to prevent disk space issues:

### Regular Garbage Collection

**Script**: `/usr/local/bin/docker-gc`
**Schedule**: Hourly (via `docker-gc.timer`)
**What it removes**:

- Stopped containers older than 4 hours
- Unused networks older than 4 hours

**What it preserves**:

- Docker images
- Build caches
- Running containers

**Configuration**:

```bash
# Set custom prune threshold (default: 4h)
DOCKER_PRUNE_UNTIL=2h
```

### Emergency Garbage Collection

**Script**: `/usr/local/bin/docker-low-disk-gc`
**Schedule**: Hourly (via `docker-low-disk-gc.timer`)
**Behavior**:

1. Checks disk space via `/usr/local/bin/bk-check-disk-space.sh`
2. If disk space is healthy, does nothing
3. If disk space is low, performs aggressive cleanup:
   - Removes all images older than 1 hour
   - Removes all build caches older than 1 hour
   - Removes all stopped containers older than 1 hour
   - Removes all unused networks older than 1 hour
4. Re-checks disk space after cleanup
5. If still low, marks instance as unhealthy and terminates itself

**Configuration**:

```bash
# Set custom prune threshold for emergency cleanup (default: 1h)
DOCKER_PRUNE_UNTIL=30m

# Set minimum free disk space in KB (default: 5GB)
DISK_MIN_AVAILABLE=10485760  # 10GB

# Set minimum free inodes (default: 250000)
DISK_MIN_INODES=500000
```

## Disk Space Protection

The disk space check script (`/usr/local/bin/bk-check-disk-space.sh`) monitors:

### Disk Space Threshold

- **Default**: 5GB minimum free space
- **Location**: Docker data directory (default: `/var/lib/docker`)
- **Configurable**: Set `DISK_MIN_AVAILABLE` environment variable (in KB)

### Inode Threshold

- **Default**: 250,000 minimum free inodes
- **Why**: Docker creates many small files and can exhaust inodes
- **Configurable**: Set `DISK_MIN_INODES` environment variable

## Self-Protection Mechanism

When emergency cleanup fails to free sufficient disk space:

1. **Cancel Running Builds**: Sends SIGQUIT to all `buildkite-agent` processes
2. **Mark Instance Unhealthy**: Deletes the instance from its managed instance group
3. **Auto-Replacement**: The autoscaler automatically provisions a healthy replacement instance

This ensures that disk space issues on one instance don't block the entire CI pipeline.

## Systemd Services

All cleanup services are managed by systemd:

### Services

- `docker-gc.service`: Regular garbage collection
- `docker-low-disk-gc.service`: Emergency garbage collection

### Timers

- `docker-gc.timer`: Triggers regular GC hourly
- `docker-low-disk-gc.timer`: Triggers emergency GC hourly

### Status Commands

```bash
# Check timer status
systemctl status docker-gc.timer
systemctl status docker-low-disk-gc.timer

# View timer schedule
systemctl list-timers docker-gc.timer docker-low-disk-gc.timer

# Manually trigger cleanup
sudo systemctl start docker-gc.service
sudo systemctl start docker-low-disk-gc.service

# View cleanup logs
journalctl -u docker-gc.service
journalctl -u docker-low-disk-gc.service
```

## Docker Daemon Configuration

The Docker daemon is configured via `/etc/docker/daemon.json`:

```json
{
  "storage-driver": "overlay2"
}
```

This configuration can be extended at instance launch time for additional features like:

- User namespace remapping
- Custom network address pools
- IPv6 support
- Alternative data directories (e.g., instance storage)

### Manual Cleanup

```bash
# Run regular GC manually
sudo /usr/local/bin/docker-gc

# Run emergency GC manually
sudo /usr/local/bin/docker-low-disk-gc

# Check disk space status
sudo /usr/local/bin/bk-check-disk-space.sh
echo $?  # 0 = healthy, 1 = low disk space
```

## Version Information

- Docker Compose: v2.38.2
- Docker Buildx: v0.26.1
- QEMU User-Static: Installed from Debian repositories
- Binfmt Support: Installed from Debian repositories

## Architecture Support

The installation script automatically detects the host architecture and downloads the appropriate binaries:

- **x86_64**: Standard AMD64 architecture
- **aarch64**: ARM64 architecture (for ARM-based instances)
