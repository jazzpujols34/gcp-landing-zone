# =============================================================================
# Frontend — nginx serving static page
# =============================================================================

resource "google_compute_instance_template" "frontend" {
  name_prefix  = "frontend-${var.environment}-"
  machine_type = var.frontend_machine_type
  region       = var.region

  tags = ["frontend", "allow-health-check", "allow-iap-ssh"]

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
  }

  network_interface {
    subnetwork = var.public_subnet_self_link
    # No access_config — traffic comes through the LB, not direct public IP
  }

  service_account {
    email  = var.frontend_sa_email
    scopes = ["cloud-platform"]
  }

  scheduling {
    preemptible       = var.use_preemptible
    automatic_restart = var.use_preemptible ? false : true
  }

  metadata_startup_script = file("${path.module}/startup-fe.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "frontend" {
  name                = "frontend-health-check-${var.environment}"
  check_interval_sec  = 15
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

resource "google_compute_region_instance_group_manager" "frontend" {
  name               = "frontend-mig-${var.environment}"
  base_instance_name = "frontend-${var.environment}"
  region             = var.region

  version {
    instance_template = google_compute_instance_template.frontend.self_link_unique
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.frontend.id
    initial_delay_sec = 120
  }
}

resource "google_compute_region_autoscaler" "frontend" {
  name   = "frontend-autoscaler-${var.environment}"
  region = var.region
  target = google_compute_region_instance_group_manager.frontend.id

  autoscaling_policy {
    min_replicas    = var.frontend_min_replicas
    max_replicas    = var.frontend_max_replicas
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}

# =============================================================================
# Backend — Python Flask API
# =============================================================================

resource "google_compute_instance_template" "backend" {
  name_prefix  = "backend-${var.environment}-"
  machine_type = var.backend_machine_type
  region       = var.region

  tags = ["backend", "allow-health-check", "allow-iap-ssh"]

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
  }

  network_interface {
    subnetwork = var.private_subnet_self_link
    # No access_config — private subnet, no public IP
  }

  service_account {
    email  = var.backend_sa_email
    scopes = ["cloud-platform"]
  }

  scheduling {
    preemptible       = var.use_preemptible
    automatic_restart = var.use_preemptible ? false : true
  }

  metadata = {
    db-private-ip = var.db_private_ip
  }

  metadata_startup_script = file("${path.module}/startup-be.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "backend" {
  name                = "backend-health-check-${var.environment}"
  check_interval_sec  = 15
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8080
    request_path = "/health"
  }
}

resource "google_compute_region_instance_group_manager" "backend" {
  name               = "backend-mig-${var.environment}"
  base_instance_name = "backend-${var.environment}"
  region             = var.region

  version {
    instance_template = google_compute_instance_template.backend.self_link_unique
  }

  named_port {
    name = "http"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.backend.id
    initial_delay_sec = 180
  }
}

resource "google_compute_region_autoscaler" "backend" {
  name   = "backend-autoscaler-${var.environment}"
  region = var.region
  target = google_compute_region_instance_group_manager.backend.id

  autoscaling_policy {
    min_replicas    = var.backend_min_replicas
    max_replicas    = var.backend_max_replicas
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}
