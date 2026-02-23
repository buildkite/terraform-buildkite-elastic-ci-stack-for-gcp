locals {
  # Determine if we need to create a service account
  create_service_account = var.service_account_email == ""

  # Use provided service account or create a new one
  service_account_email = local.create_service_account ? google_service_account.metrics_function[0].email : var.service_account_email

  # Service account ID for creation
  service_account_id = "${var.function_name}-sa"

  # Determine token configuration method
  use_secret_manager = var.buildkite_agent_token_secret != ""
  use_env_token      = var.buildkite_agent_token != ""

  # Scheduler job name
  scheduler_job_name = "${var.function_name}-scheduler"
}

# Validate that exactly one token method is configured
resource "null_resource" "token_validation" {
  count = (local.use_secret_manager && local.use_env_token) || (!local.use_secret_manager && !local.use_env_token) ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: Exactly one of buildkite_agent_token or buildkite_agent_token_secret must be provided' && exit 1"
  }
}

# Create service account if not provided
resource "google_service_account" "metrics_function" {
  count        = local.create_service_account ? 1 : 0
  account_id   = local.service_account_id
  display_name = "Buildkite Agent Metrics Cloud Function"
  description  = "Service account for Buildkite agent metrics collection Cloud Function"
  project      = var.project_id
}

# Grant necessary permissions to the service account (only if we created it)
resource "google_project_iam_member" "metrics_writer" {
  count   = local.create_service_account ? 1 : 0
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${local.service_account_email}"
}

# Grant Secret Manager access if using secret (only if we created the SA)
resource "google_project_iam_member" "secret_accessor" {
  count   = local.create_service_account && local.use_secret_manager ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${local.service_account_email}"
}

# Grant Storage Object Viewer to allow Cloud Build to access function source
# This is always needed for Cloud Functions v2, regardless of whether we created the SA
# The gcf-v2-sources-* bucket is automatically created and needs read access
resource "google_project_iam_member" "storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${local.service_account_email}"
}

# Create the Cloud Function
resource "google_cloudfunctions2_function" "metrics_function" {
  name        = var.function_name
  location    = var.region
  project     = var.project_id
  description = "Collects Buildkite agent metrics and sends them to Cloud Monitoring"

  build_config {
    runtime         = "go124"
    entry_point     = "buildkite-agent-metrics"
    service_account = "projects/${var.project_id}/serviceAccounts/${local.service_account_email}"

    source {
      storage_source {
        bucket = var.function_source_bucket
        object = var.function_source_object
      }
    }
  }

  service_config {
    max_instance_count    = 3
    min_instance_count    = 0
    available_memory      = "256M"
    timeout_seconds       = 15
    service_account_email = local.service_account_email

    environment_variables = merge(
      {
        GCP_PROJECT_ID = var.project_id
      },
      local.use_env_token ? {
        BUILDKITE_AGENT_TOKENS = var.buildkite_agent_token
      } : {},
      local.use_secret_manager ? {
        BUILDKITE_AGENT_TOKEN_SECRET_NAMES = var.buildkite_agent_token_secret
      } : {},
      var.buildkite_queue != "" ? {
        BUILDKITE_QUEUE = var.buildkite_queue
      } : {},
      var.enable_debug ? {
        BUILDKITE_DEBUG = "true"
      } : {}
    )

    ingress_settings               = "ALLOW_ALL"
    all_traffic_on_latest_revision = true
  }

  labels = var.labels

  # Ensure IAM permissions are in place before creating the function
  # The storage_viewer permission is required for Cloud Build to access the gcf-v2-sources bucket
  depends_on = [
    google_project_iam_member.storage_viewer,
    google_project_iam_member.metrics_writer,
    google_project_iam_member.secret_accessor,
  ]
}

# Grant the service account permission to invoke the function
resource "google_cloud_run_service_iam_member" "invoker" {
  location = google_cloudfunctions2_function.metrics_function.location
  project  = var.project_id
  service  = google_cloudfunctions2_function.metrics_function.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${local.service_account_email}"
}

