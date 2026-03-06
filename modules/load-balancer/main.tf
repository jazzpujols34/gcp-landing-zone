# =============================================================================
# Cloud Armor — WAF security policy
# NOTE: Disabled for free trial projects (SECURITY_POLICIES quota = 0).
# Uncomment when using a billing account with Cloud Armor access.
# =============================================================================

# resource "google_compute_security_policy" "waf" {
#   name    = "waf-policy-${var.environment}"
#   project = var.project_id
#
#   rule {
#     action   = "allow"
#     priority = "2147483647"
#     match {
#       versioned_expr = "SRC_IPS_V1"
#       config {
#         src_ip_ranges = ["*"]
#       }
#     }
#     description = "Default allow"
#   }
#
#   rule {
#     action   = "rate_based_ban"
#     priority = "1000"
#     match {
#       versioned_expr = "SRC_IPS_V1"
#       config {
#         src_ip_ranges = ["*"]
#       }
#     }
#     rate_limit_options {
#       conform_action = "allow"
#       exceed_action  = "deny(429)"
#       rate_limit_threshold {
#         count        = 100
#         interval_sec = 60
#       }
#       ban_duration_sec = 300
#     }
#     description = "Rate limit: 100 req/min per IP"
#   }
# }

# =============================================================================
# Global IP Address
# =============================================================================

resource "google_compute_global_address" "lb_ip" {
  name    = "lb-global-ip-${var.environment}"
  project = var.project_id
}

# =============================================================================
# Backend Services
# =============================================================================

# Frontend backend service (serves static content via nginx)
resource "google_compute_backend_service" "frontend" {
  name                  = "frontend-backend-svc-${var.environment}"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"
  # security_policy       = google_compute_security_policy.waf.id  # Enable when Cloud Armor quota available

  # Cloud CDN enabled for static content
  enable_cdn = true
  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    default_ttl                  = 3600
    max_ttl                      = 86400
    signed_url_cache_max_age_sec = 0
  }

  backend {
    group           = var.frontend_instance_group
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.frontend_lb.id]
}

# Backend API service (proxies /api/* requests)
resource "google_compute_backend_service" "backend" {
  name                  = "backend-backend-svc-${var.environment}"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 60
  load_balancing_scheme = "EXTERNAL_MANAGED"
  # security_policy       = google_compute_security_policy.waf.id  # Enable when Cloud Armor quota available

  enable_cdn = false # No CDN for API

  backend {
    group           = var.backend_instance_group
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.backend_lb.id]
}

# =============================================================================
# Health Checks (for LB — separate from MIG health checks)
# =============================================================================

resource "google_compute_health_check" "frontend_lb" {
  name                = "frontend-lb-hc-${var.environment}"
  project             = var.project_id
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

resource "google_compute_health_check" "backend_lb" {
  name                = "backend-lb-hc-${var.environment}"
  project             = var.project_id
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8080
    request_path = "/health"
  }
}

# =============================================================================
# URL Map — route /api/* to backend, everything else to frontend
# =============================================================================

resource "google_compute_url_map" "main" {
  name            = "lb-url-map-${var.environment}"
  project         = var.project_id
  default_service = google_compute_backend_service.frontend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "paths"
  }

  path_matcher {
    name            = "paths"
    default_service = google_compute_backend_service.frontend.id

    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.backend.id
    }
  }
}

# =============================================================================
# HTTPS Proxy + Forwarding Rule
# For demo: using HTTP (port 80) to avoid needing a domain for managed cert.
# Production would use google_compute_managed_ssl_certificate + HTTPS proxy.
# =============================================================================

resource "google_compute_target_http_proxy" "main" {
  name    = "lb-http-proxy-${var.environment}"
  project = var.project_id
  url_map = google_compute_url_map.main.id
}

resource "google_compute_global_forwarding_rule" "main" {
  name                  = "lb-forwarding-rule-${var.environment}"
  project               = var.project_id
  target                = google_compute_target_http_proxy.main.id
  port_range            = "80"
  ip_address            = google_compute_global_address.lb_ip.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
