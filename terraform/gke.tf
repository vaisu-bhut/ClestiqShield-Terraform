# GKE Cluster - Zonal for predictable node count
resource "google_container_cluster" "primary" {
  name     = "${var.application_name}-${var.environment}-gke"
  location = var.zone
  project  = var.project_id

  deletion_protection = false

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  node_config {
    disk_size_gb = var.node_disk_size
    disk_type    = var.node_disk_type
    machine_type = var.machine_type
  }

  depends_on = [
    google_project_service.container
  ]
}

# Managed node pool with proper autoscaling
resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.application_name}-${var.environment}-node-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  initial_node_count = 1
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  # Prevent Terraform drift from autoscaler changes
  lifecycle {
    ignore_changes = [initial_node_count]
  }

  node_config {
    preemptible  = true
    machine_type = var.machine_type

    # Use HDD to save SSD quota (default, but variable allows override)
    disk_size_gb = var.node_disk_size
    disk_type    = var.node_disk_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      env = var.environment
    }

    tags = ["gke-node", "${var.application_name}-${var.environment}-gke"]
  }
}
