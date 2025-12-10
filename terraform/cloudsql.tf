# Generate random password for Cloud SQL
resource "random_password" "db_password" {
  length  = 32
  special = true
  # Exclude special characters that might break connection strings
  override_special = "-_"
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "postgres" {
  name             = "${var.db_instance_name}-${var.environment}"
  database_version = "POSTGRES_17"
  region           = var.region
  project          = var.project_id

  # Deletion protection
  deletion_protection = false # Set to true in production

  settings {
    edition           = "ENTERPRISE" # Use ENTERPRISE edition for db-f1-micro support
    tier              = var.db_tier
    availability_type = "ZONAL" # Single zone
    disk_type         = "PD_SSD"
    disk_size         = var.db_disk_size

    # IP configuration - Private IP with VPC peering
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }

    user_labels = {
      env = var.environment
    }
  }

  # Timeouts - Cloud SQL can take 5-10+ minutes to create
  timeouts {
    create = "60m" # Increased to 60 minutes for private IP instances
    update = "60m"
    delete = "60m"
  }

  # Lifecycle
  lifecycle {
    prevent_destroy = false # Set to true in production
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Private VPC connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.db_instance_name}-${var.environment}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  deletion_policy         = "ABANDON"
  # ABANDON: Terraform ignores deletion - GCP auto-removes peering when Cloud SQL is deleted
  # This prevents the "Producer services still using this connection" error
}

# Create database
resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id

  # Database is automatically deleted when instance is deleted
  # Skip individual deletion to avoid ordering issues
  deletion_policy = "ABANDON"
}

# Create database user
resource "google_sql_user" "user" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
  project  = var.project_id

  # User is automatically deleted when instance is deleted
  # Skip individual deletion to avoid "role owns objects" error
  deletion_policy = "ABANDON"

  # Ensure database is created first (and deleted first on destroy)
  depends_on = [google_sql_database.database]
}
