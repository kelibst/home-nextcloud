#!/bin/bash
# Health check for the home NAS stack.
#
# Exit codes:  0 = healthy   1 = one or more checks failed
# Warnings do not fail the run — they flag things that still work but will bite
# later (no fstab entry, low disk, stale cron).
#
# Pass --pause to wait for a keypress before exiting (used by the desktop
# shortcut so the terminal window does not vanish).

cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

PAUSE=0
[ "${1:-}" = "--pause" ] && PAUSE=1

FAILED=0
WARNED=0

section() { echo -e "\n${BOLD}${BLUE}$1${NC}"; }
pass()    { echo -e "  ${GREEN}✓${NC} $1"; }
warn()    { echo -e "  ${YELLOW}!${NC} $1"; WARNED=$((WARNED + 1)); }
fail()    { echo -e "  ${RED}✗${NC} $1"; FAILED=$((FAILED + 1)); }

finish() {
    echo
    if [ "$FAILED" -gt 0 ]; then
        echo -e "${RED}${BOLD}UNHEALTHY${NC} — ${FAILED} failed, ${WARNED} warnings"
    elif [ "$WARNED" -gt 0 ]; then
        echo -e "${YELLOW}${BOLD}OK with warnings${NC} — ${WARNED} to look at"
    else
        echo -e "${GREEN}${BOLD}HEALTHY${NC} — everything checks out"
    fi
    [ "$PAUSE" -eq 1 ] && { echo; read -rp "Press Enter to close..."; }
    [ "$FAILED" -gt 0 ] && exit 1
    exit 0
}

echo -e "${BOLD}Home NAS health check${NC}  —  $(date '+%Y-%m-%d %H:%M:%S')"

# --- Configuration -----------------------------------------------------------
section "Configuration"
if [ ! -f .env ]; then
    fail ".env is missing — run ./start-homelab.sh"
    finish
fi
pass ".env present"
set -a; . ./.env; set +a

# --- Docker ------------------------------------------------------------------
section "Docker"
if ! docker info >/dev/null 2>&1; then
    fail "cannot talk to the Docker daemon"
    finish
fi
pass "daemon reachable"

# --- Storage -----------------------------------------------------------------
section "Storage"
if mountpoint -q /media/Kelib/DATA; then
    pass "/media/Kelib/DATA is mounted"

    if grep -q "[[:space:]]/media/Kelib/DATA[[:space:]]" /etc/fstab 2>/dev/null; then
        pass "fstab entry present — survives reboot"
        # A mount that predates the fstab entry (udisks2, or a manual mount) still
        # works but is not the configuration that will come back after a reboot.
        if ! findmnt -no OPTIONS /media/Kelib/DATA | grep -q 'user_id=1000'; then
            warn "mounted with different options than fstab specifies"
            warn "  current: $(findmnt -no OPTIONS /media/Kelib/DATA)"
            warn "  a reboot will remount it from fstab — that is the intended state"
        fi
    else
        warn "no fstab entry — the drive will NOT come back after a reboot"
        warn "  fix with: sudo ./setup-permanent-mount.sh"
    fi

    if [ -d "$SHARED_DRIVE_PATH" ]; then
        pass "$SHARED_DRIVE_PATH exists"
    else
        fail "$SHARED_DRIVE_PATH is missing"
    fi

    USE_PCT="$(df --output=pcent "$SHARED_DRIVE_PATH" 2>/dev/null | tail -1 | tr -dc '0-9')"
    AVAIL="$(df -h --output=avail "$SHARED_DRIVE_PATH" 2>/dev/null | tail -1 | tr -d ' ')"
    if [ -n "$USE_PCT" ] && [ "$USE_PCT" -ge 90 ]; then
        fail "drive ${USE_PCT}% full — only ${AVAIL} free"
    elif [ -n "$USE_PCT" ] && [ "$USE_PCT" -ge 80 ]; then
        warn "drive ${USE_PCT}% full — ${AVAIL} free"
    else
        pass "drive ${USE_PCT}% full — ${AVAIL} free"
    fi
else
    fail "/media/Kelib/DATA is NOT mounted — Nextcloud cannot see your files"
    fail "  fix with: sudo ./setup-permanent-mount.sh"
fi

# --- Containers --------------------------------------------------------------
section "Containers"
EXPECTED="nextcloud-db nextcloud-redis nextcloud-app nextcloud-cron nextcloud-dockerproxy nextcloud-homepage nextcloud-dozzle nextcloud-uptime-kuma"
for c in $EXPECTED; do
    STATE="$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo missing)"
    HEALTH="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$c" 2>/dev/null || true)"
    case "$STATE" in
        running)
            if [ "$HEALTH" = "unhealthy" ]; then
                fail "$c is running but unhealthy"
            elif [ "$HEALTH" = "starting" ]; then
                warn "$c is still starting"
            else
                pass "$c ${HEALTH:+($HEALTH)}"
            fi
            ;;
        missing) fail "$c does not exist — run ./start-homelab.sh" ;;
        *)       fail "$c is $STATE" ;;
    esac
