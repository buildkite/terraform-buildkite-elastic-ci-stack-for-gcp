# GCP Networking Module for Elastic CI Stack

# VPC Network (equivalent to AWS VPC)
resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  mtu                     = 1460
  routing_mode            = "REGIONAL"

  description = "VPC network for Elastic CI Stack compute instances"
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "router" {
  project = var.project_id
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id

  description = "Router for NAT gateway"
}

# Cloud NAT (equivalent to AWS Internet Gateway + NAT Gateway)
resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Subnet 0 (equivalent to AWS Subnet0 - 10.0.1.0/24)
resource "google_compute_subnetwork" "subnet_0" {
  project       = var.project_id
  name          = "${var.network_name}-subnet-0"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  description = "First subnet for Elastic CI Stack instances"

  # Enable private Google access for instances without external IPs
  private_ip_google_access = true

  # Secondary IP range for pods if using GKE in the future
  dynamic "secondary_ip_range" {
    for_each = var.enable_secondary_ranges ? [1] : []
    content {
      range_name    = "${var.network_name}-pods"
      ip_cidr_range = "192.168.0.0/18"
    }
  }

  dynamic "secondary_ip_range" {
    for_each = var.enable_secondary_ranges ? [1] : []
    content {
      range_name    = "${var.network_name}-services"
      ip_cidr_range = "192.168.64.0/18"
    }
  }
}

# Subnet 1 (equivalent to AWS Subnet1 - 10.0.2.0/24)
resource "google_compute_subnetwork" "subnet_1" {
  project       = var.project_id
  name          = "${var.network_name}-subnet-1"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  description = "Second subnet for Elastic CI Stack instances"

  # Enable private Google access for instances without external IPs
  private_ip_google_access = true

  # Secondary IP range for pods if using GKE in the future
  dynamic "secondary_ip_range" {
    for_each = var.enable_secondary_ranges ? [1] : []
    content {
      range_name    = "${var.network_name}-pods-1"
      ip_cidr_range = "192.168.128.0/18"
    }
  }

  dynamic "secondary_ip_range" {
    for_each = var.enable_secondary_ranges ? [1] : []
    content {
      range_name    = "${var.network_name}-services-1"
      ip_cidr_range = "192.168.192.0/18"
    }
  }
}

# Firewall rule for SSH access (equivalent to AWS SecurityGroupSshIngress)
resource "google_compute_firewall" "ssh_ingress" {
  count = var.enable_ssh_access ? 1 : 0

  project = var.project_id
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.vpc.name

  description = "Allow SSH access to compute instances"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = [var.instance_tag]
}

# Firewall rule for internal communication
resource "google_compute_firewall" "internal" {
  project = var.project_id
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.vpc.name

  description = "Allow internal communication between instances"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    "10.0.1.0/24", # subnet_0 CIDR
    "10.0.2.0/24", # subnet_1 CIDR
  ]

  target_tags = [var.instance_tag]
}

# Firewall rule for health checks
resource "google_compute_firewall" "health_checks" {
  project = var.project_id
  name    = "${var.network_name}-allow-health-checks"
  network = google_compute_network.vpc.name

  description = "Allow Google Cloud health checks"

  allow {
    protocol = "tcp"
  }

  source_ranges = [
    # https://cloud.google.com/compute/docs/instance-groups/autohealing-instances-in-migs
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]

  target_tags = [var.instance_tag]
}

# Firewall rule for IAP (Identity-Aware Proxy) if needed
resource "google_compute_firewall" "iap" {
  count = var.enable_iap_access ? 1 : 0

  project = var.project_id
  name    = "${var.network_name}-allow-iap"
  network = google_compute_network.vpc.name

  description = "Allow access from Identity-Aware Proxy"

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  # https://cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.instance_tag]
}
