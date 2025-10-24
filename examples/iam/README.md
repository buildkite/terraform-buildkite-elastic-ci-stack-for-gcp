# IAM Module Example

This example demonstrates how to use the IAM module to create service accounts and IAM roles for the Elastic CI Stack on GCP.

## What This Creates

- Service account for Buildkite agent VMs with appropriate IAM roles
- Service account for buildkite-agent-metrics Cloud Function with appropriate IAM roles
- Custom IAM roles for instance management and autoscaling
- IAM bindings granting the necessary permissions

## Prerequisites

1. A GCP project with the following APIs enabled:
   - Compute Engine API
   - Cloud Functions API (if using metrics function)
   - Secret Manager API (if using secrets)
   - Cloud Monitoring API
   - Cloud Logging API

2. Terraform >= 1.0

3. GCP credentials with permissions to:
   - Create service accounts
   - Create custom IAM roles
   - Bind IAM roles to service accounts

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your values:

```hcl
project = "my-gcp-project"
region  = "us-central1"
```

2. Initialize Terraform:

```bash
terraform init
```

3. Review the planned changes:

```bash
terraform plan
```

4. Apply the configuration:

```bash
terraform apply
```

## Outputs

After applying, you'll receive:

- `agent_service_account_email` - Use this with compute instance templates
- `metrics_service_account_email` - Use this with Cloud Functions
- Custom role names for reference

## Using the Service Accounts

### With Compute Instance Templates

```hcl
resource "google_compute_instance_template" "buildkite_agent" {
  name_prefix = "buildkite-agent-"
  machine_type = "n2-standard-2"

  # ... other configuration ...

  service_account {
    # Use the agent service account email from this module
    email  = module.iam.agent_service_account_email
    scopes = ["cloud-platform"]
  }
}
```

### With Cloud Functions (for metrics)

```hcl
resource "google_cloudfunctions2_function" "metrics" {
  name     = "buildkite-agent-metrics"
  location = "us-central1"

  # ... other configuration ...

  service_config {
    # Use the metrics service account email from this module
    service_account_email = module.iam.metrics_service_account_email
  }
}
```

## Customization

You can customize the service account and role names:

```hcl
module "iam" {
  source = "../../modules/iam"

  project_id                  = "my-project"
  agent_service_account_id    = "my-custom-agent-sa"
  metrics_service_account_id  = "my-custom-metrics-sa"
  agent_custom_role_id        = "myCustomAgentRole"
  metrics_custom_role_id      = "myCustomMetricsRole"
  enable_secret_access        = true
  enable_storage_access       = true  # Enable if you need artifact storage
}
```

## Cleanup

To destroy all created resources:

```bash
terraform destroy
```

Note: Service accounts and custom IAM roles will be deleted. Ensure no resources are still using these service accounts before destroying.
