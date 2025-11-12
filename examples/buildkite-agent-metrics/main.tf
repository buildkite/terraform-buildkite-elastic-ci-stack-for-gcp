terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "buildkite_metrics" {
  source = "../../modules/buildkite-agent-metrics"

  project_id            = var.project_id
  region               = var.region
  buildkite_agent_token = var.buildkite_agent_token
  
  # Optional: Monitor specific queues
  buildkite_queue = var.buildkite_queue
  
  # Optional: Customize schedule (default is every minute)
  schedule_interval = var.schedule_interval
  
  # Optional: Enable debug logging
  enable_debug = var.enable_debug
  
  labels = {
    environment = "example"
    managed_by  = "terraform"
  }
}
