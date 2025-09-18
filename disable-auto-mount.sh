#!/bin/bash
# Script to disable auto-mounting for DATA drive

echo "=== Creating udisks2 rule to prevent auto-mounting ==="

# Create udisks2 rules directory if it doesn't exist
sudo mkdir -p /etc/udisks2

# Create rule to prevent auto-mounting of DATA drive by UUID
sudo tee /etc/udisks2/mount-options.conf > /dev/null << 'EOF'
# Disable auto-mounting for specific drives
[/dev/disk/by-uuid/01DC2091A0EF3410]
noauto=true
EOF

echo "=== Creating udev rule for additional control ==="
sudo mkdir -p /etc/udev/rules.d

# Create udev rule to prevent udisks2 from auto-mounting this specific drive
sudo tee /etc/udev/rules.d/99-disable-udisks2-auto-mount.rules > /dev/null << 'EOF'
# Prevent auto-mounting of DATA drive (UUID: 01DC2091A0EF3410)
ENV{ID_FS_UUID}=="01DC2091A0EF3410", ENV{UDISKS_IGNORE}="1"
EOF

echo "=== Reloading udev rules ==="
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "=== Auto-mounting disabled for DATA drive! ==="
echo "The drive will now only mount via /etc/fstab configuration."