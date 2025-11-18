# Networking Module

This module creates the GCP networking infrastructure equivalent to the AWS networking resources used in the Elastic CI Stack for AWS.

## Resources Created

This module creates the following GCP networking resources that map to the AWS equivalents:

| AWS Resource | GCP Equivalent | Description |
|--------------|----------------|-------------|
| VPC (10.0.0.0/16) | `google_compute_network` | VPC network with custom subnets |
| Internet Gateway | `google_compute_router_nat` | Cloud NAT for internet access |
| Route Table + Routes | `google_compute_router` | Cloud Router for routing |
| Subnet0 (10.0.1.0/24) | `google_compute_subnetwork` | First subnet for instances |
| Subnet1 (10.0.2.0/24) | `google_compute_subnetwork` | Second subnet for instances |
| Security Group | `google_compute_firewall` | Firewall rules for network security |

## Features

- **VPC Network**: Custom VPC with regional routing mode
- **Dual Subnets**: Two subnets (10.0.1.0/24 and 10.0.2.0/24) for high availability
- **Cloud NAT**: Provides internet access for instances without external IPs
- **Firewall Rules**:
  - SSH access (configurable)
  - Internal communication between subnets
  - Google Cloud health checks
  - Identity-Aware Proxy (IAP) access (optional)
- **Private Google Access**: Instances can access Google APIs without external IPs
- **Future GKE Support**: Optional secondary IP ranges for pods and services

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  network_name         = "elastic-ci-stack"
  region              = "us-central1"
  enable_ssh_access   = true
  ssh_source_ranges   = ["0.0.0.0/0"]
  instance_tag        = "elastic-ci-agent"
  enable_iap_access   = false
  enable_secondary_ranges = false
}
```

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `network_name` | `string` | `"elastic-ci-stack"` | Name prefix for all networking resources |
| `region` | `string` | `"us-central1"` | GCP region for the network |
| `enable_ssh_access` | `bool` | `true` | Enable SSH firewall rule |
| `ssh_source_ranges` | `list(string)` | `["0.0.0.0/0"]` | CIDR blocks allowed SSH access |
| `instance_tag` | `string` | `"elastic-ci-agent"` | Network tag for firewall targeting |
| `enable_iap_access` | `bool` | `false` | Enable Identity-Aware Proxy access |
| `enable_secondary_ranges` | `bool` | `false` | Enable secondary IP ranges for GKE |

## Outputs

### Network Information

- `network_name` - Name of the VPC network
- `network_id` - ID of the VPC network
- `network_self_link` - Self link of the VPC network

### Subnet Information

- `subnet_0_name`, `subnet_0_id`, `subnet_0_self_link`, `subnet_0_cidr` - First subnet details
- `subnet_1_name`, `subnet_1_id`, `subnet_1_self_link`, `subnet_1_cidr` - Second subnet details
- `subnets` - List of subnet objects for use with instance groups

### Infrastructure Components

- `router_name` - Name of the Cloud Router
- `nat_name` - Name of the Cloud NAT
- `instance_tag` - Network tag for compute instances

### Firewall Rules

- `ssh_firewall_rule_name` - SSH access rule (if enabled)
- `internal_firewall_rule_name` - Internal communication rule
- `health_checks_firewall_rule_name` - Health checks rule
- `iap_firewall_rule_name` - IAP access rule (if enabled)

## Network Architecture

```sh
                    ┌─────────────────────────────────────┐
                    │         VPC Network                  │
                    │        (10.0.0.0/16)               │
                    │                                     │
         ┌──────────┼────────────┐         ┌─────────────┼──────────────┐
         │          │  Subnet 0   │         │             │   Subnet 1   │
         │          │10.0.1.0/24  │         │             │ 10.0.2.0/24  │
         │          │             │         │             │              │
         │    ┌─────▼─────┐       │         │       ┌─────▼─────┐        │
         │    │ Instances │       │         │       │ Instances │        │
         │    └───────────┘       │         │       └───────────┘        │
         │                        │         │                            │
         └────────────────────────┘         └────────────────────────────┘
                    │                                     │
                    └─────────────────┬───────────────────┘
                                      │
                              ┌───────▼───────┐
                              │  Cloud Router  │
                              │   + Cloud NAT  │
                              └───────┬───────┘
                                      │
                              ┌───────▼───────┐
                              │    Internet    │
                              └───────────────┘
```

## Requirements

- Terraform >= 0.14
- Google Cloud Provider >= 4.0
- Appropriate GCP permissions to create networking resources

## Permissions Required

The service account or user running Terraform needs the following IAM roles:

- `roles/compute.networkAdmin`
- `roles/compute.securityAdmin`

Or the following specific permissions:

- `compute.networks.create`
- `compute.networks.delete`
- `compute.networks.get`
- `compute.subnetworks.create`
- `compute.subnetworks.delete`
- `compute.subnetworks.get`
- `compute.routers.create`
- `compute.routers.delete`
- `compute.routers.get`
- `compute.firewalls.create`
- `compute.firewalls.delete`
- `compute.firewalls.get`
