#!/bin/bash
# Open the Homepage dashboard in the default browser.
# Uses localhost rather than the LAN IP: this machine's address moves with the
# USB tether, and localhost is always in HOMEPAGE_ALLOWED_HOSTS.

set -euo pipefail
cd "$(dirname "$0")"

PORT=7575
[ -f .env ] && PORT="$(grep -E '^DASHBOARD_PORT=' .env | cut -d= -f2 | tr -dc '0-9')"

URL="http://localhost:${PORT:-7575}"

if ! curl -s -o /dev/null --max-time 5 "$URL"; then
    echo "The dashboard is not responding at ${URL}."
    echo "Start the stack first: ./start-homelab.sh"
    exit 1
fi

xdg-open "$URL" >/dev/null 2>&1 &
