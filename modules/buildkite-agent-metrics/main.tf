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
resource "google_project_iam_member" "storage_viewer" {
  count   = local.create_service_account ? 1 : 0
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
        BUILDKITE_AGENT_TOKEN_SECRET_NAMES = "projects/${var.project_id}/secrets/${var.buildkite_agent_token_secret}/versions/latest"
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
