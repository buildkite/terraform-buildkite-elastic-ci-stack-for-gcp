# Buildkite Agent Metrics Example

This example demonstrates how to deploy the Buildkite Agent Metrics Cloud Function using the Terraform module.

## Prerequisites

1. Set up your GCP project and authenticate:

```bash
export PROJECT_ID="your-gcp-project-id"
gcloud auth application-default login
gcloud config set project $PROJECT_ID
```

2. Enable required APIs:

```bash
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable cloudscheduler.googleapis.com
gcloud services enable monitoring.googleapis.com
```

3. Get your Buildkite agent token from your organization's Agents page.

## Usage

1. Copy the example variables file and update with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project ID and Buildkite token
```

2. Initialize and apply Terraform:

```bash
terraform init
terraform plan
terraform apply
```

3. Verify the deployment:

```bash
# Check function status
gcloud functions describe buildkite-agent-metrics --region=us-central1

# View recent logs
gcloud functions logs read buildkite-agent-metrics --region=us-central1 --limit=20

# Manually trigger the function
FUNCTION_URI=$(terraform output -raw function_uri)
curl -X POST $FUNCTION_URI
```

4. View metrics in Cloud Monitoring:
   - Navigate to [Metrics Explorer](https://console.cloud.google.com/monitoring/metrics-explorer)
   - Select Resource Type: `Global`
   - Search for metrics starting with `custom.googleapis.com/buildkite/`

## Production Deployment

For production environments, it's recommended to use Google Secret Manager instead of passing the token directly:

1. Create a secret:

```bash
echo -n "your-buildkite-agent-token" | gcloud secrets create buildkite-agent-token --data-file=-
```

2. Update your module configuration to use `buildkite_agent_token_secret` instead of `buildkite_agent_token`:

```hcl
module "buildkite_metrics" {
  source = "../../modules/buildkite-agent-metrics"
  
  project_id                        = var.project_id
  buildkite_agent_token_secret = "buildkite-agent-token"
  # ... other configuration
}
```

## Cleanup

To remove all resources created by this example:

```bash
terraform destroy
```
