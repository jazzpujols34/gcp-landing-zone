output "frontend_sa_email" {
  description = "Frontend service account email"
  value       = google_service_account.frontend.email
}

output "backend_sa_email" {
  description = "Backend service account email"
  value       = google_service_account.backend.email
}
