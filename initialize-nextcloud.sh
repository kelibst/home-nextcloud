#!/bin/bash
# initialize-nextcloud.sh - Proper Nextcloud Initialization Script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Nextcloud Complete Initialization Script${NC}"
echo "=============================================="

# Function to wait for service
wait_for_service() {
    local service=$1
    local port=$2
    local max_attempts=30
    
    echo -e "${YELLOW}⏳ Waiting for $service to be ready...${NC}"
    for i in $(seq 1 $max_attempts); do
        if docker exec $service nc -z localhost $port 2>/dev/null; then
            echo -e "${GREEN}✅ $service is ready${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    echo -e "${RED}❌ $service failed to start properly${NC}"
    return 1
}

# Function to run occ commands safely
run_occ() {
    docker exec nextcloud-app php occ "$@" 2>/dev/null
}

# Load environment variables
if [ -f ".env" ]; then
    source .env
    echo -e "${BLUE}📄 Loaded configuration from .env${NC}"
else
    echo -e "${RED}❌ No .env file found. Creating default...${NC}"
    cat > .env << EOF
# Auto-generated IP configuration - $(date)
WINDOWS_HOST_IP=192.168.1.98
WSL_IP=172.26.58.22
NEXTCLOUD_URL=http://192.168.1.98:8090
SHARED_DRIVE_PATH=/mnt/d/shared_drive
EOF
    source .env
fi

echo -e "${YELLOW}📍 Configuration:${NC}"
echo "   Windows IP: $WINDOWS_HOST_IP"
echo "   WSL IP: $WSL_IP"
echo "   Shared Drive: $SHARED_DRIVE_PATH"
echo ""

# Stop and remove existing containers completely
echo -e "${BLUE}🛑 Stopping existing containers...${NC}"
docker compose  down -v
docker system prune -f

# Ensure shared drive path exists
echo -e "${BLUE}📁 Setting up storage directories...${NC}"
if [ -n "$SHARED_DRIVE_PATH" ] && [ ! -d "$SHARED_DRIVE_PATH" ]; then
    echo "   Creating shared drive directory: $SHARED_DRIVE_PATH"
    mkdir -p "$SHARED_DRIVE_PATH" 2>/dev/null || sudo mkdir -p "$SHARED_DRIVE_PATH"
    chmod 755 "$SHARED_DRIVE_PATH" 2>/dev/null || sudo chmod 755 "$SHARED_DRIVE_PATH"
fi

# Start database first
echo -e "${BLUE}🗄️ Starting PostgreSQL database...${NC}"
docker compose  up -d nextcloud-db

# Wait for database to be ready
wait_for_service "nextcloud-db" "5432"

# Start Redis
echo -e "${BLUE}⚡ Starting Redis cache...${NC}"
docker compose  up -d redis

# Wait a moment for Redis
sleep 5

# Start Nextcloud
echo -e "${BLUE}🌐 Starting Nextcloud application...${NC}"
docker compose  up -d nextcloud-app

# Wait for Nextcloud to be ready
echo -e "${YELLOW}⏳ Waiting for Nextcloud to initialize (this may take 2-3 minutes)...${NC}"
for i in {1..60}; do
    if docker exec nextcloud-app curl -s http://localhost/status.php 2>/dev/null | grep -q "installed"; then
        echo -e "${GREEN}✅ Nextcloud web interface is ready${NC}"
        break
    elif docker exec nextcloud-app curl -s http://localhost/index.php 2>/dev/null | grep -q "Nextcloud"; then
        echo -e "${GREEN}✅ Nextcloud is ready for setup${NC}"
        break
    fi
    echo -n "."
    sleep 3
done
echo ""

# Check if Nextcloud is already installed
echo -e "${BLUE}🔍 Checking Nextcloud installation status...${NC}"
INSTALL_STATUS=$(run_occ status 2>/dev/null)

if echo "$INSTALL_STATUS" | grep -q "installed: true"; then
    NEXTCLOUD_VERSION=$(echo "$INSTALL_STATUS" | grep "version:" | cut -d' ' -f3)
    echo -e "${GREEN}✅ Nextcloud is already installed (version: $NEXTCLOUD_VERSION)${NC}"
    echo -e "${BLUE}   Skipping installation, proceeding with configuration...${NC}"
