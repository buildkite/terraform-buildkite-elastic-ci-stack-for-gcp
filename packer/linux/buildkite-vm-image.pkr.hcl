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
  type    = string
  default = "e2-standard-4"
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

variable "image_family" {
  type        = string
  description = "The image family name for the custom image"
  default     = "buildkite-ci-stack"
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

source "googlecompute" "buildkite-ci-stack" {
  project_id              = var.project_id
  source_image_family     = var.base_image_name == "" ? var.source_image_family : null
  source_image            = var.base_image_name == "" ? null : var.base_image_name
  source_image_project_id = [var.source_image_project]
  zone                    = var.zone
  machine_type            = var.machine_type

  image_name        = "buildkite-ci-stack-${var.arch}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  image_family      = var.image_family
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
    inline = [
      "mkdir -p /tmp/plugins /tmp/build",
      "echo 'Created empty directories for plugins and build artifacts'"
    ]
  }

  # Essential utilities & updates
  provisioner "shell" {
    script = "scripts/install-utils"
  }

  # Buildkite Agent installation
  provisioner "shell" {
    script = "scripts/install-buildkite-agent"
  }

  # Buildkite utilities (excluding S3-related components)
  provisioner "shell" {
    script = "scripts/install-buildkite-utils"
  }

  # Docker installation
  provisioner "shell" {
    script = "scripts/install-docker"
  }

  # Docker configuration (daemon.json, GC scripts, systemd timers)
  provisioner "shell" {
    script = "scripts/configure-docker"
  }

  # Session Manager-like functionality for GCP
  provisioner "shell" {
    script = "scripts/install-gcp-tools"
  }

  # Google Cloud Ops Agent for centralized logging and monitoring
  provisioner "shell" {
    script = "scripts/install-ops-agent"
  }

  # Configure rsyslog to route systemd service logs to files
  provisioner "shell" {
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
    script = "scripts/cleanup"
  }
}
