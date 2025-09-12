# Nextcloud Mobile Access Setup

## Current Configuration
- **WSL IP**: 172.26.58.22:8090
- **Windows Host IP**: 172.26.48.1:8090 (for mobile devices)
- **Trusted Domains**: Automatically configured by startup script

## Mobile Device Setup Instructions

### 1. Windows PowerShell Setup (Required for Mobile Access)
Run the following command in **Windows PowerShell as Administrator**:
```powershell
powershell -ExecutionPolicy Bypass -File setup-port-forward.ps1
```

### 2. Mobile App Connection
Use this URL in your Nextcloud mobile app:
```
http://172.26.48.1:8090
```

### 3. Network Requirements
- Your mobile device must be on the same local network
- Windows Firewall must allow port 8090 (handled by PowerShell script)
- Port forwarding from Windows to WSL must be active

## Testing Connectivity

### From WSL (Internal):
```bash
curl -I http://172.26.58.22:8090
curl -I http://localhost:8090
```

### From Windows (External):
```cmd
curl -I http://172.26.48.1:8090
```

### From Mobile Device:
- Open browser and navigate to: `http://172.26.48.1:8090`
- Should see Nextcloud login/setup page

## IP Address Persistence
The startup script automatically:
1. Detects current Windows and WSL IP addresses
2. Updates .env file with current IPs
3. Configures Nextcloud trusted domains
4. Creates PowerShell script with correct IPs

This ensures the system works even after:
- Computer restarts
- WSL restarts  
- Network changes
- IP address changes

## Troubleshooting
If mobile connectivity fails:
1. Check Windows Firewall settings
2. Verify port forwarding: `netsh interface portproxy show v4tov4`
3. Ensure mobile device is on same network
4. Test Windows IP from another device: `ping 172.26.48.1`