variable "project" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "agent_service_account_id" {
  description = "ID for the Buildkite agent service account"
  type        = string
  default     = "elastic-ci-agent"
}

variable "metrics_service_account_id" {
  description = "ID for the metrics Cloud Function service account"
  type        = string
  default     = "elastic-ci-metrics"
}

variable "agent_custom_role_id" {
  description = "ID for the custom IAM role for agent instance management"
  type        = string
  default     = "elasticCiAgentInstanceMgmt"
}

variable "metrics_custom_role_id" {
  description = "ID for the custom IAM role for metrics autoscaling"
  type        = string
  default     = "elasticCiMetricsAutoscaler"
}

variable "enable_secret_access" {
  description = "Grant agent service account access to Secret Manager"
  type        = bool
  default     = true
}

variable "enable_storage_access" {
  description = "Grant agent service account access to Cloud Storage"
  type        = bool
  default     = false
}
