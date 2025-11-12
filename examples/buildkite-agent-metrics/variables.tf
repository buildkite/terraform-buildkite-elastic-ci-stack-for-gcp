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
  description = "Buildkite agent token for metrics collection"
  type        = string
  sensitive   = true
}

variable "buildkite_queue" {
  description = "Comma-separated list of Buildkite queues to monitor"
  type        = string
  default     = ""
}

variable "schedule_interval" {
  description = "Cron expression for Cloud Scheduler"
  type        = string
  default     = "* * * * *"  # Every minute
}

variable "enable_debug" {
  description = "Enable debug logging"
  type        = bool
  default     = false
}
