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

run "uses_standard_vms_by_default" {
  command = plan

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].provisioning_model == "STANDARD"
    error_message = "Agents must use standard VMs by default."
  }

  assert {
    condition     = !google_compute_instance_template.buildkite_agent.scheduling[0].preemptible
    error_message = "Standard VMs must not be preemptible."
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].instance_termination_action == null
    error_message = "Standard VMs must not set a Spot termination action."
  }
}

run "supports_spot_vms" {
  command = plan

  variables {
    provisioning_model = "SPOT"
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].provisioning_model == "SPOT"
    error_message = "Spot agents must use the SPOT provisioning model."
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].preemptible
    error_message = "Spot agents must be preemptible."
  }

  assert {
    condition     = !google_compute_instance_template.buildkite_agent.scheduling[0].automatic_restart
    error_message = "Spot agents cannot restart automatically."
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].on_host_maintenance == "TERMINATE"
    error_message = "Spot agents cannot live migrate during host maintenance."
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].instance_termination_action == "DELETE"
    error_message = "Preempted Spot agents must be deleted so the MIG recreates capacity."
  }
}

run "spot_overrides_live_migration" {
  command = plan

  variables {
    provisioning_model  = "SPOT"
    on_host_maintenance = "MIGRATE"
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.scheduling[0].on_host_maintenance == "TERMINATE"
    error_message = "Spot agents must terminate on host maintenance even when MIGRATE is requested."
  }
}

run "rejects_invalid_provisioning_model" {
  command = plan

  variables {
    provisioning_model = "PREEMPTIBLE"
  }

  expect_failures = [var.provisioning_model]
}
