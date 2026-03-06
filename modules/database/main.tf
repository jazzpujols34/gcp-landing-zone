# =============================================================================
# Cloud SQL — PostgreSQL with private IP only
# =============================================================================

resource "google_sql_database_instance" "main" {
  name             = "landing-zone-db-${var.environment}"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  # Ensure private services access is ready before creating the instance
  depends_on = [var.private_services_connection]

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL" # No HA for demo — saves cost
    disk_size         = 10
    disk_autoresize   = false

    ip_configuration {
      ipv4_enabled                                  = false # No public IP
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled    = true
      start_time = "03:00" # 3 AM UTC
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
  }

  deletion_protection = false # Demo project — allow terraform destroy
}

resource "google_sql_database" "app" {
  name     = "app"
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

resource "google_sql_user" "app" {
  name     = "app"
  instance = google_sql_database_instance.main.name
  password = var.db_password
  project  = var.project_id
}
