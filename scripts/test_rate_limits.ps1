# Test-RateLimits.ps1
# Verifies Rate Limiting for Tokens, App Creation, Key Creation, and Penalties.

$GatewayUrl = "http://api.shield.clestiq.com"
$Username = "ratetestuser_$(Get-Random)"
$Password = "TestPass123!"

function Invoke-RestMethodWithMetrics {
    param(
        [string]$Uri,
        [string]$Method,
        [hashtable]$Headers,
        [object]$Body,
        [bool]$SkipError = $true
    )
    try {
        if ($Body) {
            $jsonBody = $Body | ConvertTo-Json -Depth 10
            return Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers -Body $jsonBody -ContentType "application/json" -ErrorAction Stop
        } else {
            return Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers -ContentType "application/json" -ErrorAction Stop
        }
    } catch {
        if ($SkipError) {
             if ($_.Exception.Response) {
                # Attempt to read the error stream
                $stream = $_.Exception.Response.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $errorBody = $reader.ReadToEnd()
                    try {
                        # Add a fake property to mimic Invoke-RestMethod object so downstream checks pass
                        $errObj = $errorBody | ConvertFrom-Json
                        # We need to attach StatusCode somehow or just return the raw PSCustomObject
                        # But our checks look for .StatusCode or .status_code property validation wrapper
                        # Let's return a custom object
                        return [PSCustomObject]@{
                            StatusCode = [int]$_.Exception.Response.StatusCode
                            status_code = [int]$_.Exception.Response.StatusCode # For compatibility
                            Body = $errObj
                            Raw = $errorBody
                            IsError = $true
                        }
                    } catch {
                         return [PSCustomObject]@{
                            StatusCode = [int]$_.Exception.Response.StatusCode
                            status_code = [int]$_.Exception.Response.StatusCode
                            Body = $errorBody
                            IsError = $true
                        }
                    }
                }
                return $_.Exception.Response
             } else {
                Write-Host "Error request failed with no response object: $($_.Exception.Message)" -ForegroundColor Red
                return $null
             }
        } else {
            throw $_
        }
    }
}

Write-Host "--- Rate Limit Verification Script ---" -ForegroundColor Cyan

# 1. Setup User & Auth
Write-Host "`n[Setup] Creating User and Logging in..."
$userBody = @{ email = "$Username@example.com"; password = $Password; full_name = "Rate Test User" }
$signup = Invoke-RestMethodWithMetrics -Uri "$GatewayUrl/api/v1/auth/register" -Method Post -Body $userBody -SkipError $false
Write-Host "User created: $($signup.id)"

$loginBody = @{ username = "$Username@example.com"; password = $Password }
# Note: Login expects form-data usually, but let's try JSON or adjust if needed. EagleEye auth often uses OAuth2 form.
# If Gateway proxies /api/v1/auth/login, it might expect form data.
$formBody = "username=$Username@example.com&password=$Password"
try {
    $tokenResponse = Invoke-RestMethod -Uri "$GatewayUrl/api/v1/auth/login" -Method Post -Body $formBody -ContentType "application/x-www-form-urlencoded"
} catch {
    Write-Error "Login failed. Ensure Gateway is running and proxies to EagleEye."
    exit 1
}
$token = $tokenResponse.access_token
$authHeader = @{ "Authorization" = "Bearer $token" }
Write-Host "Got Token."

# 2. App Creation Limit Test (Limit: 2)
Write-Host "`n[Test 1] App Creation Limit (Target: 2)"
for ($i = 1; $i -le 3; $i++) {
    $rand = Get-Random
    $appBody = @{ name = "App_$($i)_$rand"; description = "Test App" }
    $response = Invoke-RestMethodWithMetrics -Uri "$GatewayUrl/api/v1/apps/" -Method Post -Headers $authHeader -Body $appBody
    
    if ($null -eq $response) { continue }
    if ($response.IsError -eq $true -or $response.GetType().Name -eq "HttpResponseMessageWrapper") {
         # Error response
         $code = if ($response.StatusCode) { $response.StatusCode } else { $response.status_code } 
         if ([int]$code -eq 429) {
             Write-Host "[$i] Request blocked as expected (429)." -ForegroundColor Green
         } else {
             Write-Host "[$i] Request failed with unexpected code: $code" -ForegroundColor Red
             Write-Host "DEBUG Info: Type=$($response.GetType().Name)" -ForegroundColor DarkGray
             # Attempt to print body if exists
             try { Write-Host "DEBUG Body: $($response.Body | ConvertTo-Json -Depth 2)" -ForegroundColor DarkGray } catch {}
         }
    } else {
        Write-Host "[$i] App created: $($response.id)" -ForegroundColor Yellow
        if ($i -eq 1) { $global:appId = $response.id; $global:appName = $response.name }
    }
}

