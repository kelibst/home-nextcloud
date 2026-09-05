#!/bin/bash
# Bring up the whole home NAS stack: Nextcloud + Postgres + Redis + dashboards.
# Safe to re-run; it reconciles .env, the drive mount and the external storage
# config on every invocation.

set -euo pipefail
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
step() { echo -e "\n${BLUE}==>${NC} $1"; }
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
die()  { echo -e "  ${RED}✗${NC} $1" >&2; exit 1; }

# --- 1. Prerequisites --------------------------------------------------------
step "Checking prerequisites"
command -v docker >/dev/null || die "docker is not installed"
docker compose version >/dev/null 2>&1 || die "the docker compose plugin is not installed"
docker info >/dev/null 2>&1 || die "cannot talk to the Docker daemon (is your user in the 'docker' group?)"
ok "docker $(docker --version | awk '{print $3}' | tr -d ,) / compose $(docker compose version --short)"

# --- 2. Network --------------------------------------------------------------
step "Detecting LAN address"
# Deliberately NOT called LAN_IP: sourcing .env below would overwrite it with
# the previously stored address, and the rewrite would then be a no-op.
DETECTED_IP="$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[\d.]+' | head -1)"
[ -n "$DETECTED_IP" ] || die "could not determine this machine's LAN IP"
ok "LAN IP: $DETECTED_IP"

# --- 3. Environment ----------------------------------------------------------
step "Preparing .env"
gen_secret() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32; }

if [ ! -f .env ]; then
    cp .env.example .env
    sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(gen_secret)|" .env
    sed -i "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$(gen_secret)|" .env
    sed -i "s|^NEXTCLOUD_ADMIN_PASSWORD=.*|NEXTCLOUD_ADMIN_PASSWORD=$(gen_secret)|" .env
    ok "created .env with freshly generated secrets"
    NEW_ENV=1
else
    ok ".env already present, keeping existing secrets"
    NEW_ENV=0
fi

set -a; . ./.env; set +a

# Keep the network-dependent values in step with the current LAN address.
sed -i "s|^LAN_IP=.*|LAN_IP=${DETECTED_IP}|" .env
# 'nextcloud-app' is required so the Homepage widget can reach Nextcloud over the
# internal network — otherwise Nextcloud answers those calls with its
# "untrusted domain" page instead of JSON.
sed -i "s|^NEXTCLOUD_TRUSTED_DOMAINS=.*|NEXTCLOUD_TRUSTED_DOMAINS=\"localhost 127.0.0.1 ${DETECTED_IP} nextcloud-app\"|" .env
sed -i "s|^HOMEPAGE_ALLOWED_HOSTS=.*|HOMEPAGE_ALLOWED_HOSTS=localhost:${DASHBOARD_PORT},127.0.0.1:${DASHBOARD_PORT},${DETECTED_IP}:${DASHBOARD_PORT}|" .env
set -a; . ./.env; set +a
ok "trusted domains: ${NEXTCLOUD_TRUSTED_DOMAINS}"

# --- 4. Storage --------------------------------------------------------------
step "Checking the shared drive"
if ! mountpoint -q /media/Kelib/DATA; then
    die "/media/Kelib/DATA is not mounted. Run: sudo ./setup-permanent-mount.sh"
fi
if ! grep -q " /media/Kelib/DATA " /etc/fstab 2>/dev/null; then
    warn "the drive is mounted but has no /etc/fstab entry — it will not survive a reboot."
    warn "run 'sudo ./setup-permanent-mount.sh' to make it permanent."
fi
mkdir -p "$SHARED_DRIVE_PATH"
[ -w "$SHARED_DRIVE_PATH" ] || die "$SHARED_DRIVE_PATH is not writable"
ok "$SHARED_DRIVE_PATH ($(df -h --output=avail "$SHARED_DRIVE_PATH" | tail -1 | tr -d ' ') free)"

# --- 5. Port conflicts -------------------------------------------------------
step "Checking ports"
IN_USE="$(ss -tlnH 2>/dev/null | awk '{print $4}' | grep -oE '[0-9]+$' | sort -un || true)"
for entry in "Nextcloud:$NEXTCLOUD_PORT" "Dashboard:$DASHBOARD_PORT" "Dozzle:$DOZZLE_PORT" "Uptime Kuma:$UPTIME_KUMA_PORT"; do
    name="${entry%%:*}"; port="${entry##*:}"
    if grep -qx "$port" <<<"$IN_USE" && ! docker ps --format '{{.Ports}}' | grep -q ":${port}->"; then
        die "port $port ($name) is already taken by another process — change it in .env"
    fi
    ok "$name → $port"
done

# --- 6. Start ----------------------------------------------------------------
step "Starting containers"
docker compose up -d
ok "compose up complete"

step "Waiting for Nextcloud to finish installing (this takes a minute on first run)"
for i in $(seq 1 90); do
    if docker exec -u www-data nextcloud-app php occ status 2>/dev/null | grep -q 'installed: true'; then
        ok "Nextcloud is installed"
        break
    fi
    [ "$i" -eq 90 ] && die "timed out. Check logs with: docker compose logs nextcloud-app"
    sleep 5
