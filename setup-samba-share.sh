#!/bin/bash
# Script to install and configure Samba for network sharing

echo "=== Installing Samba ==="
sudo apt update
sudo apt install -y samba samba-common-bin

echo "=== Backing up original Samba configuration ==="
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%Y%m%d_%H%M%S)

echo "=== Adding DATA share to Samba configuration ==="

# Add the share configuration
sudo tee -a /etc/samba/smb.conf > /dev/null << 'EOF'

# DATA Drive Network Share
[DATA]
    comment = Nextcloud DATA Drive - Network Share
    path = /media/Kelib/DATA
    browseable = yes
    writable = yes
    guest ok = no
    valid users = Kelib
    create mask = 0775
    directory mask = 0775
    force user = Kelib
    force group = Kelib
EOF

echo "=== Testing Samba configuration ==="
sudo testparm

echo "=== Setting up Samba user ==="
echo "You'll need to set a Samba password for user 'Kelib':"
sudo smbpasswd -a Kelib

echo "=== Enabling and starting Samba services ==="
sudo systemctl enable smbd
sudo systemctl enable nmbd
sudo systemctl start smbd
sudo systemctl start nmbd

echo "=== Configuring firewall for Samba ==="
sudo ufw allow samba

echo "=== Samba setup complete! ==="
echo "Access your share from:"
echo "  Windows: \\\\$(hostname -I | awk '{print $1}')\\DATA"
echo "  Linux: smb://$(hostname -I | awk '{print $1}')/DATA"
echo "  macOS: smb://$(hostname -I | awk '{print $1}')/DATA"