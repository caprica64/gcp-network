terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Region for the subnets"
  default     = "us-central1"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# GCP VPCs are global and have no CIDR of their own; 10.0.0.0/16 is the
# address space the subnets below are carved from.
resource "google_compute_network" "vpc" {
  name                    = "main-vpc"
  auto_create_subnetworks = false

  # Allocates a /48 ULA (fd20::/20) range, required for INTERNAL IPv6 subnets.
  enable_ula_internal_ipv6 = true
}

# Private subnet: dual-stack with an internal (ULA, not internet-routable) /64.
resource "google_compute_subnetwork" "private" {
  name                     = "private-subnet"
  ip_cidr_range            = "10.0.1.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "INTERNAL"
}

# Public subnet: dual-stack with a Google-assigned, internet-routable /64.
resource "google_compute_subnetwork" "public" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "EXTERNAL"
}

# Subnets in the same VPC are routed to each other automatically by system
# routes. Ingress is denied by default, so allow traffic between them.
resource "google_compute_firewall" "allow_internal" {
  name      = "allow-internal"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"

  source_ranges = [
    google_compute_subnetwork.private.ip_cidr_range,
    google_compute_subnetwork.public.ip_cidr_range,
  ]

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
}

# GCP creates the IPv4 default route (0.0.0.0/0) for you, but not the IPv6 one.
# Without this, the public VM's external IPv6 address can't reach the internet.
resource "google_compute_route" "default_ipv6" {
  name             = "default-route-ipv6"
  network          = google_compute_network.vpc.name
  dest_range       = "::/0"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

# A firewall rule can't mix IPv4 and IPv6 ranges, so IPv6 gets its own rule.
resource "google_compute_firewall" "allow_internal_ipv6" {
  name      = "allow-internal-ipv6"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"

  source_ranges = [
    google_compute_subnetwork.private.internal_ipv6_prefix,
    google_compute_subnetwork.public.external_ipv6_prefix,
  ]

  allow {
    protocol = "58" # ICMPv6
  }
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
}

# Public subnet: instances there get external IPs (access_config) and use the
# default internet gateway route. Private subnet: no external IPs; this NAT
# gives it outbound-only internet access.
resource "google_compute_router" "router" {
  name    = "main-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "private_nat" {
  name                               = "private-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# ---------------------------------------------------------------------------
# Test VMs
# ---------------------------------------------------------------------------

variable "zone" {
  type        = string
  description = "Zone for the test VMs (must be in var.region)"
  default     = "us-central1-a"
}

# SSH through Identity-Aware Proxy (gcloud compute ssh --tunnel-through-iap),
# so neither VM needs SSH open to the internet.
resource "google_compute_firewall" "allow_iap_ssh" {
  name          = "allow-iap-ssh"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["test-vm"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Private VM: no access_config / ipv6_access_config, so it only gets an
# internal IPv4 (10.0.1.x) and an internal ULA IPv6 address.
resource "google_compute_instance" "private_vm" {
  name         = "private-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["test-vm"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
    stack_type = "IPV4_IPV6"
  }
}

# Public VM: empty access_config requests an ephemeral external IPv4, and
# ipv6_access_config requests an external IPv6 from the public subnet's /64.
resource "google_compute_instance" "public_vm" {
  name         = "public-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["test-vm"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public.id
    stack_type = "IPV4_IPV6"

    access_config {}

    ipv6_access_config {
      network_tier = "PREMIUM"
    }
  }
}

output "private_vm_ips" {
  value = {
    ipv4 = google_compute_instance.private_vm.network_interface[0].network_ip
    ipv6 = google_compute_instance.private_vm.network_interface[0].ipv6_address
  }
}

output "public_vm_ips" {
  value = {
    internal_ipv4 = google_compute_instance.public_vm.network_interface[0].network_ip
    external_ipv4 = google_compute_instance.public_vm.network_interface[0].access_config[0].nat_ip
    external_ipv6 = google_compute_instance.public_vm.network_interface[0].ipv6_access_config[0].external_ipv6
  }
}
