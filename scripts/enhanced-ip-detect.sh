#!/bin/bash
# enhanced-ip-detect.sh - Smart IP detection with preference system

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PREFERENCES_FILE="ip-preferences.json"
TIMESTAMP=$(date -Iseconds)

echo -e "${BLUE}🧠 Smart IP Detection with Preference System${NC}"

# Function to read JSON value (simple grep/sed approach)
read_json_value() {
    local file="$1"
    local key="$2"
    if [ -f "$file" ]; then
        local line=$(grep "\"$key\"" "$file" | head -1)
        if echo "$line" | grep -q ': null'; then
            echo "null"
        elif echo "$line" | grep -q ': *"'; then
            echo "$line" | sed 's/.*": *"\([^"]*\)".*/\1/'
        else
            echo "$line" | sed 's/.*": *\([^,}]*\).*/\1/' | sed 's/^[ \t]*//' | sed 's/[ \t]*$//'
        fi
    fi
}

# Function to check if IP is accessible on the network
validate_ip() {
    local ip="$1"
    if [ -z "$ip" ] || [ "$ip" = "null" ]; then
        return 1
    fi

    # Try to ping the IP (simple connectivity test)
    if ping -c 1 -W 2 "$ip" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to get all available IPs
detect_all_available_ips() {
    # Detect platform
    if grep -q Microsoft /proc/version 2>/dev/null; then
        PLATFORM="wsl"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        PLATFORM="linux"
    else
        PLATFORM="unknown"
    fi

    if [ "$PLATFORM" = "wsl" ]; then
        # WSL specific detection
        DETECTED_IP=$(powershell.exe -Command "
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
        if [ -z "$DETECTED_IP" ]; then
            DETECTED_IP=$(ip route show | grep default | awk '{print $3}')
        fi
    else
        # Native Linux detection
        DETECTED_IP=$(hostname -I | awk '{print $1}')
        if [ -z "$DETECTED_IP" ]; then
            DETECTED_IP=$(ip route get 8.8.8.8 | awk '{print $7}' | head -1)
        fi
    fi

    echo "$DETECTED_IP"
}

# Load preferences
if [ -f "$PREFERENCES_FILE" ]; then
    echo -e "${BLUE}📖 Loading IP preferences...${NC}"
    PREFERRED_IP=$(read_json_value "$PREFERENCES_FILE" "preferred_ip")
    STATIC_IP=$(read_json_value "$PREFERENCES_FILE" "static_ip_override")
    AUTO_DETECT=$(read_json_value "$PREFERENCES_FILE" "auto_detect")
    PRESERVE_PREFERRED=$(read_json_value "$PREFERENCES_FILE" "preserve_preferred_ip")

    echo -e "${YELLOW}   Preferred IP: ${GREEN}$PREFERRED_IP${NC}"
    if [ "$STATIC_IP" != "null" ] && [ -n "$STATIC_IP" ]; then
        echo -e "${YELLOW}   Static Override: ${GREEN}$STATIC_IP${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No preferences file found, using auto-detection${NC}"
    PREFERRED_IP=""
    STATIC_IP=""
    AUTO_DETECT="true"
    PRESERVE_PREFERRED="true"
fi

# Determine final IP using priority logic
FINAL_IP=""

# Priority 1: Static IP override (if set)
if [ "$STATIC_IP" != "null" ] && [ -n "$STATIC_IP" ]; then
    echo -e "${BLUE}🔒 Using static IP override: $STATIC_IP${NC}"
    FINAL_IP="$STATIC_IP"

# Priority 2: Preferred IP (if accessible)
elif [ "$PRESERVE_PREFERRED" = "true" ] && [ -n "$PREFERRED_IP" ] && [ "$PREFERRED_IP" != "null" ]; then
    echo -e "${BLUE}🎯 Testing preferred IP: $PREFERRED_IP${NC}"
    if validate_ip "$PREFERRED_IP"; then
        echo -e "${GREEN}✅ Preferred IP is accessible, using: $PREFERRED_IP${NC}"
        FINAL_IP="$PREFERRED_IP"
    else
        echo -e "${YELLOW}⚠️  Preferred IP not accessible, falling back to detection${NC}"
    fi
fi

# Priority 3: Auto-detection fallback
if [ -z "$FINAL_IP" ] && [ "$AUTO_DETECT" = "true" ]; then
    echo -e "${BLUE}🔍 Auto-detecting network IP...${NC}"
    DETECTED_IP=$(detect_all_available_ips)

    if [ -n "$DETECTED_IP" ]; then
        echo -e "${GREEN}✅ Detected IP: $DETECTED_IP${NC}"
        FINAL_IP="$DETECTED_IP"

        # Update preferences if IP changed and we don't have a preferred one
        if [ -z "$PREFERRED_IP" ] || [ "$PREFERRED_IP" = "null" ]; then
            echo -e "${BLUE}📝 Setting detected IP as new preference${NC}"
            # We'll update this in the preferences file
        fi
    else
        echo -e "${RED}❌ Failed to detect IP${NC}"
        exit 1
    fi
fi

# Final validation
if [ -z "$FINAL_IP" ]; then
    echo -e "${RED}❌ No IP address could be determined${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Final IP: $FINAL_IP${NC}"

# Save results
echo "$FINAL_IP" > real-host-ip.txt
echo "$(date -Iseconds)" > last-ip-detection.txt

# Update preferences file with current usage
if [ -f "$PREFERENCES_FILE" ]; then
    # Create updated preferences (simple replacement approach)
    cat > "$PREFERENCES_FILE" << EOF
{
  "preferred_ip": "${PREFERRED_IP:-$FINAL_IP}",
  "static_ip_override": ${STATIC_IP:-null},
  "auto_detect": true,
  "last_used_ip": "$FINAL_IP",
  "last_updated": "$TIMESTAMP",
  "network_history": [
    {
      "ip": "$FINAL_IP",
      "timestamp": "$TIMESTAMP",
      "network_name": "current",
      "status": "active"
    }
  ],
  "settings": {
    "preserve_preferred_ip": true,
    "validate_ip_accessibility": true,
    "fallback_on_failure": true,
    "update_preference_on_change": false
  }
}
EOF
fi

echo -e "${GREEN}✅ Smart IP detection completed: $FINAL_IP${NC}"
echo -e "${BLUE}📱 Nextcloud will be available at: http://$FINAL_IP:8090${NC}"