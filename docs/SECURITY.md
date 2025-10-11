# Security & Best Practices

## Security Overview

This guide covers security configurations, password management, HTTPS setup, and best practices for your Nextcloud family NAS.

---

## Password Security

### Change Default Passwords

**⚠️ CRITICAL: Change all default passwords immediately!**

#### 1. Nginx Proxy Manager
```
Current: admin@example.com / changeme
Action: Login → Profile → Change Password
```

#### 2. Nextcloud Admin
```
Current: As set during installation
Action: Settings → Personal → Security → Change password
```

#### 3. Docker Compose Services

Edit `docker-compose.yml`:

```yaml
environment:
  # PostgreSQL - CHANGE THESE!
  - POSTGRES_PASSWORD=YOUR_STRONG_DB_PASSWORD_HERE

  # Redis - CHANGE THIS!
  - REDIS_HOST_PASSWORD=YOUR_STRONG_REDIS_PASSWORD_HERE
```

**After changing:**
```bash
docker compose down
docker compose up -d
```

### Password Guidelines

**Strong passwords should:**
- Be at least 16 characters long
- Include: uppercase, lowercase, numbers, symbols
- NOT be reused across services
- Be unique for each user

**Password Manager (Recommended):**
- Bitwarden (self-hosted or cloud)
- KeePassXC (offline)
- 1Password / LastPass

---

## Two-Factor Authentication (2FA)

### Enable 2FA for Admin

**1. Install TOTP app:**
1. Apps → Search "Two-Factor TOTP Provider"
2. Click Enable

**2. Configure 2FA:**
1. Settings → Security → Two-Factor Authentication
2. Scan QR code with authenticator app (Google Authenticator, Authy, etc.)
3. Enter verification code
4. Save backup codes in safe place

### Enforce 2FA for All Users

```bash
# Require 2FA for all users
docker exec nextcloud-app php occ config:app:set twofactor_totp enforced --value=yes
```

---

## HTTPS / SSL Configuration

### Method 1: Using Nginx Proxy Manager (Recommended)

#### For Local Network (Self-Signed Certificate)

**1. In NPM Proxy Host:**
- Edit proxy host for Nextcloud
- SSL tab → "Custom SSL"
- Generate self-signed certificate
- Force SSL: ✓

**2. Trust certificate on devices:**
- Download certificate from NPM
- Install on each device

#### For External Access (Let's Encrypt)

**Requirements:**
- Domain name (e.g., nextcloud.yourdomain.com)
- Public IP address (or Tailscale/CloudFlare Tunnel)
- Port 80/443 accessible

**Steps:**
1. NPM Proxy Host → SSL tab
2. "Request new SSL certificate"
3. Enter email address
4. Agree to Let's Encrypt ToS
5. Auto-renew: ✓

### Method 2: Manual SSL with Reverse Proxy

**Generate self-signed certificate:**
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /path/to/nextcloud.key \
  -out /path/to/nextcloud.crt \
  -subj "/CN=nextcloud.local"
```

**Add to NPM or configure Nginx manually**

---

## Network Security

### Firewall Configuration

#### Allow only necessary ports:
```bash
# For local network only
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.1.0/24 to any port 80
sudo ufw allow from 192.168.1.0/24 to any port 8090
sudo ufw allow from 192.168.1.0/24 to any port 81
sudo ufw enable
```

#### For external access (with VPN recommended):
```bash
# Only if using Tailscale/VPN
sudo ufw allow from 100.64.0.0/10  # Tailscale CGNAT range
```

### Trusted Proxies

**Current configuration (docker-compose.yml):**
```yaml
- TRUSTED_PROXIES=172.0.0.0/8 192.168.0.0/16 10.0.0.0/8 host.docker.internal
```

**Add NPM to trusted proxies:**
```bash
docker exec nextcloud-app php occ config:system:set trusted_proxies 0 --value=172.18.0.0/16
```

### Disable External Access (Local Only)

**Bind to local network only in docker-compose.yml:**
```yaml
ports:
  - "192.168.1.200:80:80"    # Only accessible from LAN
  - "192.168.1.200:8090:80"
```

---

## User Management & Permissions

### Create Family Users

**1. Via Web UI:**
- Settings → Users → New user
- Set username, password
- Add to "family" group

**2. Via Command Line:**
```bash
# Create user
docker exec nextcloud-app php occ user:add alice --password-from-env
# Enter password when prompted

# Add to group
docker exec nextcloud-app php occ group:adduser family alice
```

### User Permissions

**Disable admin for regular users:**
```bash
# Remove from admin group
docker exec nextcloud-app php occ group:removeuser admin alice
```

**Quota management:**
```bash
# Set user quota (e.g., 50GB)
docker exec nextcloud-app php occ user:setting alice files quota "50 GB"

