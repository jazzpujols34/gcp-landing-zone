# =============================================================================
# GCP Landing Zone — Root Module
# Orchestrates all modules for a 3-tier application deployment.
# =============================================================================

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# Network — VPC, subnets, firewall, NAT, private services access
# -----------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  project_id   = var.project_id
  region       = var.region
  network_name = var.network_name
  environment  = var.environment

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# IAM — Service accounts with least-privilege roles
# -----------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  project_id  = var.project_id
  environment = var.environment

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# Secrets — DB password in Secret Manager
# -----------------------------------------------------------------------------
module "secrets" {
  source = "./modules/secrets"

  project_id       = var.project_id
  environment      = var.environment
  db_password      = var.db_password
  backend_sa_email = module.iam.backend_sa_email

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# Database — Cloud SQL PostgreSQL with private IP
# -----------------------------------------------------------------------------
module "database" {
  source = "./modules/database"

  project_id                  = var.project_id
  region                      = var.region
  environment                 = var.environment
  network_id                  = module.network.network_id
  private_services_connection = module.network.private_services_connection
  db_tier                     = var.db_tier
  db_password                 = var.db_password

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# Storage — GCS bucket for static assets
# -----------------------------------------------------------------------------
module "storage" {
  source = "./modules/storage"

  project_id       = var.project_id
  region           = var.region
  environment      = var.environment
  backend_sa_email = module.iam.backend_sa_email

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# Compute — Frontend + Backend MIGs
# -----------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  project_id               = var.project_id
  region                   = var.region
  zone                     = var.zone
  environment              = var.environment
  network_self_link        = module.network.network_self_link
  public_subnet_self_link  = module.network.public_subnet_self_link
  private_subnet_self_link = module.network.private_subnet_self_link
  frontend_sa_email        = module.iam.frontend_sa_email
  backend_sa_email         = module.iam.backend_sa_email
  frontend_machine_type    = var.frontend_machine_type
  backend_machine_type     = var.backend_machine_type
  use_preemptible          = var.use_preemptible
  frontend_min_replicas    = var.frontend_min_replicas
  frontend_max_replicas    = var.frontend_max_replicas
  backend_min_replicas     = var.backend_min_replicas
  backend_max_replicas     = var.backend_max_replicas
  db_private_ip            = module.database.private_ip
}

# -----------------------------------------------------------------------------
# Load Balancer — Global HTTPS LB + CDN + Cloud Armor WAF
# -----------------------------------------------------------------------------
module "load_balancer" {
  source = "./modules/load-balancer"

  project_id               = var.project_id
  environment              = var.environment
  frontend_instance_group  = module.compute.frontend_instance_group
  backend_instance_group   = module.compute.backend_instance_group
}
