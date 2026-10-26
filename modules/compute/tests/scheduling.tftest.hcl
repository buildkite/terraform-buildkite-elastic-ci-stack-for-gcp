mock_provider "google" {}

variables {
  project_id                  = "test-project"
  network_self_link           = "projects/test-project/global/networks/test-network"
  subnet_self_link            = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
  agent_service_account_email = "agent@test-project.iam.gserviceaccount.com"
  image                       = "projects/test-project/global/images/test-image"
  buildkite_organization_slug = "test-organization"
  buildkite_agent_token       = "test-token"
  enable_autoscaling          = false
  enable_autohealing          = false
}

run "preserves_live_migration_by_default" {
  command = plan

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].on_host_maintenance == "MIGRATE"
    error_message = "Existing CPU fleets must retain live migration during host maintenance by default."
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].automatic_restart
    error_message = "Standard instances must retain automatic restart."
  }
}

run "supports_gpu_host_maintenance" {
  command = plan

  variables {
    machine_type        = "a2-highgpu-1g"
    on_host_maintenance = "TERMINATE"
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].on_host_maintenance == "TERMINATE"
    error_message = "GPU instances must be able to stop rather than live migrate during host maintenance."
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].automatic_restart
    error_message = "Selecting TERMINATE must not disable automatic restart after maintenance."
  }
}

run "rejects_invalid_host_maintenance_policy" {
  command = plan

  variables {
    on_host_maintenance = "STOP"
  }

  expect_failures = [var.on_host_maintenance]
}
