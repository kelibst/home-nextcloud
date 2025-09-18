#!/bin/bash
# Mobile connectivity troubleshooting script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Nextcloud Mobile Connectivity Troubleshooting${NC}"
echo "=================================================="

# Get current IPs
WINDOWS_IP=$(ip route show | grep default | awk '{print $3}')
WSL_IP=$(hostname -I | awk '{print $1}')

echo -e "${YELLOW}📍 Current IP Configuration:${NC}"
echo "   Windows Host IP: $WINDOWS_IP"
echo "   WSL IP: $WSL_IP"
echo ""

# Check if Nextcloud is running
echo -e "${BLUE}🐳 Docker Container Status:${NC}"
docker compose  ps

echo ""

# Test local connectivity
echo -e "${BLUE}🔗 Testing Local Connectivity:${NC}"
echo -n "  WSL to localhost:8090: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8090 | grep -q "302"; then
    echo -e "${GREEN}✅ Working${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
fi

echo -n "  WSL to WSL IP:8090: "
if curl -s -o /dev/null -w "%{http_code}" http://$WSL_IP:8090 | grep -q "302"; then
    echo -e "${GREEN}✅ Working${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
fi

echo ""

# Check trusted domains
echo -e "${BLUE}🛡️  Current Trusted Domains:${NC}"
docker exec nextcloud-app php occ config:system:get trusted_domains 2>/dev/null || echo "  Unable to retrieve trusted domains"

echo ""

# Windows connectivity instructions
echo -e "${YELLOW}⚠️  For Mobile Access, you MUST run this in Windows PowerShell as Administrator:${NC}"
echo -e "${BLUE}   powershell -ExecutionPolicy Bypass -File setup-port-forward.ps1${NC}"
echo ""

echo -e "${YELLOW}📋 After running PowerShell script, verify with these Windows commands:${NC}"
echo "   1. Check port forwarding:"
echo -e "      ${BLUE}netsh interface portproxy show v4tov4${NC}"
echo ""
echo "   2. Check firewall rule:"
echo -e "      ${BLUE}netsh advfirewall firewall show rule name=\"Nextcloud WSL2\"${NC}"
echo ""
echo "   3. Test from Windows:"
echo -e "      ${BLUE}curl http://localhost:8090${NC}"
echo -e "      ${BLUE}curl http://$WINDOWS_IP:8090${NC}"
echo ""

echo -e "${YELLOW}📱 Mobile Device Testing:${NC}"
echo "   1. Ensure mobile device is on the same WiFi network"
echo "   2. Find your router's network range (usually 192.168.x.x or 10.0.x.x)"
echo "   3. Your Windows computer should have an IP in that range"
echo "   4. Try pinging Windows from mobile: ping $WINDOWS_IP"
echo ""

echo -e "${YELLOW}🔍 Network Discovery:${NC}"
echo "   If $WINDOWS_IP doesn't work, try finding your actual Windows IP:"
echo "   - On Windows: ipconfig | findstr IPv4"
echo "   - Look for network adapter with IP like 192.168.x.x or 10.0.x.x"
echo "   - Update the startup script with the correct IP"
echo ""

echo -e "${BLUE}🚀 Quick Network Test Commands (run these on Windows):${NC}"
echo "   # Show all network interfaces"
echo -e "   ${GREEN}ipconfig${NC}"
echo ""
echo "   # Show port forwarding rules"
echo -e "   ${GREEN}netsh interface portproxy show all${NC}"
echo ""
echo "   # Test if port 8090 is listening"
echo -e "   ${GREEN}netstat -an | findstr :8090${NC}"