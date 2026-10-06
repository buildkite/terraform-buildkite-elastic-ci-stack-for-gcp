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

run "uses_standard_vms_without_external_ip_by_default" {
  command = plan

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].provisioning_model == "STANDARD"
    error_message = "Agents must use standard VMs by default."
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].automatic_restart == true && google_compute_instance_template.buildkite_agent.scheduling[0].on_host_maintenance == "MIGRATE"
    error_message = "Standard VMs must keep the GCE default restart and live-migration behaviour."
  }

  assert {
    condition     = length(google_compute_instance_template.buildkite_agent.network_interface[0].access_config) == 0
    error_message = "Agents must not get an external IP by default."
  }
}

run "uses_spot_vms" {
  command = plan

  variables {
    provisioning_model = "SPOT"
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].provisioning_model == "SPOT" && google_compute_instance_template.buildkite_agent.scheduling[0].preemptible == true
    error_message = "Spot agents must be provisioned as preemptible Spot VMs."
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].instance_termination_action == "DELETE"
    error_message = "Preempted Spot agents must be deleted so the MIG recreates capacity."
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].automatic_restart == false && google_compute_instance_template.buildkite_agent.scheduling[0].on_host_maintenance == "TERMINATE"
    error_message = "Spot VMs cannot auto-restart or live-migrate."
  }
}

run "rejects_unknown_provisioning_model" {
  command = plan

  variables {
    provisioning_model = "PREEMPTIBLE"
  }

  expect_failures = [var.provisioning_model]
}

run "adds_external_ip_when_enabled" {
  command = plan

  variables {
    enable_public_ip = true
  }

  assert {
    condition     = length(google_compute_instance_template.buildkite_agent.network_interface[0].access_config) == 1
    error_message = "Enabling public IPs must add an ephemeral access config."
  }
}
