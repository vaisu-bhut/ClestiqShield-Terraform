# PowerShell deployment script for VPC and Cloud SQL

$ErrorActionPreference = "Stop"

Write-Host "Clestiq Shield - VPC + Cloud SQL Deployment" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "[*] Checking prerequisites..." -ForegroundColor Yellow

$commands = @("gcloud", "terraform")
foreach ($cmd in $commands) {
    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "[ERROR] $cmd not found. Please install it first." -ForegroundColor Red
        exit 1
    }
}

Write-Host "[OK] All prerequisites found" -ForegroundColor Green

# Configure GCP
Write-Host "[*] Configuring GCP..." -ForegroundColor Yellow
$env:PROJECT_ID = "clestiq-shield"
gcloud config set project $env:PROJECT_ID
Write-Host "[OK] GCP project set to $env:PROJECT_ID" -ForegroundColor Green

# Change to terraform directory (from scripts/ to terraform/)
Write-Host "[*] Changing to terraform directory..." -ForegroundColor Yellow
Set-Location .\terraform

# Initialize Terraform
Write-Host "[*] Initializing Terraform..." -ForegroundColor Yellow
terraform init

# Validate configuration
Write-Host "[*] Validating Terraform configuration..." -ForegroundColor Yellow
terraform validate

# Plan deployment
Write-Host "[*] Planning Terraform deployment..." -ForegroundColor Yellow
terraform plan -out=tfplan

# Prompt for confirmation
Write-Host ""
$confirm = Read-Host "[PROMPT] Ready to deploy VPC and Cloud SQL? Continue? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "[CANCELLED] Deployment cancelled" -ForegroundColor Red
    Set-Location ..
    exit 0
}

# Apply Terraform
Write-Host "[*] Applying Terraform configuration..." -ForegroundColor Yellow
terraform apply tfplan

Write-Host ""
Write-Host "[SUCCESS] Infrastructure deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Deployment Summary:" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
Write-Host "Database password:"
terraform output -raw db_password
Write-Host ""
Write-Host "Database url:"
terraform output -raw database_url
Write-Host ""

# Return to project root directory
Set-Location ..

Write-Host "[DONE] Deployment script finished!" -ForegroundColor Green
