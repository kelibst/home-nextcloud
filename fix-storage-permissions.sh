#!/bin/bash

# Fix External Storage Permissions for Nextcloud
# This script changes the ownership of the external storage to match
# the www-data user (UID 33) inside the Nextcloud container

echo "Fixing external storage permissions for Nextcloud..."

# Check if the external storage path exists
STORAGE_PATH="/media/Kelib/DATA"

if [ ! -d "$STORAGE_PATH" ]; then
    echo "Error: Storage path $STORAGE_PATH does not exist"
    exit 1
fi

echo "Changing ownership of $STORAGE_PATH to UID 33:33 (www-data)..."

# Change ownership to match container's www-data user
# UID 33 = www-data in most Debian-based containers
sudo chown -R 33:33 "$STORAGE_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Permissions fixed successfully!"
    echo "External storage should now be accessible from Nextcloud"
else
    echo "❌ Failed to change permissions. You may need to run this script with sudo"
    exit 1
fi

# Verify the changes
echo "Current ownership:"
ls -la "$STORAGE_PATH"