#!/usr/bin/env bash

set -euo pipefail

# Set non-interactive mode for apt to prevent dialog prompts
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

case $(uname -m) in
x86_64) ARCH=amd64 ;;
aarch64) ARCH=arm64 ;;
*) ARCH=unknown ;;
esac

echo "Updating package index and core packages..."
sudo -E apt-get update -y
sudo -E apt-get upgrade -y

echo "Installing essential utilities..."
sudo -E apt-get install -yq \
  build-essential \
  git \
  mdadm \
  pigz \
  python3-pip \
  python3-setuptools \
  unzip \
  zip \
  locales

# Additional useful tools for CI/CD environments
sudo -E apt-get install -yq \
  dnsutils \
  lsof \
  rsyslog \
  apt-transport-https

echo "Enabling rsyslog service..."
sudo systemctl enable --now rsyslog

GIT_LFS_VERSION=3.4.0
echo "Installing git lfs ${GIT_LFS_VERSION}..."
pushd "$(mktemp -d)"
curl -sSL https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-${ARCH}-v${GIT_LFS_VERSION}.tar.gz | tar xz
sudo git-lfs-${GIT_LFS_VERSION}/install.sh
popd

# See https://github.com/goss-org/goss/releases for release versions
GOSS_VERSION=v0.3.23
echo "Installing goss $GOSS_VERSION for system validation..."
sudo curl -L "https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/goss-linux-${ARCH}" -o /usr/local/bin/goss
sudo chmod +rx /usr/local/bin/goss
sudo curl -L "https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/dgoss" -o /usr/local/bin/dgoss
sudo chmod +rx /usr/local/bin/dgoss

echo "Setting up locale..."
# Generate the locale
sudo sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
sudo update-locale LANG=en_US.UTF-8

echo "Utilities installation complete."
