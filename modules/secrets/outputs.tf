output "db_password_secret_id" {
  description = "Secret Manager secret ID for DB password"
  value       = google_secret_manager_secret.db_password.secret_id
}
