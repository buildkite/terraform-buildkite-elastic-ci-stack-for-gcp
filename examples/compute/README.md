# Compute Module Example

This example demonstrates how to deploy the complete Elastic CI Stack for GCP including networking, IAM, and compute modules.

## Overview

This example creates:

1. VPC network with dual subnets and Cloud NAT (networking module)
2. Service accounts and IAM roles (IAM module)
3. Managed instance group with autoscaling Buildkite agents (compute module)

## Prerequisites

1. **GCP Project**: You need a GCP project with billing enabled
2. **Terraform**: Version 1.0 or later
3. **GCP Credentials**: Configure authentication using one of:
   - `gcloud auth application-default login`
   - Service account key file
   - Workload identity (for CI/CD)
4. **Buildkite Agent Token**: Get your agent token from Buildkite organization settings
5. **Custom VM Image** (recommended): Build the Packer image for Docker support:
   ```bash
   cd ../../packer
   ./build --project-id your-gcp-project-id
   ```
   See [packer/README.md](../../packer/README.md) for details.

## Required APIs

Enable these GCP APIs in your project:

```bash
gcloud services enable compute.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com
```

## Usage

1. **Copy the example configuration**:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your values:

   ```hcl
   project                = "my-gcp-project-id"
   region                 = "us-central1"
   buildkite_agent_token  = "your-buildkite-agent-token"
   ```

3. **Initialize Terraform**:

   ```bash
   terraform init
   ```

4. **Review the plan**:

   ```bash
   terraform plan
   ```

5. **Apply the configuration**:

   ```bash
   terraform apply
   ```

6. **Verify the deployment**:

   ```bash
   # Check the managed instance group
   gcloud compute instance-groups managed list --filter="name~elastic-ci"

   # Check running instances
   gcloud compute instances list --filter="labels.buildkite-stack=elastic-ci-stack"

   # Check autoscaler status
   gcloud compute instance-groups managed describe elastic-ci-stack-mig --region=us-central1
   ```

## Configuration

### Minimal Configuration

The minimal required variables are:

```hcl
project               = "my-gcp-project-id"
buildkite_agent_token = "your-buildkite-agent-token"
```

### Recommended Configuration

For production use, consider settings such as these:

```hcl
project               = "my-gcp-project-id"
region                = "us-central1"
zones                 = ["us-central1-a", "us-central1-b", "us-central1-c"]

buildkite_agent_token = "your-buildkite-agent-token"
buildkite_queue       = "default"
buildkite_agent_tags  = "os=linux,environment=production,region=us-central1"

# Use custom image for Docker support
image                 = "buildkite-ci-stack"

machine_type          = "n1-standard-4"
root_disk_size_gb     = 100
root_disk_type        = "pd-ssd"

min_size              = 1
max_size              = 20

enable_ssh_access     = false
enable_secret_access  = true
enable_storage_access = true

labels = {
  environment = "production"
  managed_by  = "terraform"
  team        = "platform"
}
```

### Machine Types

Choose the appropriate machine type for your workload:

| Machine Type | vCPUs | Memory | Use Case |
|--------------|-------|--------|----------|
| `n1-standard-1` | 1 | 3.75 GB | Light workloads, small projects |
| `n1-standard-2` | 2 | 7.5 GB | Default, general purpose |
| `n1-standard-4` | 4 | 15 GB | Medium workloads, parallel jobs |
| `n1-standard-8` | 8 | 30 GB | Heavy workloads, large builds |
| `n1-highcpu-4` | 4 | 3.6 GB | CPU-intensive, compilation |
| `n1-highmem-4` | 4 | 26 GB | Memory-intensive, large tests |
| `c2-standard-4` | 4 | 16 GB | High-performance, CPU-bound |
| `e2-standard-4` | 4 | 16 GB | Cost-optimized, general purpose |

