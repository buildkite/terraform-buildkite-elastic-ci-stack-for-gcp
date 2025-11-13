# Buildkite Agent Metrics Cloud Function Module

This Terraform module deploys a Google Cloud Function that collects Buildkite CI/CD metrics and sends them to Google Cloud Monitoring (formerly Stackdriver) for use in auto-scaling decisions.

## Overview

The module creates:
- A Cloud Function (Gen 2) that fetches metrics from the Buildkite API
- A Cloud Scheduler job to trigger the function periodically
- A service account with necessary permissions (optional)
- IAM bindings for metric writing and secret access

## Prerequisites

1. **APIs to Enable**: The following Google Cloud APIs must be enabled in your project:
   - Cloud Functions API (`cloudfunctions.googleapis.com`)
   - Cloud Run API (`run.googleapis.com`)
   - Cloud Scheduler API (`cloudscheduler.googleapis.com`)
   - Cloud Monitoring API (`monitoring.googleapis.com`)
   - Secret Manager API (`secretmanager.googleapis.com`) - if using Secret Manager for tokens

2. **Buildkite Agent Token**: Obtain from your Buildkite organization's Agents page

## Usage

### Basic Usage with Environment Variable Token

```hcl
module "buildkite_metrics" {
  source = "./modules/buildkite-agent-metrics"

  project_id            = "my-gcp-project"
  region               = "us-central1"
  buildkite_agent_token = "your-buildkite-agent-token"
}
```

### Production Usage with Secret Manager

First, create a secret in Google Secret Manager:

```bash
echo -n "your-buildkite-agent-token" | gcloud secrets create buildkite-agent-token --data-file=-
```

Then use the module:

```hcl
module "buildkite_metrics" {
  source = "./modules/buildkite-agent-metrics"

  project_id                        = "my-gcp-project"
  region                           = "us-central1"
  buildkite_agent_token_secret = "buildkite-agent-token"
}
```

### Advanced Configuration

```hcl
module "buildkite_metrics" {
  source = "./modules/buildkite-agent-metrics"

  project_id                        = "my-gcp-project"
  region                           = "us-central1"
  buildkite_agent_token_secret = "buildkite-agent-token"
  
  # Monitor specific queues
  buildkite_queue = "backend,frontend,deploy"
  
  # Custom function name
  function_name = "bk-metrics-collector"
  
  # Run every 5 minutes instead of every minute
  schedule_interval = "*/5 * * * *"
  
  # Enable debug logging
  enable_debug = true
  
  # Use existing service account
  service_account_email = "existing-sa@my-project.iam.gserviceaccount.com"
  
  # Custom labels
  labels = {
    environment = "production"
    team        = "platform"
    managed_by  = "terraform"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_id` | GCP project ID where the Cloud Function will be deployed | `string` | n/a | yes |
| `region` | GCP region where the Cloud Function will be deployed | `string` | `"us-central1"` | no |
| `buildkite_agent_token` | Buildkite agent token for metrics collection (use `buildkite_agent_token_secret` for production) | `string` | `""` | no |
| `buildkite_agent_token_secret` | Name of the Google Secret Manager secret containing the Buildkite agent token | `string` | `""` | no |
| `buildkite_queue` | Comma-separated list of Buildkite queues to monitor. If empty, monitors all queues | `string` | `""` | no |
| `function_name` | Name of the Cloud Function | `string` | `"buildkite-agent-metrics"` | no |
| `schedule_interval` | Cloud Scheduler cron expression for triggering the function | `string` | `"* * * * *"` | no |
| `service_account_email` | Email of the service account to run the Cloud Function. If not provided, a new one will be created | `string` | `""` | no |
| `enable_debug` | Enable debug logging for the Cloud Function | `bool` | `false` | no |
| `labels` | Labels to apply to the Cloud Function and related resources | `map(string)` | `{managed_by = "terraform", purpose = "buildkite-metrics"}` | no |
| `function_source_bucket` | GCS bucket containing the pre-built Cloud Function zip file | `string` | `"buildkite-cloud-functions"` | no |
| `function_source_object` | Path to the Cloud Function zip file in the GCS bucket | `string` | `"buildkite-agent-metrics/cloud-function-latest.zip"` | no |

**Note**: You must provide exactly one of `buildkite_agent_token` or `buildkite_agent_token_secret`.

## Outputs

| Name | Description |
|------|-------------|
| `function_uri` | The URI of the deployed Cloud Function |
| `function_name` | The name of the deployed Cloud Function |
| `service_account_email` | The email of the service account used by the Cloud Function |
| `scheduler_job_name` | The name of the Cloud Scheduler job |
| `metrics_namespace` | The Cloud Monitoring namespace where metrics will be written (`custom.googleapis.com/buildkite`) |

## Metrics Collected

The function collects the following metrics and sends them to Cloud Monitoring:

### Job Metrics
- `ScheduledJobsCount` - Number of jobs scheduled to run
- `RunningJobsCount` - Number of jobs currently running
- `UnfinishedJobsCount` - Number of unfinished jobs
- `WaitingJobsCount` - Number of jobs waiting for an agent

### Agent Metrics
- `IdleAgentCount` - Number of idle agents
- `BusyAgentCount` - Number of busy agents
- `TotalAgentCount` - Total number of agents
- `BusyAgentPercentage` - Percentage of agents that are busy

## Viewing Metrics

After deployment, metrics will be available in Cloud Monitoring under the namespace `custom.googleapis.com/buildkite`.

To view metrics:
1. Go to the [Cloud Console Metrics Explorer](https://console.cloud.google.com/monitoring/metrics-explorer)
2. Select resource type: `Global`
3. Select metric: `custom.googleapis.com/buildkite/YOUR_ORG/*`

## Troubleshooting

### View Function Logs

```bash
gcloud functions logs read buildkite-agent-metrics \
  --region=us-central1 \
  --limit=50
```

### Common Issues

1. **"Permission denied" errors**: Ensure the service account has the `monitoring.metricWriter` role
2. **"Token invalid" errors**: Verify your Buildkite token is correct and has read access to agents and builds
3. **No metrics appearing**: Check function logs, ensure the function is being triggered, and wait 2-3 minutes for metrics to appear
4. **Function timeout**: The function is configured with a 15-second timeout, which should be sufficient for most cases

## Security Considerations

- **Token Storage**: Use Secret Manager (`buildkite_agent_token_secret`) for production deployments rather than passing tokens directly
- **Service Account**: The module creates a dedicated service account with minimal permissions by default
- **Network Access**: The function requires outbound internet access to reach the Buildkite API
