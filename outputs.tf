# Root module outputs for Elastic CI Stack for GCP

# Networking Outputs

output "network_name" {
  description = "Name of the VPC network"
  value       = module.networking.network_name
}

output "network_id" {
  description = "ID of the VPC network"
  value       = module.networking.network_id
}

output "network_self_link" {
  description = "Self link of the VPC network"
  value       = module.networking.network_self_link
}

output "subnet_0_name" {
  description = "Name of the first subnet"
  value       = module.networking.subnet_0_name
}

output "subnet_0_cidr" {
  description = "CIDR range of the first subnet"
  value       = module.networking.subnet_0_cidr
}

output "subnet_1_name" {
  description = "Name of the second subnet"
  value       = module.networking.subnet_1_name
}

output "subnet_1_cidr" {
  description = "CIDR range of the second subnet"
  value       = module.networking.subnet_1_cidr
}

# IAM Outputs

output "agent_service_account_email" {
  description = "Email address of the Buildkite agent service account"
  value       = module.iam.agent_service_account_email
}

output "agent_service_account_id" {
  description = "Unique ID of the Buildkite agent service account"
  value       = module.iam.agent_service_account_id
}

output "metrics_service_account_email" {
  description = "Email address of the metrics service account"
  value       = module.iam.metrics_service_account_email
}

output "metrics_service_account_id" {
  description = "Unique ID of the metrics service account"
  value       = module.iam.metrics_service_account_id
}

# Compute Outputs

output "instance_template_name" {
  description = "Name of the instance template used for Buildkite agents"
  value       = module.compute.instance_template_name
}

output "instance_template_id" {
  description = "ID of the instance template"
  value       = module.compute.instance_template_id
}

output "instance_group_manager_name" {
  description = "Name of the managed instance group"
  value       = module.compute.instance_group_manager_name
}

output "instance_group_manager_id" {
  description = "ID of the managed instance group"
  value       = module.compute.instance_group_manager_id
}

output "instance_group_id" {
  description = "ID of the instance group (for use with load balancers, etc.)"
  value       = module.compute.instance_group_id
}

output "autoscaler_name" {
  description = "Name of the autoscaler (if autoscaling is enabled)"
  value       = module.compute.autoscaler_name
}

output "autoscaler_id" {
  description = "ID of the autoscaler (if autoscaling is enabled)"
  value       = module.compute.autoscaler_id
}

output "health_check_id" {
  description = "ID of the health check (if autohealing is enabled)"
  value       = module.compute.health_check_id
}

# Quick Reference Outputs

output "region" {
  description = "GCP region where resources were deployed"
  value       = var.region
}

output "stack_name" {
  description = "Name of the Elastic CI Stack"
  value       = var.stack_name
}

output "buildkite_queue" {
  description = "Buildkite queue that agents are listening to"
  value       = var.buildkite_queue
}

output "machine_type" {
  description = "Machine type used for agent instances"
  value       = var.machine_type
}

output "min_size" {
  description = "Minimum number of agent instances"
  value       = var.min_size
}

output "max_size" {
  description = "Maximum number of agent instances"
  value       = var.max_size
}

output "autoscaling_enabled" {
  description = "Whether autoscaling is enabled"
  value       = var.enable_autoscaling
}
