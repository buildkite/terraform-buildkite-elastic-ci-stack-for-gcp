packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
  }
}

variable "arch" {
  type    = string
  default = "x86-64"
}

variable "machine_type" {
  type        = string
  description = "Packer builder machine type. Defaults to e2-standard-4 for x86-64 and t2a-standard-4 for arm64."
  default     = ""
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "project_id" {
  type        = string
  description = "The GCP project ID where the image will be created"
}

variable "build_number" {
  type    = string
  default = "none"
}

variable "agent_version" {
  type    = string
  default = "devel"
}

variable "is_released" {
  type    = bool
  default = false
}

variable "source_image_family" {
  type        = string
  description = "The source Debian image family to build from"
  default     = "debian-13"
}

variable "source_image_project" {
  type        = string
  description = "The project containing the source image"
  default     = "debian-cloud"
}

# Optional override for building from a pre-baked "golden base" image
variable "base_image_name" {
  type        = string
  description = "Base image name to build from instead of default Debian"
  default     = ""
}

variable "service_account_email" {
  type        = string
  description = "Service account email for the build instance (optional)"
  default     = ""
}

locals {
  builder_machine_type = var.machine_type != "" ? var.machine_type : (var.arch == "arm64" ? "t2a-standard-4" : "e2-standard-4")
}

source "googlecompute" "buildkite-ci-stack" {
  project_id                  = var.project_id
  source_image_family         = var.base_image_name == "" ? (var.arch == "arm64" ? "${var.source_image_family}-arm64" : var.source_image_family) : null
  source_image                = var.base_image_name == "" ? null : var.base_image_name
  source_image_project_id     = [var.source_image_project]
  zone                        = var.zone
  machine_type                = local.builder_machine_type
  instance_name               = "packer-${var.arch}-${var.build_number}"
  disk_name                   = "packer-${var.arch}-${var.build_number}"
  max_run_duration_in_seconds = 3600
  instance_termination_action = "DELETE"

  labels = {
    component    = "packer-builder"
    architecture = var.arch
    build_number = var.build_number
  }

  image_name        = "buildkite-ci-stack-${var.arch}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}-${var.build_number}"
  image_description = "Buildkite Elastic CI Stack (Debian 13 based) v0.1.0"

  ssh_username = "packer"

  disk_size = 20
  disk_type = "pd-ssd"

  # Service account configuration (optional)
  service_account_email = var.service_account_email != "" ? var.service_account_email : null
  scopes = var.service_account_email != "" ? [
    "https://www.googleapis.com/auth/cloud-platform"
  ] : null

  image_labels = {
    name          = "buildkite-ci-stack-${var.arch}"
    os_version    = "debian-13"
    build_number  = var.build_number
    agent_version = replace(var.agent_version, ".", "-")
    is_released   = var.is_released ? "true" : "false"
    component     = "buildkite-ci-stack"
    version       = "0-1-0"
  }

  tags = ["buildkite", "ci", "packer-build"]
}

build {
  sources = ["source.googlecompute.buildkite-ci-stack"]

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }

  provisioner "file" {
    destination = "/tmp"
    source      = "conf"
  }

  provisioner "file" {
    destination = "/tmp"
    source      = "../../templates"
  }

  # Create empty directories for plugins and build
  provisioner "shell" {
    remote_folder = "/var/tmp"
    inline = [
      "mkdir -p /tmp/plugins /tmp/build",
      "echo 'Created empty directories for plugins and build artifacts'"
    ]
  }

  # Essential utilities & updates
  provisioner "shell" {
    remote_folder = "/var/tmp"
    script        = "scripts/install-utils"
  }

  # Buildkite Agent installation
  provisioner "shell" {
    remote_folder = "/var/tmp"
    script        = "scripts/install-buildkite-agent"
  }

  # Buildkite utilities (excluding S3-related components)
  provisioner "shell" {
    remote_folder = "/var/tmp"
    script        = "scripts/install-buildkite-utils"
  }

  # Docker installation
  provisioner "shell" {
    remote_folder = "/var/tmp"
    script        = "scripts/install-docker"
  }

  # Docker configuration (daemon.json, GC scripts, systemd timers)
  provisioner "shell" {
    remote_folder = "/var/tmp"
    script        = "scripts/configure-docker"
  }

  # Session Manager-like functionality for GCP
  provisioner "shell" {
    remote_folder = "/var/tmp"
    script        = "scripts/install-gcp-tools"
  }

  # Google Cloud Ops Agent for centralized logging and monitoring
  provisioner "shell" {
    remote_folder = "/var/tmp"
    script        = "scripts/install-ops-agent"
  }

  # Configure rsyslog to route systemd service logs to files
  provisioner "shell" {
    remote_folder = "/var/tmp"
    inline = [
      "echo 'Installing rsyslog configuration for service logs...'",
      "sudo cp /tmp/conf/rsyslog/buildkite-logging.conf /etc/rsyslog.d/10-buildkite-logging.conf",
      "sudo chown root:root /etc/rsyslog.d/10-buildkite-logging.conf",
      "sudo chmod 644 /etc/rsyslog.d/10-buildkite-logging.conf",
      "echo 'Restarting rsyslog service...'",
      "sudo systemctl restart rsyslog",
      "echo 'Rsyslog configuration installed'"
    ]
  }

  # Final cleanup
  provisioner "shell" {
    remote_folder = "/var/tmp"
    script        = "scripts/cleanup"
  }
}
