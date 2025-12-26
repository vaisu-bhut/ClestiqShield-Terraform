param (
    [Parameter(Mandatory=$true)]
    [string]$Prefix
)

$ErrorActionPreference = "Stop"
# All traffic goes through Gateway
$GatewayUrl = "http://api.shield.clestiq.com"

Write-Host "Starting load generation with prefix: $Prefix" -ForegroundColor Cyan

$ApiKeys = @()

# 1. Create 3 Users
for ($i = 1; $i -le 3; $i++) {
    $Email = "${Prefix}_user_${i}@example.com"
    $Password = "strongpassword123"
    
    Write-Host "`n[$i/3] Processing User: $Email" -ForegroundColor Yellow
    
    # Signup
    try {
        $Body = @{
            email = $Email
            password = $Password
            full_name = "Test User $i"
            is_active = $true
        } | ConvertTo-Json
        
        $null = Invoke-RestMethod -Uri "$GatewayUrl/api/v1/auth/register" -Method Post -Body $Body -ContentType "application/json"
        Write-Host "  [OK] Created user" -ForegroundColor Green
    }
    catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
        if ($StatusCode -eq 400) {
            Write-Host "  [INFO] User already exists, proceeding to login" -ForegroundColor DarkYellow
        } else {
            Write-Host "  [ERROR] Failed to create user: $($_.Exception.Message)" -ForegroundColor Red
            continue
        }
    }

    # Login
    $AccessToken = $null
    try {
        $Body = @{
            username = $Email
            password = $Password
        }
        # Form data for OAuth2
        $LoginResp = Invoke-RestMethod -Uri "$GatewayUrl/api/v1/auth/login" -Method Post -Body $Body -ContentType "application/x-www-form-urlencoded"
        $AccessToken = $LoginResp.access_token
        Write-Host "  [OK] Logged in" -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Failed to login: $($_.Exception.Message)" -ForegroundColor Red
        continue
    }

    # 2. Create 1-2 Apps per User
    $NumApps = Get-Random -Minimum 1 -Maximum 3 # 1 or 2
    $AuthHeaders = @{ Authorization = "Bearer $AccessToken" }
    
    for ($j = 1; $j -le $NumApps; $j++) {
        $AppName = "${Prefix}_app_${i}_${j}"
        try {
            $Body = @{
                name = $AppName
                description = "Load test app $j"
            } | ConvertTo-Json
            
            $AppResp = Invoke-RestMethod -Uri "$GatewayUrl/api/v1/apps/" -Method Post -Body $Body -Headers $AuthHeaders -ContentType "application/json"
            $AppId = $AppResp.id
            Write-Host "  [OK] Created App: $AppName" -ForegroundColor Cyan
            
            # 3. Create API Keys (Create key for the first app)
            if ($j -eq 1) {
                $KeyName = "${Prefix}_key_${i}"
                $Body = @{ name = $KeyName } | ConvertTo-Json
                $KeyResp = Invoke-RestMethod -Uri "$GatewayUrl/api/v1/apps/$AppId/keys" -Method Post -Body $Body -Headers $AuthHeaders -ContentType "application/json"
                $RawKey = $KeyResp.api_key
                Write-Host "  [OK] Created API Key: $KeyName" -ForegroundColor Green
                $ApiKeys += $RawKey
            }
        }
        catch {
             $StatusCode = $_.Exception.Response.StatusCode.value__
             if ($StatusCode -eq 400) {
                Write-Host "  [INFO] App already exists, skipping" -ForegroundColor DarkYellow
             } else {
                Write-Host "  [ERROR] Failed to create app/key: $($_.Exception.Message)" -ForegroundColor Red
             }
        }
    }
}

# 4. Generate Traffic
Write-Host "`nSending chat traffic with $($ApiKeys.Count) keys..." -ForegroundColor Cyan

$Models = @("gemini-3-flash-preview", "gemini-3-pro-preview")
$Queries = @("Hello world", "What is the weather?", "Write a python script", "Explain quantum physics")

foreach ($Key in $ApiKeys) {
    if (-not $Key) { continue }
    $NumRequests = Get-Random -Minimum 1 -Maximum 2
    $FullHeaders = @{ "X-API-Key" = $Key }
    
    for ($r = 1; $r -le $NumRequests; $r++) {
        $Query = $Queries | Get-Random
        $Model = $Models | Get-Random
        
        $Payload = @{
            query = $Query
            model = $Model
            moderation = "moderate"
            output_format = "json"
        } | ConvertTo-Json
        
        try {
            $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            $ChatResp = Invoke-RestMethod -Uri "$GatewayUrl/chat/" -Method Post -Body $Payload -Headers $FullHeaders -ContentType "application/json"
            $StopWatch.Stop()
            $Latency = $StopWatch.ElapsedMilliseconds
            
            Write-Host "  [OK] Req $r : Status 200 (${Latency}ms)" -ForegroundColor Gray
        }
        catch {
            Write-Host "  [ERROR] Request failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 200
    }
}

Write-Host "`nLoad generation complete!" -ForegroundColor Green
