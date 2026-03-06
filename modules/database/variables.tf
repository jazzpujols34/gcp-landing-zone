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

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "private_services_connection" {
  description = "Private services networking connection (dependency)"
  type        = any
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
