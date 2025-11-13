output "function_uri" {
  description = "The URI of the deployed Cloud Function"
  value       = module.buildkite_metrics.function_uri
}

output "function_name" {
  description = "The name of the deployed Cloud Function"
  value       = module.buildkite_metrics.function_name
}

output "service_account_email" {
  description = "The email of the service account used by the Cloud Function"
  value       = module.buildkite_metrics.service_account_email
}

output "scheduler_job_name" {
  description = "The name of the Cloud Scheduler job"
  value       = module.buildkite_metrics.scheduler_job_name
}

output "metrics_namespace" {
  description = "The Cloud Monitoring namespace where metrics are written"
  value       = module.buildkite_metrics.metrics_namespace
}
