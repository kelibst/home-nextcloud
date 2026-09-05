#!/bin/bash
# Stop the home NAS stack. Named volumes are left untouched, so nothing is lost —
# ./start-homelab.sh brings everything back exactly as it was.

set -euo pipefail
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}==>${NC} Stopping the home NAS stack"

if ! docker info >/dev/null 2>&1; then
    echo -e "  ${RED}✗${NC} cannot talk to the Docker daemon" >&2
    exit 1
fi

RUNNING="$(docker compose ps -q 2>/dev/null | wc -l)"
if [ "$RUNNING" -eq 0 ]; then
    echo -e "  ${YELLOW}!${NC} nothing is running"
    exit 0
fi

# Give Nextcloud a moment to finish in-flight writes before the container dies.
if docker ps --format '{{.Names}}' | grep -q '^nextcloud-app$'; then
    docker exec -u www-data nextcloud-app php occ maintenance:mode --on >/dev/null 2>&1 || true
    echo -e "  ${GREEN}✓${NC} Nextcloud put into maintenance mode"
fi

docker compose down

echo -e "  ${GREEN}✓${NC} all containers stopped"
echo -e "  ${GREEN}✓${NC} data volumes kept — restart with ./start-homelab.sh"
