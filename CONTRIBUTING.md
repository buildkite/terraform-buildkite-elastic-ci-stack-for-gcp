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

Maintainers cut releases from `main`. A release is a `vX.Y.Z` Git tag on the merge commit of a release pull request. The release pull request only changes version numbers.

> [!IMPORTANT]
> The Terraform Registry publishes a new module version as soon as a `vX.Y.Z` tag is pushed. Publishing a GitHub release creates its tag, so it publishes the version too. Published versions can't be changed, so every change in a release must be on `main` before you publish the GitHub release.

### 1. Choose the version

Compare `main` with the previous release (`https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-gcp/compare/vA.B.C...main`) and choose the release type:

| Release type | Use when | Examples |
| --- | --- | --- |
| Major (`vX.0.0`) | Upgrading can break an existing configuration or deployment, or needs manual steps | Removing or renaming an input variable or output; changing a default incompatibly; a new Buildkite Agent major version; a new image family |
| Minor (`vX.Y.0`) | New behavior that existing configurations don't need to change for | A new input variable whose default keeps existing behavior; a new output or agent tag; a default image with new features |
| Patch (`vX.Y.Z`) | Backwards-compatible fixes only | Bug fixes; a default image with only bug or security fixes; documentation |

If the changes span more than one type, use the largest. If you're unsure, use the larger type.

Tags always have a leading `v` (for example `v1.2.0`). This process covers stable releases only.

### 2. Merge prerequisites

These changes go in their own pull requests, merged before the release pull request:

- **Default image.** If anything under `packer/`, `templates/` or `goss.yaml` changed since the previous release, update the `image` default in both `variables.tf` and `examples/compute/variables.tf`.
  Use an image published by a `main` build of the [image-builder pipeline](docs/image-release-pipeline.md) that includes those changes, and link the image build in the pull request.
- **Major releases only.** Land these with the breaking change:
  - Set `MODULE_MAJOR_VERSION` in `.buildkite/scripts/publish-image` to `vX`, so `main` image builds publish to the `buildkite-ci-stack-vX-x86-64` and `buildkite-ci-stack-vX-arm64` families.
    The default image must come from one of these builds. Check with `gcloud compute images describe IMAGE_NAME --project buildkite-gcp-stack --format='value(family)'`.
  - Update the image family names in `docs/image-release-pipeline.md`.
  - Add `docs/upgrading-to-vX.md` and link it from `README.md`.

### 3. Open and merge the release pull request

Create a branch named `release-vX.Y.Z` from `main` and make only these changes:

- **Every release:** set `stack_version` in `modules/compute/main.tf` to `vX.Y.Z`. Agents report it as the `buildkite-gcp-stack` tag, so it must match the release tag exactly, including the leading `v`.
- **Major releases only:** set the module example in `README.md` to `version = "~> X.0"`.

Open the pull request with the [release pull request template](.github/PULL_REQUEST_TEMPLATE/release.md), title it `Release vX.Y.Z`, and complete its checklist:

```bash
gh pr create --title "Release vX.Y.Z" --template release.md
```

In the browser, add `?quick_pull=1&template=release.md` to the compare URL, for example `https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-gcp/compare/main...release-vX.Y.Z?quick_pull=1&template=release.md`.

Merge the pull request after a maintainer approves it and CI passes.

### 4. Publish the GitHub release

Draft the release on the release pull request's merge commit. Use that commit even if other pull requests have merged since:

```bash
gh release create vX.Y.Z --draft --target MERGE_COMMIT_SHA --title vX.Y.Z --generate-notes
```

Review the draft notes. For a major release, start them with an upgrade callout that links `docs/upgrading-to-vX.md`. Then publish the draft. Publishing creates the `vX.Y.Z` tag, and the Terraform Registry publishes the version.

### 5. Check the release

- `vX.Y.Z` appears on the [Terraform Registry](https://registry.terraform.io/modules/buildkite/elastic-ci-stack-for-gcp/buildkite) within a few minutes. If it doesn't, select **Resync Module** under **Manage Module** on the registry page.
- `git show vX.Y.Z:modules/compute/main.tf | grep stack_version` shows `vX.Y.Z`.

If anything is wrong after the release is published, don't move or delete the tag. Fix it on `main` and release a new patch version.

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
