#!/bin/bash

# Fix-permissions script for cross-platform Nextcloud deployment
# This script ensures proper file permissions regardless of host OS
# Now works with Docker volumes for better cross-platform compatibility

echo "🔧 Fixing Nextcloud volume permissions..."

# Fix ownership and permissions for volumes if container is running
if docker ps --filter "name=nextcloud-app" --filter "status=running" -q | grep -q .; then
    echo "📁 Setting volume permissions from inside container..."
    
    # Fix data directory permissions
    docker exec -u root nextcloud-app chown -R www-data:www-data /var/www/html/data/
    docker exec -u root nextcloud-app chmod 755 /var/www/html/data/
    echo "✅ Fixed data volume permissions"
    
    # Fix config directory permissions
    docker exec -u root nextcloud-app chown -R www-data:www-data /var/www/html/config/
    echo "✅ Fixed config volume permissions"
    
    # Fix custom apps directory permissions
    docker exec -u root nextcloud-app chown -R www-data:www-data /var/www/html/custom_apps/
    echo "✅ Fixed custom_apps volume permissions"
    
    # Fix themes directory permissions
    docker exec -u root nextcloud-app chown -R www-data:www-data /var/www/html/themes/
    echo "✅ Fixed themes volume permissions"
    
    echo "✅ All volume permissions fixed!"
else
    echo "⚠️  Nextcloud container not running. Start containers first, then run this script."
    exit 1
fi