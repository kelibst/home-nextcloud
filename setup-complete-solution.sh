#!/bin/bash
# Master script to set up complete shared folder solution

echo "=========================================="
echo "  Complete Shared Folder Setup Solution"
echo "=========================================="
echo ""

echo "This script will:"
echo "1. Clean up mount mess and phantom directories"
echo "2. Set up permanent mounting in /etc/fstab"
echo "3. Disable auto-mounting via udisks2"
echo "4. Install and configure Samba for network sharing"
echo "5. Update Nextcloud configuration"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 1
fi

echo ""
echo "=== Step 1: Cleaning up mount mess ==="
./cleanup-mounts.sh
if [ $? -ne 0 ]; then
    echo "Error in cleanup step. Please check and run manually."
    exit 1
fi

echo ""
echo "=== Step 2: Setting up permanent mount ==="
./setup-permanent-mount.sh
if [ $? -ne 0 ]; then
    echo "Error in permanent mount setup. Please check and run manually."
    exit 1
fi

echo ""
echo "=== Step 3: Disabling auto-mounting ==="
./disable-auto-mount.sh
if [ $? -ne 0 ]; then
    echo "Error in disabling auto-mount. Please check and run manually."
    exit 1
fi

echo ""
echo "=== Step 4: Setting up Samba network sharing ==="
./setup-samba-share.sh
if [ $? -ne 0 ]; then
    echo "Error in Samba setup. Please check and run manually."
    exit 1
fi

echo ""
echo "=== Step 5: Restarting Nextcloud containers ==="
docker compose down
docker compose up -d

echo ""
echo "=========================================="
echo "           SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "Your DATA drive is now:"
echo "✅ Mounted permanently at /media/Kelib/DATA"
echo "✅ Accessible as network share"
echo "✅ Integrated with Nextcloud"
echo "✅ Will survive reboots and reinstalls"
echo ""
echo "Access methods:"
echo "📁 Local: /media/Kelib/DATA"
echo "🌐 Nextcloud: http://$(hostname -I | awk '{print $1}'):8090"
echo "🖧 Network share: \\\\$(hostname -I | awk '{print $1}')\\DATA"
echo ""
echo "To test: Reboot your system and verify everything still works!"
echo ""