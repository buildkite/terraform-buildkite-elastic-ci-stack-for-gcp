output "network_name" {
  description = "Name of the VPC network"
  value       = module.networking.network_name
}

output "subnet_0_name" {
  description = "Name of the first subnet"
  value       = module.networking.subnet_0_name
}

output "agent_service_account_email" {
  description = "Email of the agent service account"
  value       = module.iam.agent_service_account_email
}

output "metrics_service_account_email" {
  description = "Email of the metrics service account"
  value       = module.iam.metrics_service_account_email
}

output "instance_template_name" {
  description = "Name of the instance template"
  value       = module.compute.instance_template_name
}

output "instance_group_manager_name" {
  description = "Name of the managed instance group"
  value       = module.compute.instance_group_manager_name
}

output "autoscaler_name" {
  description = "Name of the autoscaler"
  value       = module.compute.autoscaler_name
}

output "instance_group_id" {
  description = "ID of the managed instance group"
  value       = module.compute.instance_group_id
}
