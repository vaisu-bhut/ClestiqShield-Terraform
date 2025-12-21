variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "zone" {
  description = "GCP Zone for zonal resources (e.g., us-east1-b)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., main, staging)"
  type        = string
  default     = "main"
}

variable "application_name" {
  description = "Application name"
  type        = string
}

# GKE Configuration
variable "machine_type" {
  description = "Node machine type"
  type        = string
}

variable "node_disk_size" {
  description = "Node disk size in GB"
  type        = number
}

variable "node_disk_type" {
  description = "Node disk type"
  type        = string
}

variable "min_node_count" {
  description = "Minimum nodes per zone"
  type        = number
}

variable "max_node_count" {
  description = "Maximum nodes per zone"
  type        = number
}

# Database Configuration
variable "db_instance_name" {
  description = "Cloud SQL instance name base"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_user" {
  description = "Database user"
  type        = string
}

variable "db_tier" {
  description = "Cloud SQL tier"
  type        = string
}

variable "db_disk_size" {
  description = "Database disk size in GB"
  type        = number
}

# Network Configuration
variable "vpc_cidr" {
  description = "VPC CIDR range (not used directly if subnet is custom, but good practice)" # Note: current setup uses specific subnet CIDR
  type        = string
}

variable "gke_pods_cidr" {
  description = "GKE Pods secondary range CIDR"
  type        = string
}

variable "gke_services_cidr" {
  description = "GKE Services secondary range CIDR"
  type        = string
}

# Secrets
variable "datadog_app_key" {
  description = "Datadog Application Key"
  type        = string
  sensitive   = true
}

variable "datadog_api_key" {
  description = "Datadog API Key"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog Site (e.g., us5.datadoghq.com)"
  type        = string
}

variable "eagle_eye_secret_key" {
  description = "Secret key for Eagle Eye service"
  type        = string
  sensitive   = true
}

variable "gemini_api_key" {
  description = "Gemini API Key"
  type        = string
  sensitive   = true
}