# 3. Key Creation Limit Test (Limit: 4)
Write-Host "`n[Test 2] Key Creation Limit (Target: 4)"
if (-not $global:appId) {
    Write-Warning "Skipping Test 2: No App ID available from Test 1."
} else {
    # Use the first app created
    for ($i = 1; $i -le 5; $i++) {
    $keyBody = @{ name = "Key_$i" }
    $response = Invoke-RestMethodWithMetrics -Uri "$GatewayUrl/api/v1/apps/$global:appId/keys" -Method Post -Headers $authHeader -Body $keyBody
    
    if ($null -eq $response) { continue }
    if ($response.IsError -eq $true -or $response.GetType().Name -eq "HttpResponseMessageWrapper") {
         $code = if ($response.StatusCode) { $response.StatusCode } else { $response.status_code }
         if ([int]$code -eq 429) {
             Write-Host "[$i] Request blocked as expected (429)." -ForegroundColor Green
         } else {
             Write-Host "[$i] Request failed with unexpected code: $code" -ForegroundColor Red
         }
    } else {
         Write-Host "[$i] Key created: $($response.key_prefix)..." -ForegroundColor Yellow
         if ($i -eq 1) { $global:apiKey = $response.api_key; $global:keyId = $response.id }
    }
}
}

# 4. Token Limit & Penalty Test
Write-Host "`n[Test 3] Token Usage & Penalty (Limit: 5k/5min, 2 Strikes)"
if (-not $global:apiKey) {
    Write-Warning "Skipping Test 3: No API Key available from Test 2."
} else {
$headers = @{ "X-API-Key" = $global:apiKey; "Content-Type" = "application/json" }
$chatBody = @{
    query = "Write a 500 word story about a space adventure to Mars." 
    model = "gemini-3-flash-preview"
    moderation = "moderate"
    max_output_tokens = 1000
}

# We need to loop until we hit 10k tokens.
# Assuming each request uses ~100 tokens. 100 requests.
$simulatedTokens = 0
$limit = 5000
$count = 0

while ($simulatedTokens -lt $limit + 2000) { # Go a bit over
    $count++
    $response = Invoke-RestMethodWithMetrics -Uri "$GatewayUrl/chat/" -Method Post -Headers $headers -Body $chatBody
    
    if ($null -eq $response) { continue }
    if ($response.IsError -eq $true -or $response.GetType().Name -eq "HttpResponseMessageWrapper") {
         $code = if ($response.StatusCode) { $response.StatusCode } else { $response.status_code }
         
         if ([int]$code -eq 429) {
             Write-Host "[$count] Rate Limit Hit (429)!" -ForegroundColor Green
             # Checking penalty
             # To trigger penalty (disable key), we need to hit 429 TWICE.
             # We just hit it once. We should wait a second and hit it again.
             Start-Sleep -Seconds 1
             Write-Host "Attempting to trigger 2nd strike..."
             $response2 = Invoke-RestMethodWithMetrics -Uri "$GatewayUrl/chat/" -Method Post -Headers $headers -Body $chatBody
             $code2 = if ($response2.StatusCode) { $response2.StatusCode } else { $response2.status_code }
             
             if ([int]$code2 -eq 429) {
                 Write-Host "2nd Strike recorded." -ForegroundColor Green
             }
             
             # Now, 3rd attempt should be 403 Forbidden (Key Disabled)
             Write-Host "Verifying Key Disabling..."
             $response3 = Invoke-RestMethodWithMetrics -Uri "$GatewayUrl/chat/" -Method Post -Headers $headers -Body $chatBody
             $code3 = if ($response3.StatusCode) { $response3.StatusCode } else { $response3.status_code }
             
             if ([int]$code3 -eq 403) {
                 Write-Host "SUCCESS: Key has been disabled (403: Blocked by app)." -ForegroundColor Green
                 
                 # Try to print the message
                 if ($response3.detail) {
                    Write-Host "Message: $($response3.detail)" -ForegroundColor Cyan
                 } elseif ($response3.message) {
                    Write-Host "Message: $($response3.message)" -ForegroundColor Cyan
                 } else {
                    # Fallback for raw stream reading if needed, but Invoke-RestMethod parsed it
                    Write-Host "Response Body: $($response3 | ConvertTo-Json -Depth 1 -Compress)" -ForegroundColor Cyan
                 }
                 break
             } else {
                 Write-Host "FAILURE: Key was not disabled. Code: $code3" -ForegroundColor Red
                 break
             }
         } else {
             Write-Host "[$count] Failed: $code" -ForegroundColor Red
             Write-Host "DEBUG Info: Type=$($response.GetType().Name)" -ForegroundColor DarkGray
             try { Write-Host "DEBUG Body: $($response.Body | ConvertTo-Json -Depth 2)" -ForegroundColor DarkGray } catch {}
             break
         }
    } else {
        # Valid response
        $usage = $response.metrics.token_usage.total_tokens
        $simulatedTokens += $usage
        Write-Host "[$count] OK. Used $usage tokens. Total: $simulatedTokens / $limit" -NoNewline
        if ($count % 5 -eq 0) { Write-Host "" } else { Write-Host " | " -NoNewline }
    }
}
}

Write-Host "`nTest Complete."