else
    echo -e "${BLUE}⚙️ Installing Nextcloud (first-time setup)...${NC}"

    # Run initial installation
    INSTALL_OUTPUT=$(docker exec nextcloud-app php occ maintenance:install \
        --database="pgsql" \
        --database-name="nextcloud" \
        --database-user="nextcloud" \
        --database-pass="nextcloudpassword" \
        --database-host="nextcloud-db" \
        --admin-user="admin" \
        --admin-pass="adminpassword" \
        --data-dir="/var/www/html/data" 2>&1)

    INSTALL_EXIT_CODE=$?

    if [ $INSTALL_EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✅ Nextcloud installation completed${NC}"
    else
        # Check if error is due to already being installed
        if echo "$INSTALL_OUTPUT" | grep -q "Command.*maintenance:install.*is not defined"; then
            echo -e "${GREEN}✅ Nextcloud is already installed (maintenance:install not available)${NC}"
            echo -e "${BLUE}   Proceeding with configuration...${NC}"
        else
            echo -e "${RED}❌ Nextcloud installation failed${NC}"
            echo -e "${YELLOW}Installation output:${NC}"
            echo "$INSTALL_OUTPUT"
            echo -e "${YELLOW}Checking container logs:${NC}"
            docker compose  logs --tail=20 nextcloud-app
            exit 1
        fi
    fi
fi

# Configure trusted domains
echo -e "${BLUE}🌐 Configuring trusted domains...${NC}"
run_occ config:system:set trusted_domains 0 --value=localhost
run_occ config:system:set trusted_domains 1 --value="$WSL_IP"
run_occ config:system:set trusted_domains 2 --value="$WINDOWS_IP"
run_occ config:system:set trusted_domains 3 --value=host.docker.internal
run_occ config:system:set trusted_domains 4 --value="$WSL_IP:8090"
run_occ config:system:set trusted_domains 5 --value="$WINDOWS_IP:8090"

# Configure URL overwrite settings
echo -e "${BLUE}🔗 Configuring URL settings...${NC}"
run_occ config:system:set overwrite.cli.url --value="http://$WINDOWS_IP:8090"
run_occ config:system:set overwritehost --value="$WINDOWS_IP:8090"
run_occ config:system:set overwriteprotocol --value="http"

# Configure Redis cache
echo -e "${BLUE}⚡ Configuring Redis cache...${NC}"
run_occ config:system:set redis host --value="redis"
run_occ config:system:set redis port --value="6379"
run_occ config:system:set redis password --value="redispassword"
run_occ config:system:set memcache.local --value="\\OC\\Memcache\\Redis"
run_occ config:system:set memcache.distributed --value="\\OC\\Memcache\\Redis"

# Configure external storage if path exists
if [ -n "$SHARED_DRIVE_PATH" ] && [ -d "$SHARED_DRIVE_PATH" ]; then
    echo -e "${BLUE}💾 Setting up external storage...${NC}"
    
    # Enable external storage app
    run_occ app:enable files_external
    
    # Remove any existing external storage
    run_occ files_external:list --output=json 2>/dev/null | jq -r '.[].mount_id' 2>/dev/null | while read mount_id; do
        if [ -n "$mount_id" ] && [ "$mount_id" != "null" ]; then
            run_occ files_external:delete "$mount_id"
        fi
    done
    
    # Add new external storage mount
    MOUNT_ID=$(run_occ files_external:create "SharedDrive" "local" "null::null" -c datadir="/mnt/external-storage" --output=json 2>/dev/null | jq -r '.mount_id' 2>/dev/null)
    
    if [ -n "$MOUNT_ID" ] && [ "$MOUNT_ID" != "null" ]; then
        run_occ files_external:option "$MOUNT_ID" enable_sharing true
        run_occ files_external:applicable "$MOUNT_ID" --add-user admin
        echo -e "${GREEN}✅ External storage configured (ID: $MOUNT_ID)${NC}"
    else
        echo -e "${YELLOW}⚠️ External storage setup may need manual configuration${NC}"
    fi
fi

# Fix file permissions
echo -e "${BLUE}📁 Fixing file permissions...${NC}"
docker exec --user root nextcloud-app chown -R www-data:www-data /var/www/html
docker exec --user root nextcloud-app chmod -R 755 /var/www/html
docker exec --user root nextcloud-app chmod -R 775 /var/www/html/data

# Run maintenance tasks
echo -e "${BLUE}🔧 Running maintenance tasks...${NC}"
run_occ db:add-missing-indices
run_occ db:add-missing-columns
run_occ files:scan --all

# Create Windows PowerShell networking script
echo -e "${BLUE}🖥️ Creating Windows networking script...${NC}"
cat > setup-port-forward.ps1 << EOF
# Auto-generated Windows port forwarding setup
Write-Host "Setting up port forwarding for Nextcloud..." -ForegroundColor Blue

# Remove existing port forwarding
try {
    netsh interface portproxy delete v4tov4 listenport=8090 2>\$null
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

# Final verification
echo -e "${BLUE}🔍 Verifying installation...${NC}"
sleep 5

# Check services
echo "   📊 Container Status:"
docker compose  ps

# Check Nextcloud status
if run_occ status | grep -q "installed: true"; then
    echo -e "${GREEN}   ✅ Nextcloud: Installed and ready${NC}"
else
    echo -e "${RED}   ❌ Nextcloud: Installation issues${NC}"
fi

# Check database
if docker exec nextcloud-db pg_isready -U nextcloud >/dev/null 2>&1; then
    echo -e "${GREEN}   ✅ PostgreSQL: Connected${NC}"
else
    echo -e "${RED}   ❌ PostgreSQL: Connection issues${NC}"
fi

# Check external storage
if docker exec nextcloud-app ls /mnt/external-storage >/dev/null 2>&1; then
    echo -e "${GREEN}   ✅ External Storage: Mounted${NC}"
else
    echo -e "${YELLOW}   ⚠️ External Storage: Not found${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Nextcloud initialization complete!${NC}"
echo ""
echo -e "${YELLOW}📱 Access Information:${NC}"
echo -e "   🌐 Web: ${BLUE}http://$WINDOWS_IP:8090${NC}"
echo -e "   📱 Mobile: ${BLUE}http://$WINDOWS_IP:8090${NC}"
echo -e "   🏠 Local: ${BLUE}http://localhost:8090${NC}"
echo ""
echo -e "${YELLOW}🔐 Login Credentials:${NC}"
echo -e "   👤 Username: ${GREEN}admin${NC}"
echo -e "   🔑 Password: ${GREEN}adminpassword${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Run this in Windows PowerShell as Administrator:"
echo -e "   ${BLUE}powershell -ExecutionPolicy Bypass -File setup-port-forward.ps1${NC}"
echo ""
echo "2. Open your browser and go to the web URL above"
echo ""
echo "3. For mobile access, install Nextcloud apps and use the mobile URL"
echo ""
echo -e "${BLUE}🔧 For troubleshooting: ${NC}./troubleshoot-mobile.sh"