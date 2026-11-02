# Child resource assertions run against the plan JSON in metrics_plan.jq.
mock_provider "google" {}
mock_provider "null" {}

override_resource {
  target          = module.iam.google_service_account.metrics
  override_during = plan

  values = {
    email = "metrics@test-project.iam.gserviceaccount.com"
  }
}

variables {
  project_id                   = "test-project"
  buildkite_organization_slug  = "test-organization"
  buildkite_agent_token_secret = "projects/test-project/secrets/root-token/versions/19"
}

run "pinned_default" {
  command = plan
}

run "custom_source" {
  command = plan

  variables {
    function_source = {
      bucket     = "custom-metrics-source"
      object     = "custom/metrics.zip"
      generation = 24680
    }
  }
}

run "latest_custom_generation" {
  command = plan

  variables {
    function_source = {
      bucket     = "custom-metrics-source"
      object     = "custom/metrics.zip"
      generation = null
    }
  }
}

run "disabled_autoscaling" {
  command = plan

  variables {
    enable_autoscaling = false
  }
}
