#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

validate_environment() {
    log_info "Validating Packer build environment..."

    # Check current directory structure
    local required_dirs=(
        "linux/scripts"
        "linux/conf/buildkite-agent/hooks"
        "linux/conf/buildkite-agent/scripts"
        "linux/conf/buildkite-agent/systemd"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "✓ Directory exists: $dir"
        else
            log_error "✗ Missing directory: $dir"
            return 1
        fi
    done

    # Check for required files
    local required_files=(
        "linux/buildkite-vm-image.pkr.hcl"
        "linux/scripts/install-utils.sh"
        "linux/scripts/install-buildkite-agent.sh"
        "linux/scripts/install-buildkite-utils.sh"
        "linux/scripts/install-gcp-tools.sh"
        "linux/scripts/cleanup.sh"
    )

    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "✓ File exists: $file"
        else
            log_error "✗ Missing file: $file"
            return 1
        fi
    done

    # Check build and plugins directories
    if [[ -d "../build" ]]; then
        log_info "✓ Build directory exists"
    else
        log_warn "⚠ Build directory missing, will be created during build"
    fi

    if [[ -d "../plugins" ]]; then
        log_info "✓ Plugins directory exists"
    else
        log_warn "⚠ Plugins directory missing, will be created during build"
    fi
}

validate_scripts() {
    log_info "Validating installation scripts..."

    local scripts=(
        "linux/scripts/install-utils.sh"
        "linux/scripts/install-buildkite-agent.sh"
        "linux/scripts/install-buildkite-utils.sh"
        "linux/scripts/install-gcp-tools.sh"
        "linux/scripts/cleanup.sh"
    )

    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if bash -n "$script"; then
                log_info "✓ $script syntax is valid"
            else
                log_error "✗ $script has syntax errors"
                return 1
            fi

            if [[ -x "$script" ]]; then
                log_info "✓ $script is executable"
            else
                log_warn "⚠ $script is not executable, fixing..."
                chmod +x "$script"
            fi
        else
            log_error "✗ Missing script: $script"
            return 1
        fi
    done
}

validate_packer_config() {
    log_info "Validating Packer configuration..."

    cd "$SCRIPT_DIR/linux"

    # Initialize plugins if needed
    if [ ! -d ".packer.d" ] || [ ! "$(ls -A .packer.d 2>/dev/null)" ]; then
        log_info "Initializing Packer plugins..."
        if packer init buildkite-vm-image.pkr.hcl; then
            log_info "✓ Packer plugins initialized"
        else
            log_error "✗ Failed to initialize Packer plugins"
            cd "$SCRIPT_DIR"
            return 1
        fi
    fi

    # Validate configuration
    if packer validate -var "project_id=test-project" buildkite-vm-image.pkr.hcl; then
        log_info "✓ Packer configuration is valid"
    else
        log_error "✗ Packer configuration validation failed"
        cd "$SCRIPT_DIR"
        return 1
    fi

    cd "$SCRIPT_DIR"
}

validate_tools() {
    log_info "Validating required tools..."

    if command -v packer &> /dev/null; then
        local packer_version=$(packer version | head -n1)
        log_info "✓ Packer installed: $packer_version"
    else
        log_error "✗ Packer not installed"
        return 1
    fi

    if command -v gcloud &> /dev/null; then
        local gcloud_version=$(gcloud version --format='value("Google Cloud SDK")' 2>/dev/null || echo "unknown")
        log_info "✓ gcloud CLI installed: $gcloud_version"
    else
        log_error "✗ gcloud CLI not installed"
        return 1
    fi

    # Check authentication (optional)
    if gcloud auth application-default print-access-token &> /dev/null; then
        log_info "✓ GCP authentication configured"
    else
        log_warn "⚠ GCP authentication not configured (required for build)"
        log_warn "  Run: gcloud auth application-default login"
    fi
}

main() {
    log_info "Starting validation of Packer build environment"
    log_info "Working directory: $SCRIPT_DIR"

    validate_tools
    validate_environment
    validate_scripts
    validate_packer_config

    log_info "All validations passed! ✓"
}

main "$@"
