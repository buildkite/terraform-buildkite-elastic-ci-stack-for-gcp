variable "project_id" {
  description = "GCP project ID where networking resources will be created"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network and prefix for all networking resources"
  type        = string
  default     = "elastic-ci-stack"

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{0,61}[a-z0-9]$", var.network_name))
    error_message = "Network name must be a valid GCP resource name: lowercase letters, numbers, and hyphens only."
  }
}

variable "region" {
  description = "GCP region where the network and subnets will be created"
  type        = string
  default     = "us-central1"
}

variable "enable_ssh_access" {
  description = "Enable SSH access to compute instances via firewall rule"
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "CIDR blocks allowed to SSH to compute instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for cidr in var.ssh_source_ranges : can(cidrhost(cidr, 0))
    ])
    error_message = "All SSH source ranges must be valid CIDR blocks."
  }
}

variable "instance_tag" {
  description = "Network tag applied to compute instances for firewall targeting"
  type        = string
  default     = "elastic-ci-agent"

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{0,61}[a-z0-9]$", var.instance_tag))
    error_message = "Instance tag must be a valid GCP network tag."
  }
}

variable "enable_iap_access" {
  description = "Enable Identity-Aware Proxy access for secure SSH without external IPs"
  type        = bool
  default     = false
}

variable "enable_secondary_ranges" {
  description = "Enable secondary IP ranges for GKE pods and services (for future GKE support)"
  type        = bool
  default     = false
}