done

occ() { docker exec -u www-data nextcloud-app php occ "$@"; }

# stop-homelab.sh enables maintenance mode before shutting down, and the setting
# lives in config.php, so it survives the restart. It must be cleared here,
# before anything else — in maintenance mode Nextcloud loads only AppAPI
# commands, so every occ call below would silently do nothing. Clearing it
# unconditionally also recovers from an upgrade that died halfway.
if occ maintenance:mode 2>/dev/null | grep -q 'enabled'; then
    occ maintenance:mode --off >/dev/null
    ok "maintenance mode cleared"
fi

# --- 7. External storage -----------------------------------------------------
step "Configuring external storage"
occ app:enable files_external >/dev/null 2>&1 || true

if occ files_external:list 2>/dev/null | grep -qF "$EXTERNAL_STORAGE_NAME"; then
    ok "'$EXTERNAL_STORAGE_NAME' already configured"
else
    occ files_external:create "$EXTERNAL_STORAGE_NAME" local null::null \
        -c datadir="$EXTERNAL_STORAGE_MOUNT_PATH" >/dev/null
    ok "mounted $SHARED_DRIVE_PATH as '$EXTERNAL_STORAGE_NAME'"
fi

# Read the ID off the table rather than the JSON — occ escapes forward slashes
# in JSON output ("\/Shared Drive"), which makes the JSON fiddlier to match.
MOUNT_ID="$(occ files_external:list 2>/dev/null \
    | awk -F'|' -v want=" /${EXTERNAL_STORAGE_NAME} " '$3 == want {gsub(/ /, "", $2); print $2}' \
    | head -1 || true)"
if [ -n "$MOUNT_ID" ]; then
    occ files_external:option "$MOUNT_ID" enable_sharing true >/dev/null 2>&1 || true
    ok "sharing enabled on mount $MOUNT_ID"
fi

step "Tuning Nextcloud"
# The NEXTCLOUD_TRUSTED_DOMAINS env var is only honoured during the initial
# install, so re-apply it here — this is what makes a DHCP address change
# recoverable by simply re-running this script.
idx=0
for domain in $NEXTCLOUD_TRUSTED_DOMAINS; do
    occ config:system:set trusted_domains "$idx" --value="$domain" >/dev/null
    idx=$((idx + 1))
done
ok "trusted_domains applied: $NEXTCLOUD_TRUSTED_DOMAINS"

occ config:system:set default_phone_region --value="GH" >/dev/null 2>&1 || true
occ config:system:set maintenance_window_start --type=integer --value=1 >/dev/null 2>&1 || true
occ db:add-missing-indices >/dev/null 2>&1 || true
occ background:cron >/dev/null 2>&1 || true
ok "background jobs set to cron, indices checked"

# --- 8. Dashboard credentials ------------------------------------------------
step "Linking the dashboard to Nextcloud"
if ! grep -q '^NEXTCLOUD_APP_PASSWORD=' .env; then
    # occ reads the password from OC_PASS, not PASSWORD.
    APP_PW="$(docker exec -u www-data -e OC_PASS="$NEXTCLOUD_ADMIN_PASSWORD" \
        nextcloud-app php occ user:add-app-password "$NEXTCLOUD_ADMIN_USER" --password-from-env 2>/dev/null \
        | tail -1 | awk '{print $NF}' || true)"
    if [ -n "${APP_PW:-}" ] && [ ${#APP_PW} -ge 20 ]; then
        echo "NEXTCLOUD_APP_PASSWORD=${APP_PW}" >> .env
        ok "generated an app password for the Homepage widget"
        docker compose up -d homepage >/dev/null
    else
        warn "could not generate an app password; the Nextcloud tile will show no stats."
        warn "generate one in Settings → Security and add NEXTCLOUD_APP_PASSWORD=... to .env"
    fi
else
    ok "app password already configured"
fi

# --- 9. Summary --------------------------------------------------------------
echo
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN} Home NAS is up${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "  Dashboard    ${BLUE}http://${DETECTED_IP}:${DASHBOARD_PORT}${NC}"
echo -e "  Nextcloud    ${BLUE}http://${DETECTED_IP}:${NEXTCLOUD_PORT}${NC}"
echo -e "  Uptime Kuma  ${BLUE}http://${DETECTED_IP}:${UPTIME_KUMA_PORT}${NC}  (create an admin account on first visit)"
echo -e "  Logs         ${BLUE}http://${DETECTED_IP}:${DOZZLE_PORT}${NC}"
echo
if [ "$NEW_ENV" -eq 1 ]; then
    echo -e "  ${YELLOW}Nextcloud admin login${NC}"
    echo -e "    user: ${NEXTCLOUD_ADMIN_USER}"
    echo -e "    pass: $(grep '^NEXTCLOUD_ADMIN_PASSWORD=' .env | cut -d= -f2-)"
    echo -e "  ${YELLOW}Save these now — .env is gitignored and holds the only copy.${NC}"
    echo
fi
echo -e "  Mobile apps: use the Nextcloud URL above with the same credentials."
echo -e "  Your 3TB drive appears in Files as '${EXTERNAL_STORAGE_NAME}'."
echo
