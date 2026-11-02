mock_provider "google" {}

variables {
  project_id = "test-project"
}

run "preserves_legacy_standalone_iam_callers" {
  command = plan

  assert {
    condition     = length(google_project_iam_member.metrics_secret_accessor) == 1 && length(google_project_iam_member.metrics_secret_accessor[0].condition) == 0
    error_message = "Omitting the new token reference must preserve the standalone IAM module's legacy grant."
  }
}

run "restricts_metrics_to_the_token_secret" {
  command = plan

  variables {
    buildkite_agent_token_secret = "projects/test-project/secrets/buildkite-token/versions/27"
  }

  assert {
    condition = trimspace(google_project_iam_member.metrics_secret_accessor[0].condition[0].expression) == trimspace(<<-EOT
      resource.type == "secretmanager.googleapis.com/SecretVersion" &&
      resource.name.extract("projects/{project}/secrets/buildkite-token/versions/") ==
        resource.name.extract("projects/{project}/")
    EOT
    )
    error_message = "Metrics access must require the SecretVersion resource type and compare the complete secret path against the resource's project."
  }

  assert {
    condition     = length(google_project_iam_member.agent_secret_accessor) == 1 && length(google_project_iam_member.agent_secret_accessor[0].condition) == 0
    error_message = "Metrics hardening must not change agent secret access."
  }
}

run "removes_metrics_access_without_a_secret" {
  command = plan

  variables {
    buildkite_agent_token_secret = ""
  }

  assert {
    condition     = length(google_project_iam_member.metrics_secret_accessor) == 0
    error_message = "An explicit empty reference must remove metrics secret access."
  }
}

run "leaves_cross_project_access_to_the_caller" {
  command = plan

  variables {
    buildkite_agent_token_secret = "projects/shared-secrets/secrets/buildkite-token/versions/latest"
  }

  assert {
    condition     = google_project_iam_member.metrics_secret_accessor[0].project == var.project_id && google_project_iam_member.metrics_secret_accessor[0].condition[0].expression == "false"
    error_message = "A cross-project token must not grant access to an unrelated secret in the stack project or change the other project's policy."
  }
}

run "plans_a_secret_with_a_pending_version" {
  command = plan

  module {
    source = "./tests/fixtures/pending-token"
  }
}
