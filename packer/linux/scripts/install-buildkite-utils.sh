#!/usr/bin/env bash
set -euo pipefail

# Set non-interactive mode for any apt operations
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

case $(uname -m) in
x86_64) ARCH=amd64 ;;
aarch64) ARCH=arm64 ;;
*) ARCH=unknown ;;
esac

echo "Installing buildkite elastic stack utilities (excluding S3-related components)..."

echo "Installing bk elastic stack bin files..."
if [ -d /tmp/conf/bin ]; then
  sudo chmod +x /tmp/conf/bin/bk-* || echo "No bk-* binaries found"
  sudo mv /tmp/conf/bin/bk-* /usr/local/bin/ || echo "No bk-* binaries to move"
fi

echo "Installing fix-buildkite-agent-builds-permissions..."
if [ -f "/tmp/build/fix-perms-linux-${ARCH}" ]; then
  sudo chmod +x "/tmp/build/fix-perms-linux-${ARCH}"
  sudo mv "/tmp/build/fix-perms-linux-${ARCH}" /usr/bin/fix-buildkite-agent-builds-permissions
else
  echo "Creating default fix-buildkite-agent-builds-permissions script..."
  cat <<'EOF' | sudo tee /usr/bin/fix-buildkite-agent-builds-permissions
#!/bin/bash
set -euo pipefail

# Fix permissions for buildkite agent builds directory
echo "Fixing buildkite agent builds permissions..."

if [ -d /var/lib/buildkite-agent/builds ]; then
  sudo chown -R buildkite-agent:buildkite-agent /var/lib/buildkite-agent/builds
  sudo chmod -R 755 /var/lib/buildkite-agent/builds
  echo "Permissions fixed for /var/lib/buildkite-agent/builds"
else
  echo "Builds directory not found, creating it..."
  sudo mkdir -p /var/lib/buildkite-agent/builds
  sudo chown -R buildkite-agent:buildkite-agent /var/lib/buildkite-agent/builds
fi
EOF
  sudo chmod +x /usr/bin/fix-buildkite-agent-builds-permissions
fi

# NOTE: Excluding S3-secrets-helper as per requirements
echo "Skipping S3-secrets-helper installation (excluded from v0.1.0 release)"

LIFECYCLED_VERSION=v3.3.0
echo "Installing lifecycled ${LIFECYCLED_VERSION}..."
sudo touch /etc/lifecycled
sudo curl -Lf -o /usr/bin/lifecycled \
  https://github.com/buildkite/lifecycled/releases/download/${LIFECYCLED_VERSION}/lifecycled-linux-${ARCH}
sudo chmod +x /usr/bin/lifecycled

# Create a basic systemd service for lifecycled (adapted for GCP)
echo "Creating lifecycled systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/lifecycled.service
[Unit]
Description=Lifecycled - Handle GCP instance lifecycle events
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/lifecycled
Environment=LIFECYCLED_HANDLER="/usr/local/bin/stop-agent-gracefully"
Environment=LIFECYCLED_DEBUG="true"
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Adding SSH authorized keys systemd units (if available)..."
if [ -d /tmp/conf/ssh/systemd ]; then
  sudo cp /tmp/conf/ssh/systemd/* /etc/systemd/system/ || echo "No SSH systemd units to copy"
else
  echo "No SSH systemd configuration found, skipping..."
fi

echo "Creating basic environment hook for Buildkite Secrets integration..."
sudo mkdir -p /etc/buildkite-agent/hooks
cat <<'EOF' | sudo tee /etc/buildkite-agent/hooks/environment
#!/bin/bash

# Environment hook for Buildkite agent
# This hook will source secrets from Buildkite's local environment
# instead of S3 (as per v0.1.0 requirements)

set -euo pipefail

echo "Setting up environment for build ${BUILDKITE_BUILD_NUMBER:-unknown}"

# Source any local environment variables
if [[ -f /etc/buildkite-agent/env ]]; then
  echo "Loading environment from /etc/buildkite-agent/env"
  set -a
  source /etc/buildkite-agent/env
  set +a
fi

# Any additional environment setup can be added here
echo "Environment setup complete"
EOF

sudo chmod +x /etc/buildkite-agent/hooks/environment
sudo chown buildkite-agent:buildkite-agent /etc/buildkite-agent/hooks/environment

echo "Buildkite utilities installation complete (S3 components excluded)."
