terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0, < 8.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

module "compute" {
  source = "../../modules/compute"

  project_id = var.project
  region     = var.region
  zones      = var.zones
  stack_name = var.stack_name

  # Networking (from existing networking module outputs)
  network_self_link = var.network_self_link
  subnet_self_link  = var.subnet_self_link
  instance_tag      = var.instance_tag

  # IAM (from existing IAM module outputs)
  agent_service_account_email = var.agent_service_account_email

  # Instance configuration
  machine_type      = var.machine_type
  image             = var.image
  root_disk_size_gb = var.root_disk_size_gb
  root_disk_type    = var.root_disk_type

  # Buildkite configuration
  buildkite_organization_slug  = var.buildkite_organization_slug
  buildkite_agent_token        = var.buildkite_agent_token
  buildkite_agent_token_secret = var.buildkite_agent_token_secret
  buildkite_agent_release      = var.buildkite_agent_release
  buildkite_queue              = var.buildkite_queue
  buildkite_agent_tags         = var.buildkite_agent_tags
  buildkite_api_endpoint       = var.buildkite_api_endpoint

  # Autoscaling configuration
  min_size                      = var.min_size
  max_size                      = var.max_size
  cooldown_period               = var.cooldown_period
  autoscaling_jobs_per_instance = var.autoscaling_jobs_per_instance
  enable_autoscaling            = var.enable_autoscaling

  # Health check configuration
  enable_autohealing             = var.enable_autohealing
  health_check_initial_delay_sec = var.health_check_initial_delay_sec

  # Labels
  labels = var.labels
}
