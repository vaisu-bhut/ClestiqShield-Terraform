# PowerShell deployment script for Kubernetes (GKE)
# Deploys application to GKE cluster after Terraform creates infrastructure

$ErrorActionPreference = "Stop"

# Configuration - matches Terraform outputs
$ProjectId = "clestiq-shield"
$Zone = "us-east1-b"  # Zonal cluster
$ClusterName = "clestiq-shield-main-gke"

Write-Host "Clestiq Shield - GKE Application Deployment" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
if (!(Get-Command "kubectl" -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] kubectl not found. Please install it first." -ForegroundColor Red
    exit 1
}

if (!(Get-Command "gcloud" -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] gcloud not found. Please install Google Cloud SDK." -ForegroundColor Red
    exit 1
}

# 1. Authenticate to cluster
Write-Host "[1/5] Getting cluster credentials..." -ForegroundColor Yellow
try {
    gcloud container clusters get-credentials $ClusterName --zone $Zone --project $ProjectId
    Write-Host "[OK] Connected to cluster: $ClusterName" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to get credentials. Is Terraform applied?" -ForegroundColor Red
    Write-Host "Run: terraform output gke_connect_command" -ForegroundColor Yellow
    exit 1
}

# 2. Check/Create required secrets
Write-Host "[2/5] Checking required secrets..." -ForegroundColor Yellow

# Database Secret
$dbSecretExists = kubectl get secret db-secrets -n default --ignore-not-found 2>$null
if (!$dbSecretExists) {
    Write-Host "[WARN] Secret 'db-secrets' not found. Creating from Terraform output..." -ForegroundColor Yellow
    $terraformDir = Join-Path $PSScriptRoot "..\terraform"
    Push-Location $terraformDir
    $dbUrl = terraform output -raw database_url 2>$null
    Pop-Location
    
    if ($dbUrl) {
        kubectl create secret generic db-secrets --from-literal=database-url="$dbUrl"
        Write-Host "[OK] Created db-secrets from Terraform output" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Could not get database_url from Terraform. Create manually:" -ForegroundColor Red
        Write-Host "kubectl create secret generic db-secrets --from-literal=database-url=<YOUR_URL>" -ForegroundColor Yellow
        exit 1
    }
}

# Datadog Secret
$ddSecretJson = kubectl get secret datadog-secrets -n default -o json --ignore-not-found
if ($ddSecretJson) {
    $ddSecret = $ddSecretJson | ConvertFrom-Json
    $hasToken = $ddSecret.data.'cluster-agent-token'
    $hasAppKey = $ddSecret.data.'app-key'
    
    if (!$hasToken -or !$hasAppKey) {
        Write-Host "[WARN] datadog-secrets exists but missing keys (token or app-key). Updating..." -ForegroundColor Yellow
        $regen = $true
    } else {
        $regen = $false
        Write-Host "[OK] datadog-secrets exists and is valid" -ForegroundColor Green
    }
} else {
    $regen = $true
}

if ($regen) {
    Write-Host "[INFO] Configuring datadog-secrets..." -ForegroundColor Yellow
    $terraformDir = Join-Path $PSScriptRoot "..\terraform"
    Push-Location $terraformDir
    $ddApiKey = terraform output -raw datadog_api_key 2>$null
    $ddAppKey = terraform output -raw datadog_app_key 2>$null
    $ddSite = terraform output -raw datadog_site 2>$null
    Pop-Location
    
    if ($ddApiKey -and $ddSite) {
        # Create or Update secret
        # We use --dry-run=client -o yaml | kubectl apply -f - to support updating existing secret
        $secretCmd = "kubectl create secret generic datadog-secrets -n default --from-literal=api-key='$ddApiKey' --from-literal=site='$ddSite' --dry-run=client -o yaml | kubectl apply -f -"
        Invoke-Expression $secretCmd
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Configured datadog-secrets" -ForegroundColor Green
        } else {
             Write-Host "[ERROR] Failed to configure datadog-secrets" -ForegroundColor Red
             exit 1
        }
    } else {
        Write-Host "[ERROR] Could not get datadog credentials from Terraform. Please check outputs." -ForegroundColor Red
        exit 1
    }
}

