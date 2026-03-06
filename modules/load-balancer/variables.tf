variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "frontend_instance_group" {
  description = "Frontend MIG instance group URL"
  type        = string
}

variable "backend_instance_group" {
  description = "Backend MIG instance group URL"
  type        = string
}
