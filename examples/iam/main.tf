# Example usage of the IAM module
# This example shows how to deploy the IAM module with provider configuration

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

# Deploy the IAM module
module "iam" {
  source = "../../modules/iam"

  project_id                 = var.project
  agent_service_account_id   = var.agent_service_account_id
  metrics_service_account_id = var.metrics_service_account_id
  agent_custom_role_id       = var.agent_custom_role_id
  metrics_custom_role_id     = var.metrics_custom_role_id
  enable_secret_access       = var.enable_secret_access
  enable_storage_access      = var.enable_storage_access
}
