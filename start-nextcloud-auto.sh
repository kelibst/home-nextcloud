#!/bin/bash
# start-nextcloud-auto.sh - Automatic IP detection and Docker startup

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Nextcloud with automatic IP configuration...${NC}"

# Step 1: Smart IP detection with preferences
echo -e "${YELLOW}📍 Running smart IP detection...${NC}"
./scripts/enhanced-ip-detect.sh

if [ -f "real-host-ip.txt" ]; then
    HOST_IP=$(cat real-host-ip.txt)
    echo -e "${GREEN}✅ Using IP: $HOST_IP${NC}"
else
    echo -e "${RED}❌ Failed to detect host IP${NC}"
    exit 1
fi

# Step 2: Stop any existing containers
echo -e "${BLUE}🛑 Stopping existing containers...${NC}"
docker compose down

# Step 3: Start containers with automatic configuration
echo -e "${BLUE}🚀 Starting Nextcloud containers...${NC}"
docker compose up -d

# Step 4: Wait for startup and show status
echo -e "${BLUE}⏳ Waiting for services to start...${NC}"
sleep 15

# Check if containers are running
if docker compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Nextcloud is running!${NC}"
    echo -e "${GREEN}📱 Access URLs:${NC}"
    echo -e "   Primary: ${BLUE}http://$HOST_IP:8090${NC}"
    echo -e "   Local:   ${BLUE}http://localhost:8090${NC}"
    echo ""
    echo -e "${BLUE}📊 Monitor with: ${NC}docker compose logs -f"
else
    echo -e "${RED}❌ Failed to start containers. Check logs with: docker compose logs${NC}"
    exit 1
fi