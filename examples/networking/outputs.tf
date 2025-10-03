output "network_name" {
  description = "Name of the created VPC network"
  value       = module.networking.network_name
}

output "network_self_link" {
  description = "Self link of the created VPC network"
  value       = module.networking.network_self_link
}

output "subnets" {
  description = "List of subnet objects"
  value       = module.networking.subnets
}

output "instance_tag" {
  description = "Network tag for compute instances"
  value       = module.networking.instance_tag
}