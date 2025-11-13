# Example usage of the networking module
# This example shows how to deploy the networking module with provider configuration

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0, < 8.0"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project
  region  = var.region
}

# Deploy the networking module
module "networking" {
  source = "../../modules/networking"

  project_id              = var.project
  network_name            = var.network_name
  region                  = var.region
  enable_ssh_access       = var.enable_ssh_access
  ssh_source_ranges       = var.ssh_source_ranges
  instance_tag            = var.instance_tag
  enable_iap_access       = var.enable_iap_access
  enable_secondary_ranges = var.enable_secondary_ranges
}
