# IAM Module for Elastic CI Stack

This Terraform module creates the necessary IAM resources (service accounts, roles, and bindings) for the Elastic CI Stack on GCP.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | >= 4.0, < 8.0 |

## Overview

This module creates two service accounts with associated IAM roles:

1. **Buildkite Agent Service Account**: Used by VM instances in managed instance groups running Buildkite agents
2. **Metrics Function Service Account**: Used by the Cloud Function that runs buildkite-agent-metrics

## Resources Created

### Agent Service Account

**Service Account**: `elastic-ci-agent@{project}.iam.gserviceaccount.com`

**IAM Roles Bound**:

- `roles/compute.viewer` - View compute resources and describe instances
- `roles/monitoring.metricWriter` - Write custom metrics to Cloud Monitoring
- `roles/logging.logWriter` - Write logs to Cloud Logging
- Custom role for instance management (delete/health check)
- `roles/secretmanager.secretAccessor` (optional) - Read secrets from Secret Manager
- `roles/storage.objectAdmin` (optional) - Read/write to Cloud Storage

### Metrics Service Account

**Service Account**: `elastic-ci-metrics@{project}.iam.gserviceaccount.com`

**IAM Roles Bound**:

- `roles/monitoring.metricWriter` - Publish custom metrics
- `roles/compute.viewer` - Read instance group information
- `roles/logging.logWriter` - Write function logs
- `roles/secretmanager.secretAccessor` - Read Buildkite API token
- Custom role for autoscaling (manage instance group size)

## Usage

```hcl
module "iam" {
  source = "../../modules/iam"

  project_id                  = "my-gcp-project"
  agent_service_account_id    = "elastic-ci-agent"
  metrics_service_account_id  = "elastic-ci-metrics"
  agent_custom_role_id        = "elasticCiAgentInstanceMgmt"
  metrics_custom_role_id      = "elasticCiMetricsAutoscaler"
  enable_secret_access        = true
  enable_storage_access       = false
}
```

## Using the Agent Service Account with Compute Instances

When creating compute instance templates or managed instance groups, attach the agent service account:

```hcl
resource "google_compute_instance_template" "buildkite_agent" {
  # ... other configuration ...

  service_account {
    email  = module.iam.agent_service_account_email
    scopes = ["cloud-platform"]
  }
}
```

## Using the Metrics Service Account with Cloud Functions

When creating the Cloud Function for buildkite-agent-metrics:

```hcl
resource "google_cloudfunctions2_function" "metrics" {
  # ... other configuration ...

  service_config {
    service_account_email = module.iam.metrics_service_account_email
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_id` | GCP project ID where resources will be created | `string` | n/a | yes |
| `agent_service_account_id` | ID for the Buildkite agent service account | `string` | `"elastic-ci-agent"` | no |
| `metrics_service_account_id` | ID for the metrics Cloud Function service account | `string` | `"elastic-ci-metrics"` | no |
| `agent_custom_role_id` | ID for the custom IAM role for agent instance management | `string` | `"elasticCiAgentInstanceMgmt"` | no |
| `metrics_custom_role_id` | ID for the custom IAM role for metrics autoscaling | `string` | `"elasticCiMetricsAutoscaler"` | no |
| `enable_secret_access` | Grant agent service account access to Secret Manager | `bool` | `true` | no |
| `enable_storage_access` | Grant agent service account access to Cloud Storage | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| `agent_service_account_email` | Email address of the Buildkite agent service account (use with compute instances) |
| `agent_service_account_id` | Unique ID of the Buildkite agent service account |
| `agent_service_account_name` | Fully qualified name of the Buildkite agent service account |
| `agent_custom_role_id` | ID of the custom IAM role for agent instance management |
| `agent_custom_role_name` | Name of the custom IAM role for agent instance management |
| `metrics_service_account_email` | Email address of the metrics Cloud Function service account |
| `metrics_service_account_id` | Unique ID of the metrics service account |
| `metrics_service_account_name` | Fully qualified name of the metrics service account |
| `metrics_custom_role_id` | ID of the custom IAM role for metrics autoscaling |
| `metrics_custom_role_name` | Name of the custom IAM role for metrics autoscaling |

## Custom IAM Roles

### Agent Instance Management Role

Allows agents to manage their own instances within managed instance groups:

- `compute.instanceGroupManagers.get`
- `compute.instances.get`
- `compute.instances.delete`
- `compute.zoneOperations.get`
- `compute.regionOperations.get`

This is equivalent to the AWS permissions:

- `autoscaling:SetInstanceHealth`
- `autoscaling:TerminateInstanceInAutoScalingGroup`

### Metrics Autoscaler Role

Allows the metrics function to scale instance groups based on queue depth:

- `compute.instanceGroupManagers.get/update`
- `compute.instanceGroups.get/list`
- `compute.autoscalers.get/update`
- `compute.regionAutoscalers.get/update`

## Verifying Resource Creation

After applying the module, you can verify the resources were created successfully:

### Verify Service Accounts

```bash
# List all service accounts in the project
gcloud iam service-accounts list --project=YOUR_PROJECT_ID

# Get details of the agent service account
gcloud iam service-accounts describe elastic-ci-agent@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Get details of the metrics service account
gcloud iam service-accounts describe elastic-ci-metrics@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

### Verify Custom IAM Roles

```bash
# List custom roles in the project
gcloud iam roles list --project=YOUR_PROJECT_ID

# Describe the agent instance management role
gcloud iam roles describe elasticCiAgentInstanceMgmt --project=YOUR_PROJECT_ID

# Describe the metrics autoscaler role
gcloud iam roles describe elasticCiMetricsAutoscaler --project=YOUR_PROJECT_ID
```

### Verify IAM Policy Bindings

```bash
# Get IAM policy for the project (shows all bindings)
gcloud projects get-iam-policy YOUR_PROJECT_ID

# Filter for agent service account bindings
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:elastic-ci-agent@YOUR_PROJECT_ID.iam.gserviceaccount.com"

# Filter for metrics service account bindings
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:elastic-ci-metrics@YOUR_PROJECT_ID.iam.gserviceaccount.com"
```

### Test Service Account Permissions

```bash
# Test if the agent service account can write metrics
gcloud iam service-accounts test-iam-permissions \
  elastic-ci-agent@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --permissions=monitoring.metricDescriptors.create,monitoring.timeSeries.create

# Test if the metrics service account can access secrets
gcloud iam service-accounts test-iam-permissions \
  elastic-ci-metrics@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --permissions=secretmanager.versions.access
```

## Examples

See the [examples/iam](../../examples/iam) directory for complete usage examples.

## License

See the repository LICENSE file.
