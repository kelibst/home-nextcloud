# Network & Access Configuration

## Overview
This guide covers network setup, static IP configuration, Nginx Proxy Manager, and mobile device access for your Nextcloud instance.

---

## Current Network Setup

### Static IP Configuration ✅
- **IP Address:** `192.168.1.200`
- **Gateway:** `192.168.1.1`
- **Interface:** WiFi (wlx00e02450e7cf)
- **Connection:** LiliesLink
- **Status:** Configured via NetworkManager (persists across reboots)

---

## Access Points

### Web Access
- **Nextcloud Direct:** `http://192.168.1.200:8090`
- **Nextcloud via Proxy:** `http://192.168.1.200` (after NPM setup)
- **NPM Admin Panel:** `http://192.168.1.200:81`

### Service Ports
| Service | Port | Purpose |
|---------|------|---------|
| Nginx Proxy Manager | 80 | HTTP |
| Nginx Proxy Manager | 81 | Admin UI |
| Nginx Proxy Manager | 443 | HTTPS |
| Nextcloud | 8090 | Direct access |

---

## Nginx Proxy Manager Setup

### Initial Configuration

**1. Access NPM Admin Panel:**
```
http://192.168.1.200:81
```

**2. Default Login:**
- Email: `admin@example.com`
- Password: `changeme`

**3. Change Password Immediately!**
- Click profile → Change Password
- Use strong password

### Create Proxy Host for Nextcloud

**1. Add Proxy Host:**
- Dashboard → Hosts → Proxy Hosts → Add Proxy Host

**2. Details Tab:**
- **Domain Names:** `192.168.1.200` or `nextcloud.local`
- **Scheme:** `http`
- **Forward Hostname/IP:** `nextcloud-app`
- **Forward Port:** `80`
- **Cache Assets:** ✓
- **Block Common Exploits:** ✓
- **Websockets Support:** ✓

**3. Custom Locations (Optional - for CalDAV/CardDAV):**

Location 1:
```
location = /.well-known/caldav
```
- Scheme: `http`
- Forward Hostname: `nextcloud-app`
- Forward: `/remote.php/dav`
- Port: `80`

Location 2:
```
location = /.well-known/carddav
```
- Scheme: `http`
- Forward Hostname: `nextcloud-app`
- Forward: `/remote.php/dav`
- Port: `80`

**4. Save Configuration**

---

## Static IP Setup (Already Configured)

### Verify Current Configuration
```bash
# Check IP address
ip addr show wlx00e02450e7cf | grep "inet "

# Check connection settings
nmcli connection show LiliesLink | grep ipv4
```

### Modify Static IP (if needed)
```bash
# Change IP address
nmcli connection modify LiliesLink ipv4.addresses 192.168.1.XXX/24

# Apply changes
nmcli connection up LiliesLink
```

### Revert to DHCP (if needed)
```bash
nmcli connection modify LiliesLink ipv4.method auto
nmcli connection up LiliesLink
```

---

## Trusted Domains Configuration

### View Current Trusted Domains
```bash
docker exec nextcloud-app php occ config:system:get trusted_domains
```

### Add New Trusted Domain
```bash
# Add by index number
docker exec nextcloud-app php occ config:system:set trusted_domains 6 --value=example.com
```

### Current Configured Domains
- `localhost`
- `172.17.0.1`
- `host.docker.internal`
- `192.168.1.200`
- `192.168.1.200:8090`
- `nextcloud.local`

---

## Mobile Device Setup

### Android Configuration

**1. Install Nextcloud App:**
- Google Play Store → Search "Nextcloud"
- Install official Nextcloud app

**2. Connect to Server:**
- Server URL: `http://192.168.1.200`
- Username: (your nextcloud username)
- Password: (your password)

**3. Enable Auto Upload:**
- App Settings → Auto upload
- Choose folders (Camera, Screenshots, etc.)
- Select upload folder in Nextcloud
- Enable "Upload via WiFi only" (optional)

**4. DAVx⁵ for Contacts/Calendar (Optional):**
- Install DAVx⁵ from Play Store
- Add account → Login with OAuth
- Select Contacts and/or Calendar
- Sync with Android system

### iPhone/iOS Configuration

**1. Install Nextcloud App:**
- App Store → Search "Nextcloud"
- Install official Nextcloud app

