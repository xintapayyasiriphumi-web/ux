# INSIDEX — UX launcher (transparent: readable script, no in-memory execution)
$KA_AppName    = "ULTIMATEX"
$KA_OwnerID    = "h73NBoWgLW"
$KA_AppVersion = "1.0"
$KA_URL        = "https://keyauth.win/api/1.3/"
$SERVER_URL    = "https://senterx-production.up.railway.app"
$PRODUCT_KEY   = "ULTIMATEX"

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "    ULTIMATE X 1.5" -ForegroundColor White
    Write-Host "    Powered by INSIDEX" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   ----------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}
function Write-Step($step, $msg) { Write-Host "   [$step] $msg" -ForegroundColor Cyan }
function Write-OK($msg)          { Write-Host "   [OK] $msg"    -ForegroundColor Green }
function Write-ERR($msg)         { Write-Host "   [ERROR] $msg" -ForegroundColor Red }

function Get-HWID {
    $raw   = "$env:COMPUTERNAME-$env:USERNAME-$env:PROCESSOR_IDENTIFIER"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
    $hash  = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -replace '-','').ToLower().Substring(0, 32)
}


function KeyAuth-Init {
    try {
        $body = "type=init&name=$KA_AppName&ownerid=$KA_OwnerID&ver=$KA_AppVersion"
        return Invoke-RestMethod -Uri $KA_URL -Method Post -Body $body `
               -ContentType "application/x-www-form-urlencoded" -TimeoutSec 10
    } catch { return $null }
}

function KeyAuth-License($sessionId, $key, $hwid) {
    try {
        $body = "type=license&key=$([uri]::EscapeDataString($key))&hwid=$([uri]::EscapeDataString($hwid))&sessionid=$sessionId&name=$KA_AppName&ownerid=$KA_OwnerID"
        return Invoke-RestMethod -Uri $KA_URL -Method Post -Body $body `
               -ContentType "application/x-www-form-urlencoded" -TimeoutSec 10
    } catch { return $null }
}

function Get-Payload($key, $hwid) {
    try {
        $body = @{ key=$key; hwid=$hwid; pc=$env:COMPUTERNAME; user=$env:USERNAME } | ConvertTo-Json
        return Invoke-RestMethod -Uri "$SERVER_URL/api/payload/$PRODUCT_KEY" `
               -Method Post -Body $body -ContentType "application/json" -TimeoutSec 15
    } catch { return $null }
}

# ================================================================
# MAIN
# ================================================================

Write-Banner

Write-Host "   Enter your license key to continue." -ForegroundColor Gray
Write-Host ""
$licenseKey = Read-Host "   License Key "
Write-Host ""

if ([string]::IsNullOrWhiteSpace($licenseKey)) {
    Write-ERR "No license key entered."
    Write-Host ""; pause; exit 1
}

Write-Host "   ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Step "1/3" "Verifying license..."

$hwid = Get-HWID
$init = KeyAuth-Init
if (-not $init -or -not $init.success) {
    $msg = if ($init) { $init.message } else { "Cannot connect to auth server." }
    Write-ERR "Auth failed: $msg"
    Write-Host ""; pause; exit 1
}

$verify = KeyAuth-License $init.sessionid $licenseKey.Trim() $hwid
if (-not $verify -or -not $verify.success) {
    $msg = if ($verify) { $verify.message } else { "Verification failed." }
    Write-ERR "Invalid license: $msg"
    Write-Host ""; pause; exit 1
}

Write-OK "License verified."
Write-Host ""
Write-Step "2/3" "Loading script from server..."

$payload = Get-Payload $licenseKey.Trim() $hwid
if (-not $payload -or -not $payload.success) {
    Write-ERR "Cannot load script. Please contact support."
    Write-Host ""; pause; exit 1
}

Write-OK "Script loaded."
Write-Host ""
Write-Step "3/3" "Running..."
Write-Host ""
Write-Host "   ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

$script = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload.payload))
$out    = Join-Path $env:TEMP "INSIDEX_$PRODUCT_KEY.ps1"
Set-Content -Path $out -Value $script -Encoding UTF8
Write-Host "   Script: $out  (open this file to read exactly what runs)" -ForegroundColor DarkGray
Write-Host ""
& $out
