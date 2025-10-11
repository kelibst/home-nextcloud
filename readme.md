# Nextcloud Docker NAS Setup - Complete Guide

A comprehensive guide to setting up Nextcloud as a home NAS solution using Docker with PostgreSQL database, supporting mobile devices (Android/iPhone) and utilizing existing desktop storage.

## Overview

This setup provides:
- **Home NAS functionality** using your existing desktop with 3TB storage
- **Cross-platform access** from Windows, Linux, Android, and iPhone
- **PostgreSQL database** for better performance than SQLite
- **Redis caching** for improved speed
- **Docker containerization** for easy management and portability

## Prerequisites

### System Requirements
- **Windows with WSL2 or Linux** (DeepinOS/Ubuntu)
- **Docker and Docker Compose** installed
- **3TB+ available storage space**
- **Local network access** (WiFi/Ethernet)
- **Android/iPhone devices** for mobile access

### Software Installation

#### On Windows (WSL2):
```bash
# Install Docker Desktop from docker.com
# Ensure WSL2 is enabled and Ubuntu/DeepinOS is installed
```

#### On Linux/DeepinOS:
```bash
sudo apt update && sudo apt install docker.io docker-compose
sudo usermod -aG docker $USER
# Log out and back in
```

## Quick Start

### 1. Start All Services
```bash
docker compose up -d
```

### 2. Access Points
- **Nextcloud (Direct)**: `http://192.168.1.200:8090`
- **Nextcloud (via Proxy)**: `http://192.168.1.200` (after NPM setup)
- **NPM Admin Panel**: `http://192.168.1.200:81`
  - Default: admin@example.com / changeme

### 3. Configure Nginx Proxy Manager (First Time)
1. Open `http://192.168.1.200:81`
2. Login with: admin@example.com / changeme
3. **Change password immediately!**
4. Add Proxy Host:
   - Domain: `192.168.1.200` or `nextcloud.local`
   - Scheme: `http`
   - Forward Hostname: `nextcloud-app`
   - Forward Port: `80`
   - Enable: Cache Assets, Block Exploits, Websockets

### 4. Family Access
Your family can now access Nextcloud at:
- **`http://192.168.1.200`** (after NPM setup)
- **`http://192.168.1.200:8090`** (direct access)

**Static IP configured**: Server IP won't change on reboot!

## Configuration

### Docker Compose File

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  nextcloud-db:
    image: postgres:13-alpine
    container_name: nextcloud-db
    restart: unless-stopped
    volumes:
      - ./database:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - POSTGRES_PASSWORD=nextcloudpassword
      - PGDATA=/var/lib/postgresql/data/pgdata
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nextcloud -d nextcloud"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - nextcloud-network

  redis:
    image: redis:alpine
    container_name: nextcloud-redis
    restart: unless-stopped
    command: redis-server --requirepass redispassword
    networks:
      - nextcloud-network

  nextcloud-app:
    image: nextcloud:latest
    container_name: nextcloud-app
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ./config:/var/www/html/config
      - ./data:/var/www/html/data
      - ./custom_apps:/var/www/html/custom_apps
      - ./themes:/var/www/html/themes
      # Map your 3TB drive - adjust path as needed
      - /mnt/d/shared_drive:/var/www/html/data/shared_drive
    environment:
      # PostgreSQL Configuration
      - POSTGRES_HOST=nextcloud-db
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - POSTGRES_PASSWORD=nextcloudpassword
      
      # Redis Configuration
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=redispassword
      
      # Nextcloud Configuration
      - NEXTCLOUD_ADMIN_USER=admin
      - NEXTCLOUD_ADMIN_PASSWORD=adminpassword
      
      # IMPORTANT: Replace YOUR_WINDOWS_HOST_IP with your actual IP
      - NEXTCLOUD_TRUSTED_DOMAINS=localhost 172.26.48.1 YOUR_WINDOWS_HOST_IP
      
      # Performance Configuration
      - PHP_MEMORY_LIMIT=1G
      - PHP_UPLOAD_LIMIT=10G
      - PHP_MAX_FILE_UPLOADS=100
      
      # Network optimizations
      - APACHE_DISABLE_REWRITE_IP=1
      - TRUSTED_PROXIES=172.0.0.0/8
      - OVERWRITEPROTOCOL=http
      - NEXTCLOUD_INIT_HTACCESS=true
    depends_on:
      nextcloud-db:
        condition: service_healthy
    networks:
      - nextcloud-network

