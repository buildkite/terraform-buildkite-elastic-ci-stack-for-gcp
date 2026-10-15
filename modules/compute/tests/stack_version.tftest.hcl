mock_provider "google" {}

run "reports_release_formatted_stack_version" {
  command = plan

  variables {
    project_id                  = "test-project"
    network_self_link           = "projects/test-project/global/networks/test-network"
    subnet_self_link            = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    agent_service_account_email = "agent@test-project.iam.gserviceaccount.com"
    image                       = "projects/test-project/global/images/test-image"
    buildkite_organization_slug = "test-organization"
    buildkite_agent_token       = "test-token"
  }

  assert {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", google_compute_instance_template.buildkite_agent.metadata["buildkite-stack-version"]))
    error_message = "The stack version must match the release tag format (for example v1.2.3) so Buildkite can group agents by stack version."
  }
}