See [GCP Machine Types](https://cloud.google.com/compute/docs/machine-types) for the full list.

### Disk Types

Choose the appropriate disk type:

| Disk Type | IOPS | Throughput | Use Case |
|-----------|------|------------|----------|
| `pd-standard` | Low | Low | Cost-optimized, infrequent disk access |
| `pd-balanced` | Medium | Medium | Default, balanced performance/cost |
| `pd-ssd` | High | High | High-performance, I/O intensive builds |

### Autoscaling Configuration

The autoscaler scales based on Buildkite queue metrics:

- **`min_size`**: Minimum instances (can be 0 for cost savings)
- **`max_size`**: Maximum instances (set based on expected load)
- **`cooldown_period`**: Time between scaling actions (default: 60 seconds)
- **`autoscaling_jobs_per_instance`**: Target jobs per instance (default: 1)

Example scaling scenarios:

```hcl
# Always-on (for immediate job pickup)
min_size = 2
max_size = 20

# Cost-optimized (scale from zero)
min_size = 0
max_size = 10

# High-capacity (for large organizations)
min_size = 5
max_size = 50
```

## Outputs

After deployment, you'll see these outputs:

```hcl
Outputs:

agent_service_account_email = "elastic-ci-agent@my-project.iam.gserviceaccount.com"
autoscaler_name = "elastic-ci-stack-autoscaler"
instance_group_id = "projects/my-project/regions/us-central1/instanceGroups/elastic-ci-stack-mig"
instance_group_manager_name = "elastic-ci-stack-mig"
instance_template_name = "elastic-ci-stack-20231024120000"
metrics_service_account_email = "elastic-ci-metrics@my-project.iam.gserviceaccount.com"
network_name = "elastic-ci-stack"
subnet_0_name = "elastic-ci-stack-subnet-0"
```

## Verification

### Check Instance Group Status

```bash
# List managed instance groups
gcloud compute instance-groups managed list \
  --filter="name~elastic-ci"

# Describe the instance group
gcloud compute instance-groups managed describe elastic-ci-stack-mig \
  --region=us-central1

# List instances in the group
gcloud compute instance-groups managed list-instances elastic-ci-stack-mig \
  --region=us-central1
```

### Check Autoscaler Status

```bash
# Describe the autoscaler
gcloud compute instance-groups managed describe-instance elastic-ci-stack-mig \
  --region=us-central1

# View autoscaler events
gcloud logging read "resource.type=gce_autoscaler AND resource.labels.autoscaler_name=elastic-ci-stack-autoscaler" \
  --limit=20 \
  --format=json
```

### Check Buildkite Agent Connection

1. Go to your Buildkite organization: `https://buildkite.com/{your-org}`
2. Navigate to "Agents" in the left sidebar
3. You should see your GCP agents listed with their metadata tags
4. Trigger a build on the queue to verify agents pick up jobs

### SSH to an Instance

If SSH access is enabled:

```bash
# List instances
gcloud compute instances list --filter="labels.buildkite-stack=elastic-ci-stack"

# SSH to an instance
gcloud compute ssh elastic-ci-stack-agent-xxxx --zone=us-central1-a

# Check agent status
sudo systemctl status buildkite-agent

# View agent logs
sudo journalctl -u buildkite-agent -f
```

### View Logs

```bash
# View startup script logs
gcloud logging read "resource.type=gce_instance AND logName=projects/{PROJECT}/logs/syslog" \
  --limit=50 \
  --format=json

# View agent logs (if using Cloud Logging integration)
gcloud logging read "resource.type=gce_instance AND labels.buildkite-stack=elastic-ci-stack" \
  --limit=50
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete:

- All running instances
- The managed instance group
- The instance template
- The autoscaler
- The VPC network and subnets
- Service accounts and IAM roles

## Security Best Practices

1. **Disable SSH access in production**:

   ```hcl
   enable_ssh_access = false
   ```

   Use IAP for maintenance access instead.

2. **Use Secret Manager for sensitive values**:

   ```hcl
   enable_secret_access = true
   ```

   Store agent token in Secret Manager instead of terraform.tfvars.

3. **Enable VPC Flow Logs** for audit trails:

   ```hcl
   # In networking module
   enable_flow_logs = true
   ```

4. **Restrict SSH source ranges**:

   ```hcl
   ssh_source_ranges = ["10.0.0.0/8"]  # Your corporate network
   ```

5. **Use custom service accounts** (already configured):
   - Avoids using default compute service account
   - Follows principle of least privilege

6. **Enable Shielded VM features**:

   ```hcl
   enable_secure_boot          = true
   enable_vtpm                 = true
   enable_integrity_monitoring = true
   ```

## Docker Support

This example supports Docker out of the box when using the custom Packer image:

- **Docker Engine**: Pre-installed with Compose v2 and Buildx
- **Multi-Architecture Builds**: Cross-platform builds (ARM/x86)
- **Automated Cleanup**: Hourly garbage collection to prevent disk issues
- **Disk Space Protection**: Self-healing when disk space is low

See [DOCKER.md](../../DOCKER.md) for complete Docker features and usage.

## Additional Resources

- [Docker Support Documentation](../../DOCKER.md)
- [Packer Build Guide](../../packer/README.md)
- [Buildkite Agent Documentation](https://buildkite.com/docs/agent/v3)
- [GCP Compute Engine Documentation](https://cloud.google.com/compute/docs)
- [GCP Instance Groups](https://cloud.google.com/compute/docs/instance-groups)
- [GCP Autoscaling](https://cloud.google.com/compute/docs/autoscaler)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
