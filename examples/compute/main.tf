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

module "networking" {
  source = "../../modules/networking"

  network_name      = var.network_name
  region            = var.region
  enable_ssh_access = var.enable_ssh_access
  ssh_source_ranges = var.ssh_source_ranges
  instance_tag      = var.instance_tag
}

module "iam" {
  source = "../../modules/iam"

  project_id                   = var.project
  agent_service_account_id     = var.agent_service_account_id
  metrics_service_account_id   = var.metrics_service_account_id
  agent_custom_role_id         = var.agent_custom_role_id
  metrics_custom_role_id       = var.metrics_custom_role_id
  enable_secret_access         = var.enable_secret_access
  enable_storage_access        = var.enable_storage_access
}

module "compute" {
  source = "../../modules/compute"

  project_id  = var.project
  region      = var.region
  zones       = var.zones
  stack_name  = var.stack_name

  network_self_link = module.networking.network_self_link
  subnet_self_link  = module.networking.subnet_0_self_link
  instance_tag      = module.networking.instance_tag

  agent_service_account_email = module.iam.agent_service_account_email

  machine_type      = var.machine_type
  image             = var.image
  root_disk_size_gb = var.root_disk_size_gb
  root_disk_type    = var.root_disk_type

  buildkite_agent_token   = var.buildkite_agent_token
  buildkite_agent_release = var.buildkite_agent_release
  buildkite_queue         = var.buildkite_queue
  buildkite_agent_tags    = var.buildkite_agent_tags
  buildkite_api_endpoint  = var.buildkite_api_endpoint

  min_size                = var.min_size
  max_size                = var.max_size
  cooldown_period         = var.cooldown_period
  autoscaling_jobs_per_instance = var.autoscaling_jobs_per_instance

  enable_autohealing             = var.enable_autohealing
  health_check_initial_delay_sec = var.health_check_initial_delay_sec
  enable_autoscaling             = var.enable_autoscaling

  labels = var.labels
}
