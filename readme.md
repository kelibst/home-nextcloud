# 🏠 Easy Nextcloud NAS Setup - Complete Home Cloud Solution

Transform your computer into a powerful home NAS (Network Attached Storage) with automatic mobile access, file sharing, and photo backup - all using Docker containers with **zero manual configuration**.

[![Docker](https://img.shields.io/badge/Docker-Required-blue)](https://www.docker.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20WSL2%20%7C%20Linux%20%7C%20macOS-green)]()
[![License](https://img.shields.io/badge/License-MIT-yellow)]()

## 🚀 Quick Start (5 Minutes Setup)

**For Beginners - Just run these commands:**

```bash
# 1. Download this project
git clone <repository-url> nextcloud-nas
cd nextcloud-nas

# 2. Make scripts executable
chmod +x *.sh

# 3. Start everything automatically
./start-nextcloud.sh
```

**That's it!** The script will:
- ✅ Detect your network automatically
- ✅ Configure all services (PostgreSQL, Redis, Nextcloud)
- ✅ Set up mobile device access
- ✅ Create Windows networking scripts
- ✅ Show you the exact URLs to use

## 📱 What You Get

- **🌐 Web Access**: Full Nextcloud interface from any browser
- **📱 Mobile Apps**: Automatic photo backup from iPhone/Android
- **💾 Shared Storage**: Access your computer's drives from anywhere
- **👥 Multi-Device**: Sync files between all your devices
- **🔒 Secure**: PostgreSQL database + Redis caching for performance
- **🔄 Automatic**: Dynamic IP detection, no manual configuration

## 📋 Table of Contents

1. [Prerequisites](#-prerequisites)
2. [Installation Methods](#-installation-methods)
3. [Shared Folder Configuration](#-shared-folder-configuration)
4. [Mobile Device Setup](#-mobile-device-setup)
5. [Access Your Files](#-access-your-files)
6. [Automation Scripts](#-automation-scripts)
7. [Maintenance](#-maintenance)
8. [Troubleshooting](#-troubleshooting)
9. [Advanced Configuration](#-advanced-configuration)

## 🔧 Prerequisites

### System Requirements
- **OS**: Windows 10/11 with WSL2, Linux (Ubuntu/Debian), or macOS
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 1GB for containers + your shared storage space
- **Network**: WiFi or Ethernet connection

### Required Software

#### Windows (WSL2) - Most Common Setup
```bash
# 1. Install Docker Desktop (download from docker.com)
# 2. Enable WSL2 (Windows Subsystem for Linux)
# 3. Install Ubuntu from Microsoft Store
# 4. Open Ubuntu terminal and run:
sudo apt update && sudo apt install git
```

#### Linux (Ubuntu/Debian)
```bash
# Install Docker and dependencies
sudo apt update
sudo apt install docker.io docker-compose git curl
sudo usermod -aG docker $USER
# Log out and back in for permissions to take effect
```

#### macOS
```bash
# Install Docker Desktop from docker.com
# Install git if needed:
brew install git
```

## 🛠️ Installation Methods

### Method 1: Automatic Setup (Recommended)

**Use the automated script that handles everything:**

```bash
# Clone and setup
git clone <repository-url> nextcloud-nas
cd nextcloud-nas
chmod +x *.sh

# Start with automatic configuration
./start-nextcloud.sh
```

The script will:
1. Detect your network IPs automatically
2. Update all configuration files
3. Start all Docker containers
4. Configure mobile access
5. Show you access URLs and login credentials

### Method 2: Manual Setup (Advanced Users)

```bash
# 1. Create project directory
mkdir nextcloud-nas && cd nextcloud-nas

# 2. Download the docker-compose.yml (see configuration section)

# 3. Create .env file with your settings
cp .env.example .env
# Edit .env with your storage path

# 4. Start containers
docker-compose up -d
```

## 📁 Shared Folder Configuration

### Easy Storage Setup

**The system automatically maps your computer's storage to Nextcloud. Here's how to customize it:**

#### 1. Choose Your Storage Location

**Windows Examples:**
```bash
# Map your D: drive
SHARED_DRIVE_PATH=/mnt/d/shared_drive

# Map specific folder on C: drive  
SHARED_DRIVE_PATH=/mnt/c/Users/YourName/Documents/NextcloudStorage

# Map external USB drive (E: drive)
SHARED_DRIVE_PATH=/mnt/e/external_storage
```

**Linux Examples:**
```bash
# Map home folder
SHARED_DRIVE_PATH=/home/yourusername/nextcloud_storage

# Map mounted external drive
SHARED_DRIVE_PATH=/media/yourusername/external_drive

# Map dedicated partition
SHARED_DRIVE_PATH=/mnt/storage
```

**macOS Examples:**
```bash
# Map external volume
SHARED_DRIVE_PATH=/Volumes/External_Drive

# Map Documents folder
SHARED_DRIVE_PATH=/Users/yourusername/Documents/NextcloudStorage
```

#### 2. Update Configuration

**Edit the `.env` file:**
```bash
# Open with any text editor
nano .env

# Update this line with your chosen path:
SHARED_DRIVE_PATH=/your/storage/path/here
```

#### 3. Restart to Apply Changes
```bash
./start-nextcloud.sh
```

### How Storage Mapping Works

```yaml
# This line in docker-compose.yml maps your storage:
- ${SHARED_DRIVE_PATH}:/mnt/external-storage:rw
#   ^^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^^^^^^^^^
#   Your computer path   Path inside Nextcloud
```

**In Nextcloud, your files appear under**: `Files → external-storage`

### Setting Up Shared Access

1. **Login to Nextcloud** web interface
2. **Navigate to Files** → `external-storage` folder  
3. **Right-click folder** → Share → Create share link
4. **Set permissions**: Download, upload, or edit
5. **Share the link** with family/friends

## 📱 Mobile Device Setup

### Automatic Mobile Configuration

**Run the mobile setup script:**
```bash
./auto-setup-mobile.sh
```

This creates a PowerShell script that automatically:
- ✅ Detects your real network IP
- ✅ Sets up Windows port forwarding
- ✅ Configures Windows Firewall
- ✅ Tests connectivity
- ✅ Shows you the exact mobile URL

### Windows PowerShell Setup (Required for Mobile Access)

**After running the mobile script, execute in Windows PowerShell as Administrator:**
```powershell
powershell -ExecutionPolicy Bypass -File setup-mobile-access.ps1
```

This will show output like:
```
✅ Selected network IP: 192.168.1.100
🔗 Setting up port forwarding...
🛡️ Configuring Windows Firewall...
📱 Use this URL on your mobile device: http://192.168.1.100:8090
```

### Mobile App Installation

#### Android Setup
1. **Download**: "Nextcloud" from Google Play Store
2. **Server URL**: Use the URL shown by the PowerShell script
3. **Login**: Username `admin`, Password `adminpassword`
4. **Enable**: Auto photo upload, file sync

#### iPhone Setup  
1. **Download**: "Nextcloud" from App Store
2. **Server URL**: Use the URL shown by the PowerShell script
3. **Login**: Username `admin`, Password `adminpassword`
4. **Configure**: Photo backup and file sync

### Mobile Troubleshooting

**If mobile devices can't connect:**
```bash
# Run the troubleshooting script
./troubleshoot-mobile.sh
```

## 🌐 Access Your Files

### Web Browser Access
- **Local**: `http://localhost:8090`
- **Network**: `http://YOUR_IP:8090` (shown by start script)
- **Login**: Username `admin`, Password `adminpassword`

### Default File Locations
- **Your Storage**: Files → `external-storage`
- **Uploaded Files**: Files → `your_username`
- **Shared Files**: Files → Shared sections

### URL Examples
```bash
# These URLs are automatically detected by the scripts:
Local:    http://localhost:8090
Network:  http://192.168.1.100:8090
Mobile:   http://192.168.1.100:8090
```

## 🤖 Automation Scripts

### Main Scripts

#### `start-nextcloud.sh` - Primary Setup Script
```bash
./start-nextcloud.sh
```
- Detects network IPs automatically
- Updates all configuration files  
- Starts Docker containers
- Configures trusted domains
- Creates Windows networking scripts
- Shows access URLs and credentials

#### `auto-setup-mobile.sh` - Mobile Device Configuration
```bash
./auto-setup-mobile.sh
```
- Detects real Windows network IP
- Creates PowerShell script for Windows networking
- Updates Nextcloud trusted domains
- Tests connectivity from different devices

#### `troubleshoot-mobile.sh` - Diagnostic Tool
```bash
./troubleshoot-mobile.sh
```
- Tests network connectivity
- Validates container status
- Checks Windows port forwarding
- Provides specific fix suggestions

#### `fix-permissions.sh` - File Permission Repair
```bash
./fix-permissions.sh
```
- Fixes Docker volume permissions
- Ensures cross-platform compatibility
- Resolves WSL2 permission issues

### Configuration Files

#### `docker-compose.yml` - Container Configuration
- **PostgreSQL**: Database backend for performance
- **Redis**: Caching for speed optimization  
- **Nextcloud**: Main application server
- **Automatic**: Health checks and dependencies

#### `.env` - Environment Variables
```bash
# Auto-generated by scripts
WINDOWS_HOST_IP=192.168.1.100
WSL_IP=172.26.58.22
NEXTCLOUD_URL=http://192.168.1.100:8090
SHARED_DRIVE_PATH=/mnt/d/shared_drive
```

## 🔄 Maintenance

### Daily Operations

#### View Status
```bash
# Check if containers are running
docker-compose ps

# View logs
docker-compose logs -f nextcloud-app
```

#### Start/Stop/Restart
```bash
# Start (using automated script)
./start-nextcloud.sh

# Stop containers
docker-compose down

# Restart containers
docker-compose restart
```

### Updates and Upgrades

#### Update Nextcloud
```bash
# Pull latest versions
docker-compose pull

# Restart with new versions
./start-nextcloud.sh
```

#### Backup Your Data
```bash
# Backup user files and configuration
tar -czf nextcloud-backup-$(date +%Y%m%d).tar.gz data config

# Backup database
docker exec nextcloud-db pg_dump -U nextcloud nextcloud > backup-$(date +%Y%m%d).sql
```

### Network Changes

**When your IP address changes (new WiFi, etc.):**
```bash
# Just run the start script again
./start-nextcloud.sh
```
The script automatically detects new IPs and updates everything.

## 🐛 Troubleshooting

### Common Issues and Solutions

#### 🔴 "Connection Refused" Error
**Problem**: Can't access Nextcloud web interface

**Solutions**:
```bash
# 1. Check if containers are running
docker-compose ps

# 2. Check container logs
docker-compose logs nextcloud-app

# 3. Restart containers
./start-nextcloud.sh

# 4. Check database health
docker exec nextcloud-db pg_isready -U nextcloud
```

#### 📱 Mobile App Can't Connect
**Problem**: Android/iPhone apps show connection errors

**Solutions**:
```bash
# 1. Run mobile troubleshooting
./troubleshoot-mobile.sh

# 2. Check Windows firewall
# Run in Windows PowerShell as Administrator:
powershell -ExecutionPolicy Bypass -File setup-mobile-access.ps1

# 3. Verify network connectivity
ping YOUR_WINDOWS_IP  # from mobile device
```

#### 🐌 Slow Performance
**Problem**: Nextcloud is running slowly

**Solutions**:
```bash
# 1. Check available resources
docker stats

# 2. Increase Docker memory (Docker Desktop → Settings → Resources)
# Recommended: 4GB+ RAM allocation

# 3. Check disk space
df -h

# 4. Restart Redis cache
docker-compose restart redis
```

#### 💾 Storage Not Accessible
**Problem**: Can't see shared folders in Nextcloud

**Solutions**:
```bash
# 1. Check storage path in .env file
cat .env

# 2. Verify path exists and has correct permissions
ls -la $SHARED_DRIVE_PATH

# 3. Fix permissions
./fix-permissions.sh

# 4. Restart containers
./start-nextcloud.sh
```

#### 🗄️ Database Connection Issues
**Problem**: SQLite warnings or database errors

**Solutions**:
```bash
# 1. Check PostgreSQL container
docker exec nextcloud-db pg_isready -U nextcloud

# 2. View database logs
docker-compose logs nextcloud-db

# 3. Reset database (CAUTION: Loses data)
docker-compose down -v
./start-nextcloud.sh
```

### Diagnostic Commands

```bash
# Network connectivity test
./troubleshoot-mobile.sh

# Container health check
docker-compose ps
docker-compose logs --tail=50 nextcloud-app

# Database connection test
docker exec nextcloud-app nc -zv nextcloud-db 5432

# File permissions check
./fix-permissions.sh

# Complete restart
docker-compose down && ./start-nextcloud.sh
```

## ⚙️ Advanced Configuration

### Performance Optimization

#### Increase Resource Limits
**Edit `docker-compose.yml`:**
```yaml
environment:
  - PHP_MEMORY_LIMIT=2G      # Increase for large files
  - PHP_UPLOAD_LIMIT=20G     # Increase for large uploads
  - PHP_MAX_FILE_UPLOADS=200 # Increase for batch uploads
```

#### SSD Storage
**For best performance, use SSD storage for:**
- Database files (`postgres_data` volume)
- Nextcloud config (`nextcloud_config` volume)
- Frequently accessed files

### Security Hardening

#### Change Default Passwords
**Edit `docker-compose.yml`:**
```yaml
environment:
  - POSTGRES_PASSWORD=your_secure_db_password_here
  - REDIS_HOST_PASSWORD=your_secure_redis_password_here  
  - NEXTCLOUD_ADMIN_PASSWORD=your_secure_admin_password_here
```

#### Enable HTTPS (Advanced)
**Add reverse proxy with SSL certificate:**
```bash
# Example with nginx-proxy-manager
# See advanced configuration guides for full setup
```

### External Access Setup

#### VPN Access (Recommended)
- Set up WireGuard or OpenVPN on your router
- Access Nextcloud securely from anywhere
- No port forwarding to internet required

#### Internet Port Forwarding (Advanced)
```bash
# Router configuration needed:
# Forward port 8090 to your computer's local IP
# Configure dynamic DNS for changing IP addresses
# Enable HTTPS for security
```

### Additional Nextcloud Apps

**Install via Nextcloud web interface (Apps section):**
- **📅 Calendar**: Event management and CalDAV sync
- **👥 Contacts**: Address book with CardDAV sync
- **📝 Notes**: Markdown note-taking
- **📄 OnlyOffice**: Document editing (Word, Excel, PowerPoint)
- **📞 Talk**: Video calls and chat
- **📸 Photos**: Advanced photo management
- **🔐 Passwords**: Password manager

### Custom Storage Locations

#### Multiple Storage Paths
**Edit `docker-compose.yml` to add multiple volumes:**
```yaml
volumes:
  - ${SHARED_DRIVE_PATH}:/mnt/primary-storage:rw
  - /mnt/backup-drive:/mnt/backup-storage:rw
  - /mnt/media-drive:/mnt/media-storage:rw
```

#### External Storage Plugin
**Configure via Nextcloud Admin → External Storage:**
- Add FTP/SFTP servers
- Connect to other cloud providers
- Mount network drives

## 📚 Useful Resources

### Official Documentation
- [Nextcloud Documentation](https://docs.nextcloud.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [PostgreSQL Docker](https://hub.docker.com/_/postgres)

### Community Support
- [Nextcloud Community](https://help.nextcloud.com/)
- [Docker Community Forums](https://forums.docker.com/)
- [Reddit r/NextCloud](https://reddit.com/r/NextCloud)

### Mobile Apps
- [Android App](https://play.google.com/store/apps/details?id=com.nextcloud.client)
- [iPhone App](https://apps.apple.com/app/nextcloud/id1125420102)

## 🎯 Success Checklist

**Your setup is working correctly when:**

- ✅ **Web Access**: Can open `http://YOUR_IP:8090` in browser
- ✅ **Login Works**: Can login with `admin` / `adminpassword`  
- ✅ **Database**: No SQLite warnings (using PostgreSQL)
- ✅ **Mobile Access**: Android/iPhone apps connect successfully
- ✅ **File Upload**: Can upload and download files via web
- ✅ **Shared Storage**: Can see `external-storage` folder
- ✅ **Photo Backup**: Mobile apps can backup photos automatically
- ✅ **Network Access**: Other devices on WiFi can access
- ✅ **Performance**: Pages load quickly (Redis caching active)

## 🚨 Important Security Notes

### Before Production Use
1. **Change all default passwords** in `docker-compose.yml`
2. **Enable 2FA** in Nextcloud Admin settings  
3. **Configure HTTPS** if accessing from internet
4. **Regular backups** of important data
5. **Keep containers updated** with `docker-compose pull`

### Network Security
- This setup is designed for **local network use**
- For internet access, use **VPN** or properly configured **HTTPS**
- **Never expose** with default passwords to the internet

---

## 💡 Quick Command Reference

```bash
# Essential commands for daily use:
./start-nextcloud.sh              # Start/restart everything
./auto-setup-mobile.sh            # Configure mobile access  
./troubleshoot-mobile.sh          # Fix mobile connection issues
docker-compose logs -f nextcloud-app  # View logs
docker-compose down               # Stop all containers
./fix-permissions.sh              # Fix file permission issues
```

**🎉 Enjoy your personal cloud storage solution!**

*This setup gives you enterprise-grade file storage and sync using just your existing computer hardware.*