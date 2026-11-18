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
  description = "GCP project ID of the development shared network (Shared VPC host)"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "private_subnet_cidr" {
  type = string
}

variable "public_subnet_cidr" {
  type = string
}

variable "cost_label" {
  type    = string
  default = "gcp-network-dev"
}

variable "create_test_vms" {
  type    = bool
  default = false
}

provider "google" {
  project = var.project_id
  region  = var.region

  # Applied to every resource that supports labels.
  default_labels = {
    project     = var.cost_label
    environment = "dev"
  }
}

module "network" {
  source = "../../modules/network"

  region              = var.region
  zone                = var.zone
  private_subnet_cidr = var.private_subnet_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  cost_label          = var.cost_label
  create_test_vms     = var.create_test_vms
}

output "network_id" {
  value = module.network.network_id
}

output "private_subnet_id" {
  value = module.network.private_subnet_id
}

output "public_subnet_id" {
  value = module.network.public_subnet_id
}

output "private_vm_ips" {
  value = module.network.private_vm_ips
}

output "public_vm_ips" {
  value = module.network.public_vm_ips
}
