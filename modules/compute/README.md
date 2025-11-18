# Compute Module

This module creates a managed instance group with autoscaling for running Buildkite agents on Google Compute Engine.

## Overview

This module is equivalent to AWS EC2 Launch Templates and Auto Scaling Groups from the Elastic CI Stack for AWS. It creates:

- **Instance Template** (`google_compute_instance_template`) - Defines the VM configuration including machine type, disk, network, and startup scripts
- **Managed Instance Group** (`google_compute_region_instance_group_manager`) - Manages a pool of identical VM instances across multiple zones
- **Autoscaler** (`google_compute_region_autoscaler`) - Automatically scales the instance group based on Buildkite queue metrics
- **Health Check** (`google_compute_health_check`) - Monitors instance health for autohealing

## Usage

```hcl
module "compute" {
  source = "../../modules/compute"

  project_id  = "my-gcp-project"
  region      = "us-central1"
  zones       = ["us-central1-a", "us-central1-b", "us-central1-c"]
  stack_name  = "my-buildkite-stack"

  # Networking (from networking module)
  network_self_link = module.networking.network_self_link
  subnet_self_link  = module.networking.subnet_0_self_link
  instance_tag      = module.networking.instance_tag

  # IAM (from IAM module)
  agent_service_account_email = module.iam.agent_service_account_email

  # Instance configuration
  machine_type      = "n1-standard-2"
  image             = "buildkite-ci-stack"
  root_disk_size_gb = 50
  root_disk_type    = "pd-balanced"

  # Buildkite configuration
  buildkite_agent_token   = var.buildkite_agent_token
  buildkite_agent_release = "stable"
  buildkite_queue         = "default"
  buildkite_agent_tags    = "environment=production,os=linux"

  # Autoscaling configuration
  min_size       = 0
  max_size       = 10
  cooldown_period = 60

  # Health check configuration
  enable_autohealing               = true
  health_check_initial_delay_sec   = 300
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | >= 4.0, < 8.0 |

## Dependencies

This module requires:

1. **Networking Module** - Must be deployed first to provide VPC network and subnets
2. **IAM Module** - Must be deployed first to provide service account for instances

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID where resources will be created | `string` | n/a | yes |
| region | GCP region where the instance group will be created | `string` | `"us-central1"` | no |
| zones | List of zones within the region where instances will be distributed | `list(string)` | `null` | no |
| stack_name | Name of the Elastic CI Stack (used as prefix for resources) | `string` | `"elastic-ci-stack"` | no |
| network_self_link | Self link of the VPC network (from networking module) | `string` | n/a | yes |
| subnet_self_link | Self link of the subnet where instances will be created | `string` | n/a | yes |
| instance_tag | Network tag to apply to instances (must match firewall rules) | `string` | `"elastic-ci-agent"` | no |
| agent_service_account_email | Email of the service account to attach to instances | `string` | n/a | yes |
| machine_type | GCP machine type for agent instances | `string` | `"n1-standard-2"` | no |
| image | Source image for boot disk. Use custom Packer image for Docker support, or Debian-based image. | `string` | `"debian-cloud/debian-12"` | no |
| root_disk_size_gb | Size of the root disk in GB | `number` | `50` | no |
| root_disk_type | Type of root disk (pd-standard, pd-balanced, pd-ssd) | `string` | `"pd-balanced"` | no |
| buildkite_agent_token | Buildkite agent registration token | `string` | n/a | yes |
| buildkite_agent_release | Buildkite agent release channel (stable, beta, edge) | `string` | `"stable"` | no |
| buildkite_queue | Buildkite queue name that agents will listen to | `string` | `"default"` | no |
| buildkite_agent_tags | Additional tags for Buildkite agents (comma-separated) | `string` | `""` | no |
| buildkite_api_endpoint | Buildkite API endpoint URL | `string` | `"https://agent.buildkite.com/v3"` | no |
| min_size | Minimum number of instances in the managed instance group | `number` | `0` | no |
| max_size | Maximum number of instances in the managed instance group | `number` | `10` | no |
| cooldown_period | Cooldown period in seconds between autoscaling actions | `number` | `60` | no |
| autoscaling_jobs_per_instance | Target number of Buildkite jobs per instance | `number` | `1` | no |
| enable_autohealing | Enable autohealing for unhealthy instances | `bool` | `true` | no |
| health_check_port | Port to use for health checks | `number` | `22` | no |
| health_check_interval_sec | How often (in seconds) to send a health check | `number` | `30` | no |
| health_check_timeout_sec | How long (in seconds) to wait before claiming failure | `number` | `10` | no |
| health_check_healthy_threshold | Consecutive successful checks before marking healthy | `number` | `2` | no |
| health_check_unhealthy_threshold | Consecutive failed checks before marking unhealthy | `number` | `3` | no |
| health_check_initial_delay_sec | Time to wait before starting autohealing | `number` | `300` | no |
| max_surge | Max instances that can be created during updates | `number` | `3` | no |
| max_unavailable | Max instances that can be unavailable during updates | `number` | `0` | no |
| labels | Additional labels to apply to instances | `map(string)` | `{}` | no |
| enable_secure_boot | Enable Secure Boot for shielded VM instances | `bool` | `false` | no |
| enable_vtpm | Enable vTPM for shielded VM instances | `bool` | `true` | no |
| enable_integrity_monitoring | Enable integrity monitoring for shielded VMs | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_template_id | ID of the instance template |
| instance_template_self_link | Self link of the instance template |
| instance_template_name | Name of the instance template |
| instance_group_manager_id | ID of the managed instance group |
| instance_group_manager_self_link | Self link of the managed instance group |
| instance_group_manager_name | Name of the managed instance group |
| instance_group_id | ID of the managed instance group |
| autoscaler_id | ID of the autoscaler |
| autoscaler_self_link | Self link of the autoscaler |
| autoscaler_name | Name of the autoscaler |
| health_check_id | ID of the health check (if autohealing enabled) |
| health_check_self_link | Self link of the health check (if autohealing enabled) |

## Architecture

### Instance Template

The instance template defines the configuration for each Buildkite agent VM:

- **Machine Type**: Configurable (default: `n1-standard-2`)
- **Boot Disk**: Debian 12 image with configurable size and type
- **Network**: No external IP (uses Cloud NAT from networking module)
- **Service Account**: Agent service account from IAM module
- **Startup Script**: Installs and configures Buildkite agent
- **Tags**: Applied for firewall rule targeting

### Managed Instance Group

The regional managed instance group:

- **Regional Deployment**: Distributes instances across multiple zones for HA
- **Update Policy**: Proactive updates with configurable surge/unavailable
- **Autohealing**: Optional health check-based autohealing
- **Target Size**: Managed by autoscaler (ignored by Terraform lifecycle)

### Autoscaler

The autoscaler automatically adjusts the number of instances based on:

- **Scheduled Jobs**: Custom metric from buildkite-agent-metrics
- **Running Jobs**: Custom metric from buildkite-agent-metrics
- **Min/Max Size**: Configurable boundaries
- **Cooldown Period**: Prevents thrashing (default: 60 seconds)

### Health Checks

Optional autohealing using TCP health checks:

- **Port**: Configurable (default: SSH port 22)
- **Interval**: How often to check (default: 30 seconds)
- **Timeout**: Time to wait for response (default: 10 seconds)
- **Thresholds**: Consecutive checks before state change
- **Initial Delay**: Grace period before starting checks (default: 300 seconds)

## AWS to GCP Resource Mapping

| AWS Resource | GCP Resource | Notes |
|--------------|--------------|-------|
| `AWS::EC2::LaunchTemplate` | `google_compute_instance_template` | Defines instance configuration |
| `AWS::AutoScaling::AutoScalingGroup` | `google_compute_region_instance_group_manager` | Manages instance pool |
| N/A (CloudWatch-based scaling) | `google_compute_region_autoscaler` | Separate resource in GCP |
| `AWS::ElasticLoadBalancingV2::TargetGroup` (health) | `google_compute_health_check` | For autohealing |
| Instance Profile | Service Account Email | Attached to instances |
| User Data | `metadata_startup_script` | Runs on instance startup |
| Security Group | Network Tag | Used with firewall rules |
| Mixed Instances Policy | N/A | v1.0.0 only supports on-demand |
| Multiple Instance Types | N/A | v1.0.0 uses single machine type |

## VM Image Options

### Custom Packer Image (Recommended for Production)

For production use with Docker support, build and use the custom Packer image:

1. **Build the image** (from `packer/` directory):
   ```bash
   ./build --project-id your-gcp-project-id
   ```

2. **Use the image family** in your Terraform configuration:
   ```hcl
   image = "buildkite-ci-stack"
   ```

The custom image includes:
- Pre-installed Buildkite agent
- Docker Engine with Compose v2 and Buildx
- Multi-architecture build support (ARM/x86 cross-platform)
- Automated Docker garbage collection
- Disk space monitoring and self-protection
- Centralized logging with Ops Agent

See [DOCKER.md](../../DOCKER.md) for complete Docker features and [packer/README.md](../../packer/README.md) for build instructions.

### Stock Debian Image (Basic Use)

For testing or minimal setups without Docker:

```hcl
image = "debian-cloud/debian-12"
```

The startup script will install the Buildkite agent at boot time:
1. Adds the Buildkite APT repository
2. Installs the `buildkite-agent` package
3. Configures the agent with:
   - Agent token
   - Queue name
   - API endpoint
   - Custom tags
4. Enables and starts the systemd service

**Note**: Using stock Debian means Docker and other tools must be installed via startup scripts, increasing boot time.

## Security

### Shielded VM

Shielded VM features provide verifiable integrity:

- **Secure Boot**: Prevents boot-level malware (optional, default: disabled)
- **vTPM**: Virtual Trusted Platform Module (default: enabled)
- **Integrity Monitoring**: Detects rootkits (default: enabled)

### Network Security

- Instances have no external IP addresses
- All internet access goes through Cloud NAT
- Firewall rules control all traffic
- Instance tag targets specific firewall rules

### IAM Security

- Minimal permissions via custom service account
- No default compute service account
- Follows principle of least privilege
- Service account scopes: cloud-platform (required for custom metrics)

## Autoscaling Behavior

The autoscaler scales based on custom Cloud Monitoring metrics published by the buildkite-agent-metrics function:

- **Scale Up**: When `scheduled_jobs` or `running_jobs` exceeds `jobs_per_instance * current_size`
- **Scale Down**: When both metrics fall below the target
- **Cooldown**: Prevents rapid scaling changes
- **Boundaries**: Respects min_size and max_size limits

**Note**: The metrics function must be deployed separately for autoscaling to work properly. Without it, the autoscaler will maintain min_size instances.

## Examples

See the [examples/compute](../../examples/compute) directory for complete working examples.
