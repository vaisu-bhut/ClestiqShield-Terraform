# Cloud SQL Outputs
output "database_url" {
  description = "Database connection URL (async driver for SQLAlchemy)"
  value       = "postgresql+asyncpg://${var.db_user}:${random_password.db_password.result}@${google_sql_database_instance.postgres.private_ip_address}:5432/${var.db_name}"
  sensitive   = true
}

# GKE Cluster Outputs
output "kubernetes_cluster_endpoint" {
  description = "GKE Cluster Endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "gke_connect_command" {
  description = "Command to connect kubectl to the cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${google_container_cluster.primary.location} --project ${var.project_id}"
}

output "datadog_api_key" {
  description = "Datadog API Key"
  value       = var.datadog_api_key
  sensitive   = true
}

output "datadog_site" {
  description = "Datadog Site"
  value       = var.datadog_site
}

output "eagle_eye_secret_key" {
  description = "Secret key for Eagle Eye service"
  value       = var.eagle_eye_secret_key
  sensitive   = true
}

output "gateway_static_ip" {
  description = "Static IP Address reserved for the Gateway LoadBalancer"
  value       = google_compute_address.gateway_ip.address
}

output "datadog_app_key" {
  description = "Datadog Application Key"
  value       = var.datadog_app_key
  sensitive   = true
}

output "gemini_api_key" {
  description = "Gemini API Key"
  value       = var.gemini_api_key
  sensitive   = true
}
