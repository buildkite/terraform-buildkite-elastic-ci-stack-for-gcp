# Packer Build Directory

This directory contains the Packer configuration and build scripts for creating the Buildkite Elastic CI Stack custom VM image for GCP.

## Quick Start

From this directory (`packer/`):

1. **Build the image**:

   ```bash
   ./build --project-id your-gcp-project-id
   ```

The build script includes built-in validation and will check your environment before building.

## What's Included

The custom VM image includes:

- **Buildkite Agent**: Pre-installed and configured
- **Docker Engine**: With Compose v2 (2.38.2) and Buildx (0.26.1)
- **Multi-Architecture Support**: Cross-platform builds (ARM/x86)
- **Automated Cleanup**: Hourly Docker garbage collection
- **Disk Protection**: Self-healing when disk space is low
- **System Utilities**: Essential tools for CI/CD workloads
- **GCP Integration**: Cloud Ops Agent for centralized logging

See [DOCKER.md](../DOCKER.md) for complete Docker features.

## Directory Structure

```sh
packer/
├── bootstrap                # Bootstrap script
├── build                    # Main build script with validation
├── README.md                # This file
└── linux/
    ├── buildkite-vm-image.pkr.hcl  # Packer configuration
    ├── scripts/                     # Installation scripts
    │   ├── install-utils
    │   ├── install-buildkite-agent
    │   ├── install-buildkite-utils
    │   ├── install-docker
    │   ├── configure-docker
    │   ├── install-gcp-tools
    │   ├── install-ops-agent        # Google Cloud Ops Agent installation
    │   └── cleanup
    └── conf/                        # Configuration files
        ├── buildkite-agent/
        │   ├── hooks/
        │   ├── scripts/
        │   ├── systemd/
        │   └── sudoers.conf
        ├── ops-agent/
        │   └── config.yaml          # Ops Agent logging configuration
        └── rsyslog/
            └── buildkite-logging.conf  # Rsyslog configuration for service logs
        ├── docker/
        │   ├── daemon.json          # Docker configuration
        │   ├── scripts/             # GC and disk check scripts
        │   └── systemd/             # Timer units
        └── ops-agent/
            └── config.yaml          # Logging configuration
```

## Prerequisites

- [Packer](https://developer.hashicorp.com/packer) installed
- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) installed
- GCP authentication configured: `gcloud auth application-default login`
- GCP project with Compute Engine API enabled

## Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `--project-id` | (required) | GCP project ID |
| `--zone` | `us-central1-a` | GCP zone for build instance |
| `--machine-type` | `e2-standard-4` | Build instance machine type |
| `--arch` | `x86-64` | Target architecture (`x86-64` or `arm64`) |
| `--build-number` | timestamp | Build identifier |
| `--agent-version` | `stable` | Buildkite agent version |

## Examples

### Basic Build

```bash
./build --project-id my-gcp-project
```

### ARM64 Build

```bash
./build --project-id my-gcp-project --arch arm64 --zone us-central1-a
```

### Custom Configuration

```bash
./build \
  --project-id my-gcp-project \
  --zone us-west1-a \
  --machine-type c2-standard-8 \
  --build-number v1.0.1 \
  --agent-version beta
```

### Debug Build Issues

Enable Packer logging:

```bash
PACKER_LOG=1 ./build --project-id your-project
```

### Manual Packer Commands

From the `packer/linux/` directory:

```bash
# Initialize plugins
packer init buildkite-vm-image.pkr.hcl

# Validate configuration
packer validate -var "project_id=test" buildkite-vm-image.pkr.hcl

# Build with custom variables
packer build \
  -var "project_id=my-project" \
  -var "zone=us-central1-a" \
  buildkite-vm-image.pkr.hcl
```

**Note**: The build script (`./build`) handles the directory changes automatically, so it can be run from the `packer/` directory.

## What's Included in the Image

The custom VM image includes:

- **Buildkite Agent** - Latest stable version with pre-configured hooks and scripts
- **Google Cloud Ops Agent** - Centralized logging and monitoring (see [LOGGING.md](../LOGGING.md))
- **GCP Tools** - gcloud CLI and instance management utilities
- **System Utilities** - Essential tools for CI/CD workloads (git, build-essential, etc.)
- **Rsyslog Configuration** - Routes systemd service logs to files for collection
- **Preemption Monitor** - Handles spot/preemptible instance termination gracefully

## Centralized Logging

The image includes the **Google Cloud Ops Agent** pre-installed and configured for centralized logging. This provides:

- Automatic collection of application logs (Buildkite agent, Docker)
- System log collection (syslog, auth logs)
- Cloud initialization logs (cloud-init)
- Structured log parsing with severity mapping
- Integration with Cloud Logging for centralized analysis

For detailed information about logging, see [LOGGING.md](../LOGGING.md).

## Notes

- The build script automatically creates missing `../build` and `../plugins` directories
- Packer plugins are automatically initialized on first run
- All scripts are validated for syntax and made executable automatically
- The build process creates a new image with timestamp-based naming
- Build artifacts are minimal - the installation scripts handle missing files gracefully
- Ops Agent is stopped during image build and starts automatically on instance boot