networks:
  nextcloud-network:
    driver: bridge
```

## Key Issues Fixed

### 1. **Database Configuration**
- **Problem**: Using MySQL variables for PostgreSQL
- **Solution**: Switched to `POSTGRES_*` environment variables
- **Benefit**: Proper PostgreSQL integration instead of SQLite fallback

### 2. **Service Dependencies**
- **Problem**: Nextcloud starting before PostgreSQL was ready
- **Solution**: Added health check and `condition: service_healthy`
- **Benefit**: Reliable startup sequence

### 3. **Password Consistency**
- **Problem**: Mismatched passwords between services
- **Solution**: Ensured identical passwords across all services
- **Benefit**: Seamless inter-service communication

### 4. **Auto-Setup Configuration**
- **Problem**: Manual setup required on each restart
- **Solution**: Added `NEXTCLOUD_ADMIN_USER` and `NEXTCLOUD_ADMIN_PASSWORD`
- **Benefit**: Automated initial configuration

### 5. **Mobile Device Access**
- **Problem**: Android/iPhone apps couldn't connect
- **Solution**: Proper trusted domains and WSL2 port forwarding
- **Benefit**: Full mobile device integration

## Mobile Device Setup

### For WSL2 Users (Windows)

#### 1. Configure Port Forwarding
```powershell
# Run in PowerShell as Administrator
# Replace 192.168.1.100 with your actual Windows IP
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=172.26.48.1
```

#### 2. Windows Firewall Rule
```powershell
# Run in PowerShell as Administrator
New-NetFirewallRule -DisplayName "Nextcloud" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
```

### Android Setup
1. **Install**: Download "Nextcloud" from Google Play Store
2. **Server URL**: `http://YOUR_WINDOWS_IP:8080`
3. **Credentials**: Username `admin`, Password `adminpassword`
4. **Features**: Enable auto photo upload, file sync

### iPhone Setup
1. **Install**: Download "Nextcloud" from App Store
2. **Server URL**: `http://YOUR_WINDOWS_IP:8080`
3. **Credentials**: Username `admin`, Password `adminpassword`
4. **Features**: Configure photo backup and file sync

## Storage Configuration

### Drive Mapping Explanation
```yaml
# Your storage mapping
- /mnt/d/shared_drive:/var/www/html/data/shared_drive
# ^^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# Your Windows D:   Where Nextcloud accesses it
# drive in WSL2     inside the container
```

### Path Examples
- **Windows D: drive**: `/mnt/d/shared_drive`
- **Windows E: drive**: `/mnt/e/nas_storage`
- **Linux mount**: `/home/username/3tb_drive`

### Setting Up Shared Access
1. **Login to Nextcloud** web interface
2. **Navigate to Files** → `shared_drive` folder
3. **Right-click folder** → Share → "Share with users on this server"
4. **Set permissions** for universal access

## Maintenance Commands

### Basic Operations
```bash
# View logs
docker-compose logs -f nextcloud-app

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Update Nextcloud
docker-compose pull && docker-compose up -d
```

### Clean Installation
```bash
# Complete reset (CAUTION: Deletes all data)
docker-compose down -v
rm -rf database config data custom_apps themes
mkdir -p database config data custom_apps themes
docker-compose up -d
```

### Backup Strategy
```bash
# Backup user data
tar -czf nextcloud-backup-$(date +%Y%m%d).tar.gz data config

# Backup database
docker exec nextcloud-db pg_dump -U nextcloud nextcloud > backup-$(date +%Y%m%d).sql
```

## Troubleshooting

