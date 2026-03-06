variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "backend_sa_email" {
  description = "Backend service account email (gets read access)"
  type        = string
}
