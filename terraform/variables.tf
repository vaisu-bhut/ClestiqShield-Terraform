variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "application_name" {
  description = "Application name"
  type        = string
}

variable "db_instance_name" {
  description = "Cloud SQL instance name"
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

variable "zone" {
  description = "GCP Zone for zonal resources (e.g., us-east1-b)"
  type        = string
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
