#!/bin/bash
# Script to set up permanent mounting configuration

echo "=== Adding permanent mount to /etc/fstab ==="

# Backup current fstab
sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)

# Add the DATA drive to fstab with UUID for reliability
echo "" | sudo tee -a /etc/fstab
echo "# DATA Drive - Permanent mount for Nextcloud and network sharing" | sudo tee -a /etc/fstab
echo "UUID=01DC2091A0EF3410 /media/Kelib/DATA ntfs defaults,uid=1000,gid=1000,umask=0000,auto,user 0 0" | sudo tee -a /etc/fstab

echo "=== Testing fstab configuration ==="
sudo mount -a

echo "=== Verifying mount ==="
df -h | grep DATA
ls -la /media/Kelib/DATA

echo "=== fstab configuration complete! ==="