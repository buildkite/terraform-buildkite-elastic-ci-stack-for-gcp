variable "project_id" {
  description = "GCP project ID where the Cloud Function will be deployed"
  type        = string

  validation {
    condition = (
      can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id)) &&
      !can(regex("--", var.project_id)) &&
      !can(regex("(?i)google", var.project_id))
    )
    error_message = "Project ID must be 6-30 characters, start with a letter, contain only lowercase letters, numbers, and single hyphens, and cannot contain the word 'google'."
  }
}

variable "region" {
  description = "GCP region where the Cloud Function will be deployed"
  type        = string
  default     = "us-central1"
}

variable "buildkite_agent_token" {
  description = "Buildkite agent token for metrics collection. Use buildkite_agent_token_secret for production deployments."
  type        = string
  default     = ""
  sensitive   = true
}

variable "buildkite_agent_token_secret" {
  description = "Name of the Google Secret Manager secret containing the Buildkite agent token (recommended for production)"
  type        = string
  default     = ""

  validation {
    condition = (
      var.buildkite_agent_token_secret == "" ||
      can(regex("^[a-zA-Z0-9_-]+$", var.buildkite_agent_token_secret))
    )
    error_message = "Secret name must contain only uppercase and lowercase letters, numerals, hyphens, and underscores."
  }
}

variable "buildkite_queue" {
  description = "Comma-separated list of Buildkite queues to monitor. If empty, monitors all queues."
  type        = string
  default     = ""
}

variable "function_name" {
  description = "Name of the Cloud Function"
  type        = string
  default     = "buildkite-agent-metrics"

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{0,62}$", var.function_name))
    error_message = "Function name must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens (max 63 chars)."
  }
}

variable "schedule_interval" {
  description = "Cloud Scheduler cron expression for triggering the function (e.g., '* * * * *' for every minute)"
  type        = string
  default     = "* * * * *"
}

variable "service_account_email" {
  description = "Email of the service account to run the Cloud Function. If not provided, a new one will be created."
  type        = string
  default     = ""
}

variable "enable_debug" {
  description = "Enable debug logging for the Cloud Function"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to the Cloud Function and related resources"
  type        = map(string)
  default = {
    managed_by = "terraform"
    purpose    = "buildkite-metrics"
  }
}

variable "function_source_bucket" {
  description = "GCS bucket containing the pre-built Cloud Function zip file"
  type        = string
  default     = "buildkite-cloud-functions"
}

variable "function_source_object" {
  description = "Path to the Cloud Function zip file in the GCS bucket"
  type        = string
  default     = "buildkite-agent-metrics/cloud-function-latest.zip"
}