**2. Connect to Server:**
- Server: `http://192.168.1.200`
- Username & password

**3. Auto Upload:**
- Settings → Auto upload photos
- Choose upload folder

**4. Contacts/Calendar Sync (Native):**
- iOS Settings → Accounts → Add Account
- Choose "Other" → Add CalDAV/CardDAV Account
- Server: `http://192.168.1.200`
- Username & password
- Description: Nextcloud

---

## Local DNS / mDNS (Optional)

### Using Avahi for `nextcloud.local`

**Install Avahi (if not installed):**
```bash
sudo apt install avahi-daemon
```

**Configure service:**
```bash
sudo nano /etc/avahi/services/nextcloud.service
```

```xml
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name>Nextcloud</name>
  <service>
    <type>_http._tcp</type>
    <port>80</port>
    <txt-record>path=/</txt-record>
  </service>
</service-group>
```

**Restart Avahi:**
```bash
sudo systemctl restart avahi-daemon
```

**Access via:**
- `http://nextcloud.local` (from devices on same network)
- `http://kelib-pc.local:8090` (using hostname)

---

## Troubleshooting Network Issues

### Cannot Access from Mobile

**1. Verify services running:**
```bash
docker ps
```

**2. Check firewall:**
```bash
# Check if port 80 is open
sudo netstat -tlnp | grep :80

# Allow port in firewall
sudo ufw allow 80/tcp
sudo ufw allow 8090/tcp
```

**3. Ping server from phone:**
- Install "Network Analyzer" app
- Ping `192.168.1.200`
- Check if reachable

**4. Check trusted domains:**
```bash
docker exec nextcloud-app php occ config:system:get trusted_domains
```

### IP Address Changed

**If using DHCP and IP changed:**
```bash
# Find new IP
ip addr show | grep "inet "

# Update trusted domains
docker exec nextcloud-app php occ config:system:set trusted_domains 7 --value=NEW_IP
```

**Or reconfigure static IP:**
```bash
nmcli connection modify LiliesLink ipv4.addresses 192.168.1.200/24
nmcli connection up LiliesLink
```

### NPM Not Accessible

**Check NPM container:**
```bash
docker ps | grep nginx-proxy-manager
docker logs nginx-proxy-manager
```

**Restart NPM:**
```bash
docker compose restart nginx-proxy-manager
```

**Access NPM database reset:**
```bash
# If locked out, reset admin password
docker exec nginx-proxy-manager bash -c "cd /app && node /app/setup.js"
```

### CalDAV/CardDAV Not Working

**Regenerate .well-known redirects:**
```bash
docker exec nextcloud-app php occ config:system:set htaccess.RewriteBase --value=/
docker exec nextcloud-app php occ maintenance:update:htaccess
```

**Test endpoints:**
```bash
curl -I http://192.168.1.200/.well-known/caldav
curl -I http://192.168.1.200/.well-known/carddav
```

---

## External Access (Advanced)

### Using Tailscale VPN (Recommended)

**1. Install Tailscale:**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

**2. Install on mobile devices:**
- Download Tailscale app
- Login with same account
- Access via Tailscale IP (100.x.x.x)

**Benefits:**
- Secure access from anywhere
- No port forwarding needed
- Works on cellular data

### Port Forwarding (Not Recommended for Starlink)

**Note:** Starlink uses CGNAT, port forwarding may not work.

If you have public IP:
1. Router settings → Port Forwarding
2. Forward 80/443 → 192.168.1.200:80/443
3. Set up HTTPS with Let's Encrypt
4. Use DDNS service for changing IPs

---

## Performance Optimization

### Enable Redis Caching (Already Configured)
```bash
# Verify Redis is working
docker exec nextcloud-app redis-cli -h redis -a redispassword ping
```

### HTTP/2 & HTTPS (via NPM)

**1. In NPM Proxy Host:**
- SSL tab → Request new SSL certificate
- Use Let's Encrypt (requires domain name)
- Or upload custom certificate

**2. Force SSL:**
- Enable "Force SSL"
- Enable "HTTP/2 Support"

---

## Related Documentation
- [Complete Setup Guide](SETUP.md)
- [Security Configuration](SECURITY.md)
- [Troubleshooting](TROUBLESHOOTING.md)
