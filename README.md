# Clestiq Shield - Terraform Infrastructure (VPC + Cloud SQL)

Simple Terraform configuration for deploying VPC network and Cloud SQL PostgreSQL with Secret Manager.

## 📦 What This Creates

- ✅ **VPC Network** with custom subnet (10.0.0.0/20)
- ✅ **Cloud SQL PostgreSQL 15** (Regional HA, Private IP only)
- ✅ **VPC Peering** for private database access
- ✅ **Secret Manager** for storing database password
- ✅ **Random Password** generation (32 characters)
- ✅ **API Enablement** (Compute, SQL Admin, Service Networking, Secret Manager)
- ✅ **IAM-based authentication** (no service account keys)

## 🎯 Architecture

```
VPC Network (10.0.0.0/20)
├── Subnet: 10.0.0.0/20
├── VPC Peering → Cloud SQL
└── Private IP Range: 10.8.0.0/16

Cloud SQL PostgreSQL 15
├── Tier: db-custom-2-7680 (2 vCPUs, 7.68 GB RAM)
├── Availability: Regional (HA)
├── Private IP only (no public access)
├── Auto backups enabled
└── Connection: Direct via private IP
```

## 🚀 Quick Start

### Prerequisites

1. **GCP Project**: `clestiq-shield`
2. **Tools**: `gcloud`, `terraform`
3. **Auth**: `gcloud auth application-default login`

### Deploy

```bash
cd ClestiqShield-Terraform

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

### Get Database Password

```bash
# From Secret Manager (recommended)
gcloud secrets versions access latest --secret=clestiq-shield-db-password --project=clestiq-shield

# Or view from Terraform output (shown once)
terraform output -raw db_password

# Or get full connection URL
terraform output -raw database_url
```

### Connect to Database

```bash
# Get private IP
terraform output db_private_ip

# Connect from a VM in the same VPC
psql -h <PRIVATE_IP> -U clestiq_user -d clestiq_shield
```

## 📋 Configuration

Edit `terraform.tfvars`:

```hcl
project_id = "clestiq-shield"
region     = "us-east1"

# Database
db_instance_name = "clestiq-shield-db"
db_name          = "clestiq_shield"
db_user          = "clestiq_user"
```

## 📊 Outputs

After deployment, you'll get:

- `db_connection_name` - For Cloud SQL Proxy
- `db_private_ip` - Private IP address
- `db_name` - Database name
- `db_user` - Database username
- `db_password` - Generated password (sensitive)
- `database_url` - Full connection string (sensitive)

## 🔐 Authentication

This configuration uses **gcloud IAM** for authentication - no service account keys needed!

Make sure you're authenticated:
```bash
gcloud auth application-default login
gcloud config set project clestiq-shield
```

## 💰 Cost Estimate

**Monthly (~$140-160)**:
- Cloud SQL: $140/month (db-custom-2-7680, regional HA)
- VPC/Networking: Free (no NAT/Load Balancer)

## 🏗️ Files

- `provider.tf` - GCP and Random providers
- `variables.tf` - Input variables
- `networking.tf` - VPC and subnet configuration
- `cloudsql.tf` - Cloud SQL PostgreSQL instance
- `main.tf` - API enablement
- `outputs.tf` - Output values
- `backend.tf` - State configuration (optional)

## 🔄 Idempotent

Safe to run multiple times:
```bash
terraform apply  # First time
terraform apply  # Safe to run again
```

## 🧹 Cleanup

```bash
terraform destroy
```

> ⚠️ **Warning**: This will delete the database and all data!

## 📝 Notes

- **Private IP Only**: Database is only accessible within VPC
- **Random Password**: 32-character password generated automatically
- **High Availability**: Regional configuration with automatic failover
- **Backups**: Daily automated backups at 2:00 AM
- **SSL**: Disabled for private network connections

## 🔗 Next Steps

1. Create a Compute Engine VM in the same VPC to access the database
2. Or use Cloud SQL Proxy from your local machine:
   ```bash
   cloud_sql_proxy -instances=<CONNECTION_NAME>=tcp:5432
   ```
3. Connect with psql or your application

## 📚 Documentation

- [Cloud SQL for PostgreSQL](https://cloud.google.com/sql/docs/postgres)
- [VPC Peering](https://cloud.google.com/vpc/docs/vpc-peering)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)