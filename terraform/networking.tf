# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.application_name}-${var.environment}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet with secondary ranges for GKE pods and services
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.db_instance_name}-${var.environment}-subnet"
  ip_cidr_range = var.vpc_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.gke_pods_cidr
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.gke_services_cidr
  }

  private_ip_google_access = true
}

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "${var.application_name}-${var.environment}-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id
}

# Cloud NAT for private pods to access internet
resource "google_compute_router_nat" "nat" {
  name                               = "${var.application_name}-${var.environment}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
