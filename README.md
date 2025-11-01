# Nextcloud Docker NAS - Family Cloud Storage

A complete home NAS solution using Nextcloud with Docker, featuring PostgreSQL database, Redis caching, and Nginx Proxy Manager for easy family access across all devices.

---

## 🚀 Quick Start

### 1. Start All Services
```bash
cd /home/kelib/Desktop/projects/home-nextcloud
docker compose up -d
```

### 2. Access Nextcloud
- **Web UI:** `http://192.168.1.200:8090` or `http://192.168.1.200`
- **Admin Panel:** `http://192.168.1.200:81` (Nginx Proxy Manager)

### 3. First-Time Setup
1. Configure Nginx Proxy Manager ([guide](docs/NETWORKING.md#nginx-proxy-manager-setup))
2. Enable External Storage app for your drives ([guide](docs/STORAGE.md))
3. Setup mobile devices ([Android](docs/NETWORKING.md#android-configuration) | [iPhone](docs/NETWORKING.md#iphonios-configuration))

---

## 📚 Documentation

| Guide | Description |
|-------|-------------|
| **[Complete Setup](docs/SETUP.md)** | Initial installation and configuration |
| **[Network & Access](docs/NETWORKING.md)** | Static IP, NPM, mobile setup, trusted domains |
| **[Storage Configuration](docs/STORAGE.md)** | External drives, mounting, permissions |
| **[Apps & Extensions](docs/APPS.md)** | Memories, Collabora, Calendar, Contacts, and more |
| **[Troubleshooting](docs/TROUBLESHOOTING.md)** | Common issues and solutions |
| **[Security Guide](docs/SECURITY.md)** | Passwords, 2FA, HTTPS, backups |

---

## ⚙️ Current Configuration

### System Specs
- **Operating System:** DeepinOS (Linux)
- **Static IP:** `192.168.1.200` (won't change on reboot)
- **Total Storage:** 627GB available on DATA drive
- **Network:** Starlink via WiFi (LiliesLink)

### Services Running
| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| Nextcloud | nextcloud-app | 8090 | Main application |
| PostgreSQL | nextcloud-db | 5432 | Database |
| Redis | nextcloud-redis | 6379 | Caching |
| Nginx Proxy Manager | nginx-proxy-manager | 80, 81, 443 | Reverse proxy |

### Access Points
- **Direct Access:** `http://192.168.1.200:8090`
- **Via Proxy:** `http://192.168.1.200` (after NPM configuration)
- **NPM Admin:** `http://192.168.1.200:81`
  - Default: admin@example.com / changeme (**change immediately!**)

---

## 📱 Family Access

### Web Browser
Any device on your local network can access:
- `http://192.168.1.200`

### Mobile Apps
**Android:**
1. Install "Nextcloud" from Play Store
2. Server: `http://192.168.1.200`
3. Login with your credentials

**iPhone:**
1. Install "Nextcloud" from App Store
2. Server: `http://192.168.1.200`
3. Login with your credentials

📖 **Detailed mobile setup:** [Networking Guide](docs/NETWORKING.md#mobile-device-setup)

---

## 💾 Storage

### Mounted Drives
- **Main Storage:** `/media/kelib/DATA` → 932GB (627GB free)
- **Extra Disk:** `/media/kelib/Extra Disk` → 299GB (176GB free)
- **Backup Drive:** `/media/kelib/59373E7526CE30E3` → 932GB (367GB free)

### Enable External Storage
1. **Apps** → Enable "External storage"
2. **Settings** → Administration → External storage
3. Add Local: `/mnt/external_storage` → "Shared Drive"

📖 **Full storage guide:** [Storage Configuration](docs/STORAGE.md)

---

## 🛠️ Common Commands

### Service Management
```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# Restart specific service
docker compose restart nextcloud-app

# View logs
docker compose logs -f nextcloud-app
```

### Maintenance
```bash
# Update all containers
docker compose pull && docker compose up -d

# Backup data and config
tar -czf backup-$(date +%Y%m%d).tar.gz data config

# Scan files
docker exec nextcloud-app php occ files:scan --all
```

📖 **More commands:** [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

---

## ✅ Success Criteria

Current status of your Nextcloud setup:

- [x] **Nextcloud accessible** at `http://192.168.1.200`
- [x] **Static IP configured** (no more IP changes!)
- [x] **PostgreSQL database** connected
- [x] **Redis caching** enabled
- [x] **Nginx Proxy Manager** running
- [x] **External storage** mounted (DATA drive)
- [ ] **Mobile apps** connected (Android/iPhone)
- [ ] **Auto photo upload** configured
- [ ] **Family users** created
- [ ] **Shared folders** configured

---

## 🔒 Security Reminders

### ⚠️ IMPORTANT: Change Default Passwords!
1. **NPM:** Login to `http://192.168.1.200:81` and change password
2. **Docker services:** Edit `docker-compose.yml` and update:
   - `POSTGRES_PASSWORD`
   - `REDIS_HOST_PASSWORD`
3. **Nextcloud admin:** Settings → Security → Change password

### Recommended Security Steps
- [ ] Enable 2FA for admin account
- [ ] Configure HTTPS/SSL via NPM
- [ ] Set up automated backups
- [ ] Review security warnings in admin panel

📖 **Complete security guide:** [Security Documentation](docs/SECURITY.md)

---

## 🆘 Need Help?

### Quick Fixes
- **Can't access web UI?** Check containers are running: `docker compose ps`
- **Trusted domain error?** See [Networking Guide](docs/NETWORKING.md#trusted-domains-configuration)
- **Mobile app won't connect?** Verify server URL: `http://192.168.1.200`
- **External mount error?** Fix permissions: `docker exec nextcloud-app chown -R www-data:www-data /mnt/external_storage`
- **Slow performance?** Check Redis: `docker exec nextcloud-app redis-cli -h redis -a redispassword ping`

### Resources
- 📖 [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions
- 📖 [Official Nextcloud Docs](https://docs.nextcloud.com/server/latest/admin_manual/)
- 📖 [Community Forum](https://help.nextcloud.com/)

---

## 📝 Project Files

```
home-nextcloud/
├── docker-compose.yml          # Main configuration
├── README.md                   # This file
├── ACTIVITIES.md              # Change log
├── docs/                      # Detailed documentation
│   ├── SETUP.md              # Complete setup guide
│   ├── NETWORKING.md         # Network configuration
│   ├── STORAGE.md            # Storage setup
│   ├── APPS.md               # Apps and extensions
│   ├── TROUBLESHOOTING.md    # Problem solving
│   └── SECURITY.md           # Security guide
├── data/                     # User files (auto-created)
├── config/                   # Nextcloud config (auto-created)
├── database/                 # PostgreSQL data (auto-created)
└── custom_apps/              # Additional apps (auto-created)
```

---

## 🎯 Next Steps

1. **Configure NPM Proxy Host** → [Guide](docs/NETWORKING.md#create-proxy-host-for-nextcloud)
2. **Enable External Storage** → [Guide](docs/STORAGE.md#method-1-single-external-drive-current-setup)
3. **Setup Mobile Devices** → [Guide](docs/NETWORKING.md#mobile-device-setup)
4. **Install Essential Apps** → [Guide](docs/APPS.md#essential-apps)
5. **Create Family Users** → [Guide](docs/SECURITY.md#create-family-users)

---

**Built with:** Docker • Nextcloud • PostgreSQL • Redis • Nginx Proxy Manager

*Last Updated: October 3, 2025*
