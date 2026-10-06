mock_provider "google" {}

variables {
  project_id   = "test-project"
  network_name = "test-network"
  instance_tag = "test-agent"
}

run "creates_nat_by_default" {
  command = plan

  assert {
    condition     = length(google_compute_router_nat.nat) == 1 && length(google_compute_router.router) == 1
    error_message = "Cloud NAT and its router must be created by default."
  }
}

run "omits_nat_when_disabled" {
  command = plan

  variables {
    enable_nat = false
  }

  assert {
    condition     = length(google_compute_router_nat.nat) == 0 && length(google_compute_router.router) == 0
    error_message = "Disabling NAT must omit the Cloud Router and Cloud NAT."
  }

  assert {
    condition     = output.nat_name == null && output.router_name == null
    error_message = "NAT outputs must be null when NAT is disabled."
  }
}
