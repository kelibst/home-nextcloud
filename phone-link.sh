#!/bin/bash
# Day-to-day driver for the phone connection. Run ./setup-phone-link.sh once
# first.
#
#   ./phone-link.sh status      what is connected, and how
#   ./phone-link.sh mirror      mirror and control the phone (default)
#   ./phone-link.sh desk        mirror with the phone's own screen off
#   ./phone-link.sh wireless    switch to Wi-Fi, so the cable can come out
#   ./phone-link.sh pair        pair over Wi-Fi with a code (Android 11+)
#   ./phone-link.sh usb         switch back to the cable
#   ./phone-link.sh shell       a shell on the phone

set -euo pipefail
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
step() { echo -e "\n${BLUE}==>${NC} $1"; }
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
die()  { echo -e "  ${RED}✗${NC} $1" >&2; exit 1; }

command -v adb    >/dev/null || die "adb not found — run ./setup-phone-link.sh first"
command -v scrcpy >/dev/null || die "scrcpy not found — run ./setup-phone-link.sh first"

# The tether gateway is the phone itself, so it doubles as the phone's address
# on the USB link. Falls back to the default route if that ever changes.
phone_ip() {
    ip route | awk '/^default/ {print $3; exit}'
}

require_device() {
    local n
    n="$(adb devices | awk 'NR>1 && $2=="device"' | wc -l)"
    if [ "$n" -eq 0 ]; then
        if adb devices | grep -q unauthorized; then
            die "phone is unauthorized — unlock it and accept the USB debugging prompt"
        fi
        die "no phone connected — check the cable and that USB debugging is on (see PHONE-LINK.md)"
    fi
}

cmd_status() {
    step "Devices"
    local out
    out="$(adb devices | awk 'NR>1 && NF')"
    if [ -z "$out" ]; then
        warn "nothing connected"
    else
        echo "$out" | while read -r serial state; do
            case "$serial" in
                *:*) echo -e "  ${GREEN}●${NC} $serial  (Wi-Fi)  [$state]" ;;
                *)   echo -e "  ${GREEN}●${NC} $serial  (USB)    [$state]" ;;
            esac
        done
    fi

    step "This machine's network"
    local iface ipaddr
    iface="$(ip route | awk '/^default/ {print $5; exit}')"
    ipaddr="$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2; exit}')"
    echo "  interface : ${iface:-none}"
    echo "  address   : ${ipaddr:-none}"
    echo "  phone/gw  : $(phone_ip)"

    # An RNDIS default route means the phone is the uplink, which is worth
    # calling out — pulling the cable takes the internet with it.
    if [ -n "${iface:-}" ] && [ -e "/sys/class/net/$iface/device/driver" ] \
       && readlink -f "/sys/class/net/$iface/device/driver" | grep -q rndis; then
        echo
        warn "this machine's only uplink is the phone's USB tethering"
        echo "    Unplugging the phone disconnects the desktop, and the homelab"
        echo "    with it. See the 'Getting off the tether' note in PHONE-LINK.md."
    fi
}

cmd_mirror() {
    require_device
    step "Starting mirror"
    ok "close the window, or press Ctrl+C here, to stop"
    # --stay-awake holds the phone awake while it is charging; uhid gives a
    # real keyboard so typing and modifiers behave normally.
    scrcpy --stay-awake --keyboard=uhid --window-title="Phone" "$@"
}

cmd_desk() {
    require_device
    step "Starting mirror with the phone's screen off"
    ok "the phone screen turns back on when you close the window"
    scrcpy --stay-awake --keyboard=uhid --turn-screen-off \
           --power-off-on-close --window-title="Phone" "$@"
}

cmd_wireless() {
    step "Switching to Wi-Fi"

    # Legacy tcpip mode needs one USB-attached device to bootstrap from.
    local usb_serial
    usb_serial="$(adb devices | awk 'NR>1 && $2=="device" && $1 !~ /:/ {print $1; exit}')"
    [ -n "$usb_serial" ] || die "plug the phone in over USB first — that is how the wireless handoff is set up"
    ok "using USB device $usb_serial"

    # Ask the phone for its address on a real network. On the tether link this
    # returns nothing useful, which is exactly the case we want to catch.
    local wifi_ip
    wifi_ip="$(adb -s "$usb_serial" shell ip -4 addr show wlan0 2>/dev/null \
               | awk '/inet /{sub(/\/.*/,"",$2); print $2; exit}' || true)"

    if [ -z "$wifi_ip" ]; then
        warn "the phone has no Wi-Fi address (wlan0 is down or unassigned)"
        echo
        echo "  Wireless ADB needs the phone and this desktop on a shared network."
        echo "  Right now this desktop has no Wi-Fi hardware and no ethernet link,"
        echo "  so there is no such network to share. See PHONE-LINK.md."
        exit 1
    fi
    ok "phone Wi-Fi address: $wifi_ip"

    adb -s "$usb_serial" tcpip 5555
    sleep 2
    if adb connect "${wifi_ip}:5555" | grep -qE "connected|already"; then
        ok "connected to ${wifi_ip}:5555 — the cable can come out now"
        echo
        echo "  Reconnect later with:  adb connect ${wifi_ip}:5555"
    else
        die "could not connect to ${wifi_ip}:5555"
    fi
}

cmd_pair() {
    # Android 11+ pairing flow, for networks where plain tcpip is blocked.
    step "Wi-Fi pairing (Android 11+)"
    echo "  On the phone: Developer options → Wireless debugging → Pair device with pairing code"
    echo
    read -rp "  Pairing address shown on the phone (ip:port): " pair_addr
    read -rp "  Six-digit pairing code: " pair_code
    [ -n "$pair_addr" ] && [ -n "$pair_code" ] || die "both values are required"

    adb pair "$pair_addr" "$pair_code" || die "pairing failed"
    ok "paired"

    echo
    read -rp "  Connection address from the Wireless debugging screen (ip:port): " conn_addr
    [ -n "$conn_addr" ] || die "connection address is required"
    adb connect "$conn_addr" || die "connect failed"
    ok "connected to $conn_addr"
}

cmd_usb() {
    step "Switching back to USB"
    adb disconnect >/dev/null 2>&1 || true
    ok "wireless connections dropped"
    adb devices | awk 'NR>1 && NF' || true
}

cmd_shell() {
    require_device
    adb shell
}

case "${1:-mirror}" in
    status)   shift || true; cmd_status ;;
    mirror)   shift || true; cmd_mirror "$@" ;;
    desk)     shift || true; cmd_desk "$@" ;;
    wireless) shift || true; cmd_wireless ;;
    pair)     shift || true; cmd_pair ;;
    usb)      shift || true; cmd_usb ;;
    shell)    shift || true; cmd_shell ;;
    -h|--help|help)
        # Print the header comment block, stopping at the first line that is
        # no longer a comment.
        awk 'NR>1 { if ($0 !~ /^#/) exit; sub(/^# ?/,""); print }' "$0" ;;
    *) die "unknown command '$1' — try: status, mirror, desk, wireless, pair, usb, shell" ;;
esac
