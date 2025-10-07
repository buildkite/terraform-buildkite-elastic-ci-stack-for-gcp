output "network_name" {
  description = "Name of the created VPC network"
  value       = google_compute_network.vpc.name
}

output "network_id" {
  description = "ID of the created VPC network"
  value       = google_compute_network.vpc.id
}

output "network_self_link" {
  description = "Self link of the created VPC network"
  value       = google_compute_network.vpc.self_link
}

output "subnet_0_name" {
  description = "Name of the first subnet"
  value       = google_compute_subnetwork.subnet_0.name
}

output "subnet_0_id" {
  description = "ID of the first subnet"
  value       = google_compute_subnetwork.subnet_0.id
}

output "subnet_0_self_link" {
  description = "Self link of the first subnet"
  value       = google_compute_subnetwork.subnet_0.self_link
}

output "subnet_0_cidr" {
  description = "CIDR range of the first subnet"
  value       = google_compute_subnetwork.subnet_0.ip_cidr_range
}

output "subnet_1_name" {
  description = "Name of the second subnet"
  value       = google_compute_subnetwork.subnet_1.name
}

output "subnet_1_id" {
  description = "ID of the second subnet"
  value       = google_compute_subnetwork.subnet_1.id
}

output "subnet_1_self_link" {
  description = "Self link of the second subnet"
  value       = google_compute_subnetwork.subnet_1.self_link
}

output "subnet_1_cidr" {
  description = "CIDR range of the second subnet"
  value       = google_compute_subnetwork.subnet_1.ip_cidr_range
}

output "router_name" {
  description = "Name of the Cloud Router"
  value       = google_compute_router.router.name
}

output "nat_name" {
  description = "Name of the Cloud NAT"
  value       = google_compute_router_nat.nat.name
}

output "ssh_firewall_rule_name" {
  description = "Name of the SSH firewall rule (if enabled)"
  value       = var.enable_ssh_access ? google_compute_firewall.ssh_ingress[0].name : null
}

output "internal_firewall_rule_name" {
  description = "Name of the internal communication firewall rule"
  value       = google_compute_firewall.internal.name
}

output "health_checks_firewall_rule_name" {
  description = "Name of the health checks firewall rule"
  value       = google_compute_firewall.health_checks.name
}

output "iap_firewall_rule_name" {
  description = "Name of the IAP firewall rule (if enabled)"
  value       = var.enable_iap_access ? google_compute_firewall.iap[0].name : null
}

output "subnets" {
  description = "List of subnet objects for use with instance groups"
  value = [
    {
      name      = google_compute_subnetwork.subnet_0.name
      self_link = google_compute_subnetwork.subnet_0.self_link
      region    = google_compute_subnetwork.subnet_0.region
      cidr      = google_compute_subnetwork.subnet_0.ip_cidr_range
    },
    {
      name      = google_compute_subnetwork.subnet_1.name
      self_link = google_compute_subnetwork.subnet_1.self_link
      region    = google_compute_subnetwork.subnet_1.region
      cidr      = google_compute_subnetwork.subnet_1.ip_cidr_range
    }
  ]
}

output "instance_tag" {
  description = "Network tag to apply to compute instances for firewall targeting"
  value       = var.instance_tag
}