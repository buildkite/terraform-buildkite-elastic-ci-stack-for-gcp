mock_provider "google" {}

run "uses_non_disruptive_update_policy" {
  command = plan

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
    max_surge                   = 5
    max_unavailable             = 1
  }

  assert {
    condition     = google_compute_region_instance_group_manager.buildkite_agents.update_policy[0].type == "OPPORTUNISTIC"
    error_message = "The managed instance group must not proactively replace agents when its instance template changes."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.buildkite_agents.update_policy[0].instance_redistribution_type == "NONE"
    error_message = "The regional managed instance group must not proactively redistribute agents between zones."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.buildkite_agents.update_policy[0].minimal_action == "REPLACE"
    error_message = "New instance templates must be applied when agents are replaced opportunistically."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.buildkite_agents.update_policy[0].replacement_method == "SUBSTITUTE"
    error_message = "Explicit rolling updates must create replacement agents before removing existing agents."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.buildkite_agents.update_policy[0].max_surge_fixed == 5
    error_message = "Explicit rolling updates must retain the configured surge capacity."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.buildkite_agents.update_policy[0].max_unavailable_fixed == 1
    error_message = "Explicit rolling updates must not make existing agents unavailable before their replacements are ready."
  }
}
