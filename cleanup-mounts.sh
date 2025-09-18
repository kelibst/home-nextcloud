#!/bin/bash
# Script to clean up mount mess and set up permanent mounting

echo "=== Step 1: Unmounting auto-mounted drives ==="
sudo umount /media/Kelib/44BA5E29BA5E182E 2>/dev/null || echo "Already unmounted or not mounted"
sudo umount /media/Kelib/59373E7526CE30E3 2>/dev/null || echo "Already unmounted or not mounted"
sudo umount "/media/Kelib/Extra Disk" 2>/dev/null || echo "Already unmounted or not mounted"
sudo umount /media/Kelib/DATA3 2>/dev/null || echo "DATA3 already unmounted or not mounted"

echo "=== Step 2: Removing phantom directories ==="
sudo rmdir /media/Kelib/DATA1 2>/dev/null || echo "DATA1 already removed or doesn't exist"
sudo rmdir /media/Kelib/DATA2 2>/dev/null || echo "DATA2 already removed or doesn't exist"
sudo rmdir /media/Kelib/44BA5E29BA5E182E 2>/dev/null || echo "Hex directory already removed"
sudo rmdir /media/Kelib/59373E7526CE30E3 2>/dev/null || echo "Hex directory already removed"
sudo rmdir "/media/Kelib/Extra Disk" 2>/dev/null || echo "Extra Disk directory already removed"

echo "=== Step 3: Creating clean DATA directory ==="
sudo mkdir -p /media/Kelib/DATA
sudo chown Kelib:Kelib /media/Kelib/DATA
sudo chmod 755 /media/Kelib/DATA

echo "=== Step 4: Mounting DATA drive to clean location ==="
sudo mount -t ntfs -o defaults,uid=1000,gid=1000,umask=0000 /dev/sda1 /media/Kelib/DATA

echo "=== Cleanup complete! Check with: ls -la /media/Kelib/ ==="