terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=6.0, <7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.5, <4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "random" {}