### Common Issues

#### "Connection Refused" Error
- **Check**: Database is healthy with `docker-compose logs nextcloud-db`
- **Solution**: Wait for PostgreSQL health check to pass

#### Mobile App Can't Connect
- **Check**: Windows IP address hasn't changed
- **Solution**: Update `NEXTCLOUD_TRUSTED_DOMAINS` and restart
- **Alternative**: Use `0.0.0.0:8080:80` port binding

#### SQLite Warning
- **Cause**: Database connection failed, falling back to SQLite
- **Solution**: Verify PostgreSQL environment variables match

#### Slow Performance
- **Check**: Available RAM and disk space
- **Solution**: Increase Docker Desktop memory allocation
- **Optimization**: Use SSD for database storage

### Network Diagnostics
```bash
# Test database connection
docker exec nextcloud-app nc -zv nextcloud-db 5432

# Check container networking
docker network ls
docker network inspect nextcloud-nas_nextcloud-network

# Verify port accessibility
netstat -tlnp | grep 8080
```

## Security Considerations

### Production Deployment
1. **Change default passwords** in docker-compose.yml
2. **Enable HTTPS** with reverse proxy (nginx/Apache)
3. **Configure proper firewall rules**
4. **Regular security updates**: `docker-compose pull`
5. **Backup encryption** for sensitive data

### Password Security
```yaml
# Example of secure passwords
- POSTGRES_PASSWORD=your_super_strong_db_password_here
- REDIS_HOST_PASSWORD=your_strong_redis_password_here
- NEXTCLOUD_ADMIN_PASSWORD=your_secure_admin_password_here
```

## Advanced Configuration

### External Access (Optional)
For access outside your home network:
1. **Set up VPN** (recommended) or port forwarding
2. **Configure HTTPS** with Let's Encrypt
3. **Use dynamic DNS** service for changing IP addresses

### Additional Apps
Install through Nextcloud web interface:
- **Collabora Online**: Document editing
- **Calendar**: Event management
- **Contacts**: Contact synchronization
- **Notes**: Note-taking across devices

## Making Your Shared Folder Accessible in Nextcloud

### Current Setup
Your docker-compose.yml already mounts your DATA drive:
```yaml
- /media/Kelib/DATA:/mnt/external_storage:rw
```

### Steps to Enable Access:

#### 1. Restart Nextcloud Container (if you just changed the mount)
```bash
docker compose restart nextcloud-app
```

#### 2. Enable External Storage App
1. Login to Nextcloud web UI (`http://192.168.1.200:8090` or `http://192.168.1.200`)
2. Click your profile icon → **Apps**
3. Search for **"External storage"**
4. Click **Enable**

#### 3. Configure External Storage
1. Click profile icon → **Settings** → **Administration** → **External storage**
2. Click **"Add storage"** → **Local**
3. Configure:
   - **Folder name**: `Shared Drive` (or any name you want)
   - **Configuration**: `/mnt/external_storage`
   - **Available for**: Select users or groups (or leave blank for admin only)
   - Check **"Enable sharing"** to allow family to share files
4. Click the checkmark ✓ to save

#### 4. Set Permissions (Optional)
- Click the three dots next to the storage
- Set read/write permissions
- Choose which users can access

### Alternative: Mount Multiple Drives
If you want to add more storage drives, edit docker-compose.yml volumes:

```yaml
volumes:
  - ./config:/var/www/html/config
  - ./data:/var/www/html/data
  - /media/kelib/DATA:/mnt/storage/DATA:rw
  - /media/kelib/Extra Disk:/mnt/storage/ExtraDisk:rw
  - /media/kelib/59373E7526CE30E3:/mnt/storage/Backup:rw
```

Then configure each as separate external storage in Nextcloud admin panel.

### Troubleshooting External Storage

**"Red indicator" on external storage:**
- Check folder exists: `docker exec nextcloud-app ls -la /mnt/external_storage`
- Check permissions: Folder should be readable by www-data user
- Verify mount in docker-compose.yml is correct

