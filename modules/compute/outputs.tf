output "frontend_instance_group" {
  description = "Frontend managed instance group self link"
  value       = google_compute_region_instance_group_manager.frontend.instance_group
}

output "backend_instance_group" {
  description = "Backend managed instance group self link"
  value       = google_compute_region_instance_group_manager.backend.instance_group
}
