#!/usr/bin/env bash
set -euo pipefail

# Startup script for Buildkite agent VM instances
# This script is run via Terraform's metadata_startup_script
#
# The image already has:
# - buildkite-agent installed via apt
# - Configuration templates at /etc/buildkite-agent/templates/
# - Bootstrap script at /usr/local/bin/bootstrap-buildkite-agent
#
# This script just calls the bootstrap to configure and start the agent

echo "Running Buildkite agent bootstrap..."

# The bootstrap script reads configuration from GCP instance metadata:
# - buildkite-token (required)
# - buildkite-queue (optional, default: "default")
# - buildkite-agent-name (optional, default: hostname)
# - buildkite-priority (optional, default: 1)
# - buildkite-tags (optional, default: "")

exec /usr/local/bin/bootstrap-buildkite-agent
