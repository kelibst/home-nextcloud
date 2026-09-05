#!/bin/bash
# Install Start / Stop / Health Check / Dashboard launchers onto the desktop
# and into the application menu.
#
# The .desktop files are generated rather than committed as static files so the
# Exec= paths match wherever this repo actually lives. Re-run after moving it.

set -euo pipefail
cd "$(dirname "$0")"
REPO="$(pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
MENU_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR" "$MENU_DIR"

chmod +x ./*.sh

# name|filename|icon|comment|exec
ENTRIES=(
"Start Home NAS|homelab-start|media-playback-start|Start Nextcloud, the dashboard and monitoring|${REPO}/desktop-run.sh ${REPO}/start-homelab.sh"
"Stop Home NAS|homelab-stop|media-playback-stop|Stop all Home NAS containers (your data is kept)|${REPO}/desktop-run.sh ${REPO}/stop-homelab.sh"
"Home NAS Health Check|homelab-health|utilities-system-monitor|Check the drive, containers, endpoints and network|${REPO}/health-check.sh --pause"
"Home NAS Dashboard|homelab-dashboard|applications-internet|Open the Homepage dashboard in your browser|${REPO}/open-dashboard.sh"
)

echo -e "${BLUE}==>${NC} Installing launchers"

for entry in "${ENTRIES[@]}"; do
    IFS='|' read -r name file icon comment exec_cmd <<<"$entry"

    # The dashboard launcher opens a browser, so it needs no terminal window.
    terminal=true
    [ "$file" = "homelab-dashboard" ] && terminal=false

    tmp="$(mktemp)"
    cat >"$tmp" <<EOF
[Desktop Entry]
Version=1.1
Type=Application
Name=${name}
Comment=${comment}
Exec=${exec_cmd}
Path=${REPO}
Icon=${icon}
Terminal=${terminal}
Categories=System;
Keywords=nextcloud;nas;homelab;docker;
StartupNotify=true
EOF

    for target in "${DESKTOP_DIR}/${file}.desktop" "${MENU_DIR}/${file}.desktop"; do
        install -m 755 "$tmp" "$target"
    done
    rm -f "$tmp"

    # DDE, GNOME and KDE all refuse to launch a desktop file that is not marked
    # trusted, showing it as a plain text file instead.
    gio set "${DESKTOP_DIR}/${file}.desktop" metadata::trusted true 2>/dev/null || true

    echo -e "  ${GREEN}✓${NC} ${name}"
done

update-desktop-database "$MENU_DIR" 2>/dev/null || true

echo
echo -e "${GREEN}Installed to:${NC}"
echo "  ${DESKTOP_DIR}"
echo "  ${MENU_DIR}  (application menu)"
echo
echo -e "${YELLOW}If an icon shows as a text file, right-click it and choose${NC}"
echo -e "${YELLOW}'Allow Launching' / 'Trust this executable'.${NC}"
