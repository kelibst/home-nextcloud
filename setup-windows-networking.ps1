# setup-windows-networking.ps1 - Persistent Windows networking for Nextcloud
# Run this as Administrator in Windows PowerShell

param(
    [string]$WSLDistro = "Ubuntu"
)

Write-Host "🚀 Setting up persistent Nextcloud networking for WSL2..." -ForegroundColor Blue

# Function to get WSL IP dynamically
function Get-WSL-IP {
    try {
        $wslIP = wsl -d $WSLDistro hostname -I
        $wslIP = $wslIP.Trim().Split()[0]
        return $wslIP
    }
    catch {
        Write-Host "❌ Could not get WSL IP. Make sure WSL is running." -ForegroundColor Red
        exit 1
    }
}

# Function to setup port forwarding
function Setup-PortForwarding {
    param([string]$wslIP)
    
    Write-Host "🔧 Setting up port forwarding to WSL IP: $wslIP" -ForegroundColor Yellow
    
    # Remove existing port forwarding
    try {
        netsh interface portproxy delete v4tov4 listenport=8080 2>$null
        Write-Host "🗑️  Removed existing port forwarding" -ForegroundColor Gray
    }
    catch {
        # Ignore errors if no existing forwarding
    }
    
    # Add new port forwarding
    $result = netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=$wslIP
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Port forwarding added: 0.0.0.0:8080 -> $wslIP:8080" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Failed to add port forwarding" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Function to setup firewall rule
function Setup-Firewall {
    Write-Host "🛡️  Configuring Windows Firewall..." -ForegroundColor Yellow
    
    try {
        # Remove existing rule if it exists
        Remove-NetFirewallRule -DisplayName "Nextcloud WSL2" -ErrorAction SilentlyContinue
        
        # Add new firewall rule
        New-NetFirewallRule -DisplayName "Nextcloud WSL2" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow -Profile Any
        Write-Host "✅ Firewall rule configured" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Could not configure firewall rule. You may need to allow port 8080 manually." -ForegroundColor Yellow
    }
}

# Function to create startup task
function Create-StartupTask {
    param([string]$scriptPath)
    
    Write-Host "⚡ Creating Windows startup task for automatic networking..." -ForegroundColor Yellow
    
    $taskName = "NextcloudWSLNetworking"
    $taskDescription = "Automatically configure networking for Nextcloud in WSL2"
    
    # Remove existing task if it exists
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch {
        # Ignore if task doesn't exist
    }
    
    # Create the task action
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    # Create triggers for startup and WSL start
    $startupTrigger = New-ScheduledTaskTrigger -AtStartup
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn
    
    # Task settings
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    # Create the task principal (run with highest privileges)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    try {
        # Register the task
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $startupTrigger, $logonTrigger -Settings $settings -Principal $principal -Description $taskDescription
        Write-Host "✅ Startup task created: $taskName" -ForegroundColor Green
        Write-Host "   This will automatically setup networking when Windows starts" -ForegroundColor Gray
    }
    catch {
        Write-Host "⚠️  Could not create startup task. You may need to run this script manually after restarts." -ForegroundColor Yellow
    }
}

# Main execution
try {
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "  Nextcloud WSL2 Networking Setup" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    # Check if running as administrator
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "❌ This script requires Administrator privileges!" -ForegroundColor Red
        Write-Host "   Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    # Get current WSL IP
    $currentWSLIP = Get-WSL-IP
    Write-Host "📍 Current WSL IP: $currentWSLIP" -ForegroundColor Green
    
    # Get Windows IP for reference
    $windowsIP = (Get-NetIPConfiguration | Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Ethernet*" }).IPv4Address.IPAddress | Select-Object -First 1
    Write-Host "📍 Windows IP: $windowsIP" -ForegroundColor Green
    
    # Setup port forwarding
    if (Setup-PortForwarding -wslIP $currentWSLIP) {
        Write-Host ""
        
        # Setup firewall
        Setup-Firewall
        Write-Host ""
        
        # Create this script in a permanent location for the startup task
        $scriptDir = "$env:ProgramData\NextcloudWSL"
        $permanentScriptPath = "$scriptDir\setup-networking.ps1"
        
        if (-not (Test-Path $scriptDir)) {
            New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
        }
        
        # Copy this script to permanent location with dynamic WSL IP detection
        $permanentScript = @"
# Auto-generated Nextcloud WSL2 networking script
param([string]`$WSLDistro = "Ubuntu")

function Get-WSL-IP {
    try {
        `$wslIP = wsl -d `$WSLDistro hostname -I
        `$wslIP = `$wslIP.Trim().Split()[0]
        return `$wslIP
    }
    catch {
        return `$null
    }
}

# Only run if WSL is available
`$wslIP = Get-WSL-IP
if (`$wslIP) {
    # Remove existing port forwarding
    netsh interface portproxy delete v4tov4 listenport=8080 2>`$null
    
    # Add new port forwarding
    netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=`$wslIP
    
    # Log the action
    Add-Content -Path "`$env:ProgramData\NextcloudWSL\networking.log" -Value "`$(Get-Date): Port forwarding setup for WSL IP: `$wslIP"
}
"@
        
        $permanentScript | Out-File -FilePath $permanentScriptPath -Encoding UTF8
        
        # Create startup task
        Create-StartupTask -scriptPath $permanentScriptPath
        
        Write-Host ""
        Write-Host "📊 Current port forwarding rules:" -ForegroundColor Cyan
        netsh interface portproxy show v4tov4
        
        Write-Host ""
        Write-Host "✅ Setup complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🌐 Nextcloud will be accessible at:" -ForegroundColor Yellow
        Write-Host "   http://$windowsIP:8080 (from mobile devices)" -ForegroundColor Cyan
        Write-Host "   http://$currentWSLIP:8080 (from WSL)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "🔄 Networking will automatically reconfigure on Windows startup!" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Failed to setup networking" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ An error occurred: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press Enter to exit..." -ForegroundColor Gray
Read-Host