# Comprehensive Mobile Access Setup for Nextcloud
param(
    [string]$WSLAddress = "172.26.58.22"
)

Write-Host "🚀 Setting up Nextcloud mobile access..." -ForegroundColor Blue
Write-Host ""

# Function to get the main network IP
function Get-MainNetworkIP {
    Write-Host "🔍 Detecting network interfaces..." -ForegroundColor Yellow
    
    $adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -notmatch "^127\." -and 
        $_.IPAddress -notmatch "^169\.254\." -and
        $_.IPAddress -notmatch "^172\.1[6-9]\." -and
        $_.IPAddress -notmatch "^172\.2[0-9]\." -and
        $_.IPAddress -notmatch "^172\.3[0-1]\." -and
        $_.InterfaceAlias -notmatch "WSL" -and
        $_.InterfaceAlias -notmatch "Loopback" -and
        $_.InterfaceAlias -notmatch "vEthernet.*WSL"
    } | Sort-Object InterfaceIndex

    Write-Host "Available network interfaces:" -ForegroundColor Cyan
    $adapters | ForEach-Object {
        Write-Host "  $($_.InterfaceAlias): $($_.IPAddress)" -ForegroundColor White
    }
    Write-Host ""

    # Prefer WiFi or Ethernet adapters
    $mainAdapter = $adapters | Where-Object { 
        $_.InterfaceAlias -match "Wi-Fi|Ethernet|Wireless" 
    } | Select-Object -First 1

    if (-not $mainAdapter) {
        $mainAdapter = $adapters | Select-Object -First 1
    }

    return $mainAdapter
}

# Detect network configuration
$mainAdapter = Get-MainNetworkIP
if ($mainAdapter) {
    $networkIP = $mainAdapter.IPAddress
    Write-Host "✅ Selected network IP: $networkIP (Interface: $($mainAdapter.InterfaceAlias))" -ForegroundColor Green
} else {
    Write-Host "❌ Could not detect network IP, using localhost" -ForegroundColor Red
    $networkIP = "127.0.0.1"
}

Write-Host ""

# Clean up existing port forwarding
Write-Host "🧹 Cleaning up existing port forwarding..." -ForegroundColor Yellow
try {
    $existing = netsh interface portproxy show v4tov4 | Select-String "8090"
    if ($existing) {
        netsh interface portproxy delete v4tov4 listenport=8090 listenaddress=0.0.0.0 2>$null
        netsh interface portproxy delete v4tov4 listenport=8090 listenaddress=127.0.0.1 2>$null
        netsh interface portproxy delete v4tov4 listenport=8090 2>$null
        Write-Host "  Removed existing rules" -ForegroundColor White
    }
} catch {}

# Add new port forwarding rules
Write-Host "🔗 Setting up port forwarding..." -ForegroundColor Yellow
Write-Host "  Adding rule: 0.0.0.0:8090 -> $WSLAddress:8090" -ForegroundColor White
netsh interface portproxy add v4tov4 listenport=8090 listenaddress=0.0.0.0 connectport=8090 connectaddress=$WSLAddress

# Configure Windows Firewall
Write-Host "🛡️  Configuring Windows Firewall..." -ForegroundColor Yellow
try {
    # Remove existing rules
    Remove-NetFirewallRule -DisplayName "Nextcloud WSL2*" -ErrorAction SilentlyContinue
    
    # Add new rule for all profiles and interfaces
    New-NetFirewallRule -DisplayName "Nextcloud WSL2 Mobile Access" -Direction Inbound -Protocol TCP -LocalPort 8090 -Action Allow -Profile Any -Enabled True
    Write-Host "✅ Firewall rule configured for all network profiles" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not configure firewall: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   You may need to manually allow port 8090 in Windows Firewall" -ForegroundColor Yellow
}

# Show current configuration
Write-Host ""
Write-Host "📋 Current port forwarding rules:" -ForegroundColor Cyan
netsh interface portproxy show v4tov4

# Test local connectivity
Write-Host ""
Write-Host "🧪 Testing connectivity..." -ForegroundColor Blue
$testResults = @()

# Test localhost
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8090" -Method Head -TimeoutSec 10 -ErrorAction Stop
    $testResults += "✅ localhost:8090 - Working (Status: $($response.StatusCode))"
} catch {
    $testResults += "❌ localhost:8090 - Failed: $($_.Exception.Message)"
}

# Test network IP
try {
    $response = Invoke-WebRequest -Uri "http://${networkIP}:8090" -Method Head -TimeoutSec 10 -ErrorAction Stop
    $testResults += "✅ ${networkIP}:8090 - Working (Status: $($response.StatusCode))"
} catch {
    $testResults += "❌ ${networkIP}:8090 - Failed: $($_.Exception.Message)"
}

$testResults | ForEach-Object {
    if ($_ -match "✅") {
        Write-Host $_ -ForegroundColor Green
    } else {
        Write-Host $_ -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🎯 Mobile Access Information:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Use this URL on your mobile device:" -ForegroundColor Yellow
Write-Host "  http://${networkIP}:8090" -ForegroundColor White
Write-Host ""
Write-Host "Network Requirements:" -ForegroundColor Yellow
Write-Host "  ✓ Mobile device must be on the same WiFi network" -ForegroundColor White
Write-Host "  ✓ Windows Firewall configured (done above)" -ForegroundColor White
Write-Host "  ✓ Port forwarding configured (done above)" -ForegroundColor White
Write-Host ""

if ($networkIP -match "^192\.168\.|^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.") {
    Write-Host "✅ Network IP looks good for local network access!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Network IP might not be accessible from mobile devices" -ForegroundColor Yellow
    Write-Host "   Try checking other network adapters or router settings" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🔍 Troubleshooting:" -ForegroundColor Yellow
Write-Host "  If mobile access fails:" -ForegroundColor White
Write-Host "  1. Ping Windows PC from mobile: ping $networkIP" -ForegroundColor White
Write-Host "  2. Check router settings for 'AP Isolation' or 'Client Isolation'" -ForegroundColor White
Write-Host "  3. Try temporarily disabling Windows Firewall" -ForegroundColor White
Write-Host "  4. Ensure both devices are on the same WiFi network" -ForegroundColor White

Write-Host ""
Write-Host "🎉 Setup complete!" -ForegroundColor Green
