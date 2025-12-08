output "function_uri" {
  description = "The URI of the deployed Cloud Function"
  value       = google_cloudfunctions2_function.metrics_function.service_config[0].uri
}

output "function_name" {
  description = "The name of the deployed Cloud Function"
  value       = google_cloudfunctions2_function.metrics_function.name
}

output "service_account_email" {
  description = "The email of the service account used by the Cloud Function"
  value       = local.service_account_email
}

output "scheduler_job_name" {
  description = "The name of the Cloud Scheduler job"
  value       = google_cloud_scheduler_job.metrics_trigger.name
}

output "metrics_namespace" {
  description = "The Cloud Monitoring namespace where metrics will be written"
  value       = "custom.googleapis.com/buildkite"
}

output "metrics_initialized" {
  description = "Marker output that indicates the metrics function has been invoked and the custom metric should exist. Use this as a dependency for autoscalers."
  value       = null_resource.initial_metrics_invocation.id
}
