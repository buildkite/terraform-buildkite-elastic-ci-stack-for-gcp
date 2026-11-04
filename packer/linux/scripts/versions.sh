#!/usr/bin/env bash
# Shared utility versions for image installation and validation.

# Keep the guest SDK and auth plugin on the same patched upstream release.
export GOOGLE_CLOUD_CLI_VERSION="592.0.0-0"

# renovate: depName=git-lfs/git-lfs
export GIT_LFS_VERSION="3.4.0"
# renovate: depName=goss-org/goss
export GOSS_VERSION="v0.4.10"

# renovate: depName=docker/compose
export DOCKER_COMPOSE_V2_VERSION="2.40.3"
# renovate: depName=docker/buildx
export DOCKER_BUILDX_VERSION="0.38.1"
