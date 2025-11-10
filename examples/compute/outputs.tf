output "instance_template_name" {
  description = "Name of the instance template"
  value       = module.compute.instance_template_name
}

output "instance_group_manager_name" {
  description = "Name of the managed instance group"
  value       = module.compute.instance_group_manager_name
}

output "instance_group_id" {
  description = "ID of the managed instance group"
  value       = module.compute.instance_group_id
}

output "autoscaler_name" {
  description = "Name of the autoscaler (if enabled)"
  value       = module.compute.autoscaler_name
}

output "health_check_id" {
  description = "ID of the health check (if enabled)"
  value       = module.compute.health_check_id
}
