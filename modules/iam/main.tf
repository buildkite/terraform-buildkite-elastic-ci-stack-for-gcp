# GCP IAM Module for Elastic CI Stack
# This module creates service accounts and IAM policies for:
# 1. Buildkite agent VMs
# 2. buildkite-agent-metrics Cloud Function

# Equivalent to AWS IAMRole for EC2 instances
resource "google_service_account" "agent" {
  account_id   = var.agent_service_account_id
  display_name = "Elastic CI Stack Buildkite Agent"
  description  = "Service account for Buildkite agent compute instances in managed instance groups"
  project      = var.project_id
}

# Allows agents to describe their own instance and auto-scaling group
resource "google_project_iam_member" "agent_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.agent.email}"
}

# Allows agents to write custom metrics to Cloud Monitoring
resource "google_project_iam_member" "agent_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.agent.email}"
}

# Allows agents to write logs to Cloud Logging
resource "google_project_iam_member" "agent_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.agent.email}"
}

# Allows setting instance health and deleting instances within the managed instance group
resource "google_project_iam_custom_role" "agent_instance_management" {
  role_id     = var.agent_custom_role_id
  title       = "Elastic CI Stack Agent Instance Management"
  description = "Custom role for Buildkite agents to manage their own instances in managed instance groups"
  project     = var.project_id

  permissions = [
    # Equivalent to autoscaling:SetInstanceHealth, TerminateInstanceInAutoScalingGroup
    "compute.instanceGroupManagers.get",
    "compute.instances.get",
    "compute.instances.delete",
    "compute.zoneOperations.get",
    "compute.regionOperations.get",
  ]
}

# Bind custom role to agent service account
resource "google_project_iam_member" "agent_instance_management" {
  project = var.project_id
  role    = google_project_iam_custom_role.agent_instance_management.id
  member  = "serviceAccount:${google_service_account.agent.email}"
}

# Allow agents to read secrets from Secret Manager
# Useful for managing sensitive configuration like Buildkite agent tokens
# This is optional.
resource "google_project_iam_member" "agent_secret_accessor" {
  count   = var.enable_secret_access ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.agent.email}"
}

# Allow agents to read/write to Cloud Storage buckets
# Useful for artifact storage, caching, etc.
# This is optional.
resource "google_project_iam_member" "agent_storage_admin" {
  count   = var.enable_storage_access ? 1 : 0
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.agent.email}"
}

# This function monitors Buildkite queues and publishes metrics
resource "google_service_account" "metrics" {
  account_id   = var.metrics_service_account_id
  display_name = "Buildkite Agent Metrics Function"
  description  = "Service account for Cloud Function that runs buildkite-agent-metrics"
  project      = var.project_id
}

# publish custom metrics
resource "google_project_iam_member" "metrics_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.metrics.email}"
}

# read instance group information
resource "google_project_iam_member" "metrics_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.metrics.email}"
}

# write function logs
resource "google_project_iam_member" "metrics_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.metrics.email}"
}

# read Buildkite API token from Secret Manager
resource "google_project_iam_member" "metrics_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.metrics.email}"
}

# access Cloud Storage for Cloud Function builds
resource "google_project_iam_member" "metrics_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.metrics.email}"
}

# access Artifact Registry for Cloud Function build caching (needs write for cache)
resource "google_project_iam_member" "metrics_artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.metrics.email}"
}

# Allows the metrics function to scale instance groups based on queue depth
resource "google_project_iam_custom_role" "metrics_autoscaler" {
  role_id     = var.metrics_custom_role_id
  title       = "Elastic CI Stack Metrics Autoscaler"
  description = "Custom role for metrics function to manage instance group scaling"
  project     = var.project_id

  permissions = [
    "compute.instanceGroupManagers.get",
    "compute.instanceGroupManagers.update",
    "compute.instanceGroups.get",
    "compute.instanceGroups.list",
    "compute.autoscalers.get",
    "compute.autoscalers.update",
  ]
}

# Bind custom autoscaler role to metrics service account
resource "google_project_iam_member" "metrics_autoscaler" {
  project = var.project_id
  role    = google_project_iam_custom_role.metrics_autoscaler.id
  member  = "serviceAccount:${google_service_account.metrics.email}"
}
