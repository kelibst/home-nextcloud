#!/bin/bash
# Open the NAS ports to the local network only.
#
# Note: this machine currently has no active host firewall (neither ufw nor
# firewalld is installed or running), so the ports are already reachable on the
# LAN and you do not need to run this. It exists so the rules are defined if you
# ever enable ufw.

set -euo pipefail
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

[ -f .env ] || { echo -e "${RED}.env not found — run ./start-homelab.sh first${NC}" >&2; exit 1; }
set -a; . ./.env; set +a

if ! command -v ufw >/dev/null 2>&1; then
    echo -e "${YELLOW}ufw is not installed — nothing to configure.${NC}"
    echo -e "${YELLOW}No host firewall is blocking these ports:${NC}"
    echo "  ${NEXTCLOUD_PORT} (Nextcloud), ${DASHBOARD_PORT} (Dashboard), ${DOZZLE_PORT} (Dozzle), ${UPTIME_KUMA_PORT} (Uptime Kuma)"
    exit 0
fi

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run with sudo: sudo ./setup-firewall.sh${NC}" >&2
    exit 1
fi

# Restrict to the local subnet — none of these services should face the internet.
SUBNET="$(ip -4 route show scope link | grep -oP '^\K[\d./]+' | head -1)"
[ -n "$SUBNET" ] || { echo -e "${RED}Could not determine the LAN subnet${NC}" >&2; exit 1; }
echo "Allowing from $SUBNET only."

for entry in "Nextcloud:$NEXTCLOUD_PORT" "Dashboard:$DASHBOARD_PORT" "Dozzle:$DOZZLE_PORT" "Uptime-Kuma:$UPTIME_KUMA_PORT"; do
    name="${entry%%:*}"; port="${entry##*:}"
    ufw allow from "$SUBNET" to any port "$port" proto tcp comment "$name"
    echo -e "${GREEN}✓${NC} $name → $port/tcp"
done

echo -e "${GREEN}Done.${NC} Check with: sudo ufw status numbered"
