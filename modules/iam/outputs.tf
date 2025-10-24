output "agent_service_account_email" {
  description = "Email address of the Buildkite agent service account (use with compute instances)"
  value       = google_service_account.agent.email
}

output "agent_service_account_id" {
  description = "Unique ID of the Buildkite agent service account"
  value       = google_service_account.agent.unique_id
}

output "agent_service_account_name" {
  description = "Fully qualified name of the Buildkite agent service account"
  value       = google_service_account.agent.name
}

output "agent_custom_role_id" {
  description = "ID of the custom IAM role for agent instance management"
  value       = google_project_iam_custom_role.agent_instance_management.role_id
}

output "agent_custom_role_name" {
  description = "Name of the custom IAM role for agent instance management"
  value       = google_project_iam_custom_role.agent_instance_management.name
}

output "metrics_service_account_email" {
  description = "Email address of the metrics Cloud Function service account"
  value       = google_service_account.metrics.email
}

output "metrics_service_account_id" {
  description = "Unique ID of the metrics service account"
  value       = google_service_account.metrics.unique_id
}

output "metrics_service_account_name" {
  description = "Fully qualified name of the metrics service account"
  value       = google_service_account.metrics.name
}

output "metrics_custom_role_id" {
  description = "ID of the custom IAM role for metrics autoscaling"
  value       = google_project_iam_custom_role.metrics_autoscaler.role_id
}

output "metrics_custom_role_name" {
  description = "Name of the custom IAM role for metrics autoscaling"
  value       = google_project_iam_custom_role.metrics_autoscaler.name
}
