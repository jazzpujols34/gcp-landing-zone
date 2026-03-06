# =============================================================================
# Cloud Storage — static assets bucket
# =============================================================================

resource "google_storage_bucket" "assets" {
  name     = "${var.project_id}-assets-${var.environment}"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true
  force_destroy               = true # Demo — allow terraform destroy

  versioning {
    enabled = false
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 90
    }
  }
}

# Backend SA can read objects
resource "google_storage_bucket_iam_member" "backend_reader" {
  bucket = google_storage_bucket.assets.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.backend_sa_email}"
}
