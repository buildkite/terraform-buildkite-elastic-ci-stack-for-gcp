output "instance_template_id" {
  description = "ID of the instance template"
  value       = google_compute_instance_template.buildkite_agent.id
}

output "instance_template_self_link" {
  description = "Self link of the instance template"
  value       = google_compute_instance_template.buildkite_agent.self_link
}

output "instance_template_name" {
  description = "Name of the instance template"
  value       = google_compute_instance_template.buildkite_agent.name
}

output "instance_group_manager_id" {
  description = "ID of the managed instance group"
  value       = google_compute_region_instance_group_manager.buildkite_agents.id
}

output "instance_group_manager_self_link" {
  description = "Self link of the managed instance group"
  value       = google_compute_region_instance_group_manager.buildkite_agents.self_link
}

output "instance_group_manager_name" {
  description = "Name of the managed instance group"
  value       = google_compute_region_instance_group_manager.buildkite_agents.name
}

output "instance_group_id" {
  description = "ID of the managed instance group"
  value       = google_compute_region_instance_group_manager.buildkite_agents.instance_group
}

output "autoscaler_id" {
  description = "ID of the autoscaler (if autoscaling is enabled)"
  value       = var.enable_autoscaling ? google_compute_region_autoscaler.buildkite_agents[0].id : null
}

output "autoscaler_self_link" {
  description = "Self link of the autoscaler (if autoscaling is enabled)"
  value       = var.enable_autoscaling ? google_compute_region_autoscaler.buildkite_agents[0].self_link : null
}

output "autoscaler_name" {
  description = "Name of the autoscaler (if autoscaling is enabled)"
  value       = var.enable_autoscaling ? google_compute_region_autoscaler.buildkite_agents[0].name : null
}

output "health_check_id" {
  description = "ID of the health check (if autohealing is enabled)"
  value       = var.enable_autohealing ? google_compute_health_check.autohealing[0].id : null
}

output "health_check_self_link" {
  description = "Self link of the health check (if autohealing is enabled)"
  value       = var.enable_autohealing ? google_compute_health_check.autohealing[0].self_link : null
}
