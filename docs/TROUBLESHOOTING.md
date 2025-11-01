# Troubleshooting Guide

## Quick Diagnostics

### Check Service Status
```bash
# All containers
docker compose ps

# View logs
docker compose logs -f

# Specific service logs
docker compose logs -f nextcloud-app
docker compose logs -f nextcloud-db
docker compose logs -f nginx-proxy-manager
```

---

## Common Issues

### 1. Cannot Access Nextcloud Web UI

#### Symptoms
- Browser shows "Connection refused" or "Site can't be reached"
- Timeout when accessing `http://192.168.1.200:8090`

#### Solutions

**Check containers are running:**
```bash
docker compose ps
```

**Verify port bindings:**
```bash
docker port nextcloud-app
# Should show: 80/tcp -> 0.0.0.0:8090
```

**Check firewall:**
```bash
sudo ufw status
sudo ufw allow 8090/tcp
sudo ufw allow 80/tcp
```

**Test local access:**
```bash
curl -I http://localhost:8090
curl -I http://192.168.1.200:8090
```

**Restart services:**
```bash
docker compose restart nextcloud-app
```

---

### 2. "Trusted Domain" Error

#### Symptoms
- "Access through untrusted domain" error
- Cannot access from mobile device

#### Solutions

**View current trusted domains:**
```bash
docker exec nextcloud-app php occ config:system:get trusted_domains
```

**Add your IP/domain:**
```bash
docker exec nextcloud-app php occ config:system:set trusted_domains 6 --value=YOUR_IP_HERE
```

**Add multiple domains:**
```bash
docker exec nextcloud-app php occ config:system:set trusted_domains 7 --value=nextcloud.local
docker exec nextcloud-app php occ config:system:set trusted_domains 8 --value=192.168.1.200:8090
```

---

### 3. Database Connection Issues

#### Symptoms
- "Error while trying to connect to the database"
- Nextcloud shows SQLite warning
- 500 Internal Server Error

#### Solutions

**Check PostgreSQL health:**
```bash
docker exec nextcloud-db pg_isready -U nextcloud -d nextcloud
# Should return: accepting connections
```

**Verify database credentials:**
```bash
# Check environment variables
docker compose config | grep POSTGRES

# Should match in both nextcloud-db and nextcloud-app
```

**Check database logs:**
```bash
docker logs nextcloud-db
```

**Restart database:**
```bash
docker compose restart nextcloud-db
# Wait for health check
docker compose logs nextcloud-db | grep "ready to accept"
```

**Test connection from Nextcloud:**
```bash
docker exec nextcloud-app nc -zv nextcloud-db 5432
```

---

### 4. Redis Connection Failed

#### Symptoms
- Warning about file locking
- Slow performance
- "Redis server went away" error

#### Solutions

**Check Redis is running:**
```bash
docker ps | grep redis
```

**Test Redis connection:**
```bash
docker exec nextcloud-app redis-cli -h redis -a redispassword ping
# Should return: PONG
```

**Check Redis logs:**
```bash
docker logs nextcloud-redis
```

**Verify configuration:**
```bash
docker exec nextcloud-app php occ config:system:get redis
```

**Restart Redis:**
```bash
docker compose restart redis
```

---

### 5. Mobile App Cannot Connect

#### Symptoms
- "Unable to connect to server"
- "Invalid server URL"
- Sync not working

#### Android Solutions

**1. Verify server URL:**
- Must be: `http://192.168.1.200` (no port, no trailing slash)
- Or: `http://192.168.1.200:8090` for direct access

**2. Check same WiFi network:**
```bash
# On phone, ping the server
# Use Network Analyzer app
ping 192.168.1.200
```

**3. Add trusted domain:**
```bash
docker exec nextcloud-app php occ config:system:set trusted_domains 9 --value=192.168.1.200
```

**4. Clear app cache:**
- Android: Settings → Apps → Nextcloud → Storage → Clear Cache

#### iPhone Solutions

**1. Use HTTP (not HTTPS) for local:**
- Server: `http://192.168.1.200`

**2. Trust certificate (if using HTTPS):**
- Settings → General → About → Certificate Trust Settings

**3. Check iOS restrictions:**
- Settings → Screen Time → Content Restrictions → Allow HTTP

---

### 6. External Storage Mount Error

