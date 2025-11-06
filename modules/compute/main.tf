locals {
  # Validate that either token or secret is provided
  token_validation = var.buildkite_agent_token != "" || var.buildkite_agent_token_secret != "" ? true : tobool("Either buildkite_agent_token or buildkite_agent_token_secret must be provided")
}

resource "google_compute_instance_template" "buildkite_agent" {
  name_prefix  = "${var.stack_name}-"
  description  = "Instance template for Buildkite agent instances"
  machine_type = var.machine_type
  region       = var.region

  tags = [var.instance_tag]

  labels = merge(
    var.labels,
    {
      "buildkite-stack" = var.stack_name
      "buildkite-queue" = var.buildkite_queue
    }
  )

  disk {
    source_image = var.image
    auto_delete  = true
    boot         = true
    disk_size_gb = var.root_disk_size_gb
    disk_type    = var.root_disk_type
  }

  network_interface {
    network    = var.network_self_link
    subnetwork = var.subnet_self_link
  }

  service_account {
    email  = var.agent_service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "FALSE"
  }

  metadata_startup_script = templatefile("${path.module}/templates/startup.sh", {
    project_id                     = var.project_id
    buildkite_agent_token          = var.buildkite_agent_token
    buildkite_agent_token_secret   = var.buildkite_agent_token_secret
    buildkite_agent_release        = var.buildkite_agent_release
    buildkite_queue                = var.buildkite_queue
    buildkite_agent_tags           = var.buildkite_agent_tags
    buildkite_api_endpoint         = var.buildkite_api_endpoint
  })

  lifecycle {
    create_before_destroy = true
  }

  shielded_instance_config {
    enable_secure_boot          = var.enable_secure_boot
    enable_vtpm                 = var.enable_vtpm
    enable_integrity_monitoring = var.enable_integrity_monitoring
  }
}

resource "google_compute_region_instance_group_manager" "buildkite_agents" {
  name               = "${var.stack_name}-mig"
  base_instance_name = "${var.stack_name}-agent"
  region             = var.region

  version {
    instance_template = google_compute_instance_template.buildkite_agent.id
  }

  distribution_policy_zones = var.zones

  update_policy {
    type                         = "PROACTIVE"
    instance_redistribution_type = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = var.max_surge
    max_unavailable_fixed        = var.max_unavailable
    replacement_method           = "SUBSTITUTE"
  }

  dynamic "auto_healing_policies" {
    for_each = var.enable_autohealing ? [1] : []
    content {
      health_check      = google_compute_health_check.autohealing[0].id
      initial_delay_sec = var.health_check_initial_delay_sec
    }
  }

  lifecycle {
    ignore_changes = [target_size]
  }
}

resource "google_compute_health_check" "autohealing" {
  count = var.enable_autohealing ? 1 : 0

  name                = "${var.stack_name}-autohealing"
  check_interval_sec  = var.health_check_interval_sec
  timeout_sec         = var.health_check_timeout_sec
  healthy_threshold   = var.health_check_healthy_threshold
  unhealthy_threshold = var.health_check_unhealthy_threshold

  tcp_health_check {
    port = var.health_check_port
  }
}

resource "google_compute_region_autoscaler" "buildkite_agents" {
  count = var.enable_autoscaling ? 1 : 0

  name   = "${var.stack_name}-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.buildkite_agents.id

  autoscaling_policy {
    min_replicas    = var.min_size
    max_replicas    = var.max_size
    cooldown_period = var.cooldown_period

    metric {
      name   = "custom.googleapis.com/buildkite/scheduled_jobs"
      type   = "GAUGE"
      target = var.autoscaling_jobs_per_instance
    }

    metric {
      name   = "custom.googleapis.com/buildkite/running_jobs"
      type   = "GAUGE"
      target = var.autoscaling_jobs_per_instance
    }

    mode = "ON"
  }
}
