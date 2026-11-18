variable "region" {
  type        = string
  description = "Region for the subnets"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "Zone for the test VMs (must be in var.region)"
  default     = "us-central1-a"
}

variable "private_subnet_cidr" {
  type        = string
  description = "IPv4 range of the private subnet"
}

variable "public_subnet_cidr" {
  type        = string
  description = "IPv4 range of the public subnet"
}

variable "cost_label" {
  type        = string
  description = "Value of the 'project' label applied to the VMs and disks"
}

variable "enable_shared_vpc_host" {
  type        = bool
  description = "Make the project a Shared VPC host project (needs org-level Shared VPC Admin permission)"
  default     = true
}

variable "create_test_vms" {
  type        = bool
  description = "Create one test VM in each subnet"
  default     = false
}