# Create Cloud Scheduler job to trigger the function
resource "google_cloud_scheduler_job" "metrics_trigger" {
  name        = local.scheduler_job_name
  description = "Triggers the Buildkite agent metrics collection function"
  schedule    = var.schedule_interval
  project     = var.project_id
  region      = var.region

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.metrics_function.service_config[0].uri

    oidc_token {
      service_account_email = local.service_account_email
    }
  }

  depends_on = [
    google_cloudfunctions2_function.metrics_function,
    google_cloud_run_service_iam_member.invoker
  ]
}

# Invoke the metrics function once during deployment to create the custom metric.
# This ensures the metric exists before the autoscaler is created, preventing
# the autoscaler from being configured with an undefined metric reference.
# We use "gcloud scheduler jobs run" which triggers the job using its configured
# service account authentication, rather than trying to call the function directly.
resource "null_resource" "initial_metrics_invocation" {
  triggers = {
    scheduler_job = google_cloud_scheduler_job.metrics_trigger.name
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Cloud Scheduler job to be ready..."
      for i in {1..30}; do
        if gcloud scheduler jobs describe "${google_cloud_scheduler_job.metrics_trigger.name}" \
            --project="${var.project_id}" \
            --location="${var.region}" \
            --format="value(state)" 2>/dev/null | grep -q "ENABLED"; then
          echo "Scheduler job is ready."
          break
        fi
        echo "Waiting for scheduler job... (attempt $i/30)"
        sleep 2
      done

      echo "Triggering metrics function via Cloud Scheduler to create initial metric..."
      if gcloud scheduler jobs run "${google_cloud_scheduler_job.metrics_trigger.name}" \
          --project="${var.project_id}" \
          --location="${var.region}" 2>&1; then
        echo "Scheduler job triggered successfully."
      else
        echo "Warning: Failed to trigger scheduler job. The autoscaler may need to be recreated after the first scheduled run."
      fi

      # Give the function time to execute and the metric time to propagate
      # Note: The metrics function converts hyphens to underscores in the org slug
      # because GCP custom metrics don't allow hyphens in the metric type path.
      echo "Waiting for metric to be created and propagate..."
      ORG_SLUG_SANITIZED=$(echo "${var.buildkite_organization_slug}" | tr '-' '_')
      METRIC_TYPE="custom.googleapis.com/buildkite/$ORG_SLUG_SANITIZED/ScheduledJobsCount"
      PROJECT_ID="${var.project_id}"
      FILTER="metric.type = \"$METRIC_TYPE\""

      # Use the Cloud Monitoring API directly to check for the metric descriptor
      # The gcloud CLI doesn't have a metrics-descriptors command, so we use curl with the REST API
      # We use the list endpoint with a filter since the GET endpoint has URL encoding issues
      for i in {1..60}; do
        ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null)
        if [ -n "$ACCESS_TOKEN" ]; then
          RESPONSE=$(curl -s -G \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            "https://monitoring.googleapis.com/v3/projects/$PROJECT_ID/metricDescriptors" \
            --data-urlencode "filter=$FILTER")
          if echo "$RESPONSE" | grep -q "\"type\": \"$METRIC_TYPE\""; then
            echo "Custom metric '$METRIC_TYPE' has been created successfully."
            exit 0
          fi
        fi
        echo "Waiting for metric to appear... (attempt $i/60, waiting up to 2 minutes)"
        sleep 2
      done

      echo "Warning: Metric verification timed out. The metric may still be propagating."
      echo "The autoscaler may need a few minutes before it can use the metric."
    EOT
  }

  depends_on = [
    google_cloudfunctions2_function.metrics_function,
    google_cloud_run_service_iam_member.invoker,
    google_cloud_scheduler_job.metrics_trigger
  ]
}
