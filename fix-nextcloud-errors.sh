#!/bin/bash
# fix-nextcloud-errors.sh - Comprehensive Nextcloud Error Fixing Script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Nextcloud Error Fixing Script${NC}"
echo "========================================"

# Function to run commands in Nextcloud container
run_occ() {
    docker exec nextcloud-app php occ "$@" 2>/dev/null || echo "  ⚠️ Command failed: occ $*"
}

# Function to fix file permissions
fix_permissions() {
    echo -e "${BLUE}📁 Fixing file permissions...${NC}"
    
    # Fix container file permissions
    docker exec --user root nextcloud-app chown -R www-data:www-data /var/www/html
    docker exec --user root nextcloud-app chmod -R 755 /var/www/html
    docker exec --user root nextcloud-app chmod -R 775 /var/www/html/data
    docker exec --user root nextcloud-app chmod -R 775 /var/www/html/config
    
    # Fix external storage permissions if it exists
    if [ -n "${SHARED_DRIVE_PATH}" ] && [ -d "${SHARED_DRIVE_PATH}" ]; then
        echo "  📂 Fixing external storage permissions: ${SHARED_DRIVE_PATH}"
        sudo chmod -R 755 "${SHARED_DRIVE_PATH}" 2>/dev/null || echo "  ⚠️ Could not fix external storage permissions"
        sudo chown -R $USER:$USER "${SHARED_DRIVE_PATH}" 2>/dev/null || echo "  ⚠️ Could not change external storage ownership"
    fi
    
    echo -e "${GREEN}✅ File permissions fixed${NC}"
}

# Function to clear Nextcloud caches
clear_caches() {
    echo -e "${BLUE}🧹 Clearing caches and temporary files...${NC}"
    
    # Clear all Nextcloud caches
    run_occ maintenance:mode --on
    run_occ db:add-missing-indices
    run_occ db:add-missing-columns
    run_occ db:add-missing-primary-keys
    run_occ files:cleanup
    run_occ files:scan --all
    run_occ maintenance:repair
    run_occ maintenance:mode --off
    
    echo -e "${GREEN}✅ Caches cleared and database repaired${NC}"
}

# Function to fix external storage configuration
fix_external_storage() {
    echo -e "${BLUE}💾 Configuring external storage...${NC}"
    
    # Check if external storage app is enabled
    run_occ app:enable files_external
    
    # Get the shared drive path from .env
    if [ -f ".env" ]; then
        source .env
        if [ -n "${SHARED_DRIVE_PATH}" ]; then
            echo "  📂 External storage path: ${SHARED_DRIVE_PATH}"
            
            # Remove existing external storage mounts
            run_occ files_external:list --output=json | jq -r '.[].mount_id' 2>/dev/null | while read mount_id; do
                if [ -n "$mount_id" ]; then
                    run_occ files_external:delete "$mount_id"
                fi
            done
            
            # Add new external storage mount
            run_occ files_external:create "SharedDrive" "local" "null::null" -c datadir="/mnt/external-storage"
            run_occ files_external:option 1 enable_sharing true
            run_occ files_external:applicable 1 --add-user admin
            
            echo -e "${GREEN}✅ External storage configured${NC}"
        else
            echo -e "${YELLOW}⚠️ No SHARED_DRIVE_PATH found in .env file${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ No .env file found${NC}"
    fi
}

