#!/bin/bash
set -euo pipefail

# Check disk space for Docker data directory
# Returns 0 if disk space is healthy, 1 if critically low

# Configurable thresholds (in KB for disk, count for inodes)
DISK_MIN_AVAILABLE=${DISK_MIN_AVAILABLE:-5242880}  # 5GB in KB
DISK_MIN_INODES=${DISK_MIN_INODES:-250000}         # Docker needs lots of inodes

# Get Docker data directory from daemon.json
if [[ -f /etc/docker/daemon.json ]]; then
  DOCKER_DIR=$(jq -r '."data-root" // "/var/lib/docker"' /etc/docker/daemon.json)
else
  DOCKER_DIR="/var/lib/docker"
fi

# Check if Docker directory exists
if [[ ! -d "$DOCKER_DIR" ]]; then
  echo "Warning: Docker directory $DOCKER_DIR does not exist" >&2
  exit 0  # Don't fail if Docker isn't set up yet
fi

# Check available disk space
disk_avail=$(df -k --output=avail "$DOCKER_DIR" | tail -n1)

if [[ $disk_avail -lt $DISK_MIN_AVAILABLE ]]; then
  echo "ERROR: Not enough disk space free in $DOCKER_DIR" >&2
  echo "  Available: $((disk_avail / 1024)) MB" >&2
  echo "  Required:  $((DISK_MIN_AVAILABLE / 1024)) MB" >&2
  exit 1
fi

# Check available inodes
inodes_avail=$(df -k --output=iavail "$DOCKER_DIR" | tail -n1)

if [[ $inodes_avail -lt $DISK_MIN_INODES ]]; then
  echo "ERROR: Not enough inodes free in $DOCKER_DIR" >&2
  echo "  Available: $inodes_avail" >&2
  echo "  Required:  $DISK_MIN_INODES" >&2
  exit 1
fi

# All checks passed
exit 0
