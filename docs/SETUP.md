# Complete Setup Guide

## Prerequisites

### System Requirements
- **Operating System:** DeepinOS, Ubuntu, or Windows with WSL2
- **Docker:** version 20.10+
- **Docker Compose:** version 1.29+
- **Storage:** 3TB+ available space
- **Network:** Local network access (WiFi/Ethernet)
- **RAM:** 4GB minimum (8GB recommended)

### Software Installation

#### On DeepinOS/Ubuntu:
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install docker.io docker-compose -y

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
```

#### On Windows (WSL2):
1. Install Docker Desktop from docker.com
2. Enable WSL2 integration
3. Install Ubuntu from Microsoft Store

---

## Project Setup

### 1. Download Project
```bash
# Navigate to projects directory
cd ~/Desktop/projects

# Clone or create project directory
git clone <your-repo> home-nextcloud
# OR
mkdir home-nextcloud && cd home-nextcloud
```

### 2. Create Directory Structure
```bash
# Create required directories
mkdir -p database config data custom_apps themes nginx-proxy-manager/data nginx-proxy-manager/letsencrypt scripts
```

### 3. Create Docker Compose File

Create `docker-compose.yml` with the current configuration (see project root).

Key services:
- **nextcloud-db:** PostgreSQL database
- **redis:** Caching layer
- **nextcloud-app:** Main Nextcloud application
- **nginx-proxy-manager:** Reverse proxy for domain management

---

## Initial Deployment

### 1. Start Services
```bash
docker compose up -d
```

### 2. Check Container Status
```bash
docker compose ps
```

All containers should show "Up" status.

### 3. View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f nextcloud-app
```

---

## First-Time Configuration

### 1. Access Nextcloud Web UI
Open browser and navigate to:
- `http://192.168.1.200:8090`

### 2. Create Admin Account
If prompted (first install):
- **Username:** admin (or your choice)
- **Password:** Choose strong password
- **Database:** Should auto-detect PostgreSQL
  - User: `nextcloud`
  - Password: `nextcloudpassword`
  - Database: `nextcloud`
  - Host: `nextcloud-db`

### 3. Initial Settings
- **Data folder:** `/var/www/html/data` (default)
- **Database:** PostgreSQL (already configured)
- **Apps:** Install recommended apps (Calendar, Contacts, etc.)

---

## Network Configuration

### Configure Static IP
```bash
# Check current connection
nmcli connection show

# Set static IP (already done for LiliesLink)
nmcli connection modify LiliesLink ipv4.method manual \
  ipv4.addresses 192.168.1.200/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "192.168.1.1"

# Apply changes
nmcli connection up LiliesLink
```

### Configure Trusted Domains
```bash
# Add static IP to trusted domains
docker exec nextcloud-app php occ config:system:set trusted_domains 3 --value=192.168.1.200
docker exec nextcloud-app php occ config:system:set trusted_domains 4 --value=192.168.1.200:8090
```

See [Networking Guide](NETWORKING.md) for detailed network configuration.

---

## Nginx Proxy Manager Setup

### 1. Access NPM Admin
Navigate to: `http://192.168.1.200:81`

**Default credentials:**
- Email: `admin@example.com`
- Password: `changeme`

**⚠️ Change password immediately!**

### 2. Create Proxy Host
- Dashboard → Proxy Hosts → Add Proxy Host
- **Domain:** `192.168.1.200` or `nextcloud.local`
- **Forward to:** `nextcloud-app` port `80`
- Enable: Cache Assets, Block Exploits, Websockets

See [Networking Guide](NETWORKING.md#nginx-proxy-manager-setup) for detailed steps.

---

## Storage Configuration

### Mount External Drive
```bash
# Verify drive is mounted
df -h | grep /media/kelib/DATA

# Check docker-compose.yml has volume mount
# - /media/Kelib/DATA:/mnt/external_storage:rw
```

### Configure External Storage App
1. Apps → Enable "External storage"
2. Settings → Administration → External storage
3. Add Local storage:
   - Folder: `Shared Drive`
   - Path: `/mnt/external_storage`
   - Available for: All users

See [Storage Guide](STORAGE.md) for detailed configuration.

---

## Performance Optimization

### Verify Redis Caching
```bash
# Check Redis connection
docker exec nextcloud-app redis-cli -h redis -a redispassword ping

# Should return: PONG
```

### Configure Cron Jobs
```bash
# In Nextcloud: Settings → Basic settings
# Background jobs → Select "Cron"

# Add to host crontab:
crontab -e

# Add line:
*/5 * * * * docker exec -u www-data nextcloud-app php -f /var/www/html/cron.php
```

### PHP Settings (Already Configured)
- Memory: 1GB
- Upload limit: 10GB
- Max file uploads: 100

---

## Verification Checklist

### Services Running
```bash
docker compose ps
```

✅ All containers should be "Up"

### Database Connection
```bash
docker exec nextcloud-app php occ db:convert-type
```

Should show PostgreSQL (not SQLite)

### Web Access
- ✅ `http://192.168.1.200:8090` → Nextcloud
- ✅ `http://192.168.1.200:81` → NPM Admin
- ✅ `http://192.168.1.200` → Nextcloud (after NPM proxy)

### Mobile Access
- ✅ Android app connects to `http://192.168.1.200`
- ✅ iPhone app connects to `http://192.168.1.200`

---

## Maintenance Commands

### Update Containers
```bash
# Pull latest images
docker compose pull

# Recreate containers
docker compose up -d
```

### Backup
```bash
# Backup data and config
tar -czf nextcloud-backup-$(date +%Y%m%d).tar.gz data config

# Backup database
docker exec nextcloud-db pg_dump -U nextcloud nextcloud > backup-$(date +%Y%m%d).sql
```

### Restart Services
```bash
# All services
docker compose restart

# Specific service
docker compose restart nextcloud-app
```

### Clean Restart
```bash
# Stop all
docker compose down

# Start all
docker compose up -d
```

---

## Troubleshooting Initial Setup

### Containers Won't Start
```bash
# Check logs
docker compose logs

# Check port conflicts
sudo netstat -tlnp | grep -E "80|8090|81|443"
```

### Database Connection Failed
```bash
# Check PostgreSQL health
docker exec nextcloud-db pg_isready -U nextcloud

# Verify environment variables match between services
docker compose config | grep -A 5 POSTGRES
```

### Can't Access Web UI
```bash
# Check firewall
sudo ufw status
sudo ufw allow 8090/tcp
sudo ufw allow 80/tcp
sudo ufw allow 81/tcp

# Check if bound to correct interface
docker port nextcloud-app
```

### Permission Errors
```bash
# Fix ownership
sudo chown -R 33:33 data config

# Or match your user
sudo chown -R kelib:kelib data config
```

---

## Post-Installation

### 1. Install Essential Apps
- External Storage (for drives)
- Calendar (family calendar sync)
- Contacts (contact sync)
- Memories (photo management)

See [Apps Guide](APPS.md)

### 2. Configure Security
- Change default passwords
- Enable 2FA (Two-Factor Authentication)
- Review security warnings in Admin panel

See [Security Guide](SECURITY.md)

### 3. Setup Mobile Devices
- Install Nextcloud apps
- Configure auto-upload
- Setup DAVx⁵ for contacts/calendar

See [Networking Guide](NETWORKING.md#mobile-device-setup)

---

## Related Documentation
- [Network Configuration](NETWORKING.md)
- [Storage Setup](STORAGE.md)
- [Apps & Extensions](APPS.md)
- [Security Guide](SECURITY.md)
- [Troubleshooting](TROUBLESHOOTING.md)