done

# Restart loops are invisible in a plain status check.
for c in $EXPECTED; do
    RESTARTS="$(docker inspect -f '{{.RestartCount}}' "$c" 2>/dev/null || echo 0)"
    [ "${RESTARTS:-0}" -gt 3 ] && warn "$c has restarted ${RESTARTS} times"
done

# --- Endpoints ---------------------------------------------------------------
section "Web endpoints"
LAN_IP_NOW="$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[\d.]+' | head -1)"
CHECK_HOST="${LAN_IP_NOW:-127.0.0.1}"

check_http() {
    local name="$1" port="$2" path="${3:-/}"
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://${CHECK_HOST}:${port}${path}" 2>/dev/null || echo 000)"
    case "$code" in
        200|301|302) pass "$name → :${port} (HTTP $code)" ;;
        000)         fail "$name → :${port} unreachable" ;;
        *)           fail "$name → :${port} returned HTTP $code" ;;
    esac
}

check_http "Dashboard"   "$DASHBOARD_PORT"
check_http "Nextcloud"   "$NEXTCLOUD_PORT" "/status.php"
check_http "Uptime Kuma" "$UPTIME_KUMA_PORT"
check_http "Dozzle"      "$DOZZLE_PORT"

# --- Nextcloud ---------------------------------------------------------------
section "Nextcloud"
if docker ps --format '{{.Names}}' | grep -q '^nextcloud-app$'; then
    STATUS="$(curl -s --max-time 10 "http://${CHECK_HOST}:${NEXTCLOUD_PORT}/status.php" 2>/dev/null || true)"
    if echo "$STATUS" | grep -q '"installed":true'; then
        pass "installed — version $(echo "$STATUS" | grep -oP '"versionstring":"\K[^"]+')"
    else
        fail "not reporting as installed"
    fi
    echo "$STATUS" | grep -q '"maintenance":true' \
        && fail "in maintenance mode — clear with ./start-homelab.sh" \
        || pass "not in maintenance mode"
    echo "$STATUS" | grep -q '"needsDbUpgrade":true' \
        && warn "database upgrade pending" \
        || pass "no pending database upgrade"

    if docker exec -u www-data nextcloud-app php occ files_external:list 2>/dev/null | grep -qF "$EXTERNAL_STORAGE_NAME"; then
        pass "external storage '$EXTERNAL_STORAGE_NAME' configured"
    else
        fail "external storage '$EXTERNAL_STORAGE_NAME' is missing"
    fi

    # The bind mount can go stale if the drive was unmounted underneath a
    # running container — it then shows an empty directory rather than an error.
    if docker exec -u www-data nextcloud-app sh -c \
        "echo ok > ${EXTERNAL_STORAGE_MOUNT_PATH}/.healthcheck && rm ${EXTERNAL_STORAGE_MOUNT_PATH}/.healthcheck" 2>/dev/null; then
        pass "container can write to the shared drive"
    else
        fail "container CANNOT write to the shared drive"
        fail "  the bind mount is stale — restart with ./start-homelab.sh"
    fi

    LAST_CRON="$(docker exec -u www-data nextcloud-app php occ config:app:get core lastcron 2>/dev/null | tr -dc '0-9')"
    if [ -n "$LAST_CRON" ]; then
        AGE=$(( $(date +%s) - LAST_CRON ))
        if [ "$AGE" -gt 3600 ]; then
            warn "background jobs last ran $((AGE / 60)) minutes ago — check nextcloud-cron"
        else
            pass "background jobs ran $((AGE / 60)) minutes ago"
        fi
    fi
else
    fail "nextcloud-app is not running — skipping application checks"
fi

# --- Network -----------------------------------------------------------------
section "Network"
if [ -z "$LAN_IP_NOW" ]; then
    fail "no route to the network — this host is offline"
elif [ "$LAN_IP_NOW" = "$LAN_IP" ]; then
    pass "LAN IP unchanged ($LAN_IP_NOW)"
else
    # This machine's only uplink is USB tethering, so the address moves often.
    warn "LAN IP changed: .env says $LAN_IP, now $LAN_IP_NOW"
    warn "  mobile clients and trusted domains are stale — re-run ./start-homelab.sh"
fi

if [ -n "$LAN_IP_NOW" ]; then
    if docker exec -u www-data nextcloud-app php occ config:system:get trusted_domains 2>/dev/null | grep -qx "$LAN_IP_NOW"; then
        pass "current IP is a trusted domain"
    else
        fail "current IP $LAN_IP_NOW is not in trusted_domains — re-run ./start-homelab.sh"
    fi
fi

finish
