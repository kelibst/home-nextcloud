# Nextcloud Apps & Extensions

## Overview
Nextcloud has a rich ecosystem of apps that extend functionality. This guide covers recommended apps for your family NAS setup.

---

## Essential Apps

### 1. External Storage
**Purpose:** Access files on external drives without copying them into Nextcloud.

**Installation:**
1. Apps → Search "External storage"
2. Click **Enable**
3. Configure in Settings → Administration → External storage

**Configuration:** See [Storage Configuration Guide](STORAGE.md)

---

### 2. Memories (Photo Management)
**Purpose:** Google Photos alternative - organize photos by date, location, and faces.

**Installation:**
1. Apps → Search "Memories"
2. Click **Download and enable**

**Setup:**
1. Go to Memories app
2. Select folders to scan (e.g., external storage with photos)
3. Enable timeline view
4. Configure face recognition (optional)

**Mobile Upload:**
1. Install Nextcloud mobile app
2. Settings → Auto upload
3. Choose Memories folder as destination

---

### 3. Collabora Online (Office Suite)
**Purpose:** Edit documents, spreadsheets, presentations online (like Google Docs).

#### Option A: Built-in CODE Server (Recommended for Home)
```bash
# Add to docker-compose.yml
collabora:
  image: collabora/code
  container_name: nextcloud-collabora
  restart: unless-stopped
  environment:
    - domain=192.168.1.200
    - username=admin
    - password=collabora_password
    - extra_params=--o:ssl.enable=false
  ports:
    - "9980:9980"
  networks:
    - nextcloud-network
```

**Restart containers:**
```bash
docker compose up -d
```

**Configure in Nextcloud:**
1. Apps → Office & text → Download "Collabora Online"
2. Settings → Administration → Collabora Online
3. Use built-in CODE server: `http://192.168.1.200:9980`

#### Option B: App-only (simpler but limited)
1. Apps → Search "Nextcloud Office"
2. Enable and use limited built-in functionality

---

### 4. Calendar
**Purpose:** Sync calendars across devices (replaces Google Calendar).

**Installation:**
1. Apps → Search "Calendar"
2. Click **Enable**

**Mobile Sync:**
1. Install DAVx⁵ app (Android) or use iOS built-in
2. Add account with Nextcloud server URL
3. Select calendars to sync

**Share with Family:**
1. Create calendar → Share
2. Add family members
3. Set permissions (view/edit)

---

### 5. Contacts
**Purpose:** Sync contacts across devices (replaces Google Contacts).

**Installation:**
1. Apps → Search "Contacts"
2. Click **Enable**

**Mobile Sync:**
- Same as Calendar (uses DAVx⁵ on Android)
- iOS: Settings → Accounts → Add Nextcloud

---

### 6. Notes
**Purpose:** Simple note-taking synced across devices.

**Installation:**
1. Apps → Search "Notes"
2. Click **Enable**

**Features:**
- Markdown support
- Categories
- Mobile apps available

---

### 7. Tasks
**Purpose:** To-do lists and task management.

**Installation:**
1. Apps → Search "Tasks"
2. Click **Enable**

**Integration:**
- Works with Calendar app
- Sync via DAVx⁵ (Android)
- iOS Reminders compatible

---

## Recommended Optional Apps

### Media & Entertainment

**Music**
- Stream your music library
- Mobile apps available

**Deck**
- Kanban-style project management
- Great for family organization

**Photos** (alternative to Memories)
- Simpler photo viewer
- Timeline and albums

### Productivity

**Mail**
- Full email client in Nextcloud
- IMAP support

**Talk**
- Video calls and chat
- Screen sharing
- End-to-end encryption

**Forms**
- Create surveys and forms
- Collect responses

### File Management

**Group folders**
- Shared folders for family members
- Quota management

**Files automated tagging**
- Auto-organize files by rules
- Custom workflows

**PDF viewer**
- View PDFs in browser
- No download needed

---

## App Configuration Best Practices

### Performance Tips

1. **Enable only needed apps**
   ```bash
   # List enabled apps
   docker exec nextcloud-app php occ app:list

   # Disable unused app
   docker exec nextcloud-app php occ app:disable <app-name>
   ```

2. **Background jobs for heavy apps**
   - Settings → Administration → Basic settings
   - Set to "Cron" (recommended)
   - Add to host crontab:
   ```bash
   */5 * * * * docker exec -u www-data nextcloud-app php -f /var/www/html/cron.php
   ```

3. **Preview generation** (for photos/videos)
   ```bash
   docker exec nextcloud-app php occ config:system:set preview_max_x --value=2048
   docker exec nextcloud-app php occ config:system:set preview_max_y --value=2048
   docker exec nextcloud-app php occ config:system:set jpeg_quality --value=60
   ```

### Security Considerations

**App Permissions:**
- Review app permissions before enabling
- Stick to official Nextcloud apps
- Check app ratings and reviews

**User Access:**
- Settings → Users → Disable app access per user
- Limit admin apps to admin accounts

---

## Updating Apps

### Via Web Interface
1. Apps → Updates available
2. Click "Update" for each app

### Via Command Line
```bash
# Update all apps
docker exec nextcloud-app php occ app:update --all

# Update specific app
docker exec nextcloud-app php occ app:update calendar
```

---

## Troubleshooting Apps

### App Won't Enable

**Check compatibility:**
```bash
docker exec nextcloud-app php occ app:list
```

**Check logs:**
```bash
docker exec nextcloud-app tail -f /var/www/html/data/nextcloud.log
```

### Collabora/Office Not Working

**Check CODE server:**
```bash
curl http://192.168.1.200:9980
```

**Verify domain setting:**
- Must match Nextcloud URL (no https if using http)

### Mobile App Sync Issues

**Re-enable DAV:**
```bash
docker exec nextcloud-app php occ dav:sync-system-addressbook
docker exec nextcloud-app php occ dav:create-calendar admin family
```

**Check trusted domains:**
```bash
docker exec nextcloud-app php occ config:system:get trusted_domains
```

---

## App Data & Backups

### Backup App Data
```bash
# Backup entire data directory (includes all apps)
tar -czf nextcloud-apps-$(date +%Y%m%d).tar.gz data/

# Backup specific app data
tar -czf memories-backup.tar.gz data/admin/files/Photos/
```

### Export App Configurations
```bash
# Export calendar
docker exec nextcloud-app php occ dav:export-calendar admin/family > family-calendar.ics

# Export contacts
docker exec nextcloud-app php occ dav:export-contacts admin > contacts.vcf
```

---

## Related Documentation
- [Storage Configuration](STORAGE.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Network Setup](NETWORKING.md)
