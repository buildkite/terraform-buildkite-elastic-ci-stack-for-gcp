# Packer Build Directory

This directory contains the Packer configuration and build scripts for creating the Buildkite Elastic CI Stack custom VM image for GCP.

## Quick Start

From this directory (`packer/`):

1. **Build the image**:
   ```bash
   ./build --project-id your-gcp-project-id
   ```

The build script includes built-in validation and will check your environment before building.

## Directory Structure

```
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
    │   ├── install-gcp-tools
    │   └── cleanup
    └── conf/                        # Configuration files
        └── buildkite-agent/
            ├── hooks/
            ├── scripts/
            ├── systemd/
            └── sudoers.conf
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

**Note**: The build script (`./build`) handles the directory changes automatically, so you can run it from the `packer/` directory.

## Notes

- The build script automatically creates missing `../build` and `../plugins` directories
- Packer plugins are automatically initialized on first run
- All scripts are validated for syntax and made executable automatically
- The build process creates a new image with timestamp-based naming
- Build artifacts are minimal - the installation scripts handle missing files gracefully

## Next Steps

After building the image:

1. **Deploy VMs**: Use the deployment guide in `../DEPLOYMENT.md`
2. **Test the image**: Create a test instance and verify agent functionality
3. **Scale deployment**: Use instance templates and managed instance groups

For complete deployment instructions, see:
- `../DEPLOYMENT.md` - Comprehensive deployment guide
- `../QUICK-REFERENCE.md` - Essential commands
- `../examples/` - Example scripts and configurations
