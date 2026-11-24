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

run "uses_a_single_machine_type_by_default" {
  command = plan

  assert {
    condition     = length(google_compute_region_instance_group_manager.buildkite_agents.instance_flexibility_policy) == 0
    error_message = "Existing stacks must keep a single machine type by default."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.buildkite_agents.distribution_policy_target_shape == "EVEN"
    error_message = "Existing stacks must keep the EVEN target distribution shape by default."
  }

  assert {
    condition     = length(google_compute_region_instance_group_manager.buildkite_agents.instance_lifecycle_policy) == 0
    error_message = "Existing stacks must keep the default repair behaviour."
  }
}

run "ranks_fallback_machine_types_in_order" {
  command = plan

  variables {
    machine_type                     = "c3d-standard-8"
    fallback_machine_types           = ["c2d-standard-8", "n2d-standard-8"]
    distribution_policy_target_shape = "ANY"
  }

  assert {
    condition = toset([
      for selection in google_compute_region_instance_group_manager.buildkite_agents.instance_flexibility_policy[0].instance_selections :
      "${selection.rank}:${one(selection.machine_types)}"
    ]) == toset(["1:c3d-standard-8", "2:c2d-standard-8", "3:n2d-standard-8"])
    error_message = "machine_type must rank first, followed by the fallbacks in list order."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.buildkite_agents.distribution_policy_target_shape == "ANY"
    error_message = "The requested target distribution shape must be applied."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.buildkite_agents.instance_lifecycle_policy[0].force_update_on_repair == "YES"
    error_message = "Repairs must be able to switch to an available machine type."
  }
}

run "rejects_fallbacks_with_even_distribution" {
  command = plan

  variables {
    fallback_machine_types = ["n2d-standard-2"]
  }

  expect_failures = [google_compute_region_instance_group_manager.buildkite_agents]
}

run "rejects_invalid_target_shape" {
  command = plan

  variables {
    distribution_policy_target_shape = "SINGLE_ZONE"
  }

  expect_failures = [var.distribution_policy_target_shape]
}
