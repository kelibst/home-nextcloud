# Enhanced Windows port forwarding setup for Nextcloud
Write-Host "Setting up port forwarding for Nextcloud..." -ForegroundColor Blue

# Function to get the main network IP (not WSL gateway)
function Get-MainNetworkIP {
    # Get all network adapters with IP addresses
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

    # Prefer WiFi or Ethernet adapters
    $mainAdapter = $adapters | Where-Object { 
        $_.InterfaceAlias -match "Wi-Fi|Ethernet|Wireless" 
    } | Select-Object -First 1

    if (-not $mainAdapter) {
        $mainAdapter = $adapters | Select-Object -First 1
    }

    return $mainAdapter
}

# Get WSL IP
$wslIP = "172.26.58.22"  # This should be passed from WSL script

# Get main network IP
$mainAdapter = Get-MainNetworkIP
if ($mainAdapter) {
    $networkIP = $mainAdapter.IPAddress
    Write-Host "Found main network IP: $networkIP (Interface: $($mainAdapter.InterfaceAlias))" -ForegroundColor Yellow
} else {
    Write-Host "Could not detect main network IP, using localhost" -ForegroundColor Red
    $networkIP = "127.0.0.1"
}

Write-Host ""
Write-Host "Network Configuration:" -ForegroundColor Cyan
Write-Host "  WSL IP: $wslIP" -ForegroundColor White
Write-Host "  Windows Network IP: $networkIP" -ForegroundColor White
Write-Host ""

# Remove existing port forwarding rules for port 8090
Write-Host "Removing any existing port forwarding rules..." -ForegroundColor Yellow
try {
    netsh interface portproxy delete v4tov4 listenport=8090 2>$null
} catch {}

# Add new port forwarding rules
Write-Host "Adding port forwarding rules..." -ForegroundColor Yellow

# Forward from localhost to WSL
Write-Host "  localhost:8090 -> WSL:8090" -ForegroundColor White
netsh interface portproxy add v4tov4 listenport=8090 listenaddress=127.0.0.1 connectport=8090 connectaddress=$wslIP

# Forward from all interfaces to WSL (for mobile access)
Write-Host "  0.0.0.0:8090 -> WSL:8090" -ForegroundColor White
netsh interface portproxy add v4tov4 listenport=8090 listenaddress=0.0.0.0 connectport=8090 connectaddress=$wslIP

# Add Windows Firewall rules
Write-Host "Configuring Windows Firewall..." -ForegroundColor Yellow
try {
    # Remove existing rule if it exists
    Remove-NetFirewallRule -DisplayName "Nextcloud WSL2" -ErrorAction SilentlyContinue
    
    # Add new rule for all interfaces
    New-NetFirewallRule -DisplayName "Nextcloud WSL2" -Direction Inbound -Protocol TCP -LocalPort 8090 -Action Allow -Profile Any
    Write-Host "✅ Firewall rule added for all network profiles" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not configure firewall rule: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Show current port forwarding
Write-Host ""
Write-Host "Current port forwarding rules:" -ForegroundColor Green
netsh interface portproxy show v4tov4

# Test connectivity
Write-Host ""
Write-Host "Testing connectivity..." -ForegroundColor Blue
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8090" -Method Head -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✅ Localhost test: Working (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "❌ Localhost test: Failed - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "✅ Windows networking setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Access URLs:" -ForegroundColor Cyan
Write-Host "  Local: http://localhost:8090" -ForegroundColor White
Write-Host "  Network: http://$networkIP:8090" -ForegroundColor White
Write-Host ""
Write-Host "For mobile devices, use: http://$networkIP:8090" -ForegroundColor Yellow
Write-Host ""
Write-Host "If mobile access still fails:" -ForegroundColor Yellow
Write-Host "  1. Ensure your mobile device is on the same WiFi network" -ForegroundColor White
Write-Host "  2. Try disabling Windows Defender Firewall temporarily" -ForegroundColor White
Write-Host "  3. Check router settings for client isolation" -ForegroundColor White