#### Symptoms
- "External mount error" popup in Nextcloud
- Red indicator on external storage
- Folder not visible or accessible in Files
- "Storage not available" error

#### Root Cause
The most common issue is **permissions**. Nextcloud runs as `www-data` (UID 33) inside the container, but the mounted directory is owned by root (UID 0) and lacks write permissions for www-data.

#### Quick Fix (RECOMMENDED)
```bash
# Fix ownership inside the container
docker exec nextcloud-app chown -R www-data:www-data /mnt/external_storage

# Verify the fix
docker exec -u www-data nextcloud-app php /var/www/html/occ files_external:verify 1
# Expected: status: ok
```

#### Diagnostic Steps

**1. Check mount exists in container:**
```bash
docker exec nextcloud-app ls -la /mnt/external_storage
```

**2. Check ownership and permissions:**
```bash
# Numeric UIDs (should show 33:33 for www-data)
docker exec nextcloud-app ls -lan /mnt/external_storage

# Check www-data UID
docker exec nextcloud-app id www-data
# Expected: uid=33(www-data) gid=33(www-data)
```

**3. Test write access:**
```bash
# Try to create a file as www-data
docker exec -u www-data nextcloud-app touch /mnt/external_storage/test_file

# If successful, clean up
docker exec -u www-data nextcloud-app rm /mnt/external_storage/test_file
```

**4. Verify host path exists:**
```bash
ls -la /media/kelib/DATA
```

#### Alternative Solutions

**If container fix doesn't work, try host permissions:**
```bash
sudo chmod -R 755 /media/kelib/DATA
sudo chown -R kelib:kelib /media/kelib/DATA
```

**Rescan files after fixing:**
```bash
docker exec -u www-data nextcloud-app php /var/www/html/occ files:scan --all
```

**Check external storage configuration:**
```bash
# List all external mounts
docker exec -u www-data nextcloud-app php /var/www/html/occ files_external:list

# Verify specific mount (replace 1 with mount ID)
docker exec -u www-data nextcloud-app php /var/www/html/occ files_external:verify 1
```

**Re-mount volume (last resort):**
```bash
# Edit docker-compose.yml to fix volume path if needed
docker compose down
docker compose up -d
```

**Permanent fix - Run container as www-data:**
Add to `docker-compose.yml` under `nextcloud-app` service:
```yaml
user: "33:33"
```
Then restart: `docker compose restart nextcloud-app`

