# GKE Cluster - Zonal for predictable node count
resource "google_container_cluster" "primary" {
  name     = "${var.application_name}-gke"
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
    disk_size_gb = 50
    disk_type    = "pd-standard"
    machine_type = "e2-medium"
  }

  depends_on = [
    google_project_service.container
  ]
}

# Managed node pool with proper autoscaling
resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.application_name}-node-pool"
  location = var.zone 
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  initial_node_count = 1
  autoscaling {
    min_node_count = 0  # Scale to zero when idle (cost savings)
    max_node_count = 3
  }

  # Prevent Terraform drift from autoscaler changes
  lifecycle {
    ignore_changes = [initial_node_count]
  }

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Use HDD to save SSD quota
    disk_size_gb = 50
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      env = "sandbox"
    }

    tags = ["gke-node", "${var.application_name}-gke"]
  }
}
