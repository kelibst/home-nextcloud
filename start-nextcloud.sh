#!/bin/bash
# start-nextcloud.sh - Cross-platform Nextcloud startup with dynamic IP configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Nextcloud with automatic IP configuration...${NC}"

# Detect platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
    if grep -q Microsoft /proc/version; then
        PLATFORM="wsl"
    fi
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    PLATFORM="windows"
else
    PLATFORM="unknown"
fi

echo -e "${YELLOW}📋 Detected platform: ${GREEN}$PLATFORM${NC}"

# Function to detect network IPs based on platform
detect_network_ips() {
    if [ "$PLATFORM" = "wsl" ]; then
        # WSL specific detection
        WINDOWS_IP=$(powershell.exe -Command "
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
        
        # Fallback to WSL gateway if PowerShell detection failed
        if [ -z "$WINDOWS_IP" ] || [ "$WINDOWS_IP" = "" ]; then
            WINDOWS_IP=$(ip route show | grep default | awk '{print $3}')
        fi
        
        WSL_IP=$(hostname -I | awk '{print $1}')
        HOST_IP=$WINDOWS_IP
    elif [ "$PLATFORM" = "linux" ]; then
        # Native Linux detection
        HOST_IP=$(hostname -I | awk '{print $1}')
        if [ -z "$HOST_IP" ]; then
            HOST_IP=$(ip route get 8.8.8.8 | awk '{print $7}' | head -1)
        fi
        WINDOWS_IP=$HOST_IP
        WSL_IP=$HOST_IP
    else
        # Windows or other
        HOST_IP=$(ipconfig | grep -A 2 "Wireless LAN adapter Wi-Fi" | grep "IPv4 Address" | awk '{print $14}' | tr -d '\r' 2>/dev/null || echo "192.168.1.100")
        WINDOWS_IP=$HOST_IP
        WSL_IP=$HOST_IP
    fi
}

# Get current IPs based on platform
detect_network_ips

echo -e "${YELLOW}📍 Detected IPs:${NC}"
echo -e "   Host IP: ${GREEN}$HOST_IP${NC}"
if [ "$PLATFORM" = "wsl" ]; then
    echo -e "   Windows Host IP: ${GREEN}$WINDOWS_IP${NC}"
    echo -e "   WSL IP: ${GREEN}$WSL_IP${NC}"
fi

# Create or update .env file with dynamic IPs
cat > .env << EOF
# Auto-generated IP configuration - $(date)
PLATFORM=$PLATFORM
HOST_IP=$HOST_IP
WINDOWS_HOST_IP=$WINDOWS_IP
WSL_IP=$WSL_IP
NEXTCLOUD_URL=http://$HOST_IP:8090
EOF

echo -e "${BLUE}📝 Updated .env file with current IPs${NC}"

# Update config.php if it exists with trusted domains
if [ -f "./config/config.php" ]; then
    echo -e "${BLUE}🔧 Updating existing Nextcloud config with new IPs...${NC}"
    
    # Backup existing config (with proper permissions)
    if [ -r ./config/config.php ]; then
        cp ./config/config.php ./config/config.php.backup
    else
        echo -e "${YELLOW}⚠️  Cannot read config.php directly, will create new trusted domains in container${NC}"
        # We'll update via docker exec instead
        UPDATE_VIA_CONTAINER=true
    fi
    
    # Update trusted domains in existing config
    if [ "$UPDATE_VIA_CONTAINER" != "true" ]; then
        python3 -c "
import re
import sys

try:
    # Read the config file
    with open('./config/config.php', 'r') as f:
        content = f.read()

    # Define the new trusted domains array
    new_domains = [
        'localhost',
        '$WSL_IP',
        '$WINDOWS_IP', 
        'host.docker.internal'
    ]

    # Create the PHP array string
    domains_str = ',\\n    '.join([f'\'{domain}\'' for domain in new_domains])
    new_trusted_domains = f'''  'trusted_domains' => 
  array (
    {domains_str}
  ),'''

    # Replace or add trusted_domains
    if 'trusted_domains' in content:
        # Replace existing trusted_domains
        content = re.sub(
            r\"'trusted_domains'[^,]*,\",
            new_trusted_domains + ',',
            content,
            flags=re.DOTALL
        )
    else:
        # Add trusted_domains after the first array element
        content = re.sub(
            r\"(  'instanceid' => '[^']*',\\n)\",
            r\"\1\" + new_trusted_domains + \"\\n\",
            content
        )

    # Write back the updated config
    with open('./config/config.php', 'w') as f:
        f.write(content)

    print('✅ Config updated successfully')
except PermissionError:
    print('⚠️  Permission denied updating config.php, will update via container')
    exit(1)
except Exception as e:
    print(f'⚠️  Error updating config: {e}')
    exit(1)
"
    fi
fi

# Setup directories and permissions
echo -e "${BLUE}📁 Setting up directories and permissions...${NC}"

# Create directories if they don't exist
mkdir -p ./config ./data ./custom_apps ./themes ./database

# Fix permissions on Linux/WSL (www-data is UID 33)
if [ "$PLATFORM" = "linux" ] || [ "$PLATFORM" = "wsl" ]; then
    echo -e "${YELLOW}  Fixing directory permissions for www-data (UID 33)...${NC}"
    # Try to fix permissions, fallback to creating with correct ownership
    if ! docker run --rm -v "$(pwd):/workspace" busybox chown -R 33:33 /workspace/config /workspace/data /workspace/custom_apps /workspace/themes 2>/dev/null; then
        echo -e "${YELLOW}  Setting up directories with Docker user...${NC}"
        docker run --rm -v "$(pwd):/workspace" --user root busybox sh -c "
            chown -R 33:33 /workspace/config /workspace/data /workspace/custom_apps /workspace/themes
            chmod -R 755 /workspace/config /workspace/data /workspace/custom_apps /workspace/themes
        "
    fi
fi

# Setup Windows port forwarding (requires Windows PowerShell) - only for WSL
if [ "$PLATFORM" = "wsl" ]; then
    echo -e "${BLUE}🌐 Setting up Windows port forwarding...${NC}"
fi

# Create enhanced PowerShell script for port forwarding (only for WSL)
if [ "$PLATFORM" = "wsl" ]; then
cat > setup-port-forward.ps1 << EOF
# Auto-generated Windows port forwarding setup
Write-Host "Setting up port forwarding for Nextcloud..." -ForegroundColor Blue

# Remove existing port forwarding
try {
    netsh interface portproxy delete v4tov4 listenport=8090 2>$null
} catch {}

# Add new port forwarding
Write-Host "Adding port forward: 0.0.0.0:8090 -> $WSL_IP:8090" -ForegroundColor Yellow
netsh interface portproxy add v4tov4 listenport=8090 listenaddress=0.0.0.0 connectport=8090 connectaddress=$WSL_IP

# Add firewall rule if it doesn't exist
Write-Host "Configuring Windows Firewall..." -ForegroundColor Yellow
try {
    New-NetFirewallRule -DisplayName "Nextcloud WSL2" -Direction Inbound -Protocol TCP -LocalPort 8090 -Action Allow -ErrorAction SilentlyContinue
    Write-Host "✅ Firewall rule added" -ForegroundColor Green
} catch {
    Write-Host "ℹ️  Firewall rule already exists or couldn't be added" -ForegroundColor Yellow
}

# Show current port forwarding
Write-Host "Current port forwarding rules:" -ForegroundColor Green
netsh interface portproxy show v4tov4

Write-Host "✅ Windows networking setup complete!" -ForegroundColor Green
Write-Host "Access Nextcloud at: http://$WINDOWS_IP:8090" -ForegroundColor Cyan
EOF

    echo -e "${YELLOW}📋 Windows PowerShell script created: setup-port-forward.ps1${NC}"
    echo -e "${YELLOW}   Run this in Windows PowerShell as Administrator:${NC}"
    echo -e "${BLUE}   powershell -ExecutionPolicy Bypass -File setup-port-forward.ps1${NC}"
fi

# Stop any existing containers
echo -e "${BLUE}🛑 Stopping existing containers...${NC}"
docker compose down

# Start the containers
echo -e "${BLUE}🚀 Starting Nextcloud containers...${NC}"
docker compose up -d

# Wait for services to be ready
echo -e "${BLUE}⏳ Waiting for services to start...${NC}"
sleep 10

# Configure trusted domains via container after startup
echo -e "${BLUE}🔧 Configuring trusted domains for current IPs...${NC}"
sleep 5  # Give container a bit more time to fully initialize

# Set trusted domains using occ command in container
docker exec nextcloud-app php occ config:system:set trusted_domains 0 --value=localhost 2>/dev/null || echo "  ℹ️  Localhost domain set"
docker exec nextcloud-app php occ config:system:set trusted_domains 1 --value="$HOST_IP" 2>/dev/null || echo "  ℹ️  Host IP domain set"
if [ "$PLATFORM" = "wsl" ]; then
    docker exec nextcloud-app php occ config:system:set trusted_domains 2 --value="$WSL_IP" 2>/dev/null || echo "  ℹ️  WSL IP domain set"
    docker exec nextcloud-app php occ config:system:set trusted_domains 3 --value="$WINDOWS_IP" 2>/dev/null || echo "  ℹ️  Windows IP domain set"
    docker exec nextcloud-app php occ config:system:set trusted_domains 4 --value=host.docker.internal 2>/dev/null || echo "  ℹ️  Docker internal domain set"
else
    docker exec nextcloud-app php occ config:system:set trusted_domains 2 --value=host.docker.internal 2>/dev/null || echo "  ℹ️  Docker internal domain set"
fi

echo -e "${GREEN}✅ Trusted domains configured for current session${NC}"

# Check if containers are running
if docker compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Nextcloud is starting up!${NC}"
    echo -e "${GREEN}📱 Access URLs:${NC}"
    echo -e "   Primary:     ${BLUE}http://$HOST_IP:8090${NC}"
    if [ "$PLATFORM" = "wsl" ]; then
        echo -e "   Local (WSL): ${BLUE}http://$WSL_IP:8090${NC}"
        echo -e "   Windows:     ${BLUE}http://$WINDOWS_IP:8090${NC}"
        echo -e "   Mobile:      ${BLUE}http://$WINDOWS_IP:8090${NC}"
    fi
    echo ""
    echo -e "${YELLOW}📋 Setup Admin Account via Web Interface${NC}"
    echo -e "   Navigate to ${BLUE}http://$HOST_IP:8090${NC} to complete setup"
    echo ""
    if [ "$PLATFORM" = "wsl" ]; then
        echo -e "${YELLOW}⚠️  Don't forget to run the PowerShell script in Windows as Administrator!${NC}"
        echo ""
    fi
    echo ""
    echo -e "${BLUE}📊 Monitor startup with: ${NC}docker compose logs -f nextcloud-app"
else
    echo -e "${RED}❌ Failed to start containers. Check logs with: docker compose logs${NC}"
    exit 1
fi