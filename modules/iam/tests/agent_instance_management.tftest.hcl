mock_provider "google" {}

run "grants_only_managed_instance_group_removal_permissions" {
  command = plan

  variables {
    project_id = "test-project"
  }

  assert {
    condition = toset(google_project_iam_custom_role.agent_instance_management.permissions) == toset([
      "compute.instanceGroupManagers.get",
      "compute.instanceGroupManagers.update",
      "compute.regionOperations.get",
    ])
    error_message = "Agents must be able to inspect and update their managed instance group and poll regional operations without directly deleting VMs."
  }
}
