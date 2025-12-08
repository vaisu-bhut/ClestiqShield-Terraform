#!/bin/bash
# Deployment script for VPC and Cloud SQL

set -e

echo "🚀 Clestiq Shield - VPC + Cloud SQL Deployment"
echo "=============================================="

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v gcloud >/dev/null 2>&1 || { echo "❌ gcloud CLI not found. Install Google Cloud SDK."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ terraform not found. Install Terraform."; exit 1; }

echo "✅ All prerequisites found"

# Configure GCP
echo "🔧 Configuring GCP..."
export PROJECT_ID="clestiq-shield"
gcloud config set project $PROJECT_ID
echo "✅ GCP project set to $PROJECT_ID"

# Change to terraform directory (from scripts/ to terraform/)
echo "📂 Changing to terraform directory..."
cd ./terraform

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📝 Planning Terraform deployment..."
terraform plan -out=tfplan

# Prompt for confirmation
echo ""
read -p "🚀 Ready to deploy VPC and Cloud SQL? Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Deployment cancelled"
    cd ..
    exit 0
fi

# Apply Terraform
echo "🚀 Applying Terraform configuration..."
terraform apply tfplan

echo ""
echo "✅ Infrastructure deployment complete!"
echo ""
echo "📊 Deployment Summary:"
echo "====================="
terraform output

echo ""
echo "📝 Next Steps:"
echo "1. Get database password:"
echo "   cd terraform && terraform output -raw db_password"
echo ""
echo "2. Get connection URL:"
echo "   terraform output -raw database_url"
echo ""
echo "3. Connect from a VM in the same VPC:"
echo "   psql -h <PRIVATE_IP> -U clestiq_user -d clestiq_shield"
echo ""

# Return to project root directory
cd ..

echo "🎉 Deployment script finished!"