# Eagle Eye Secret
$eeSecretExists = kubectl get secret eagle-eye-secrets -n default --ignore-not-found 2>$null
if (!$eeSecretExists) {
    Write-Host "[WARN] Secret 'eagle-eye-secrets' not found. Creating from Terraform output..." -ForegroundColor Yellow
    $terraformDir = Join-Path $PSScriptRoot "..\terraform"
    Push-Location $terraformDir
    $eeSecretKey = terraform output -raw eagle_eye_secret_key 2>$null
    Pop-Location
    
    if ($eeSecretKey) {
        kubectl create secret generic eagle-eye-secrets --from-literal=secret-key="$eeSecretKey"
        Write-Host "[OK] Created eagle-eye-secrets from Terraform output" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Could not get eagle_eye_secret_key from Terraform. Create manually:" -ForegroundColor Red
        Write-Host "kubectl create secret generic eagle-eye-secrets --from-literal=secret-key=<YOUR_SECRET_KEY>" -ForegroundColor Yellow
        exit 1
    }
}

# Gemini Secret
$geminiSecretExists = kubectl get secret gemini-secrets -n default --ignore-not-found 2>$null
if (!$geminiSecretExists) {
    Write-Host "[WARN] Secret 'gemini-secrets' not found. Creating from Terraform output..." -ForegroundColor Yellow
    $terraformDir = Join-Path $PSScriptRoot "..\terraform"
    Push-Location $terraformDir
    $gemini_key = terraform output -raw gemini_api_key 2>$null
    Pop-Location
    
    if ($gemini_key) {
        kubectl create secret generic gemini-secrets --from-literal=api-key="$gemini_key"
        Write-Host "[OK] Created gemini-secrets from Terraform output." -ForegroundColor Green
    } else {
        Write-Host "[WARN] Gemini API Key not found in Terraform output." -ForegroundColor Yellow
        Write-Host "[INFO] Please create manually using: kubectl create secret generic gemini-secrets --from-literal=api-key=YOUR_KEY" -ForegroundColor Cyan
    }
} else {
    Write-Host "[OK] gemini-secrets exists" -ForegroundColor Green
}

Write-Host "[OK] All required secrets exist" -ForegroundColor Green

# 3. Deploy manifests
Write-Host "[3/5] Applying Kubernetes manifests..." -ForegroundColor Yellow
$ManifestDir = Join-Path $PSScriptRoot "..\k8s"

if (Test-Path $ManifestDir) {
    kubectl apply -f $ManifestDir
    Write-Host "[OK] Manifests applied successfully" -ForegroundColor Green
}
else {
    Write-Host "[ERROR] Manifest directory not found at $ManifestDir" -ForegroundColor Red
    exit 1
}

# 3.5 Patch Gateway Service with Static IP
Write-Host "[3.5/5] Configuring Gateway Static IP..." -ForegroundColor Yellow
$terraformDir = Join-Path $PSScriptRoot "..\terraform"
Push-Location $terraformDir
    Try {
        $staticIp = terraform output -raw gateway_static_ip 2>$null
    } Catch {
        $staticIp = $null
    }
Pop-Location

if ($staticIp) {
    Write-Host "  Found Static IP: $staticIp" -ForegroundColor Gray
    # Patch the service to use the loadBalancerIP
    # We use --type=merge to ensure we only update the specific field
    kubectl patch svc gateway -p "{\`"spec\`": {\`"loadBalancerIP\`": \`"$staticIp\`"}}"
    Write-Host "  [OK] Patched Gateway service with Static IP" -ForegroundColor Green
} else {
    Write-Host "  [WARN] No static IP found in Terraform output. Using ephemeral IP." -ForegroundColor Yellow
}

# 4. Wait for deployments
Write-Host "[4/5] Waiting for deployments to be ready..." -ForegroundColor Yellow
Write-Host "(This may take 2-3 minutes for first-time deployment)" -ForegroundColor Gray

$deployments = @("gateway", "sentinel", "guardian", "eagle-eye")
foreach ($dep in $deployments) {
    Write-Host "  Waiting for $dep..." -ForegroundColor Gray
    kubectl rollout status deployment/$dep --timeout=180s 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $dep is ready" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] $dep rollout may still be in progress" -ForegroundColor Yellow
    }
}

# 5. Show status
Write-Host "[5/5] Deployment Status:" -ForegroundColor Yellow
Write-Host ""
kubectl get pods -o wide
Write-Host ""
kubectl get services
Write-Host ""

# Get LoadBalancer IP
$lbIP = kubectl get svc gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
if ($lbIP) {
    Write-Host "[DONE] Application deployed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Gateway URL: http://$lbIP" -ForegroundColor Cyan
    Write-Host "DNS: http://api.shield.clestiq.com" -ForegroundColor Cyan
    Write-Host "Health Check: curl http://$lbIP/health" -ForegroundColor Cyan
} else {
    Write-Host "[INFO] LoadBalancer IP not ready yet. Run this to check:" -ForegroundColor Yellow
    Write-Host "kubectl get svc gateway -w" -ForegroundColor Gray
}
