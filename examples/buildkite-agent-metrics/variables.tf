variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "buildkite_agent_token" {
  description = "Buildkite agent token for metrics collection (use this OR buildkite_agent_token_secret)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "buildkite_agent_token_secret" {
  description = "Name of the Google Secret Manager secret containing the Buildkite agent token"
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
  description = "Comma-separated list of Buildkite queues to monitor"
  type        = string
  default     = ""
}

variable "schedule_interval" {
  description = "Cron expression for Cloud Scheduler"
  type        = string
  default     = "* * * * *" # Every minute
}

variable "enable_debug" {
  description = "Enable debug logging"
  type        = bool
  default     = false
}
