# Elastic CI Stack for GCP

> **⚠️ Active Development Warning**
> This project is under active development and is not yet ready for production use. APIs, configuration options, and module interfaces may change without notice. Use at your own risk and expect breaking changes.

[![Build status](https://badge.buildkite.com/3215529db5b0c43976ce30bd625724ae0f71af146ef8ac0007.svg)](https://buildkite.com/buildkite/elastic-ci-stack-for-gcp?branch=main)

## What is this?

The Elastic CI Stack for GCP gives you a private, autoscaling [Buildkite Agent](https://buildkite.com/docs/agent) cluster running on Google Cloud Platform. Use it to run your builds on your own infrastructure, with complete control over security, networking, and costs.

This is a GCP implementation inspired by Buildkite's [Elastic CI Stack for AWS](https://github.com/buildkite/elastic-ci-stack-for-aws), built with Terraform and designed for production use.

## Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Packer](https://www.packer.io/downloads) >= 1.8 (optional, for custom images)
- [Buildkite Account](https://buildkite.com/signup)
- [GCP Account](https://cloud.google.com/) with a project
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) configured

### Basic Usage

Create a `main.tf` file:

```hcl
module "buildkite_stack" {
  source = "github.com/buildkite/elastic-ci-stack-for-gcp"

  # Required
  project_id                  = "your-gcp-project"
  buildkite_organization_slug = "your-org-slug"
  buildkite_agent_token       = "YOUR_AGENT_TOKEN"

  # Stack configuration
  stack_name       = "my-buildkite-stack"
  buildkite_queue  = "default"

  # Scaling configuration
  min_size = 0
  max_size = 10

  # Instance configuration
  machine_type = "e2-standard-4"
  region       = "us-central1"
}
```

Deploy:

```bash
terraform init
terraform plan
terraform apply
```

That's it! The module will automatically create:

- A VPC network with Cloud NAT
- IAM service accounts with appropriate permissions
- A managed instance group with Buildkite agents
- A Cloud Function that publishes Buildkite metrics (for autoscaling)
- Health checks and autoscaling based on queue depth

### Autoscaling

By default, the stack will autoscale based on your Buildkite queue depth:

- **Scale up**: When jobs are queued, new instances spin up (typically 2-5 minutes)
- **Scale down**: When idle, instances terminate (typically 10-15 minutes after jobs complete)
- **Scale to zero**: With `min_size = 0`, you pay nothing when idle
- **Metrics**: A Cloud Function publishes queue metrics every minute to Cloud Monitoring

The autoscaler targets `autoscaling_jobs_per_instance` (default: 1 job per instance). To run multiple jobs per instance:

```hcl
autoscaling_jobs_per_instance = 2  # Each instance handles 2 concurrent jobs
```

To disable autoscaling and use a fixed instance count:

```hcl
enable_autoscaling = false
min_size          = 3  # Always run 3 instances
```

### Advanced Usage

For more control, you can use the individual modules separately:

```hcl
module "buildkite_iam" {
  source = "github.com/buildkite/elastic-ci-stack-for-gcp//modules/iam"

  project_id = "your-gcp-project"
}

module "buildkite_networking" {
  source = "github.com/buildkite/elastic-ci-stack-for-gcp//modules/networking"

  region            = "us-central1"
  ssh_source_ranges = ["YOUR_IP/32"]  # Restrict SSH access
}

module "buildkite_compute" {
  source = "github.com/buildkite/elastic-ci-stack-for-gcp//modules/compute"

  project_id            = "your-gcp-project"
  region                = "us-central1"
  zones                 = ["us-central1-a", "us-central1-b", "us-central1-c"]
  buildkite_agent_token = "YOUR_AGENT_TOKEN"
  buildkite_queue       = "default"

  min_size     = 0
  max_size     = 10
  machine_type = "e2-standard-4"

  # Wire up networking and IAM modules
  network_self_link           = module.buildkite_networking.network_self_link
  subnet_self_link            = module.buildkite_networking.subnet_0_self_link
  instance_tag                = module.buildkite_networking.instance_tag
  agent_service_account_email = module.buildkite_iam.agent_service_account_email
}
```

## Architecture

The stack is organized into four main modules:

### 1. Networking Module (`modules/networking/`)

Creates the foundational GCP network infrastructure:

- VPC network with configurable CIDR
- Two subnets across multiple availability zones
- Cloud Router with Cloud NAT for outbound internet access
- Firewall rules for SSH and internal communication
- Optional Identity-Aware Proxy (IAP) access

**[View Networking Module Documentation →](modules/networking/README.md)**

### 2. IAM Module (`modules/iam/`)

Manages service accounts and permissions:

- **Agent Service Account**: For Buildkite agent VM instances
  - Compute permissions for instance self-management
  - Logging and monitoring permissions
  - Optional Secret Manager and Cloud Storage access

- **Metrics Service Account**: For autoscaling metrics function
  - Custom metrics publishing
  - Instance group management for autoscaling

**[View IAM Module Documentation →](modules/iam/README.md)**

### 3. Compute Module (`modules/compute/`)

Deploys and manages the Buildkite agents:

- Regional managed instance groups for high availability
- Instance templates with custom Buildkite agent images
- Autoscaling based on Buildkite job metrics
- Health checks and autohealing
- Rolling update policies

**[View Compute Module Documentation →](modules/compute/README.md)**

### 4. Buildkite Agent Metrics Module (`modules/buildkite-agent-metrics/`)

Provides autoscaling metrics via Cloud Function:

- Cloud Function that collects Buildkite queue metrics
- Publishes custom metrics to Cloud Monitoring for autoscaling
- Supports multiple queues and organizations
- Configurable polling intervals and Secret Manager integration

**[View Buildkite Agent Metrics Module Documentation →](modules/buildkite-agent-metrics/README.md)**

## Custom VM Images

The stack includes Packer templates for building custom VM images with:

- Pre-installed Buildkite agent
- Google Cloud Ops Agent for centralized logging
- System utilities and GCP tools
- Preemption monitor for spot instance handling

**[View Packer Documentation →](packer/README.md)**

**[View Logging Documentation →](LOGGING.md)**

## Configuration Examples

See the [`examples/`](examples/) directory for complete working examples:

- **[Networking Example](examples/networking/)** - Standalone VPC setup
- **[IAM Example](examples/iam/)** - Service account configuration
- **[Compute Example](examples/compute/)** - Full agent deployment

**[Learn more about autoscaling →](examples/compute/AUTOSCALING.md)**

## Security Best Practices

- **No External IPs**: Instances communicate through Cloud NAT
- **Private Networking**: All resources in private subnets by default
- **Service Account Isolation**: Separate accounts for agents and metrics
- **Secret Management**: Use Secret Manager for sensitive values like agent tokens
- **Least Privilege**: IAM roles follow principle of least privilege

## CI/CD Pipeline

This repository includes a Buildkite pipeline for automated testing:

```bash
# Run tests locally
docker-compose run terraform fmt -check -recursive
docker-compose run shellcheck sh -c "shellcheck packer/linux/scripts/*"
```

**[View Pipeline Configuration →](.buildkite/pipeline.yml)**

## Cost Optimization

- **Scale to Zero**: Set `min_size = 0` to avoid costs when idle
- **Regional Deployment**: Distributes instances across zones automatically
- **Cloud NAT**: Single NAT gateway serves all instances
- **Spot Instances**: Future support for preemptible VMs (coming soon)

## Monitoring and Logging

All logs are centralized in Cloud Logging:

- **Agent Logs**: `/var/log/buildkite-agent.log`
- **System Logs**: `/var/log/syslog`, `/var/log/auth.log`
- **Cloud-init Logs**: `/var/log/cloud-init.log`
- **Docker Logs**: `/var/log/docker.log`

Access logs via Cloud Console or `gcloud logging read`.

## Module Compatibility

| Module | Terraform Version | GCP Provider Version |
|--------|------------------|---------------------|
| networking | >= 1.0 | >= 4.0 |
| iam | >= 1.0 | >= 4.0 |
| compute | >= 1.0 | >= 4.0 |

## Upgrading

This project is in active development. Upgrading may require:

1. Review the [CHANGELOG](CHANGELOG.md) for breaking changes
2. Update module versions in your Terraform configuration
3. Run `terraform plan` to preview changes
4. Apply updates with `terraform apply`

## Contributing

We welcome contributions! Please see:

- **[Code of Conduct](CODE_OF_CONDUCT.md)** - Community guidelines
- **[Contributing Guidelines](CONTRIBUTING.md)** - Development process and contribution guidelines

## Support

- **[Open an Issue](https://github.com/your-org/elastic-ci-stack-for-gcp/issues/new)** - Bug reports and feature requests
- **[Buildkite Docs](https://buildkite.com/docs)** - Official documentation

## Related Projects

- [Elastic CI Stack for AWS](https://github.com/buildkite/elastic-ci-stack-for-aws) - The original AWS implementation
- [Terraform Elastic CI Stack for AWS](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws) - A terraform implementation of the AWS Elastic Stack
- [Buildkite Agent](https://github.com/buildkite/agent) - The Buildkite agent source code

## License

MIT License - see [LICENSE](LICENSE) file for details.