See [Storage Documentation](STORAGE.md#external-mount-error-message) for more details.

---

### 7. Upload Issues

#### Symptoms
- Large file upload fails
- "File too large" error
- Upload stuck at certain percentage

#### Solutions

**Check PHP upload limits (already set to 10GB):**
```bash
docker exec nextcloud-app php -i | grep upload_max_filesize
docker exec nextcloud-app php -i | grep post_max_size
```

**Increase if needed (edit docker-compose.yml):**
```yaml
environment:
  - PHP_UPLOAD_LIMIT=20G
```

**Check disk space:**
```bash
df -h | grep -E "data|DATA"
```

**Chunked upload for large files:**
- Nextcloud web: Automatically enabled
- Mobile: Settings → Upload → Use chunked uploads

**Clear upload cache:**
```bash
docker exec nextcloud-app php occ files:cleanup
```

---

### 8. Slow Performance

#### Symptoms
- Pages load slowly
- File browsing is sluggish
- High CPU usage

#### Solutions

**1. Verify Redis caching:**
```bash
docker exec nextcloud-app php occ config:system:get memcache.local
# Should return: \OC\Memcache\Redis
```

**2. Enable PHP opcache (check if enabled):**
```bash
docker exec nextcloud-app php -i | grep opcache.enable
```

**3. Background jobs via cron:**
```bash
# Add to host crontab
crontab -e
```
```
*/5 * * * * docker exec -u www-data nextcloud-app php -f /var/www/html/cron.php
```

**4. Database optimization:**
```bash
# Add missing indices
docker exec nextcloud-app php occ db:add-missing-indices

# Convert filecache to bigint
docker exec nextcloud-app php occ db:convert-filecache-bigint
```

**5. Preview generation:**
```bash
# Generate previews for existing files
docker exec nextcloud-app php occ preview:generate-all
```

**6. Check system resources:**
```bash
# Container stats
docker stats

# Host resources
htop
```

---

### 9. Nginx Proxy Manager Issues

#### Symptoms
- NPM admin not accessible
- Proxy host returns 502/504 errors
- Can't create SSL certificates

#### Solutions

**Check NPM is running:**
```bash
docker ps | grep nginx-proxy-manager
docker logs nginx-proxy-manager
```

**Access NPM:**
```bash
# Ensure it's on port 81
curl -I http://192.168.1.200:81
```

**Reset admin password:**
```bash
# Stop NPM
docker compose stop nginx-proxy-manager

# Access database and reset
docker compose run --rm nginx-proxy-manager /bin/bash
# Inside container: node /app/setup.js

# Restart
docker compose up -d nginx-proxy-manager
```

**502 Bad Gateway:**
- Check forward host is correct: `nextcloud-app` (not IP)
- Verify Nextcloud is running
- Check Docker network connectivity:
```bash
docker exec nginx-proxy-manager ping nextcloud-app
```

---

### 10. Permission Errors

#### Symptoms
- "Permission denied" errors
- Cannot write to files
- Apps can't be installed

#### Solutions

**Fix www-data permissions:**
```bash
docker exec nextcloud-app chown -R www-data:www-data /var/www/html/data
docker exec nextcloud-app chown -R www-data:www-data /var/www/html/config
docker exec nextcloud-app chown -R www-data:www-data /var/www/html/apps
```

**Fix host permissions:**
```bash
sudo chown -R kelib:kelib ./data ./config ./custom_apps
sudo chmod -R 755 ./data ./config
```

**External storage permissions:**
```bash
sudo chown -R kelib:kelib /media/kelib/DATA
sudo chmod -R 755 /media/kelib/DATA
```

---

## Advanced Troubleshooting

### Enable Debug Mode

**Edit config.php:**
```bash
docker exec nextcloud-app nano /var/www/html/config/config.php
```

Add:
```php
'loglevel' => 0,  // 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR
```

**View debug logs:**
```bash
docker exec nextcloud-app tail -f /var/www/html/data/nextcloud.log
```

### Database Maintenance

**Run maintenance mode:**
```bash
docker exec nextcloud-app php occ maintenance:mode --on
```

**Repair database:**
```bash
docker exec nextcloud-app php occ maintenance:repair
```

**Disable maintenance:**
```bash
docker exec nextcloud-app php occ maintenance:mode --off
```

### Network Diagnostics

**Test DNS resolution:**
```bash
docker exec nextcloud-app nslookup nextcloud-db
docker exec nginx-proxy-manager nslookup nextcloud-app
```

**Check Docker network:**
```bash
docker network inspect nextcloud-network
```

**Port conflicts:**
```bash
sudo netstat -tlnp | grep -E "80|8090|81|443|5432|6379"
```

### Clean Reinstall (Last Resort)

**⚠️ This deletes all data!**

```bash
# Stop and remove containers
docker compose down -v

# Backup if needed
cp -r data data-backup-$(date +%Y%m%d)

# Remove old data
rm -rf database config data custom_apps

# Recreate directories
mkdir -p database config data custom_apps themes

# Start fresh
docker compose up -d
```

---

## Getting More Help

### Useful Commands

**Container information:**
```bash
docker inspect nextcloud-app
docker exec nextcloud-app php -i
```

**Nextcloud system info:**
```bash
docker exec nextcloud-app php occ status
docker exec nextcloud-app php occ check
```

**List all OCC commands:**
```bash
docker exec nextcloud-app php occ list
```

### Log Files

**Nextcloud log:**
```bash
docker exec nextcloud-app tail -f /var/www/html/data/nextcloud.log
```

**Web server log:**
```bash
docker exec nextcloud-app tail -f /var/log/apache2/error.log
```

**Database log:**
```bash
docker logs nextcloud-db
```

### External Resources
- [Nextcloud Admin Manual](https://docs.nextcloud.com/server/latest/admin_manual/)
- [Nextcloud Community Forum](https://help.nextcloud.com/)
- [Docker Compose Troubleshooting](https://docs.docker.com/compose/faq/)

---

## Related Documentation
- [Setup Guide](SETUP.md)
- [Network Configuration](NETWORKING.md)
- [Storage Setup](STORAGE.md)
- [Security Guide](SECURITY.md)
