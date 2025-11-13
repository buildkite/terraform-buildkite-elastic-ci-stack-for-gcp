# Autoscaling

The Elastic CI Stack for GCP compute module is currently running **without autoscaling**. The managed instance group will maintain a fixed size based on manual configuration.

## Why is Autoscaling Disabled?

Autoscaling requires custom Cloud Monitoring metrics that are published by the **buildkite-agent-metrics** Cloud Function. Without these metrics, the autoscaler will show errors like:

```sh
The monitoring metric that was specified does not exist or does not have the required labels.
```

## Current Configuration

- **Autoscaling**: Disabled (`enable_autoscaling = false`)
- **Instance Group**: `elastic-ci-stack-mig`
- **Current Target Size**: Manually managed
- **Min/Max Size**: Configured but not enforced by autoscaler

## Manually Scaling the Instance Group

You can manually adjust the number of instances:

```bash
# Set to 5 instances
gcloud compute instance-groups managed resize elastic-ci-stack-mig \
  --region=us-central1 \
  --size=5 \
  --project=PROJECT_ID

# Scale to 0 (no instances running)
gcloud compute instance-groups managed resize elastic-ci-stack-mig \
  --region=us-central1 \
  --size=0 \
  --project=PROJECT_ID
```

## Enabling Autoscaling

To enable metric-based autoscaling, you need to:

### 1. Deploy the buildkite-agent-metrics Cloud Function

This function monitors your Buildkite queue and publishes custom metrics to Cloud Monitoring:

- `custom.googleapis.com/buildkite/scheduled_jobs` - Number of jobs waiting in queue
- `custom.googleapis.com/buildkite/running_jobs` - Number of jobs currently running

**Reference**: The metrics function will be deployed in a future module.

### 2. Update Terraform Configuration

Once the metrics function is deployed and publishing metrics:

```hcl
# In terraform.tfvars or your configuration
enable_autoscaling = true
```

### 3. Apply the Changes

```bash
cd examples/compute
terraform plan  # Review the changes
terraform apply  # Create the autoscaler
```

### 4. Verify Autoscaling

```bash
# Check autoscaler status
gcloud compute instance-groups managed describe elastic-ci-stack-mig \
  --region=us-central1 \
  --project=PROJECT_ID

# View autoscaling events
gcloud logging read "resource.type=gce_autoscaler AND resource.labels.autoscaler_name=elastic-ci-stack-autoscaler" \
  --limit=20 \
  --format=json \
  --project=PROJECT_ID
```

## How Autoscaling Works

When enabled, the autoscaler will:

1. **Monitor custom metrics** published by buildkite-agent-metrics function
2. **Calculate required capacity** based on:
   - Scheduled jobs (waiting in queue)
   - Running jobs (currently executing)
   - Jobs per instance target (default: 1)
3. **Scale the instance group** between `min_size` and `max_size`
4. **Respect cooldown period** (default: 60 seconds) to prevent thrashing

### Scaling Formula

```sh
desired_instances = max(
  scheduled_jobs / jobs_per_instance,
  running_jobs / jobs_per_instance
)

# Bounded by min_size and max_size
final_size = clamp(desired_instances, min_size, max_size)
```

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_autoscaling` | `false` | Enable/disable autoscaling |
| `min_size` | `0` | Minimum number of instances |
| `max_size` | `10` | Maximum number of instances |
| `cooldown_period` | `60` | Seconds between scaling actions |
| `autoscaling_jobs_per_instance` | `1` | Target jobs per instance |

## Resources

- [GCP Autoscaling Documentation](https://cloud.google.com/compute/docs/autoscaler)
- [Custom Metrics](https://cloud.google.com/monitoring/custom-metrics)
- [Buildkite Agent Metrics](https://github.com/buildkite/buildkite-agent-metrics)
