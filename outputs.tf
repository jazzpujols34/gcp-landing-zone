output "load_balancer_ip" {
  description = "Global IP address of the HTTPS load balancer"
  value       = module.load_balancer.global_ip
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = module.database.connection_name
}

output "cloud_sql_private_ip" {
  description = "Cloud SQL private IP address"
  value       = module.database.private_ip
}

output "gcs_bucket_url" {
  description = "Cloud Storage bucket URL"
  value       = module.storage.bucket_url
}

output "frontend_service_account" {
  description = "Frontend service account email"
  value       = module.iam.frontend_sa_email
}

output "backend_service_account" {
  description = "Backend service account email"
  value       = module.iam.backend_sa_email
}
