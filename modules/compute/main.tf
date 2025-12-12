locals {
  # Check that at least one authentication method is provided
  has_auth = var.buildkite_agent_token != "" || var.buildkite_agent_token_secret != ""

  # The buildkite-agent-metrics function converts hyphens to underscores in the
  # organization slug when writing metrics (GCP custom metrics don't allow hyphens
  # in the metric type path). We need to match this conversion in the autoscaler.
  # See: https://github.com/buildkite/buildkite-agent-metrics/blob/main/backend/stackdriver.go
  # Note: This uses Terraform's built-in replace() function, not a shell command.
  metrics_org_slug = replace(var.buildkite_organization_slug, "-", "_")
}

resource "google_compute_instance_template" "buildkite_agent" {
  project      = var.project_id
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
    enable-oslogin           = "FALSE"
    buildkite-token          = var.buildkite_agent_token
    buildkite-token-secret   = var.buildkite_agent_token_secret
    buildkite-queue          = var.buildkite_queue
    buildkite-tags           = var.buildkite_agent_tags
    buildkite-api-endpoint   = var.buildkite_api_endpoint
  }

  metadata_startup_script = file("${path.module}/templates/startup.sh")

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.buildkite_agent_token != "" || var.buildkite_agent_token_secret != ""
      error_message = "Either buildkite_agent_token or buildkite_agent_token_secret must be provided."
    }
  }

  shielded_instance_config {
    enable_secure_boot          = var.enable_secure_boot
    enable_vtpm                 = var.enable_vtpm
    enable_integrity_monitoring = var.enable_integrity_monitoring
  }
}

resource "google_compute_region_instance_group_manager" "buildkite_agents" {
  project            = var.project_id
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

  project             = var.project_id
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

  project = var.project_id
  name    = "${var.stack_name}-autoscaler"
  region  = var.region
  target  = google_compute_region_instance_group_manager.buildkite_agents.id

  autoscaling_policy {
    min_replicas    = var.min_size
    max_replicas    = var.max_size
    cooldown_period = var.cooldown_period

    # Using scheduled jobs as the primary scaling metric
    # The autoscaler will scale to: ceil(metric_value / target)
    # If ScheduledJobsCount = 13 and target = 1, we get 13 instances
    # 
    # Note: Metrics are published by buildkite-agent-metrics to:
    # custom.googleapis.com/buildkite/<org-slug>/<MetricName>
    # The filter matches the Queue label to ensure we're scaling based on the correct queue.
    #
    # Important: The metrics function converts hyphens to underscores in the org slug
    # (GCP custom metrics don't allow hyphens), so we use local.metrics_org_slug here.
    metric {
      name   = "custom.googleapis.com/buildkite/${local.metrics_org_slug}/ScheduledJobsCount"
      target = var.autoscaling_jobs_per_instance
      type   = "GAUGE"
      filter = "resource.type = \"global\" AND metric.label.Queue = \"${var.buildkite_queue}\""
    }

    mode = "ON"
  }

  # Ensure the metrics function has been invoked and the custom metric exists
  # before creating the autoscaler. Without this, the autoscaler may be created
  # with an undefined metric reference.
  depends_on = [var.autoscaler_depends_on]
}
