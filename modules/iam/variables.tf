variable "project_id" {
  description = "GCP project ID where resources will be created"
  type        = string

  validation {
    condition = (
      can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id)) &&
      !can(regex("--", var.project_id)) &&
      !can(regex("(?i)google", var.project_id)) # Case-insensitive check for "google"
    )
    error_message = "Project ID must be 6-30 characters, start with a letter, contain only lowercase letters, numbers, and single hyphens, and cannot contain the word 'google'."
  }
}

variable "agent_service_account_id" {
  description = "ID for the Buildkite agent service account (6-30 chars, lowercase, digits, hyphens)"
  type        = string
  default     = "elastic-ci-agent"

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{4,28}[a-z0-9]$", var.agent_service_account_id))
    error_message = "Service account ID must be 6-30 characters, lowercase letters, digits, and hyphens only."
  }
}

variable "metrics_service_account_id" {
  description = "ID for the buildkite-agent-metrics Cloud Function service account"
  type        = string
  default     = "elastic-ci-metrics"

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{4,28}[a-z0-9]$", var.metrics_service_account_id))
    error_message = "Service account ID must be 6-30 characters, lowercase letters, digits, and hyphens only."
  }
}

variable "agent_custom_role_id" {
  description = "ID for the custom IAM role for agent instance management"
  type        = string
  default     = "elasticCiAgentInstanceMgmt"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_\\.]{3,64}$", var.agent_custom_role_id))
    error_message = "Custom role ID must be 3-64 characters, letters, numbers, underscores, and periods only."
  }
}

variable "metrics_custom_role_id" {
  description = "ID for the custom IAM role for metrics function autoscaling"
  type        = string
  default     = "elasticCiMetricsAutoscaler"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_\\.]{3,64}$", var.metrics_custom_role_id))
    error_message = "Custom role ID must be 3-64 characters, letters, numbers, underscores, and periods only."
  }
}

variable "enable_secret_access" {
  description = "Grant agent service account access to Secret Manager secrets"
  type        = bool
  default     = true
}

variable "enable_storage_access" {
  description = "Grant agent service account access to Cloud Storage for artifacts and caching"
  type        = bool
  default     = false
}
