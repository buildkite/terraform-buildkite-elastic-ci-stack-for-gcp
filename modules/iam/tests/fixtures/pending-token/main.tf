variable "project_id" {
  type = string
}

resource "google_secret_manager_secret_version" "token" {
  secret      = "projects/${var.project_id}/secrets/buildkite-token"
  secret_data = "test-token"
}

module "iam" {
  source                       = "../../.."
  project_id                   = var.project_id
  buildkite_agent_token_secret = "projects/${var.project_id}/secrets/buildkite-token/versions/${google_secret_manager_secret_version.token.version}"
}
