#!/bin/bash
# manage-ip.sh - Utility to manage IP preferences and static overrides

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PREFERENCES_FILE="ip-preferences.json"

# Function to show usage
show_usage() {
    echo -e "${BLUE}Nextcloud IP Management Utility${NC}"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo -e "  ${GREEN}status${NC}           - Show current IP configuration"
    echo -e "  ${GREEN}set-static <ip>${NC}   - Set a static IP override (e.g., 192.168.1.98)"
    echo -e "  ${GREEN}clear-static${NC}     - Remove static IP override (use auto-detection)"
    echo -e "  ${GREEN}set-preferred <ip>${NC} - Set preferred IP for consistency"
    echo -e "  ${GREEN}detect${NC}           - Run IP detection and show result"
    echo -e "  ${GREEN}reset${NC}            - Reset all preferences to defaults"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 set-static 192.168.1.98"
    echo "  $0 clear-static"
    echo "  $0 set-preferred 192.168.1.98"
}

# Function to read JSON value
read_json_value() {
    local file="$1"
    local key="$2"
    if [ -f "$file" ]; then
        local line=$(grep "\"$key\"" "$file" | head -1)
        if echo "$line" | grep -q ': null'; then
            echo "null"
        elif echo "$line" | grep -q ': *"'; then
            echo "$line" | sed 's/.*": *"\([^"]*\)".*/\1/'
        elif echo "$line" | grep -q ': *[0-9]'; then
            echo "$line" | sed 's/.*": *\([^,}]*\).*/\1/'
        else
            echo "$line" | sed 's/.*": *\([^,}]*\).*/\1/'
        fi
    fi
}

# Function to show status
show_status() {
    echo -e "${BLUE}📊 Current IP Configuration${NC}"
    echo ""

    if [ -f "$PREFERENCES_FILE" ]; then
        PREFERRED_IP=$(read_json_value "$PREFERENCES_FILE" "preferred_ip")
        STATIC_IP=$(read_json_value "$PREFERENCES_FILE" "static_ip_override")
        LAST_USED_IP=$(read_json_value "$PREFERENCES_FILE" "last_used_ip")
        LAST_UPDATED=$(read_json_value "$PREFERENCES_FILE" "last_updated")

        echo -e "Preferred IP:    ${GREEN}$PREFERRED_IP${NC}"

        if [ "$STATIC_IP" != "null" ] && [ -n "$STATIC_IP" ]; then
            echo -e "Static Override: ${YELLOW}$STATIC_IP${NC} (ACTIVE)"
            echo -e "Current URL:     ${BLUE}http://$STATIC_IP:8090${NC}"
        else
            echo -e "Static Override: ${GREEN}None${NC} (using auto-detection)"
            echo -e "Current URL:     ${BLUE}http://$LAST_USED_IP:8090${NC}"
        fi

        echo -e "Last Used IP:    ${GREEN}$LAST_USED_IP${NC}"
        echo -e "Last Updated:    ${GREEN}$LAST_UPDATED${NC}"
    else
        echo -e "${YELLOW}⚠️  No preferences file found${NC}"
        echo -e "Status: Using auto-detection mode"
    fi

    # Show current detected IP
    if [ -f "real-host-ip.txt" ]; then
        CURRENT_IP=$(cat real-host-ip.txt)
        echo -e "Detected IP:     ${GREEN}$CURRENT_IP${NC}"
    fi
}

