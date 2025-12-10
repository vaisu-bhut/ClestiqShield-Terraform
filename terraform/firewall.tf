# Internal firewall - allow communication between VPC resources
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.application_name}-${var.environment}-allow-internal"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "5432", "8000-8002", "4317-4318"]
  }

  allow {
    protocol = "udp"
    ports    = ["4317-4318"]
  }

  source_ranges = ["10.0.0.0/8"]
  priority      = 1000
  description   = "Allow internal VPC traffic on specific ports"
}

# Allow health checks from GCP load balancers
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.application_name}-${var.environment}-allow-health-checks"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "8000-8002"]
  }

  # GCP health check ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["gke-node", "${var.application_name}-${var.environment}-gke"]
  priority      = 900
  description   = "Allow GCP health checks to reach GKE nodes"
}

# Allow external access to gateway LoadBalancer
resource "google_compute_firewall" "allow_gateway_external" {
  name    = "${var.application_name}-${var.environment}-allow-gateway-external"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-node", "${var.application_name}-${var.environment}-gke"]
  priority      = 800
  description   = "Allow external traffic to gateway service"
}
