# =============================================================================
# VPC Network
# =============================================================================

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

# =============================================================================
# Subnets
# =============================================================================

# Public subnet — frontend instances (have external IPs via LB, not directly)
resource "google_compute_subnetwork" "public" {
  name                     = "${var.network_name}-public"
  ip_cidr_range            = "10.10.1.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# Private subnet — backend instances + Cloud SQL (no external IPs)
resource "google_compute_subnetwork" "private" {
  name                     = "${var.network_name}-private"
  ip_cidr_range            = "10.10.2.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# =============================================================================
# Cloud Router + Cloud NAT (outbound internet for private subnet)
# =============================================================================

resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  # Both subnets need NAT — instances have no public IPs (traffic goes through LB)
  subnetwork {
    name                    = google_compute_subnetwork.public.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# =============================================================================
# Firewall Rules
# =============================================================================

# Allow health checks from Google's health check ranges
resource "google_compute_firewall" "allow_health_check" {
  name    = "${var.network_name}-allow-health-check"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80", "8080"]
  }

  # Google health check IP ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["allow-health-check"]
}

# Allow IAP for SSH (secure remote access without public IPs)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.network_name}-allow-iap-ssh"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["allow-iap-ssh"]
}

# Allow frontend to receive traffic from LB
resource "google_compute_firewall" "allow_frontend" {
  name    = "${var.network_name}-allow-frontend"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["frontend"]
}

# Allow backend to receive traffic only from frontend subnet
resource "google_compute_firewall" "allow_backend_from_frontend" {
  name    = "${var.network_name}-allow-be-from-fe"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = [google_compute_subnetwork.public.ip_cidr_range]
  target_tags   = ["backend"]
}

# Deny all ingress by default (implicit in GCP, but explicit is clearer)
resource "google_compute_firewall" "deny_all_ingress" {
  name     = "${var.network_name}-deny-all-ingress"
  network  = google_compute_network.vpc.id
  priority = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

# =============================================================================
# Private Services Access (for Cloud SQL private IP)
# Allocate an IP range for Google's service producer network,
# then create a VPC peering connection to it.
# =============================================================================

resource "google_compute_global_address" "private_services_range" {
  name          = "${var.network_name}-private-svc-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services_range.name]
}
