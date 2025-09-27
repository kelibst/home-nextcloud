# Auto-generated Windows port forwarding setup
Write-Host "Setting up port forwarding for Nextcloud..." -ForegroundColor Blue

# Remove existing port forwarding
try {
    netsh interface portproxy delete v4tov4 listenport=8090 2>
} catch {}

# Add new port forwarding
Write-Host "Adding port forward: 0.0.0.0:8090 -> 192.168.1.98:8090" -ForegroundColor Yellow
netsh interface portproxy add v4tov4 listenport=8090 listenaddress=0.0.0.0 connectport=8090 connectaddress=192.168.1.98

# Add firewall rule if it doesn't exist
Write-Host "Configuring Windows Firewall..." -ForegroundColor Yellow
try {
    New-NetFirewallRule -DisplayName "Nextcloud WSL2" -Direction Inbound -Protocol TCP -LocalPort 8090 -Action Allow -ErrorAction SilentlyContinue
    Write-Host "✅ Firewall rule added" -ForegroundColor Green
} catch {
    Write-Host "ℹ️  Firewall rule already exists or couldn't be added" -ForegroundColor Yellow
}

# Show current port forwarding
Write-Host "Current port forwarding rules:" -ForegroundColor Green
netsh interface portproxy show v4tov4

Write-Host "✅ Windows networking setup complete!" -ForegroundColor Green
Write-Host "Access Nextcloud at: http://10.42.138.216:8090" -ForegroundColor Cyan
