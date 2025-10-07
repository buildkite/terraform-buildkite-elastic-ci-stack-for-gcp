variable "project" {
  description = "GCP project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "GCP region where the network and subnets will be created"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "Name of the VPC network and prefix for all networking resources"
  type        = string
  default     = "elastic-ci-stack-example"
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
}

variable "instance_tag" {
  description = "Network tag applied to compute instances for firewall targeting"
  type        = string
  default     = "elastic-ci-agent"
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