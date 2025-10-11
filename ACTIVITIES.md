# Activities

## Wednesday, September 10, 2025

- Troubleshooted issue with accessing the Nextcloud app via IP address.
- Verified that the Docker containers are running correctly.
- Checked the `trusted_domains` configuration in `config.php`.
- Confirmed that the app is accessible via `http://localhost:8080`.
- Identified the issue as a WSL networking problem.
- Recommended using `http://localhost:8080` for accessing the app.
- Assisted with configuring access from the Android client by:
    - Instructing the user to create a Windows Firewall rule.
    - Adding the Windows host IP address to the `trusted_domains` configuration.
    - Added the WSL vEthernet IP address to the `trusted_domains` configuration as an alternative.
    - Instructed the user to disable the Windows Firewall for the public profile for testing.
    - Recommended enabling the mirrored networking mode in WSL as a potential solution.

## Friday, September 12, 2025

- Created a `.gitignore` file and populated it with the right things to ignore.

## Friday, October 3, 2025

### Static IP & Nginx Proxy Manager Configuration

- **Problem**: IP address kept changing on reboot, making family access inconsistent
- **Solution Implemented**: Static IP + Nginx Proxy Manager for consistent access

#### Changes Made:
1. **Added Nginx Proxy Manager** to docker-compose.yml
   - Runs on ports 80 (HTTP), 81 (Admin UI), 443 (HTTPS)
   - Provides reverse proxy for friendly domain names

2. **Configured Static IP** via NetworkManager
   - WiFi interface (wlx00e02450e7cf) now has permanent IP: **192.168.1.200**
   - Connection: LiliesLink
   - Gateway: 192.168.1.1
   - No more IP changes on reboot!

#### Access Points:
- **Nextcloud direct access**: http://192.168.1.200:8090
- **NPM Admin Panel**: http://192.168.1.200:81
  - Default login: admin@example.com / changeme (CHANGE THIS!)
- **After NPM proxy setup**: http://192.168.1.200 or http://nextcloud.local

#### Services Running:
- nextcloud-app (port 8090)
- nextcloud-db (PostgreSQL)
- nextcloud-redis (caching)
- nginx-proxy-manager (ports 80, 81, 443)