# Function to fix trusted domains and CSRF issues
fix_trusted_domains() {
    echo -e "${BLUE}🌐 Fixing trusted domains and CSRF configuration...${NC}"
    
    # Get current IPs
    WSL_IP=$(hostname -I | awk '{print $1}')
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
    
    if [ -z "$WINDOWS_IP" ]; then
        WINDOWS_IP=$(ip route show | grep default | awk '{print $3}')
    fi
    
    echo "  📍 WSL IP: $WSL_IP"
    echo "  📍 Windows IP: $WINDOWS_IP"
    
    # Set trusted domains
    run_occ config:system:set trusted_domains 0 --value=localhost
    run_occ config:system:set trusted_domains 1 --value="$WSL_IP"
    run_occ config:system:set trusted_domains 2 --value="$WINDOWS_IP"
    run_occ config:system:set trusted_domains 3 --value=host.docker.internal
    run_occ config:system:set trusted_domains 4 --value="$WSL_IP:8090"
    run_occ config:system:set trusted_domains 5 --value="$WINDOWS_IP:8090"
    
    # Fix overwrite settings for proper URL generation
    run_occ config:system:set overwrite.cli.url --value="http://$WINDOWS_IP:8090"
    run_occ config:system:set overwritehost --value="$WINDOWS_IP:8090"
    run_occ config:system:set overwriteprotocol --value="http"
    run_occ config:system:set overwritewebroot --value=""
    
    # Enable additional security settings
    run_occ config:system:set csrf.disabled --value=false
    
    echo -e "${GREEN}✅ Trusted domains and URL configuration updated${NC}"
}

# Function to restart services properly
restart_services() {
    echo -e "${BLUE}🔄 Restarting services...${NC}"
    
    # Restart containers in proper order
    docker-compose restart redis
    sleep 5
    docker-compose restart nextcloud-app
    sleep 10
    
    # Wait for services to be ready
    echo "  ⏳ Waiting for services to start..."
    for i in {1..30}; do
        if docker exec nextcloud-app curl -s http://localhost/status.php >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Services are ready${NC}"
            break
        fi
        sleep 2
        echo -n "."
    done
    echo ""
}

# Function to verify fix
verify_fix() {
    echo -e "${BLUE}🔍 Verifying fixes...${NC}"
    
    # Check container status
    if docker-compose ps | grep -q "Up"; then
        echo -e "${GREEN}✅ Containers are running${NC}"
    else
        echo -e "${RED}❌ Some containers are not running${NC}"
    fi
    
    # Check database connection
    if docker exec nextcloud-db pg_isready -U nextcloud >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Database connection is healthy${NC}"
    else
        echo -e "${RED}❌ Database connection issues${NC}"
    fi
    
    # Check Nextcloud status
    if docker exec nextcloud-app php occ status 2>/dev/null | grep -q "installed: true"; then
        echo -e "${GREEN}✅ Nextcloud is properly installed${NC}"
    else
        echo -e "${RED}❌ Nextcloud installation issues${NC}"
    fi
    
    # Check external storage mount
    if docker exec nextcloud-app ls /mnt/external-storage >/dev/null 2>&1; then
        echo -e "${GREEN}✅ External storage is mounted${NC}"
    else
        echo -e "${YELLOW}⚠️ External storage mount not found${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}🎯 Access URLs:${NC}"
    if [ -n "$WINDOWS_IP" ]; then
        echo -e "   Web: ${BLUE}http://$WINDOWS_IP:8090${NC}"
        echo -e "   Mobile: ${BLUE}http://$WINDOWS_IP:8090${NC}"
    fi
    echo -e "   Local: ${BLUE}http://localhost:8090${NC}"
    echo ""
    echo -e "${YELLOW}📋 Login: admin / adminpassword${NC}"
}

# Main execution
echo -e "${BLUE}Starting comprehensive Nextcloud error fixing...${NC}"
echo ""

# Check if containers are running
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${YELLOW}⚠️ Starting containers first...${NC}"
    docker-compose up -d
    sleep 15
fi

# Load environment variables
if [ -f ".env" ]; then
    source .env
fi

# Execute fixes in order
fix_permissions
clear_caches
fix_trusted_domains
fix_external_storage
restart_services
verify_fix

echo ""
echo -e "${GREEN}🎉 Error fixing complete!${NC}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Clear your browser cache and cookies for this site"
echo "2. Login again to Nextcloud web interface"
echo "3. Check if files in external-storage folder are accessible"
echo "4. Test mobile app connections"
echo ""
echo -e "${BLUE}If issues persist, run: ${NC}./troubleshoot-mobile.sh"