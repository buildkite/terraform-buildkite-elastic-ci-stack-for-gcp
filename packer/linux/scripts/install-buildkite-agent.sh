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

echo "Creating buildkite-agent user and group..."
sudo useradd --base-dir /var/lib --uid 2000 --create-home --shell /bin/bash buildkite-agent || true

AGENT_VERSION=3.107.0
echo "Downloading buildkite-agent v${AGENT_VERSION} stable..."
sudo curl -Lsf -o /usr/bin/buildkite-agent-stable \
  "https://download.buildkite.com/agent/stable/${AGENT_VERSION}/buildkite-agent-linux-${ARCH}"
sudo chmod +x /usr/bin/buildkite-agent-stable
buildkite-agent-stable --version

echo "Downloading buildkite-agent beta..."
sudo curl -Lsf -o /usr/bin/buildkite-agent-beta \
  "https://download.buildkite.com/agent/unstable/latest/buildkite-agent-linux-${ARCH}"
sudo chmod +x /usr/bin/buildkite-agent-beta
buildkite-agent-beta --version

echo "Adding scripts..."
sudo mkdir -p /tmp/conf/buildkite-agent/scripts
if [ -d /tmp/conf/buildkite-agent/scripts ]; then
  sudo cp /tmp/conf/buildkite-agent/scripts/* /usr/bin/ || echo "No scripts to copy"
fi

echo "Adding sudoers config..."
if [ -f /tmp/conf/buildkite-agent/sudoers.conf ]; then
  sudo cp /tmp/conf/buildkite-agent/sudoers.conf /etc/sudoers.d/buildkite-agent
  sudo chmod 440 /etc/sudoers.d/buildkite-agent
else
  echo "Creating default sudoers config for buildkite-agent..."
  echo "buildkite-agent ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/buildkite-agent
  sudo chmod 440 /etc/sudoers.d/buildkite-agent
fi

echo "Creating hooks dir..."
sudo mkdir -p /etc/buildkite-agent/hooks
sudo chown -R buildkite-agent: /etc/buildkite-agent/hooks

echo "Copying custom hooks..."
if [ -d /tmp/conf/buildkite-agent/hooks ]; then
  sudo cp -a /tmp/conf/buildkite-agent/hooks/* /etc/buildkite-agent/hooks/ || echo "No hooks to copy"
  sudo chmod +x /etc/buildkite-agent/hooks/* || true
  sudo chown -R buildkite-agent: /etc/buildkite-agent/hooks
fi

echo "Creating builds dir..."
sudo mkdir -p /var/lib/buildkite-agent/builds
sudo chown -R buildkite-agent: /var/lib/buildkite-agent/builds

echo "Creating git-mirrors dir..."
sudo mkdir -p /var/lib/buildkite-agent/git-mirrors
sudo chown -R buildkite-agent: /var/lib/buildkite-agent/git-mirrors

echo "Creating plugins dir..."
sudo mkdir -p /var/lib/buildkite-agent/plugins
sudo chown -R buildkite-agent: /var/lib/buildkite-agent/plugins

echo "Adding systemd service template..."
sudo mkdir -p /etc/systemd/system
if [ -f /tmp/conf/buildkite-agent/systemd/buildkite-agent.service ]; then
  sudo cp /tmp/conf/buildkite-agent/systemd/buildkite-agent.service /etc/systemd/system/buildkite-agent.service
else
  echo "Creating default systemd service..."
  cat <<EOF | sudo tee /etc/systemd/system/buildkite-agent.service
[Unit]
Description=Buildkite Agent
After=network.target

[Service]
Type=simple
User=buildkite-agent
Group=buildkite-agent
Environment=HOME=/var/lib/buildkite-agent
WorkingDirectory=/var/lib/buildkite-agent
ExecStart=/usr/bin/buildkite-agent-stable start
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

echo "Adding termination scripts..."
sudo mkdir -p /usr/local/bin
if [ -f /tmp/conf/buildkite-agent/scripts/stop-agent-gracefully ]; then
  sudo cp /tmp/conf/buildkite-agent/scripts/stop-agent-gracefully /usr/local/bin/stop-agent-gracefully
else
  echo "Creating default stop-agent-gracefully script..."
  cat <<'EOF' | sudo tee /usr/local/bin/stop-agent-gracefully
#!/bin/bash
set -euo pipefail
echo "Gracefully stopping buildkite agent..."
sudo systemctl stop buildkite-agent || true
EOF
  sudo chmod +x /usr/local/bin/stop-agent-gracefully
fi

if [ -f /tmp/conf/buildkite-agent/scripts/terminate-instance ]; then
  sudo cp /tmp/conf/buildkite-agent/scripts/terminate-instance /usr/local/bin/terminate-instance
else
  echo "Creating default terminate-instance script..."
  cat <<'EOF' | sudo tee /usr/local/bin/terminate-instance
#!/bin/bash
set -euo pipefail
echo "Terminating instance..."
# Note: This is a placeholder for GCP-specific instance termination
# In GCP, you would typically use: gcloud compute instances delete
echo "Instance termination requested"
EOF
  sudo chmod +x /usr/local/bin/terminate-instance
fi

echo "Copying built-in plugins..."
if [ -d /tmp/plugins ]; then
  sudo mkdir -p /usr/local/buildkite-gcp-stack/plugins
  sudo cp -a /tmp/plugins/* /usr/local/buildkite-gcp-stack/plugins/ || echo "No plugins to copy"
  sudo chown -R buildkite-agent: /usr/local/buildkite-gcp-stack || true
fi

echo "Buildkite agent installation complete."