# Unlimited (use carefully!)
docker exec nextcloud-app php occ user:setting alice files quota "none"
```

### Group Folders (Family Shared Space)

**1. Enable Group Folders app:**
- Apps → Search "Group folders"
- Enable

**2. Create shared folder:**
- Settings → Administration → Group folders
- Create folder: "Family Shared"
- Add group: "family"
- Set quota

---

## File Security

### Server-Side Encryption (Optional)

**⚠️ Warning:** Can impact performance. Test before enabling.

**1. Enable encryption app:**
```bash
docker exec nextcloud-app php occ app:enable encryption
```

**2. Initialize encryption:**
```bash
docker exec nextcloud-app php occ encryption:enable
docker exec nextcloud-app php occ encryption:encrypt-all
```

**3. Decrypt if needed:**
```bash
docker exec nextnextcloud-app php occ encryption:decrypt-all
```

### File Access Control

**1. Enable File Access Control app:**
- Apps → Search "File access control"
- Enable

**2. Create rules:**
- Settings → Administration → File access control
- Block/allow based on: file type, size, user, IP

**Example: Block .exe files:**
- File name pattern: `*.exe`
- Block upload

---

## Brute Force Protection

### Built-in Protection (Enabled by Default)

**Check status:**
```bash
docker exec nextcloud-app php occ config:list | grep bruteforce
```

**Configure:**
```bash
# Ban after X failed attempts
docker exec nextcloud-app php occ config:system:set auth.bruteforce.protection.enabled --value=true --type=boolean

# IP whitelist (your local network)
docker exec nextcloud-app php occ config:system:set auth.bruteforce.protection.testing --value=192.168.1.0/24
```

### Fail2Ban Integration (Advanced)

**Install Fail2Ban on host:**
```bash
sudo apt install fail2ban
```

**Create Nextcloud filter:**
```bash
sudo nano /etc/fail2ban/filter.d/nextcloud.conf
```

```ini
[Definition]
failregex = ^.*Login failed.*Remote IP.*<HOST>.*$
ignoreregex =
```

**Create jail:**
```bash
sudo nano /etc/fail2ban/jail.d/nextcloud.local
```

```ini
[nextcloud]
enabled = true
port = 80,443
protocol = tcp
filter = nextcloud
logpath = /home/kelib/Desktop/projects/home-nextcloud/data/nextcloud.log
maxretry = 3
bantime = 3600
```

---

## Audit & Logging

### Enable Audit Log

**1. Enable app:**
- Apps → Search "Auditing / Logging"
- Enable

**2. View logs:**
- Settings → Administration → Logging

### Security Warnings

**Check for security issues:**
```bash
docker exec nextcloud-app php occ security:certificates
docker exec nextcloud-app php occ security:certificates:import
```

**Review admin overview:**
- Settings → Administration → Overview
- Fix all warnings

---

## Backup & Recovery

### Automated Backups

**1. Database backup script:**

Create `/home/kelib/backup-nextcloud.sh`:
```bash
#!/bin/bash
BACKUP_DIR="/home/kelib/nextcloud-backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
docker exec nextcloud-db pg_dump -U nextcloud nextcloud > $BACKUP_DIR/db_$DATE.sql

# Backup config and data
tar -czf $BACKUP_DIR/files_$DATE.tar.gz -C /home/kelib/Desktop/projects/home-nextcloud config data

# Keep only last 7 backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

**2. Make executable and schedule:**
```bash
chmod +x /home/kelib/backup-nextcloud.sh

# Add to crontab (daily at 2 AM)
crontab -e
```
```
0 2 * * * /home/kelib/backup-nextcloud.sh >> /home/kelib/backup.log 2>&1
```

### Restore from Backup

**1. Restore database:**
```bash
docker exec -i nextcloud-db psql -U nextcloud nextcloud < backup.sql
```

**2. Restore files:**
```bash
tar -xzf files_backup.tar.gz -C /home/kelib/Desktop/projects/home-nextcloud
```

**3. Set permissions:**
```bash
sudo chown -R 33:33 data config
```

---

## External Access (Advanced)

### Using Tailscale VPN (Recommended)

**Why Tailscale?**
- Zero-config mesh VPN
- Works behind CGNAT (Starlink compatible)
- End-to-end encrypted
- Access from anywhere securely

**Setup:**
```bash
# Install on server
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Get Tailscale IP
tailscale ip
```

**Mobile access:**
1. Install Tailscale app
2. Login with same account
3. Access Nextcloud via Tailscale IP: `http://100.x.x.x:8090`

### Using CloudFlare Tunnel (Alternative)

**For domain-based access without public IP:**

1. Sign up for CloudFlare
2. Install cloudflared
3. Create tunnel pointing to `localhost:80`
4. Access via `https://nextcloud.yourdomain.com`

---

## Security Checklist

### Initial Setup
- [ ] Change all default passwords
- [ ] Enable 2FA for admin account
- [ ] Configure HTTPS/SSL
- [ ] Review and fix security warnings in admin panel
- [ ] Set up firewall rules

### Regular Maintenance
- [ ] Update containers monthly: `docker compose pull && docker compose up -d`
- [ ] Review user access logs
- [ ] Check for Nextcloud security advisories
- [ ] Test backups quarterly
- [ ] Rotate passwords annually

### Access Control
- [ ] Use strong, unique passwords
- [ ] Enable 2FA for all users
- [ ] Limit user quotas
- [ ] Review file sharing settings
- [ ] Use VPN for external access

---

## Security Monitoring

### Check for Suspicious Activity

**Failed logins:**
```bash
docker exec nextcloud-app grep "Login failed" /var/www/html/data/nextcloud.log | tail -20
```

**Active sessions:**
```bash
docker exec nextcloud-app php occ user:list --info
```

**Shared files audit:**
```bash
docker exec nextcloud-app php occ sharing:list admin
```

---

## Related Documentation
- [Setup Guide](SETUP.md)
- [Network Configuration](NETWORKING.md)
- [Troubleshooting](TROUBLESHOOTING.md)
