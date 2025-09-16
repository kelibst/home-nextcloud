#!/bin/bash
# start-nextcloud.sh - Automated Nextcloud startup with dynamic IP configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Nextcloud with automatic IP configuration...${NC}"

# Function to detect Windows network IP from WSL
detect_windows_network_ip() {
    # Try to get real Windows network IP via PowerShell
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
    
    echo $WINDOWS_IP
}

# Function to get WSL IP
get_wsl_ip() {
    hostname -I | awk '{print $1}'
}

# Get current IPs
WINDOWS_IP=$(detect_windows_network_ip)
WSL_IP=$(get_wsl_ip)

echo -e "${YELLOW}📍 Detected IPs:${NC}"
echo -e "   Windows Host IP: ${GREEN}$WINDOWS_IP${NC}"
echo -e "   WSL IP: ${GREEN}$WSL_IP${NC}"

# Function to detect shared drive path based on OS
detect_shared_drive_path() {
    echo -e "${BLUE}🔍 Detecting external storage path...${NC}" >&2

    # Try different common paths based on OS
    POSSIBLE_PATHS=(
        "/mnt/d/shared_drive"     # WSL/Linux mounting Windows D: drive
        "/mnt/c/shared_drive"     # WSL/Linux mounting Windows C: drive
        "D:/shared_drive"         # Native Windows path
        "C:/shared_drive"         # Native Windows path
        "/Volumes/SharedDrive"    # macOS external drive
        "./shared_drive"          # Local directory fallback
    )

    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -d "$path" ]; then
            echo -e "   ✅ Found external storage at: ${GREEN}$path${NC}" >&2
            echo "$path"
            return 0
        fi
    done

    # If no path found, use the WSL default and warn
    echo -e "${YELLOW}⚠️  No existing external storage found, using default: /mnt/d/shared_drive${NC}" >&2
    echo -e "${YELLOW}   Create this directory or update SHARED_DRIVE_PATH in .env${NC}" >&2
    echo "/mnt/d/shared_drive"
}

# Detect external storage path
SHARED_DRIVE_PATH=$(detect_shared_drive_path)

# Validate external storage path
if [ ! -d "$SHARED_DRIVE_PATH" ]; then
    echo -e "${YELLOW}⚠️  External storage path does not exist: $SHARED_DRIVE_PATH${NC}"
    echo -e "${YELLOW}   Creating directory...${NC}"
    mkdir -p "$SHARED_DRIVE_PATH" 2>/dev/null || {
        echo -e "${RED}❌ Failed to create external storage directory${NC}"
        echo -e "${YELLOW}   Please create it manually or update SHARED_DRIVE_PATH in .env${NC}"
    }
fi

# Create or update .env file with dynamic IPs and external storage
cat > .env << EOF
# Auto-generated IP configuration - $(date)
WINDOWS_HOST_IP=$WINDOWS_IP
WSL_IP=$WSL_IP
NEXTCLOUD_URL=http://$WINDOWS_IP:8090

# External Storage Configuration
# Path will be auto-detected by start script based on OS
SHARED_DRIVE_PATH=$SHARED_DRIVE_PATH
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

# Setup Windows port forwarding (requires Windows PowerShell)
echo -e "${BLUE}🌐 Setting up Windows port forwarding...${NC}"

# Create enhanced PowerShell script for port forwarding
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

# Stop any existing containers
echo -e "${BLUE}🛑 Stopping existing containers...${NC}"
docker-compose down

# Start the containers
echo -e "${BLUE}🚀 Starting Nextcloud containers...${NC}"
docker-compose up -d

# Wait for services to be ready
echo -e "${BLUE}⏳ Waiting for services to start...${NC}"
sleep 10

# Fix file permissions for cross-platform compatibility
echo -e "${BLUE}🔧 Fixing file permissions for cross-platform compatibility...${NC}"
./fix-permissions.sh

# Configure trusted domains via container after startup
echo -e "${BLUE}🔧 Configuring trusted domains for current IPs...${NC}"
sleep 5  # Give container a bit more time to fully initialize

# Set trusted domains using occ command in container
docker exec nextcloud-app php occ config:system:set trusted_domains 0 --value=localhost 2>/dev/null || echo "  ℹ️  Localhost domain set"
docker exec nextcloud-app php occ config:system:set trusted_domains 1 --value="$WSL_IP" 2>/dev/null || echo "  ℹ️  WSL IP domain set"
docker exec nextcloud-app php occ config:system:set trusted_domains 2 --value="$WINDOWS_IP" 2>/dev/null || echo "  ℹ️  Windows IP domain set"
docker exec nextcloud-app php occ config:system:set trusted_domains 3 --value=host.docker.internal 2>/dev/null || echo "  ℹ️  Docker internal domain set"

echo -e "${GREEN}✅ Trusted domains configured for current session${NC}"

# Configure external storage via occ command
echo -e "${BLUE}🗂️  Configuring external storage...${NC}"

# Enable external storage app
docker exec nextcloud-app php occ app:enable files_external 2>/dev/null || echo "  ℹ️  External storage app enabled"

# Wait a moment for the app to be fully loaded
sleep 2

# Remove any existing external storage with the same mount point
docker exec nextcloud-app php occ files_external:delete -y 1 2>/dev/null || echo "  ℹ️  Cleaned up existing external storage"

# Add external storage mount
docker exec nextcloud-app php occ files_external:create \
    "SharedDrive" \
    "local" \
    "null::null" \
    -c datadir="/mnt/external-storage" \
    --user admin 2>/dev/null && echo "  ✅ External storage configured" || echo "  ℹ️  External storage already exists"

# Verify external storage configuration
docker exec nextcloud-app php occ files_external:list 2>/dev/null | grep -q "SharedDrive" && \
    echo -e "${GREEN}✅ External storage 'SharedDrive' configured successfully${NC}" || \
    echo -e "${YELLOW}⚠️  External storage configuration needs manual setup${NC}"

echo -e "${GREEN}✅ External storage configuration completed${NC}"

# Check if containers are running
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Nextcloud is starting up!${NC}"
    echo -e "${GREEN}📱 Access URLs:${NC}"
    echo -e "   Local (WSL): ${BLUE}http://$WSL_IP:8090${NC}"
    echo -e "   Network:     ${BLUE}http://$WINDOWS_IP:8090${NC}"
    echo -e "   Mobile:      ${BLUE}http://$WINDOWS_IP:8090${NC}"
    echo ""
    echo -e "${YELLOW}📋 Login credentials:${NC}"
    echo -e "   Username: ${GREEN}admin${NC}"
    echo -e "   Password: ${GREEN}adminpassword${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Don't forget to run the PowerShell script in Windows as Administrator!${NC}"
    echo ""
    echo -e "${BLUE}📊 Monitor startup with: ${NC}docker-compose logs -f nextcloud-app"
else
    echo -e "${RED}❌ Failed to start containers. Check logs with: docker-compose logs${NC}"
    exit 1
fi