# Function to set static IP
set_static_ip() {
    local ip="$1"
    if [ -z "$ip" ]; then
        echo -e "${RED}❌ Error: IP address required${NC}"
        echo "Usage: $0 set-static <ip>"
        exit 1
    fi

    # Basic IP validation
    if ! echo "$ip" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
        echo -e "${RED}❌ Error: Invalid IP address format${NC}"
        exit 1
    fi

    echo -e "${BLUE}🔒 Setting static IP override: $ip${NC}"

    # Create or update preferences file
    TIMESTAMP=$(date -Iseconds)
    cat > "$PREFERENCES_FILE" << EOF
{
  "preferred_ip": "192.168.1.98",
  "static_ip_override": "$ip",
  "auto_detect": true,
  "last_used_ip": "$ip",
  "last_updated": "$TIMESTAMP",
  "network_history": [
    {
      "ip": "$ip",
      "timestamp": "$TIMESTAMP",
      "network_name": "static_override",
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

    echo -e "${GREEN}✅ Static IP override set to: $ip${NC}"
    echo -e "${BLUE}📱 Nextcloud will use: http://$ip:8090${NC}"
    echo -e "${YELLOW}💡 Run './start-nextcloud-auto.sh' to apply changes${NC}"
}

# Function to clear static IP
clear_static_ip() {
    echo -e "${BLUE}🔓 Clearing static IP override${NC}"

    if [ -f "$PREFERENCES_FILE" ]; then
        PREFERRED_IP=$(read_json_value "$PREFERENCES_FILE" "preferred_ip")
    else
        PREFERRED_IP="192.168.1.98"
    fi

    TIMESTAMP=$(date -Iseconds)
    cat > "$PREFERENCES_FILE" << EOF
{
  "preferred_ip": "$PREFERRED_IP",
  "static_ip_override": null,
  "auto_detect": true,
  "last_used_ip": "$PREFERRED_IP",
  "last_updated": "$TIMESTAMP",
  "network_history": [
    {
      "ip": "$PREFERRED_IP",
      "timestamp": "$TIMESTAMP",
      "network_name": "auto_detect",
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

    echo -e "${GREEN}✅ Static IP override cleared${NC}"
    echo -e "${BLUE}📱 Nextcloud will use auto-detection (preferred: $PREFERRED_IP)${NC}"
    echo -e "${YELLOW}💡 Run './start-nextcloud-auto.sh' to apply changes${NC}"
}

# Function to set preferred IP
set_preferred_ip() {
    local ip="$1"
    if [ -z "$ip" ]; then
        echo -e "${RED}❌ Error: IP address required${NC}"
        echo "Usage: $0 set-preferred <ip>"
        exit 1
    fi

    # Basic IP validation
    if ! echo "$ip" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
        echo -e "${RED}❌ Error: Invalid IP address format${NC}"
        exit 1
    fi

    echo -e "${BLUE}🎯 Setting preferred IP: $ip${NC}"

    TIMESTAMP=$(date -Iseconds)
    cat > "$PREFERENCES_FILE" << EOF
{
  "preferred_ip": "$ip",
  "static_ip_override": null,
  "auto_detect": true,
  "last_used_ip": "$ip",
  "last_updated": "$TIMESTAMP",
  "network_history": [
    {
      "ip": "$ip",
      "timestamp": "$TIMESTAMP",
      "network_name": "preferred",
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

    echo -e "${GREEN}✅ Preferred IP set to: $ip${NC}"
    echo -e "${BLUE}📱 Nextcloud will prefer: http://$ip:8090${NC}"
    echo -e "${YELLOW}💡 Run './start-nextcloud-auto.sh' to apply changes${NC}"
}

# Function to run detection
run_detection() {
    echo -e "${BLUE}🔍 Running IP detection...${NC}"
    ./scripts/enhanced-ip-detect.sh
}

# Function to reset preferences
reset_preferences() {
    echo -e "${BLUE}🔄 Resetting IP preferences to defaults${NC}"

    TIMESTAMP=$(date -Iseconds)
    cat > "$PREFERENCES_FILE" << EOF
{
  "preferred_ip": "192.168.1.98",
  "static_ip_override": null,
  "auto_detect": true,
  "last_used_ip": "192.168.1.98",
  "last_updated": "$TIMESTAMP",
  "network_history": [
    {
      "ip": "192.168.1.98",
      "timestamp": "$TIMESTAMP",
      "network_name": "default",
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

    echo -e "${GREEN}✅ Preferences reset to defaults${NC}"
    echo -e "${BLUE}📱 Preferred IP: 192.168.1.98${NC}"
}

# Main command handling
case "$1" in
    "status")
        show_status
        ;;
    "set-static")
        set_static_ip "$2"
        ;;
    "clear-static")
        clear_static_ip
        ;;
    "set-preferred")
        set_preferred_ip "$2"
        ;;
    "detect")
        run_detection
        ;;
    "reset")
        reset_preferences
        ;;
    *)
        show_usage
        ;;
esac