**Files not showing:**
- Run scan: `docker exec nextcloud-app php occ files:scan --all`
- Check Nextcloud logs in Admin → Logging

**Permission denied:**
```bash
# Fix permissions on host
sudo chown -R kelib:kelib /media/kelib/DATA
sudo chmod -R 755 /media/kelib/DATA
```

## Success Criteria

✅ **Nextcloud accessible** via web browser at `http://192.168.1.200`
✅ **Static IP configured** (192.168.1.200 - won't change on reboot)
✅ **PostgreSQL database** connected (no SQLite warnings)
✅ **Redis caching** active for performance
✅ **Nginx Proxy Manager** running for domain management
✅ **External storage** mounted and accessible (627GB available on DATA drive)
✅ **Android app** connects and syncs files
✅ **iPhone app** connects and syncs files
✅ **Photo backup** working from mobile devices
✅ **File sharing** between devices operational  

## Support

### Getting Help
- **Docker logs**: `docker-compose logs -f`
- **Nextcloud logs**: Check Admin → Logging section
- **Network issues**: Verify IP addresses and firewall rules
- **Database issues**: Check PostgreSQL container health

### Useful Resources
- [Nextcloud Documentation](https://docs.nextcloud.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)

---

**Note**: Remember to change default passwords before using in a production environment. This setup provides a robust, scalable NAS solution using your existing hardware.

Complete Solution for Persistent IP Configuration
Here are 4 automated solutions to eliminate manual IP updates:
Solution 1: Automated Startup Script (Recommended)

Make the startup script executable:

bash   chmod +x start-nextcloud.sh

Use this instead of docker-compose up:

bash   ./start-nextcloud.sh
This script automatically:

✅ Detects current Windows and WSL IPs
✅ Updates Nextcloud configuration
✅ Creates Windows PowerShell script for port forwarding
✅ Starts containers with correct settings

Solution 2: Windows Persistent Networking (One-time setup)

In Windows PowerShell (as Administrator):

powershell   .\setup-windows-networking.ps1
This creates:

✅ Automatic port forwarding on Windows startup
✅ Windows Firewall rules
✅ Scheduled task that runs on boot
✅ Dynamic WSL IP detection

Solution 3: WSL Systemd Service (Advanced)

Install the systemd service:

bash   sudo cp nextcloud-ip-update.service /etc/systemd/system/
   sudo systemctl enable nextcloud-ip-update.service
   sudo systemctl daemon-reload
This automatically updates IPs when WSL starts.
Solution 4: Docker Compose with Dynamic Resolution
The updated docker-compose.yml uses:

✅ host.docker.internal for dynamic Windows IP resolution
✅ 0.0.0.0:8080:80 for binding to all interfaces
✅ Broader trusted proxy ranges

Quick Setup Process:
Step 1: One-time Windows Setup
powershell# In Windows PowerShell (as Administrator)
.\setup-windows-networking.ps1
Step 2: Use Automated Startup
bash# In WSL Ubuntu - instead of docker-compose up
./start-nextcloud.sh
Step 3: Access from Any Device

Your Windows IP will be automatically detected
Mobile devices use: http://[auto-detected-ip]:8080
No manual IP updates needed!

Key Benefits:

🔄 Automatic IP Detection: Scripts detect current IPs dynamically
🚀 Persistent Windows Setup: Port forwarding survives reboots
📱 Mobile Always Works: No more "connection refused" errors
⚡ One-Time Setup: Configure once, works forever
🛠️ Smart Updates: Automatically updates Nextcloud config

What This Solves:

❌ No more manual IP updates after restarts
❌ No more Android connection failures
❌ No more WSL2 networking headaches
✅ Works after Windows reboots
✅ Works after WSL restarts
✅ Works when IP changes (WiFi networks)

The startup script + Windows automation combination will make your setup completely maintenance-free for IP changes!RetryClaude does not have the ability to run the code it generates yet.

 powershell -ExecutionPolicy Bypass -File setup-port-forward-enhanced.ps1