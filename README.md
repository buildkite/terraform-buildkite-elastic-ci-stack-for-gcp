# Elastic CI Stack for GCP

> **⚠️ Active Development Warning**
> This project is under active development and is not yet ready for production use. APIs, configuration options, and module interfaces may change without notice. Use at your own risk and expect breaking changes.

[![Build status](https://badge.buildkite.com/3215529db5b0c43976ce30bd625724ae0f71af146ef8ac0007.svg)](https://buildkite.com/buildkite/elastic-ci-stack-for-gcp?branch=main)

The Elastic CI Stack for GCP gives you a private, autoscaling [Buildkite Agent](https://buildkite.com/docs/agent) cluster running on Google Cloud Platform. Use it to run your builds on your own infrastructure, with complete control over security, networking, and costs.

This is a GCP implementation inspired by Buildkite's [Elastic CI Stack for AWS](https://github.com/buildkite/elastic-ci-stack-for-aws), built with Terraform.

## Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Buildkite Account](https://buildkite.com/signup)
- [GCP Account](https://cloud.google.com/) with a project
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) configured

### Deploy the Stack

Create a `main.tf` file:

```hcl
module "elastic-ci-stack-for-gcp" {
  source  = "buildkite/elastic-ci-stack-for-gcp/buildkite"
  version = "0.1.0"

  # Required
  project_id                  = "your-gcp-project"
  buildkite_organization_slug = "your-org-slug"
  buildkite_agent_token       = "YOUR_AGENT_TOKEN"

  # Stack configuration
  stack_name      = "my-buildkite-stack"
  buildkite_queue = "default"

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

The module will create:

- VPC network with Cloud NAT
- IAM service accounts with appropriate permissions
- Managed instance group with Buildkite agents
- Cloud Function for autoscaling metrics
- Health checks and autoscaling based on queue depth

## Architecture

The stack is organized into four modules:

- **[Networking](modules/networking/)** - VPC, subnets, Cloud NAT, and firewall rules
- **[IAM](modules/iam/)** - Service accounts and permissions for agents and metrics
- **[Compute](modules/compute/)** - Instance groups, autoscaling, and agent configuration
- **[Buildkite Agent Metrics](modules/buildkite-agent-metrics/)** - Cloud Function for publishing queue metrics

## Examples

See the [`examples/`](examples/) directory for complete working examples:

- **[Networking Example](examples/networking/)** - Standalone VPC setup
- **[IAM Example](examples/iam/)** - Service account configuration
- **[Compute Example](examples/compute/)** - Full agent deployment with autoscaling

## Custom Images

The stack includes [Packer templates](packer/) for building custom VM images with pre-installed Buildkite agents and GCP monitoring tools.

## Contributing

We welcome contributions! Please see [Contributing Guidelines](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).

## Related Projects

- [Elastic CI Stack for AWS](https://github.com/buildkite/elastic-ci-stack-for-aws) - The original AWS implementation
- [Buildkite Agent](https://github.com/buildkite/agent) - The Buildkite agent source code

## License

MIT License - see [LICENSE](LICENSE) file for details.
