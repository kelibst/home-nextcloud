# Storage & External Drives Configuration

## Overview
Configure external storage drives to make your files accessible through Nextcloud. This allows your family to access existing files without moving them.

## Current Setup

Your docker-compose.yml mounts your DATA drive:
```yaml
- /media/Kelib/DATA:/mnt/external_storage:rw
```

**Available Storage:**
- `/media/kelib/DATA` - 932GB (627GB free)
- `/media/kelib/Extra Disk` - 299GB (176GB free)
- `/media/kelib/59373E7526CE30E3` - 932GB (367GB free)

---

## Method 1: Single External Drive (Current Setup)

### Step 1: Restart Nextcloud Container
```bash
docker compose restart nextcloud-app
```

### Step 2: Enable External Storage App
1. Login to Nextcloud web UI (`http://192.168.1.200:8090`)
2. Click profile icon → **Apps**
3. Search for **"External storage"**
4. Click **Enable**

### Step 3: Configure External Storage
1. Click profile icon → **Settings** → **Administration** → **External storage**
2. Click **"Add storage"** → **Local**
3. Configure:
   - **Folder name**: `Shared Drive` (or any name)
   - **Configuration**: `/mnt/external_storage`
   - **Available for**: Select users/groups (or blank for admin only)
   - **Enable sharing**: ✓ (to allow family to share files)
4. Click checkmark ✓ to save

### Step 4: Verify Access
- Green indicator = working correctly
- Red indicator = see troubleshooting below

---

## Method 2: Multiple Drives

### Update docker-compose.yml

Add multiple volume mounts:

```yaml
volumes:
  - ./config:/var/www/html/config
  - ./data:/var/www/html/data
  - ./custom_apps:/var/www/html/custom_apps
  - ./themes:/var/www/html/themes
  - /media/kelib/DATA:/mnt/storage/DATA:rw
  - /media/kelib/Extra Disk:/mnt/storage/ExtraDisk:rw
  - /media/kelib/59373E7526CE30E3:/mnt/storage/Backup:rw
```

### Restart Container
```bash
docker compose restart nextcloud-app
```

### Add Each Drive in Nextcloud
Repeat External Storage configuration for each:
- Drive 1: `/mnt/storage/DATA` → "Main Storage"
- Drive 2: `/mnt/storage/ExtraDisk` → "Extra Disk"
- Drive 3: `/mnt/storage/Backup` → "Backup Drive"

---

## Method 3: Dedicated Shared Folder

Create a specific folder for Nextcloud sharing:

### On Host System
```bash
mkdir -p /media/kelib/DATA/nextcloud-shared
sudo chown -R kelib:kelib /media/kelib/DATA/nextcloud-shared
```

### Update docker-compose.yml
```yaml
volumes:
  - /media/kelib/DATA/nextcloud-shared:/var/www/html/data/shared:rw
```

### Restart and Access
```bash
docker compose restart nextcloud-app
```

Files will appear directly in Nextcloud Files under `/shared` folder.

---

## User Permissions

### Make Storage Available to Specific Users
1. External storage admin panel
2. Under "Available for" column
3. Select users or groups
4. Click checkmark to save

### Share Folders with Family
1. Navigate to the external storage folder
2. Click share icon
3. Add users or create share link
4. Set permissions (read-only, edit, upload)

---

## Troubleshooting

### "External mount error" Message

If you see this error when accessing external storage in Nextcloud, it indicates the mount point is not accessible or has incorrect permissions.

**Common Causes:**
1. Directory owned by root instead of www-data
2. Missing write permissions for www-data user
3. Directory not mounted correctly
4. Empty or non-existent directory

**Quick Fix:**
```bash
# Fix ownership to www-data
docker exec nextcloud-app chown -R www-data:www-data /mnt/external_storage

# Verify it works
docker exec -u www-data nextcloud-app php /var/www/html/occ files_external:verify 1
```

Expected output: `status: ok`

---

### Red Indicator on External Storage

This usually indicates a permissions issue. The Nextcloud process runs as `www-data` (UID 33) and needs write access to the mounted directory.

