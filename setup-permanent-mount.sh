#!/bin/bash
# Pin the 3TB NTFS drive to a stable mount point via /etc/fstab.
#
# Without this the drive is auto-mounted by udisks2, which picks the mount point
# at random (DATA, DATA1, DATA2...) and only mounts once a desktop session is up.
# Docker bind mounts break in both cases. A UUID-based fstab entry survives
# reboots, disk reordering and OS reinstalls.

set -euo pipefail

DEVICE="/dev/sda1"
MOUNT_POINT="/media/Kelib/DATA"
OWNER_UID="$(id -u "${SUDO_USER:-$USER}")"
OWNER_GID="$(id -g "${SUDO_USER:-$USER}")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run with sudo: sudo ./setup-permanent-mount.sh${NC}" >&2
    exit 1
fi

UUID="$(blkid -s UUID -o value "$DEVICE" 2>/dev/null || true)"
FSTYPE="$(blkid -s TYPE -o value "$DEVICE" 2>/dev/null || true)"

if [ -z "$UUID" ]; then
    echo -e "${RED}Could not read a UUID from $DEVICE.${NC}" >&2
    echo -e "${YELLOW}Check 'lsblk -f' and update DEVICE at the top of this script.${NC}" >&2
    exit 1
fi

echo -e "${BLUE}Device:${NC} $DEVICE"
echo -e "${BLUE}UUID:  ${NC} $UUID"
echo -e "${BLUE}Type:  ${NC} $FSTYPE"

if [ "$FSTYPE" != "ntfs" ]; then
    echo -e "${YELLOW}Warning: expected ntfs, found '$FSTYPE'. Review the options below before continuing.${NC}"
fi

# umask=000 makes every file 0777 on this filesystem. NTFS stores no POSIX
# ownership, so this is how the container's www-data (uid 33) gets write access
# while the desktop user keeps it too. allow_other lets non-root users through
# the FUSE mount, which is what makes the Docker bind mount work at all.
OPTS="uid=${OWNER_UID},gid=${OWNER_GID},umask=000,allow_other,nosuid,nodev,nofail,x-systemd.device-timeout=15"
FSTAB_LINE="UUID=${UUID}  ${MOUNT_POINT}  ntfs-3g  ${OPTS}  0  0"

mkdir -p "$MOUNT_POINT"

# FUSE needs this for allow_other to be honoured in all cases.
if [ -f /etc/fuse.conf ] && ! grep -qE '^\s*user_allow_other' /etc/fuse.conf; then
    echo "user_allow_other" >> /etc/fuse.conf
    echo -e "${GREEN}Enabled user_allow_other in /etc/fuse.conf${NC}"
fi

cp /etc/fstab "/etc/fstab.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}Backed up /etc/fstab${NC}"

if grep -q "UUID=${UUID}" /etc/fstab; then
    echo -e "${YELLOW}An entry for this UUID already exists; replacing it.${NC}"
    sed -i "\|UUID=${UUID}|d" /etc/fstab
fi
# Drop any stale entry pointing at the same mount point under a different UUID.
sed -i "\|[[:space:]]${MOUNT_POINT}[[:space:]]|d" /etc/fstab

{
    echo ""
    echo "# 3TB shared drive for the Nextcloud NAS (home-nextcloud)"
    echo "$FSTAB_LINE"
} >> /etc/fstab

echo -e "${GREEN}Added to /etc/fstab:${NC}"
echo "  $FSTAB_LINE"

# Remount so the new options take effect now rather than at next boot.
if mountpoint -q "$MOUNT_POINT"; then
    echo -e "${BLUE}Unmounting existing udisks2 mount...${NC}"
    umount "$MOUNT_POINT" || {
        echo -e "${YELLOW}Busy. Close anything using the drive (including containers) and run:${NC}"
        echo "  sudo umount $MOUNT_POINT && sudo mount $MOUNT_POINT"
        exit 1
    }
fi

# udisks2 removes the mount directory it created, but does so *asynchronously*
# after the unmount returns. Recreating the directory here and immediately
# calling mount(8) loses that race: udisks2 deletes it in between and mount
# fails with ENOENT. Wait for the cleanup to land first.
if [ -d "$MOUNT_POINT" ]; then
    echo -e "${BLUE}Waiting for udisks2 to release the mount point...${NC}"
    for _ in $(seq 1 10); do
        [ -d "$MOUNT_POINT" ] || break
        sleep 1
    done
fi
udevadm settle 2>/dev/null || true

systemctl daemon-reload 2>/dev/null || true

# Prefer the systemd unit generated from the fstab entry: it creates the mount
# point as part of mounting, so there is no window for udisks2 to delete it.
MOUNT_UNIT="$(systemd-escape -p --suffix=mount "$MOUNT_POINT" 2>/dev/null || true)"
mounted=0
for attempt in 1 2 3; do
    if [ -n "$MOUNT_UNIT" ] && systemctl start "$MOUNT_UNIT" 2>/dev/null; then
        mounted=1; break
    fi
    # Fallback for non-systemd or a unit that failed to generate.
    mkdir -p "$MOUNT_POINT"
    if mount "$MOUNT_POINT" 2>/dev/null; then
        mounted=1; break
    fi
    echo -e "${YELLOW}Mount attempt ${attempt} failed, retrying...${NC}"
    sleep 2
done

if [ "$mounted" -eq 1 ] && mountpoint -q "$MOUNT_POINT"; then
    echo -e "${GREEN}Mounted successfully.${NC}"
    findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS "$MOUNT_POINT"
else
    echo -e "${RED}Mount failed. /etc/fstab has been updated but the drive is not mounted.${NC}" >&2
    echo -e "${YELLOW}Try manually:${NC}" >&2
    echo "  sudo mkdir -p $MOUNT_POINT && sudo mount $MOUNT_POINT" >&2
    echo -e "${YELLOW}Restore fstab with: sudo cp /etc/fstab.backup.* /etc/fstab${NC}" >&2
    exit 1
fi

mkdir -p "${MOUNT_POINT}/shared_drive"
echo -e "${GREEN}Done. ${MOUNT_POINT}/shared_drive is ready for the Nextcloud stack.${NC}"

# Containers bind-mounted the old mount point and are still holding a reference
# to it, so they see an empty directory until they are recreated.
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^nextcloud-app$'; then
    echo
    echo -e "${YELLOW}The stack is running and is still pinned to the previous mount.${NC}"
    echo -e "${YELLOW}Re-attach it with:${NC}  ./start-homelab.sh"
fi
