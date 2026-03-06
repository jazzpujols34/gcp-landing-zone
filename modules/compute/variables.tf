variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "zone" {
  description = "GCP zone"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "network_self_link" {
  description = "VPC network self link"
  type        = string
}

variable "public_subnet_self_link" {
  description = "Public subnet self link (frontend)"
  type        = string
}

variable "private_subnet_self_link" {
  description = "Private subnet self link (backend)"
  type        = string
}

variable "frontend_sa_email" {
  description = "Frontend service account email"
  type        = string
}

variable "backend_sa_email" {
  description = "Backend service account email"
  type        = string
}

variable "frontend_machine_type" {
  description = "Machine type for frontend instances"
  type        = string
}

variable "backend_machine_type" {
  description = "Machine type for backend instances"
  type        = string
}

variable "use_preemptible" {
  description = "Use preemptible/spot instances"
  type        = bool
}

variable "frontend_min_replicas" {
  description = "Min frontend instances"
  type        = number
}

variable "frontend_max_replicas" {
  description = "Max frontend instances"
  type        = number
}

variable "backend_min_replicas" {
  description = "Min backend instances"
  type        = number
}

variable "backend_max_replicas" {
  description = "Max backend instances"
  type        = number
}

variable "db_private_ip" {
  description = "Cloud SQL private IP address"
  type        = string
  default     = ""
}
