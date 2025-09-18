#!/bin/bash
# Automatic Mobile Setup Script - Detects real Windows network IP

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🚀 Automatic Mobile Setup for Nextcloud${NC}"
echo "=========================================="

# Function to get WSL IP
get_wsl_ip() {
    hostname -I | awk '{print $1}'
}

# Function to detect Windows network IP from WSL
detect_windows_network_ip() {
    # Method 1: Try to get from Windows via PowerShell through WSL
    # This requires Windows PowerShell to be accessible from WSL
    local detected_ip=$(powershell.exe -Command "
        \$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            \$_.IPAddress -notmatch '^127\.' -and 
            \$_.IPAddress -notmatch '^169\.254\.' -and
            \$_.IPAddress -notmatch '^172\.1[6-9]\.' -and
            \$_.IPAddress -notmatch '^172\.2[0-9]\.' -and
            \$_.IPAddress -notmatch '^172\.3[0-1]\.' -and
            \$_.InterfaceAlias -notmatch 'WSL' -and
            \$_.InterfaceAlias -notmatch 'Loopback' -and
            \$_.InterfaceAlias -notmatch 'vEthernet.*WSL'
        } | Sort-Object InterfaceIndex;
        \$mainAdapter = \$adapters | Where-Object { 
            \$_.InterfaceAlias -match 'Wi-Fi|Ethernet|Wireless' 
        } | Select-Object -First 1;
        if (-not \$mainAdapter) {
            \$mainAdapter = \$adapters | Select-Object -First 1;
        };
        if (\$mainAdapter) {
            Write-Output \$mainAdapter.IPAddress;
        }
    " 2>/dev/null | tr -d '\r\n' | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
    
    # If PowerShell method failed, fall back to WSL gateway
    if [ -z "$detected_ip" ] || [ "$detected_ip" = "" ]; then
        detected_ip=$(ip route show | grep default | awk '{print $3}')
    fi
    
    echo "$detected_ip"
}

# Get current IPs
WSL_IP=$(get_wsl_ip)
WINDOWS_IP=$(detect_windows_network_ip)

echo -e "${YELLOW}📍 Detected Network Configuration:${NC}"
echo "   WSL IP: $WSL_IP"
echo "   Windows IP: $WINDOWS_IP"

# Determine if this looks like a real network IP
if [[ $WINDOWS_IP =~ ^192\.168\. ]] || [[ $WINDOWS_IP =~ ^10\. ]] || [[ $WINDOWS_IP =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
    echo -e "${GREEN}✅ Detected real network IP: $WINDOWS_IP${NC}"
    NETWORK_TYPE="real"
elif [[ $WINDOWS_IP =~ ^172\.2[6-9]\. ]]; then
    echo -e "${YELLOW}⚠️  Using WSL gateway IP: $WINDOWS_IP (may not work for mobile)${NC}"
    NETWORK_TYPE="wsl_gateway"
else
    echo -e "${RED}❌ Unknown IP type: $WINDOWS_IP${NC}"
    NETWORK_TYPE="unknown"
fi

echo ""

# Update .env file
echo -e "${BLUE}📝 Updating configuration files...${NC}"
cat > .env << EOF
# Auto-generated IP configuration - $(date)
WSL_IP=$WSL_IP
WINDOWS_HOST_IP=$WINDOWS_IP
WINDOWS_NETWORK_IP=$WINDOWS_IP
NEXTCLOUD_URL=http://$WINDOWS_IP:8090
NETWORK_TYPE=$NETWORK_TYPE
EOF

echo "✅ Updated .env file"

# Create comprehensive PowerShell script
cat > setup-mobile-access.ps1 << 'EOF'
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
EOF

# Update the WSL IP in the PowerShell script
sed -i "s/172.26.58.22/$WSL_IP/g" setup-mobile-access.ps1

echo "✅ Created setup-mobile-access.ps1"

# Update trusted domains
echo -e "${BLUE}🛡️  Updating Nextcloud trusted domains...${NC}"
if docker compose ps | grep -q "nextcloud-app.*Up"; then
    docker exec nextcloud-app php occ config:system:set trusted_domains 0 --value=localhost 2>/dev/null
    docker exec nextcloud-app php occ config:system:set trusted_domains 1 --value="$WSL_IP" 2>/dev/null
    docker exec nextcloud-app php occ config:system:set trusted_domains 2 --value="$WINDOWS_IP" 2>/dev/null
    docker exec nextcloud-app php occ config:system:set trusted_domains 3 --value=host.docker.internal 2>/dev/null
    echo "✅ Trusted domains updated"
else
    echo "⚠️  Nextcloud container not running, trusted domains will be set on next startup"
fi

echo ""
echo -e "${GREEN}🎯 Next Steps:${NC}"
echo "=============="
echo "1. Run this command in Windows PowerShell as Administrator:"
echo -e "   ${BLUE}powershell -ExecutionPolicy Bypass -File setup-mobile-access.ps1${NC}"
echo ""
echo "2. The script will show you the correct IP address for mobile access"
echo ""
echo "3. Use that IP address in your mobile device browser or Nextcloud app"
echo ""

if [ "$NETWORK_TYPE" = "wsl_gateway" ]; then
    echo -e "${YELLOW}⚠️  Important: The detected IP ($WINDOWS_IP) might not work for mobile devices.${NC}"
    echo -e "${YELLOW}   The PowerShell script will detect your real network IP.${NC}"
    echo ""
fi

echo -e "${CYAN}📱 Mobile Testing:${NC}"
echo "  1. Ensure mobile device is on same WiFi as Windows PC"
echo "  2. Use the IP shown by the PowerShell script"
echo "  3. If it doesn't work, try the troubleshooting steps in the script output"