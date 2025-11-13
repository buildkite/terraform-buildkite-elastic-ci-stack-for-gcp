#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "Starting Buildkite agent installation..."

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg

echo "Adding Buildkite agent repository..."
curl -fsSL "https://keys.openpgp.org/vks/v1/by-fingerprint/32A37959C2FA5C3C99EFBC32A79206696452D198" | gpg --dearmor -o /usr/share/keyrings/buildkite-agent-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/buildkite-agent-archive-keyring.gpg] https://apt.buildkite.com/buildkite-agent ${buildkite_agent_release} main" > /etc/apt/sources.list.d/buildkite-agent.list

apt-get update

echo "Installing Buildkite agent..."
apt-get install -y buildkite-agent

echo "Configuring Buildkite agent..."
%{ if buildkite_agent_token_secret != "" ~}
# Fetch token from Secret Manager
echo "Fetching Buildkite agent token from Secret Manager..."
AGENT_TOKEN=$(gcloud secrets versions access latest --secret="${buildkite_agent_token_secret}" --project="${project_id}")
sed -i "s/xxx/$AGENT_TOKEN/g" /etc/buildkite-agent/buildkite-agent.cfg
%{ else ~}
# Use token from variable
sed -i "s/xxx/${buildkite_agent_token}/g" /etc/buildkite-agent/buildkite-agent.cfg
%{ endif ~}
sed -i "s/# queue=.*/queue=\"${buildkite_queue}\"/g" /etc/buildkite-agent/buildkite-agent.cfg
sed -i "s~# endpoint=.*~endpoint=\"${buildkite_api_endpoint}\"~g" /etc/buildkite-agent/buildkite-agent.cfg

%{ if buildkite_agent_tags != "" ~}
sed -i "s/# tags=.*/tags=\"${buildkite_agent_tags}\"/g" /etc/buildkite-agent/buildkite-agent.cfg
%{ endif ~}

echo "Starting Buildkite agent service..."
systemctl enable buildkite-agent
systemctl start buildkite-agent

echo "Buildkite agent installation complete!"
