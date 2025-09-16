#!/bin/bash
# host-ip-detect.sh - Run on host to detect real IP for container use

# Detect platform
if grep -q Microsoft /proc/version 2>/dev/null; then
    PLATFORM="wsl"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
else
    PLATFORM="unknown"
fi

echo "Detecting host IP for platform: $PLATFORM"

if [ "$PLATFORM" = "wsl" ]; then
    # WSL specific detection
    WINDOWS_IP=$(powershell.exe -Command "
        \$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            \$_.IPAddress -notmatch '^127\.' -and
            \$_.IPAddress -notmatch '^169\.254\.' -and
            \$_.IPAddress -notmatch '^172\.1[6-9]\.' -and
            \$_.IPAddress -notmatch '^172\.2[0-9]\.' -and
            \$_.IPAddress -notmatch '^172\.3[0-1]\.' -and
            \$_.InterfaceAlias -notmatch 'WSL' -and
            \$_.InterfaceAlias -notmatch 'Loopback' -and
            \$_.InterfaceAlias -notmatch 'vEthernet.*WSL'
        } | Sort-Object InterfaceIndex;
        \$mainAdapter = \$adapters | Where-Object {
            \$_.InterfaceAlias -match 'Wi-Fi|Ethernet|Wireless'
        } | Select-Object -First 1;
        if (-not \$mainAdapter) {
            \$mainAdapter = \$adapters | Select-Object -First 1;
        };
        if (\$mainAdapter) {
            Write-Output \$mainAdapter.IPAddress;
        }
    " 2>/dev/null | tr -d '\r\n' | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')

    # Fallback to WSL gateway if PowerShell detection failed
    if [ -z "$WINDOWS_IP" ]; then
        WINDOWS_IP=$(ip route show | grep default | awk '{print $3}')
    fi

    WSL_IP=$(hostname -I | awk '{print $1}')
    HOST_IP=$WINDOWS_IP
else
    # Native Linux detection
    HOST_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$HOST_IP" ]; then
        HOST_IP=$(ip route get 8.8.8.8 | awk '{print $7}' | head -1)
    fi
    WINDOWS_IP=$HOST_IP
    WSL_IP=$HOST_IP
fi

echo "Detected Host IP: $HOST_IP"

# Save to file for container to read
echo "$HOST_IP" > real-host-ip.txt
echo "$PLATFORM" > platform.txt

echo "Real host IP saved to real-host-ip.txt"