# TODO: replace with the real production host project ID
project_id = "rm-lab-prod"

# Production address space: 10.1.0.0/16 (does not overlap with dev 10.0.0.0/16)
private_subnet_cidr = "10.1.1.0/24"
public_subnet_cidr  = "10.1.2.0/24"

cost_label      = "gcp-network-prod"
create_test_vms = true
