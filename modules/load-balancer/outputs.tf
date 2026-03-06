output "global_ip" {
  description = "Global IP address of the load balancer"
  value       = google_compute_global_address.lb_ip.address
}

output "url_map_id" {
  description = "URL map ID"
  value       = google_compute_url_map.main.id
}
