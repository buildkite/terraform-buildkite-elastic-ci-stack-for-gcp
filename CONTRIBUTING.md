# Contributing to Elastic CI Stack for GCP

Thank you for considering contributing to this project! We welcome contributions from the community.

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How to Contribute

### Reporting Bugs

- Use the [GitHub issue tracker](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-gcp/issues)
- Check if the bug has already been reported
- Include:
  - Terraform version
  - GCP provider version
  - Minimal reproduction steps
  - Expected vs actual behavior
  - Relevant log output (redact sensitive information)

### Suggesting Features

- Open an issue with the `enhancement` label
- Describe the use case and benefits
- Consider if it fits the project's scope
- Be open to discussion and feedback

### Pull Requests

Fork the repo and create your branch from `main`. Make your changes following the existing code style, and add documentation or examples if you're introducing new features.

Before submitting, test everything:

```bash
terraform init
terraform validate
terraform plan
```

Format your code and update docs:

```bash
terraform fmt -recursive
terraform-docs markdown table . --output-file README.md --output-mode inject
```

Add comments for anything complex. Write clear commit messages and reference issues when relevant (like "Fixes #123").

When you open the PR, explain what changed and why. Link any related issues and tag maintainers for review.

## Development Setup

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) configured with credentials
- [Packer](https://www.packer.io/downloads) >= 1.8 (optional, for custom images)
- [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/) for CI testing
- [terraform-docs](https://terraform-docs.io/) for documentation

### Local Testing

1. Clone your fork:

   ```bash
   git clone https://github.com/YOUR_USERNAME/elastic-ci-stack-for-gcp.git
   cd elastic-ci-stack-for-gcp
   ```

2. Run CI checks locally:

   ```bash
   # Test Terraform formatting
   docker-compose run terraform fmt -check -recursive

   # Validate Terraform modules
   docker-compose run terraform sh -c "cd modules/networking && terraform init -backend=false && terraform validate"

   # Run shellcheck on scripts
   docker-compose run shellcheck sh -c "shellcheck packer/linux/scripts/*"

   # Lint markdown files
   docker-compose run markdownlint '**/*.md'
   ```

3. Create a test configuration:

   ```bash
   cd examples/compute
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

4. Test the module:

   ```bash
   terraform init
   terraform plan
   terraform apply  # Only if you want to actually create resources
   terraform destroy  # Clean up when done
   ```

### Code Style

Stick to 2 spaces for indentation and follow the [Terraform Style Guide](https://www.terraform.io/docs/language/syntax/style.html). Run `terraform fmt -recursive` before you commit.

Try to keep lines under 120 characters, and add comments when you're doing something non-obvious.

For shell scripts, follow the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) and ensure they pass shellcheck.

### Documentation

Every variable needs a description. If it's complex, add examples to help people understand what goes there. Before opening a PR, regenerate module READMEs:

```bash
# For root module
terraform-docs markdown table . --output-file README.md

# For sub-modules
cd modules/networking
terraform-docs markdown table . --output-file README.md
```

## Project Structure

```sh
.
├── *.tf                    # Root module Terraform files
├── modules/                # Sub-modules
│   ├── networking/        # VPC, subnets, firewall, NAT
│   ├── iam/               # Service accounts and permissions
│   └── compute/           # Managed instance groups and agents
├── packer/                # Custom VM image definitions
│   └── linux/             # Debian-based Buildkite agent image
├── examples/              # Usage examples
│   ├── networking/        # Standalone networking
│   ├── iam/               # Standalone IAM
│   └── compute/           # Full stack deployment
├── templates/             # Configuration templates
├── .buildkite/            # CI pipeline configuration
├── docker-compose.yml     # Local CI testing tools
└── README.md              # Generated documentation
```

## Testing Changes

### Module Testing

When making changes to modules, test them individually:

```bash
# Test networking module
cd modules/networking
terraform init -backend=false
terraform validate

# Test IAM module
cd modules/iam
terraform init -backend=false
terraform validate

# Test compute module
cd modules/compute
terraform init -backend=false
terraform validate
```

### Packer Image Testing

When making changes to Packer images:

```bash
# Validate Packer template
cd packer/linux
packer validate -var project_id=test-project buildkite-vm-image.pkr.hcl

# Format Packer files
packer fmt .

# Build test image (requires GCP credentials)
packer build -var project_id=YOUR_PROJECT buildkite-vm-image.pkr.hcl
```

### Integration Testing

For full integration testing, deploy the complete stack in a test GCP project:

```bash
# Use the root module
terraform init
terraform plan -var="project_id=test-project" -var="buildkite_agent_token=test-token"
terraform apply -auto-approve
# Verify agents connect and run test builds
terraform destroy -auto-approve
```

## Release Process

Releases are managed by maintainers. The process includes:

1. Version bump in relevant files
2. Update CHANGELOG.md with release notes
3. Create GitHub release with notes
4. Tag the release (semantic versioning: v0.1.0, v0.2.0, etc.)
5. Update examples to reference new version

## CI/CD Pipeline

This project uses Buildkite for CI/CD. The pipeline runs:

- Terraform format checks (`terraform fmt -check`)
- Terraform validation for all modules
- TFLint for best practices
- TFSec for security scanning
- Packer validation
- ShellCheck for bash scripts
- Markdown linting

See [`.buildkite/pipeline.yml`](.buildkite/pipeline.yml) for the full pipeline definition.

## Common Development Tasks

### Adding a New Variable

1. Add the variable to the appropriate `variables.tf` file
2. Add validation rules if applicable
3. Update the variable in `main.tf` if it's passed to a module
4. Update examples to show usage
5. Regenerate documentation with `terraform-docs`

### Adding a New Output

1. Add the output to the appropriate `outputs.tf` file
2. If it's a sub-module output, expose it in the root module's `outputs.tf`
3. Update examples to demonstrate usage
4. Regenerate documentation

### Adding a New Module

1. Create a new directory under `modules/`
2. Add `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
3. Create a README.md with module documentation
4. Add an example under `examples/`
5. Wire it into the root module if appropriate
6. Add CI validation for the new module

## Questions?

- Open a [GitHub Issue](https://github.com/buildkite/elastic-ci-stack-for-gcp/issues)
- Check the [Buildkite Documentation](https://buildkite.com/docs)
- Review the [AWS version](https://github.com/buildkite/elastic-ci-stack-for-aws) for reference

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
