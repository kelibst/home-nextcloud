#!/bin/bash
# configure-trusted-domains.sh - Configure Nextcloud trusted domains from IP detection

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Configuring Nextcloud trusted domains...${NC}"

# Wait for Nextcloud to be ready
echo -e "${YELLOW}⏳ Waiting for Nextcloud container to be ready...${NC}"
for i in {1..60}; do
    if docker exec nextcloud-app php occ status >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Nextcloud container is ready${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}❌ Timeout waiting for Nextcloud container${NC}"
        exit 1
    fi
    echo -e "${BLUE}  Attempt $i/60 - waiting for Nextcloud...${NC}"
    sleep 3
done

# Read IP configuration if available
if [ -f "/shared/ip-config.json" ]; then
    echo -e "${BLUE}📖 Reading IP configuration from shared volume...${NC}"

    # Extract IPs using simple grep/sed (avoiding jq dependency)
    HOST_IP=$(grep '"host_ip"' /shared/ip-config.json | sed 's/.*": *"\([^"]*\)".*/\1/')
    WSL_IP=$(grep '"wsl_ip"' /shared/ip-config.json | sed 's/.*": *"\([^"]*\)".*/\1/')
    WINDOWS_IP=$(grep '"windows_ip"' /shared/ip-config.json | sed 's/.*": *"\([^"]*\)".*/\1/')
    PLATFORM=$(grep '"platform"' /shared/ip-config.json | sed 's/.*": *"\([^"]*\)".*/\1/')

    echo -e "${YELLOW}📍 Using detected IPs:${NC}"
    echo -e "   Platform: ${GREEN}$PLATFORM${NC}"
    echo -e "   Host IP: ${GREEN}$HOST_IP${NC}"
    echo -e "   WSL IP: ${GREEN}$WSL_IP${NC}"
    echo -e "   Windows IP: ${GREEN}$WINDOWS_IP${NC}"
else
    echo -e "${YELLOW}⚠️  No IP configuration found, using defaults${NC}"
    HOST_IP="localhost"
    WSL_IP="localhost"
    WINDOWS_IP="localhost"
    PLATFORM="unknown"
fi

# Configure trusted domains using occ command
echo -e "${BLUE}🌐 Setting trusted domains...${NC}"

# Set basic domains
docker exec nextcloud-app php occ config:system:set trusted_domains 0 --value=localhost 2>/dev/null && echo -e "  ✅ localhost"
docker exec nextcloud-app php occ config:system:set trusted_domains 1 --value="$HOST_IP" 2>/dev/null && echo -e "  ✅ $HOST_IP"

# Set platform-specific domains
if [ "$PLATFORM" = "wsl" ]; then
    docker exec nextcloud-app php occ config:system:set trusted_domains 2 --value="$WSL_IP" 2>/dev/null && echo -e "  ✅ $WSL_IP (WSL)"
    docker exec nextcloud-app php occ config:system:set trusted_domains 3 --value="$WINDOWS_IP" 2>/dev/null && echo -e "  ✅ $WINDOWS_IP (Windows)"
    docker exec nextcloud-app php occ config:system:set trusted_domains 4 --value=host.docker.internal 2>/dev/null && echo -e "  ✅ host.docker.internal"
else
    docker exec nextcloud-app php occ config:system:set trusted_domains 2 --value=host.docker.internal 2>/dev/null && echo -e "  ✅ host.docker.internal"
fi

# Verify configuration
echo -e "${BLUE}🔍 Verifying trusted domains configuration...${NC}"
DOMAINS=$(docker exec nextcloud-app php occ config:system:get trusted_domains 2>/dev/null || echo "Error reading domains")
if [ "$DOMAINS" != "Error reading domains" ]; then
    echo -e "${GREEN}✅ Trusted domains configured successfully${NC}"
    echo -e "${BLUE}📋 Current trusted domains:${NC}"
    docker exec nextcloud-app php occ config:system:get trusted_domains 2>/dev/null | grep -E '^[0-9]+' | while read line; do
        echo -e "   $line"
    done
else
    echo -e "${YELLOW}⚠️  Could not verify trusted domains (Nextcloud may still be initializing)${NC}"
fi

# Create status file to indicate completion
echo "$(date -Iseconds)" > /shared/trusted-domains-configured

echo -e "${GREEN}✅ Trusted domains configuration completed${NC}"