mock_provider "google" {}
mock_provider "null" {}

variables {
  project_id                   = "test-project"
  buildkite_organization_slug  = "test-organization"
  buildkite_agent_token_secret = "projects/test-project/secrets/buildkite-token/versions/latest"
}

run "preserves_standalone_source_defaults" {
  command = plan

  assert {
    condition     = google_cloudfunctions2_function.metrics_function.build_config[0].source[0].storage_source[0].bucket == "buildkite-cloud-functions" && google_cloudfunctions2_function.metrics_function.build_config[0].source[0].storage_source[0].object == "buildkite-agent-metrics/cloud-function-latest.zip"
    error_message = "Standalone callers must retain their existing source defaults."
  }
}

run "preserves_external_account_iam_ownership" {
  command = plan

  variables {
    service_account_email = "external@test-project.iam.gserviceaccount.com"
  }

  assert {
    condition     = length(google_project_iam_member.secret_accessor) == 0 && length(google_service_account.metrics_function) == 0
    error_message = "An externally supplied metrics account must retain caller-managed secret IAM."
  }
}

run "preserves_multiple_secret_references" {
  command = plan

  variables {
    buildkite_agent_token_secret = "projects/test-project/secrets/cluster-one/versions/latest,projects/test-project/secrets/cluster-two/versions/7"
  }

  assert {
    condition     = length(google_project_iam_member.secret_accessor) == 1
    error_message = "Standalone callers using multiple secret references must retain secret access."
  }

  assert {
    condition     = google_cloudfunctions2_function.metrics_function.service_config[0].environment_variables["BUILDKITE_AGENT_TOKEN_SECRET_NAMES"] == var.buildkite_agent_token_secret
    error_message = "The function must receive every configured secret reference unchanged."
  }
}

run "supports_direct_tokens_and_custom_generation_pins" {
  command = plan

  variables {
    buildkite_agent_token        = "test-token"
    buildkite_agent_token_secret = ""
    function_source_bucket       = "custom-source-bucket"
    function_source_object       = "metrics/custom.zip"
    function_source_generation   = 123456789
  }

  assert {
    condition     = length(google_project_iam_member.secret_accessor) == 0
    error_message = "Direct-token deployments must not receive secret access."
  }

  assert {
    condition     = google_cloudfunctions2_function.metrics_function.build_config[0].source[0].storage_source[0].generation == 123456789 && google_cloudfunctions2_function.metrics_function.build_config[0].source[0].storage_source[0].bucket == "custom-source-bucket" && google_cloudfunctions2_function.metrics_function.build_config[0].source[0].storage_source[0].object == "metrics/custom.zip"
    error_message = "A custom source must retain the caller's bucket, object, and explicit generation."
  }
}
