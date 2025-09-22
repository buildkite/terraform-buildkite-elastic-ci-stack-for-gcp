#!/usr/bin/env bash
set -euo pipefail

# Set non-interactive mode for apt operations
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

echo "Installing GCP-specific tools and utilities..."

sudo -E apt-get update -y
sudo -E apt-get install -yq google-cloud-cli

# Install gcloud compute instance management tools
echo "Installing gcloud compute components..."
sudo -E apt-get install -yq google-cloud-cli-gke-gcloud-auth-plugin

# Create a simple metadata service helper (equivalent to AWS instance metadata)
echo "Creating GCP metadata helper script..."
cat <<'EOF' | sudo tee /usr/local/bin/gcp-metadata
#!/bin/bash
# GCP Instance Metadata Helper
# Similar functionality to AWS instance metadata service

set -euo pipefail

METADATA_URL="http://metadata.google.internal/computeMetadata/v1"
HEADERS="Metadata-Flavor: Google"

case "${1:-}" in
  "zone")
    curl -s -H "${HEADERS}" "${METADATA_URL}/instance/zone" | cut -d'/' -f4
    ;;
  "instance-id")
    curl -s -H "${HEADERS}" "${METADATA_URL}/instance/id"
    ;;
  "instance-name")
    curl -s -H "${HEADERS}" "${METADATA_URL}/instance/name"
    ;;
  "project-id")
    curl -s -H "${HEADERS}" "${METADATA_URL}/project/project-id"
    ;;
  "machine-type")
    curl -s -H "${HEADERS}" "${METADATA_URL}/instance/machine-type" | cut -d'/' -f4
    ;;
  "preempted")
    curl -s -H "${HEADERS}" "${METADATA_URL}/instance/preempted" 2>/dev/null || echo "FALSE"
    ;;
  "help"|"--help"|"-h")
    echo "Usage: gcp-metadata [zone|instance-id|instance-name|project-id|machine-type|preempted]"
    echo "Retrieves GCP instance metadata similar to AWS instance metadata service"
    ;;
  *)
    echo "Unknown metadata type: ${1:-}"
    echo "Use 'gcp-metadata help' for available options"
    exit 1
    ;;
esac
EOF
sudo chmod +x /usr/local/bin/gcp-metadata

# Create a spot/preemptible instance handler (equivalent to AWS spot instance handling)
echo "Creating preemptible instance monitor..."
cat <<'EOF' | sudo tee /usr/local/bin/monitor-preemption
#!/bin/bash
# Monitor for GCP preemptible instance termination
# Similar to AWS spot instance termination monitoring

set -euo pipefail

METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/preempted"
HEADERS="Metadata-Flavor: Google"

while true; do
  if curl -s -H "${HEADERS}" "${METADATA_URL}" 2>/dev/null | grep -q "TRUE"; then
    echo "Instance is being preempted, initiating graceful shutdown..."
    /usr/local/bin/stop-agent-gracefully
    break
  fi
  sleep 10
done
EOF
sudo chmod +x /usr/local/bin/monitor-preemption

# Create systemd service for preemption monitoring
echo "Creating preemption monitor systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/preemption-monitor.service
[Unit]
Description=GCP Preemptible Instance Monitor
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/monitor-preemption
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Enable but don't start the preemption monitor (will be started by user configuration)
sudo systemctl enable preemption-monitor.service

# Install ops-agent equivalent functionality (basic monitoring without the agent itself)
echo "Setting up basic system monitoring (ops-agent excluded from v1.0.0)..."

# Create a simple system metrics collection script
cat <<'EOF' | sudo tee /usr/local/bin/collect-system-metrics
#!/bin/bash
# Basic system metrics collection
# Placeholder for future ops-agent integration

set -euo pipefail

# Collect basic system information
echo "System Metrics Collection - $(date)"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)"
echo "Memory Usage: $(free | grep Mem | awk '{printf "%.2f%%", $3/$2 * 100.0}')"
echo "Disk Usage: $(df -h / | awk 'NR==2{printf "%s", $5}')"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo "---"
EOF
sudo chmod +x /usr/local/bin/collect-system-metrics

echo "Creating log rotation configuration for buildkite agent..."
cat <<EOF | sudo tee /etc/logrotate.d/buildkite-agent
/var/log/buildkite-agent/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF

echo "GCP tools installation complete."
