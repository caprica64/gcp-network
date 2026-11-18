output "network_id" {
  value = google_compute_network.vpc.id
}

output "private_subnet_id" {
  value = google_compute_subnetwork.private.id
}

output "public_subnet_id" {
  value = google_compute_subnetwork.public.id
}

output "private_vm_ips" {
  value = var.create_test_vms ? {
    ipv4 = google_compute_instance.private_vm[0].network_interface[0].network_ip
    ipv6 = google_compute_instance.private_vm[0].network_interface[0].ipv6_address
  } : null
}

output "public_vm_ips" {
  value = var.create_test_vms ? {
    internal_ipv4 = google_compute_instance.public_vm[0].network_interface[0].network_ip
    external_ipv4 = google_compute_instance.public_vm[0].network_interface[0].access_config[0].nat_ip
    external_ipv6 = google_compute_instance.public_vm[0].network_interface[0].ipv6_access_config[0].external_ipv6
  } : null
}
