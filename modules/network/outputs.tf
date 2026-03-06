output "network_id" {
  description = "VPC network ID"
  value       = google_compute_network.vpc.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.vpc.name
}

output "network_self_link" {
  description = "VPC network self link"
  value       = google_compute_network.vpc.self_link
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = google_compute_subnetwork.public.id
}

output "public_subnet_self_link" {
  description = "Public subnet self link"
  value       = google_compute_subnetwork.public.self_link
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = google_compute_subnetwork.private.id
}

output "private_subnet_self_link" {
  description = "Private subnet self link"
  value       = google_compute_subnetwork.private.self_link
}

output "private_services_connection" {
  description = "Private services networking connection (for Cloud SQL dependency)"
  value       = google_service_networking_connection.private_services
}
