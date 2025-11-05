variable "project" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zones" {
  description = "List of zones within the region for instance distribution"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "elastic-ci-stack"
}

variable "stack_name" {
  description = "Name of the Elastic CI Stack"
  type        = string
  default     = "elastic-ci-stack"
}

variable "enable_ssh_access" {
  description = "Enable SSH access to instances"
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_tag" {
  description = "Network tag for instances"
  type        = string
  default     = "elastic-ci-agent"
}

variable "agent_service_account_id" {
  description = "Service account ID for Buildkite agents"
  type        = string
  default     = "elastic-ci-agent"
}

variable "metrics_service_account_id" {
  description = "Service account ID for metrics function"
  type        = string
  default     = "elastic-ci-metrics"
}

variable "agent_custom_role_id" {
  description = "Custom role ID for agent instance management"
  type        = string
  default     = "elasticCiAgentInstanceMgmt"
}

variable "metrics_custom_role_id" {
  description = "Custom role ID for metrics autoscaling"
  type        = string
  default     = "elasticCiMetricsAutoscaler"
}

variable "enable_secret_access" {
  description = "Enable Secret Manager access for agents"
  type        = bool
  default     = false
}

variable "enable_storage_access" {
  description = "Enable Cloud Storage access for agents"
  type        = bool
  default     = false
}

variable "machine_type" {
  description = "GCP machine type for agent instances"
  type        = string
  default     = "n1-standard-2"
}

variable "image" {
  description = "Source image for boot disk"
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "root_disk_size_gb" {
  description = "Size of the root disk in GB"
  type        = number
  default     = 50
}

variable "root_disk_type" {
  description = "Type of root disk"
  type        = string
  default     = "pd-balanced"
}

variable "buildkite_agent_token" {
  description = "Buildkite agent registration token"
  type        = string
  sensitive   = true
}

variable "buildkite_agent_release" {
  description = "Buildkite agent release channel"
  type        = string
  default     = "stable"
}

variable "buildkite_queue" {
  description = "Buildkite queue name"
  type        = string
  default     = "default"
}

variable "buildkite_agent_tags" {
  description = "Additional tags for Buildkite agents"
  type        = string
  default     = ""
}

variable "buildkite_api_endpoint" {
  description = "Buildkite API endpoint URL"
  type        = string
  default     = "https://agent.buildkite.com/v3"
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "cooldown_period" {
  description = "Cooldown period in seconds between autoscaling actions"
  type        = number
  default     = 60
}

variable "autoscaling_jobs_per_instance" {
  description = "Target number of Buildkite jobs per instance for autoscaling"
  type        = number
  default     = 1
}

variable "enable_autohealing" {
  description = "Enable autohealing for unhealthy instances"
  type        = bool
  default     = true
}

variable "health_check_initial_delay_sec" {
  description = "Time to wait before starting autohealing"
  type        = number
  default     = 300
}

variable "labels" {
  description = "Additional labels to apply to instances"
  type        = map(string)
  default     = {}
}

variable "enable_autoscaling" {
  description = "Enable autoscaling based on custom Buildkite metrics (requires buildkite-agent-metrics function)"
  type        = bool
  default     = false
}
