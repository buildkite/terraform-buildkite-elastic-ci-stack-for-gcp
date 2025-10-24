output "agent_service_account_email" {
  description = "Email address of the Buildkite agent service account"
  value       = module.iam.agent_service_account_email
}

output "metrics_service_account_email" {
  description = "Email address of the metrics Cloud Function service account"
  value       = module.iam.metrics_service_account_email
}

output "agent_custom_role_name" {
  description = "Name of the custom IAM role for agent instance management"
  value       = module.iam.agent_custom_role_name
}

output "metrics_custom_role_name" {
  description = "Name of the custom IAM role for metrics autoscaling"
  value       = module.iam.metrics_custom_role_name
}
