# VPC Network for Cloud SQL private connection
resource "google_compute_network" "vpc" {
  name                    = "${var.application_name}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet for private IP allocation
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.db_instance_name}-subnet"
  ip_cidr_range = "10.0.0.0/20"
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  private_ip_google_access = true
}
