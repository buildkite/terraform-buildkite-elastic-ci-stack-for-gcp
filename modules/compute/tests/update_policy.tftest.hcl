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
    agent_idle_timeout          = 123
    max_surge                   = 5
    max_unavailable             = 1
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.metadata["buildkite-disconnect-after-idle-timeout"] == "0"
    error_message = "Static fleets must disable idle disconnect so they retain their configured capacity."
  }

  assert {
    condition     = strcontains(google_compute_instance_template.buildkite_agent.metadata_startup_script, "SELF_TERMINATION_ENABLED=\"false\"")
    error_message = "Static fleets must disable the self-termination lifecycle and bootstrap-failure removal paths."
  }

  # The installed template deliberately retains a literal zero default for
  # compatibility with old module bootstraps; the new bootstrap applies the
  # metadata value after rendering.
  assert {
    condition     = strcontains(google_compute_instance_template.buildkite_agent.metadata_startup_script, "disconnect-after-idle-timeout=0")
    error_message = "The module-installed agent configuration template must retain its backward-compatible idle-timeout default."
  }

  assert {
    condition     = strcontains(google_compute_instance_template.buildkite_agent.metadata_startup_script, "Buildkite agent bootstrap failed; requesting exact managed instance group removal")
    error_message = "A VM whose agent cannot bootstrap must remove itself from the scale-out-only fleet."
  }

  assert {
    condition     = strcontains(google_compute_instance_template.buildkite_agent.metadata_startup_script, "Serialize with ExecStopPost")
    error_message = "Bootstrap failure removal must be serialized with the agent post-stop lifecycle."
  }

  assert {
    condition     = strcontains(google_compute_instance_template.buildkite_agent.metadata_startup_script, "ExecStopPost=/usr/local/bin/terminate-instance-after-agent-exit")
    error_message = "The startup script must install the managed instance group termination lifecycle hook."
  }

  assert {
    condition     = strcontains(google_compute_instance_template.buildkite_agent.metadata_startup_script, "compute instance-groups managed delete-instances")
    error_message = "The startup script must install the module-matched exact-instance termination script."
  }

  assert {
    condition     = strcontains(google_compute_instance_template.buildkite_agent.metadata_startup_script, "allowing systemd to restart the Buildkite agent")
    error_message = "The startup script must install termination failure recovery for the Buildkite agent service."
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
    error_message = "The managed instance group update policy must store the configured maximum surge capacity."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.buildkite_agents.update_policy[0].max_unavailable_fixed == 1
    error_message = "The managed instance group update policy must store the configured maximum unavailable capacity."
  }
}

run "uses_scale_out_only_autoscaling" {
  command = plan

  variables {
    project_id                    = "test-project"
    network_self_link             = "projects/test-project/global/networks/test-network"
    subnet_self_link              = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    agent_service_account_email   = "agent@test-project.iam.gserviceaccount.com"
    image                         = "projects/test-project/global/images/test-image"
    buildkite_organization_slug   = "test-organization"
    buildkite_agent_token         = "test-token"
    enable_autoscaling            = true
    enable_autohealing            = false
    autoscaling_jobs_per_instance = 2
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.metadata["buildkite-disconnect-after-idle-timeout"] == "600"
    error_message = "Autoscaled fleets must pass the configured idle timeout to agent metadata."
  }

  assert {
    condition     = strcontains(google_compute_instance_template.buildkite_agent.metadata_startup_script, "ExecStopPost=/usr/local/bin/terminate-instance-after-agent-exit")
    error_message = "Autoscaled fleets must install the self-termination lifecycle hook."
  }

  assert {
    condition     = strcontains(google_compute_instance_template.buildkite_agent.metadata_startup_script, "Buildkite agent bootstrap failed; requesting exact managed instance group removal")
    error_message = "Autoscaled fleets must reclaim VMs whose agent cannot bootstrap."
  }

  assert {
    condition     = google_compute_region_autoscaler.buildkite_agents[0].autoscaling_policy[0].mode == "ONLY_SCALE_OUT"
    error_message = "The native GCP autoscaler must never select arbitrary agents for scale-in."
  }

  assert {
    condition     = google_compute_region_autoscaler.buildkite_agents[0].autoscaling_policy[0].stabilization_period == 1
    error_message = "The autoscaler must use the tested one-second stabilization period."
  }

  assert {
    condition     = google_compute_region_autoscaler.buildkite_agents[0].autoscaling_policy[0].metric[0].single_instance_assignment == 2
    error_message = "Unfinished jobs must be assigned per instance as a per-group work metric."
  }

  assert {
    condition     = google_compute_region_autoscaler.buildkite_agents[0].autoscaling_policy[0].metric[0].target == null
    error_message = "The per-group unfinished-jobs metric must not be configured as a utilization target."
  }
}

run "uses_default_agent_idle_timeout" {
  command = plan

  variables {
    project_id                  = "test-project"
    network_self_link           = "projects/test-project/global/networks/test-network"
    subnet_self_link            = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
    agent_service_account_email = "agent@test-project.iam.gserviceaccount.com"
    image                       = "projects/test-project/global/images/test-image"
    buildkite_organization_slug = "test-organization"
    buildkite_agent_token       = "test-token"
    enable_autoscaling          = true
    enable_autohealing          = false
  }

  assert {
    condition     = google_compute_instance_template.buildkite_agent.metadata["buildkite-disconnect-after-idle-timeout"] == "600"
    error_message = "Autoscaled fleets must use the default 600-second agent idle timeout."
  }
}
