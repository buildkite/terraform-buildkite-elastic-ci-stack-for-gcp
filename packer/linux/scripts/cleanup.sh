#!/usr/bin/env bash
set -euo pipefail

# Set non-interactive mode for apt operations
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

echo "Starting cleanup process..."

# Clean package cache
echo "Cleaning package cache..."
sudo -E apt-get clean
sudo -E apt-get autoclean
sudo -E apt-get autoremove -y

# Clear system logs
echo "Clearing system logs..."
sudo journalctl --vacuum-time=1d || true
sudo rm -rf /var/log/*.log.* || true

# Clear temporary files
echo "Clearing temporary files..."
sudo rm -rf /tmp/* || true
sudo rm -rf /var/tmp/* || true

# Clear command history
echo "Clearing command history..."
rm -f ~/.bash_history || true
sudo rm -f /root/.bash_history || true

# Clear any cached credentials
echo "Clearing cached credentials..."
rm -rf ~/.gcloud || true
sudo rm -rf /root/.gcloud || true

# Clear SSH host keys (they will be regenerated on first boot)
echo "Clearing SSH host keys..."
sudo rm -f /etc/ssh/ssh_host_* || true

# Clear machine ID (will be regenerated on first boot)
echo "Clearing machine ID..."
sudo rm -f /etc/machine-id || true
sudo touch /etc/machine-id || true

# Sync filesystem
echo "Syncing filesystem..."
sync

echo "Cleanup process complete."