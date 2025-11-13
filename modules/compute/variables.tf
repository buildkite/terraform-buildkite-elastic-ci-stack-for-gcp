variable "project_id" {
  description = "GCP project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "GCP region where the instance group will be created"
  type        = string
  default     = "us-central1"
}

variable "zones" {
  description = "List of zones within the region where instances will be distributed"
  type        = list(string)
  default     = null

  validation {
    condition     = var.zones == null || length(var.zones) > 0
    error_message = "If zones are specified, at least one zone must be provided."
  }
}

variable "stack_name" {
  description = "Name of the Elastic CI Stack (used as prefix for resources)"
  type        = string
  default     = "elastic-ci-stack"

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{0,61}[a-z0-9]$", var.stack_name))
    error_message = "Stack name must be a valid GCP resource name: lowercase letters, numbers, and hyphens only."
  }
}

variable "network_self_link" {
  description = "Self link of the VPC network (from networking module)"
  type        = string
}

variable "subnet_self_link" {
  description = "Self link of the subnet where instances will be created (from networking module)"
  type        = string
}

variable "instance_tag" {
  description = "Network tag to apply to instances (must match networking module firewall rules)"
  type        = string
  default     = "elastic-ci-agent"
}

variable "agent_service_account_email" {
  description = "Email of the service account to attach to instances (from IAM module)"
  type        = string
}

variable "machine_type" {
  description = "GCP machine type for agent instances"
  type        = string
  default     = "n1-standard-2"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+$", var.machine_type))
    error_message = "Machine type must be a valid GCP machine type."
  }
}

variable "image" {
  description = "Source image for boot disk (Debian-based image recommended)"
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "root_disk_size_gb" {
  description = "Size of the root disk in GB"
  type        = number
  default     = 50

  validation {
    condition     = var.root_disk_size_gb >= 10 && var.root_disk_size_gb <= 65536
    error_message = "Root disk size must be between 10 GB and 65536 GB."
  }
}

variable "root_disk_type" {
  description = "Type of root disk (pd-standard, pd-balanced, pd-ssd)"
  type        = string
  default     = "pd-balanced"

  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd"], var.root_disk_type)
    error_message = "Root disk type must be one of: pd-standard, pd-balanced, pd-ssd."
  }
}

variable "buildkite_organization_slug" {
  description = "Buildkite organization slug for metrics namespacing"
  type        = string
}

variable "buildkite_agent_token" {
  description = "Buildkite agent registration token (leave empty if using buildkite_agent_token_secret)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "buildkite_agent_token_secret" {
  description = "GCP Secret Manager secret name containing Buildkite agent token (e.g. 'projects/PROJECT_ID/secrets/buildkite-agent-token/versions/latest')"
  type        = string
  default     = ""
}

variable "buildkite_agent_release" {
  description = "Buildkite agent release channel (stable, beta, edge)"
  type        = string
  default     = "stable"

  validation {
    condition     = contains(["stable", "beta", "edge"], var.buildkite_agent_release)
    error_message = "Buildkite agent release must be one of: stable, beta, edge."
  }
}

variable "buildkite_queue" {
  description = "Buildkite queue name that agents will listen to"
  type        = string
  default     = "default"
}

variable "buildkite_agent_tags" {
  description = "Additional tags for Buildkite agents (comma-separated key=value pairs)"
  type        = string
  default     = ""
}

variable "buildkite_api_endpoint" {
  description = "Buildkite API endpoint URL"
  type        = string
  default     = "https://agent.buildkite.com/v3"
}

variable "min_size" {
  description = "Minimum number of instances in the managed instance group"
  type        = number
  default     = 0

  validation {
    condition     = var.min_size >= 0
    error_message = "Minimum size must be greater than or equal to 0."
  }
}

variable "max_size" {
  description = "Maximum number of instances in the managed instance group"
  type        = number
  default     = 10

  validation {
    condition     = var.max_size >= 1
    error_message = "Maximum size must be greater than or equal to 1."
  }
}

variable "cooldown_period" {
  description = "Cooldown period in seconds between autoscaling actions"
  type        = number
  default     = 60

  validation {
    condition     = var.cooldown_period >= 30
    error_message = "Cooldown period must be at least 30 seconds."
  }
}

variable "autoscaling_jobs_per_instance" {
  description = "Target number of Buildkite jobs per instance for autoscaling"
  type        = number
  default     = 1

  validation {
    condition     = var.autoscaling_jobs_per_instance >= 1
    error_message = "Jobs per instance must be at least 1."
  }
}

variable "enable_autohealing" {
  description = "Enable autohealing for unhealthy instances"
  type        = bool
  default     = true
}

variable "health_check_port" {
  description = "Port to use for health checks"
  type        = number
  default     = 22

  validation {
    condition     = var.health_check_port > 0 && var.health_check_port <= 65535
    error_message = "Health check port must be between 1 and 65535."
  }
}

variable "health_check_interval_sec" {
  description = "How often (in seconds) to send a health check"
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval_sec >= 1
    error_message = "Health check interval must be at least 1 second."
  }
}

variable "health_check_timeout_sec" {
  description = "How long (in seconds) to wait before claiming failure"
  type        = number
  default     = 10

  validation {
    condition     = var.health_check_timeout_sec >= 1
    error_message = "Health check timeout must be at least 1 second."
  }
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks before marking instance healthy"
  type        = number
  default     = 2

  validation {
    condition     = var.health_check_healthy_threshold >= 1
    error_message = "Healthy threshold must be at least 1."
  }
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking instance unhealthy"
  type        = number
  default     = 3

  validation {
    condition     = var.health_check_unhealthy_threshold >= 1
    error_message = "Unhealthy threshold must be at least 1."
  }
}

variable "health_check_initial_delay_sec" {
  description = "Time (in seconds) that the managed instance group waits before starting autohealing"
  type        = number
  default     = 300

  validation {
    condition     = var.health_check_initial_delay_sec >= 0
    error_message = "Initial delay must be greater than or equal to 0."
  }
}

variable "max_surge" {
  description = "Maximum number of instances that can be created above the target size during updates"
  type        = number
  default     = 3

  validation {
    condition     = var.max_surge >= 0
    error_message = "Max surge must be greater than or equal to 0."
  }
}

variable "max_unavailable" {
  description = "Maximum number of instances that can be unavailable during updates"
  type        = number
  default     = 0

  validation {
    condition     = var.max_unavailable >= 0
    error_message = "Max unavailable must be greater than or equal to 0."
  }
}

variable "labels" {
  description = "Additional labels to apply to instances"
  type        = map(string)
  default     = {}
}

variable "enable_secure_boot" {
  description = "Enable Secure Boot for shielded VM instances"
  type        = bool
  default     = false
}

variable "enable_vtpm" {
  description = "Enable vTPM for shielded VM instances"
  type        = bool
  default     = true
}

variable "enable_integrity_monitoring" {
  description = "Enable integrity monitoring for shielded VM instances"
  type        = bool
  default     = true
}

variable "enable_autoscaling" {
  description = "Enable autoscaling based on custom Buildkite metrics (requires buildkite-agent-metrics function)"
  type        = bool
  default     = true
}
