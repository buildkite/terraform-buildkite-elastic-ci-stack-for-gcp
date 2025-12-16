# Root module for Elastic CI Stack for GCP
# This module wraps the networking, IAM, and compute sub-modules
# to provide a simplified interface for deploying a complete stack

locals {
  # Compute stack-name-based defaults for resources that must be unique per stack
  network_name               = var.network_name != null ? var.network_name : "${var.stack_name}-network"
  instance_tag               = var.instance_tag != null ? var.instance_tag : "${var.stack_name}-agent"
  agent_service_account_id   = var.agent_service_account_id != null ? var.agent_service_account_id : "${var.stack_name}-agent"
  metrics_service_account_id = var.metrics_service_account_id != null ? var.metrics_service_account_id : "${var.stack_name}-metrics"
  agent_custom_role_id       = var.agent_custom_role_id != null ? var.agent_custom_role_id : "${replace(var.stack_name, "/[^a-zA-Z0-9_.]/", "")}AgentInstanceMgmt"
  metrics_custom_role_id     = var.metrics_custom_role_id != null ? var.metrics_custom_role_id : "${replace(var.stack_name, "/[^a-zA-Z0-9_.]/", "")}MetricsAutoscaler"
  metrics_function_name      = "${var.stack_name}-metrics-function"
}

module "networking" {
  source = "./modules/networking"

  project_id              = var.project_id
  network_name            = local.network_name
  region                  = var.region
  enable_ssh_access       = var.enable_ssh_access
  ssh_source_ranges       = var.ssh_source_ranges
  instance_tag            = local.instance_tag
  enable_iap_access       = var.enable_iap_access
  enable_secondary_ranges = var.enable_secondary_ranges
}

module "iam" {
  source = "./modules/iam"

  project_id                 = var.project_id
  agent_service_account_id   = local.agent_service_account_id
  metrics_service_account_id = local.metrics_service_account_id
  agent_custom_role_id       = local.agent_custom_role_id
  metrics_custom_role_id     = local.metrics_custom_role_id
  enable_secret_access       = var.enable_secret_access
  enable_storage_access      = var.enable_storage_access
}

module "compute" {
  source = "./modules/compute"

  project_id = var.project_id
  region     = var.region
  zones      = var.zones
  stack_name = var.stack_name

  # Buildkite configuration
  buildkite_organization_slug  = var.buildkite_organization_slug
  buildkite_agent_token        = var.buildkite_agent_token
  buildkite_agent_token_secret = var.buildkite_agent_token_secret
  buildkite_agent_release      = var.buildkite_agent_release
  buildkite_queue              = var.buildkite_queue
  buildkite_agent_tags         = var.buildkite_agent_tags
  buildkite_api_endpoint       = var.buildkite_api_endpoint

  # Instance configuration
  machine_type      = var.machine_type
  image             = var.image
  root_disk_size_gb = var.root_disk_size_gb
  root_disk_type    = var.root_disk_type

  # Scaling configuration
  min_size                      = var.min_size
  max_size                      = var.max_size
  cooldown_period               = var.cooldown_period
  autoscaling_jobs_per_instance = var.autoscaling_jobs_per_instance
  enable_autoscaling            = var.enable_autoscaling

  # Health check configuration
  enable_autohealing               = var.enable_autohealing
  health_check_port                = var.health_check_port
  health_check_interval_sec        = var.health_check_interval_sec
  health_check_timeout_sec         = var.health_check_timeout_sec
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
  health_check_initial_delay_sec   = var.health_check_initial_delay_sec

  # Update policy configuration
  max_surge       = var.max_surge
  max_unavailable = var.max_unavailable

  # Security configuration
  enable_secure_boot          = var.enable_secure_boot
  enable_vtpm                 = var.enable_vtpm
  enable_integrity_monitoring = var.enable_integrity_monitoring

  # Additional configuration
  labels = var.labels

  # Networking (from networking module)
  network_self_link = module.networking.network_self_link
  subnet_self_link  = module.networking.subnet_0_self_link
  instance_tag      = module.networking.instance_tag

  # IAM (from IAM module)
  agent_service_account_email = module.iam.agent_service_account_email

  # Ensure the autoscaler waits for the metrics function to be invoked
  # so the custom metric exists before the autoscaler is created
  autoscaler_depends_on = var.enable_autoscaling ? module.buildkite_metrics : []
}

module "buildkite_metrics" {
  source = "./modules/buildkite-agent-metrics"
  count  = var.enable_autoscaling ? 1 : 0

  project_id                   = var.project_id
  enable_debug                 = true
  region                       = var.region
  function_name                = local.metrics_function_name
  buildkite_agent_token        = var.buildkite_agent_token
  buildkite_agent_token_secret = var.buildkite_agent_token_secret
  buildkite_queue              = var.buildkite_queue
  buildkite_organization_slug  = var.buildkite_organization_slug
  service_account_email        = module.iam.metrics_service_account_email

  labels = var.labels

  # Ensure IAM permissions (especially storage.objectViewer for gcf-v2-sources bucket)
  # are fully applied before creating the Cloud Function
  depends_on = [module.iam]
}