**Step 1: Check if folder exists:**
```bash
docker exec nextcloud-app ls -la /mnt/external_storage
```

**Step 2: Check permissions and ownership:**
```bash
# Check who owns the directory inside the container
docker exec nextcloud-app ls -lan /mnt/external_storage

# Check the www-data user ID
docker exec nextcloud-app id www-data
```

**Step 3: Fix permissions (REQUIRED):**
```bash
# Change ownership to www-data inside the container
docker exec nextcloud-app chown -R www-data:www-data /mnt/external_storage

# Verify the fix
docker exec -u www-data nextcloud-app touch /mnt/external_storage/test_file
docker exec -u www-data nextcloud-app rm /mnt/external_storage/test_file
```

**Step 4: Verify the mount:**
```bash
# Check external storage status
docker exec -u www-data nextcloud-app php /var/www/html/occ files_external:list

# Verify specific mount (replace 1 with your mount ID)
docker exec -u www-data nextcloud-app php /var/www/html/occ files_external:verify 1
```

**Alternative: Fix host permissions (if container fix doesn't work):**
```bash
sudo chown -R kelib:kelib /media/kelib/DATA
sudo chmod -R 755 /media/kelib/DATA
```

**Verify mount in container:**
```bash
docker exec nextcloud-app df -h | grep /mnt
```

### Files Not Showing

**Run file scan:**
```bash
docker exec nextcloud-app php occ files:scan --all
```

**Check specific user:**
```bash
docker exec nextcloud-app php occ files:scan admin
```

### Permission Denied Errors

**Understanding the Issue:**
The problem occurs because Docker mounts the host directory with the host's user permissions, but Nextcloud inside the container runs as `www-data` (UID 33). If the mounted directory is owned by root (UID 0), www-data cannot write to it.

**Option 1: Fix inside container (RECOMMENDED)**
```bash
# Change ownership to www-data inside the container
docker exec nextcloud-app chown -R www-data:www-data /mnt/external_storage

# Test write access
docker exec -u www-data nextcloud-app touch /mnt/external_storage/test_file && \
  echo "Success! Write access confirmed."
```

**Option 2: Fix host permissions**
```bash
sudo chown -R kelib:kelib /media/kelib/DATA
sudo chmod -R 755 /media/kelib/DATA
```

**Option 3: Match Docker user ID (advanced)**
```bash
# Check www-data UID in container
docker exec nextcloud-app id www-data

# If needed, adjust host permissions to match (UID 33)
sudo chown -R 33:33 /media/kelib/DATA
```

**Permanent Solution:**
Add this to your docker-compose.yml under the nextcloud-app service:
```yaml
user: "33:33"  # Run as www-data
```
Then restart: `docker compose restart nextcloud-app`

### Slow Performance

**Enable Redis caching** (already configured):
- Check redis is running: `docker ps | grep redis`
- Verify in Nextcloud: Settings → Overview → "Memory cache configured"

**Use SSD for database:**
- Move `./database` folder to SSD
- Update docker-compose.yml path

---

## Backup Strategy

### Backup External Storage Configuration
```bash
# Backup Nextcloud config
cp -r config config-backup-$(date +%Y%m%d)

# Or export specific settings
docker exec nextcloud-app php occ config:list > nextcloud-config-$(date +%Y%m%d).json
```

### Restore Configuration
```bash
docker exec nextcloud-app php occ config:import < nextcloud-config.json
```

---

## Advanced: Auto-Mount on Boot

Create systemd mount unit (optional):

```bash
sudo nano /etc/systemd/system/media-kelib-DATA.mount
```

```ini
[Unit]
Description=Mount DATA drive for Nextcloud
Before=docker.service

[Mount]
What=/dev/sda1
Where=/media/kelib/DATA
Type=ntfs
Options=defaults,uid=1000,gid=1000

[Install]
WantedBy=multi-user.target
```

Enable:
```bash
sudo systemctl daemon-reload
sudo systemctl enable media-kelib-DATA.mount
```

---

## Related Documentation
- [Complete Setup Guide](SETUP.md)
- [Nextcloud Apps](APPS.md)
- [Troubleshooting](TROUBLESHOOTING.md)
