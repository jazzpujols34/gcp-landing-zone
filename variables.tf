variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for regional resources"
  type        = string
  default     = "asia-east1"
}

variable "zone" {
  description = "GCP zone for zonal resources"
  type        = string
  default     = "asia-east1-b"
}

variable "environment" {
  description = "Environment label (e.g., demo, dev, prod)"
  type        = string
  default     = "demo"
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "landing-zone-vpc"
}

variable "frontend_machine_type" {
  description = "Machine type for frontend instances"
  type        = string
  default     = "e2-micro"
}

variable "backend_machine_type" {
  description = "Machine type for backend instances"
  type        = string
  default     = "e2-micro"
}

variable "use_preemptible" {
  description = "Use preemptible/spot instances to save cost"
  type        = bool
  default     = true
}

variable "frontend_min_replicas" {
  description = "Minimum number of frontend instances"
  type        = number
  default     = 1
}

variable "frontend_max_replicas" {
  description = "Maximum number of frontend instances"
  type        = number
  default     = 3
}

variable "backend_min_replicas" {
  description = "Minimum number of backend instances"
  type        = number
  default     = 1
}

variable "backend_max_replicas" {
  description = "Maximum number of backend instances"
  type        = number
  default     = 3
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-g1-small"
}

variable "db_password" {
  description = "Database password (will be stored in Secret Manager)"
  type        = string
  sensitive   = true
}
