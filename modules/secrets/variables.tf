variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "db_password" {
  description = "Database password to store"
  type        = string
  sensitive   = true
}

variable "backend_sa_email" {
  description = "Backend SA that needs secret access"
  type        = string
}
