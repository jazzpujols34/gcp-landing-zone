# =============================================================================
# Service Accounts — one per tier, least privilege
# =============================================================================

resource "google_service_account" "frontend" {
  account_id   = "sa-frontend-${var.environment}"
  display_name = "Frontend Service Account (${var.environment})"
  project      = var.project_id
}

resource "google_service_account" "backend" {
  account_id   = "sa-backend-${var.environment}"
  display_name = "Backend Service Account (${var.environment})"
  project      = var.project_id
}

# =============================================================================
# IAM Bindings — scoped to what each tier actually needs
# =============================================================================

# Frontend: only needs to write logs
resource "google_project_iam_member" "frontend_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.frontend.email}"
}

resource "google_project_iam_member" "frontend_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.frontend.email}"
}

# Backend: logs + Secret Manager access + Cloud SQL client + GCS read
resource "google_project_iam_member" "backend_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

resource "google_project_iam_member" "backend_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

resource "google_project_iam_member" "backend_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

resource "google_project_iam_member" "backend_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

resource "google_project_iam_member" "backend_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.backend.email}"
}
