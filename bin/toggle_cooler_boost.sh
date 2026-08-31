#!/usr/bin/env bash
# ==============================================================================
#  Universal Hardware Cooler Boost Toggle Script
# ==============================================================================
# Automatically detects the hardware vendor / machine model and toggles fan
# speeds between 100% Boost and Auto mode via ISW, Asusctl, NBFC, or EC tools.

STATE_FILE="/tmp/cooler_boost_state"

# --- 1. Dynamic Hardware Vendor Detection ---
detect_vendor() {
    local raw_vendor=""
    if [[ -r /sys/devices/virtual/dmi/id/sys_vendor ]]; then
        raw_vendor=$(< /sys/devices/virtual/dmi/id/sys_vendor)
    elif [[ -r /sys/class/dmi/id/sys_vendor ]]; then
        raw_vendor=$(< /sys/class/dmi/id/sys_vendor)
    elif command -v hostnamectl >/dev/null 2>&1; then
        raw_vendor=$(hostnamectl 2>/dev/null | awk -F": " '/Hardware Vendor/ {print $2}')
    fi

    case "${raw_vendor,,}" in
        *micro-star*|*msi*)
            echo "MSI" ;;
        *asustek*|*asus*)
            echo "ASUS" ;;
        *lenovo*)
            echo "Lenovo" ;;
        *alienware*)
            echo "Alienware" ;;
        *dell*)
            echo "Dell" ;;
        *hp*|*hewlett-packard*)
            echo "HP" ;;
        *acer*)
            echo "Acer" ;;
        *gigabyte*)
            echo "Gigabyte" ;;
        *razer*)
            echo "Razer" ;;
        *apple*)
            echo "Apple" ;;
        *framework*)
            echo "Framework" ;;
        *)
            if [[ -n "$raw_vendor" ]]; then
                local clean
                clean=$(echo "$raw_vendor" | sed -E "s/,? (Inc\.|Co\.,? Ltd\.|Corporation|Technology).*//gi" | awk '{print $1}')
                echo "${clean:-System}"
            else
                echo "System"
            fi
            ;;
    esac
}

VENDOR=$(detect_vendor)

# --- 2. Read State ---
if [ ! -f "$STATE_FILE" ]; then
    echo "off" > "$STATE_FILE"
fi

STATE=$(cat "$STATE_FILE")

# --- 3. Toggle Fan Profile ---
if [ "$STATE" == "off" ]; then
    # Enable Cooler Boost
    if command -v isw >/dev/null 2>&1; then
        sudo /usr/bin/isw -b on >/dev/null 2>&1 || sudo isw -b on >/dev/null 2>&1
    elif command -v asusctl >/dev/null 2>&1; then
        asusctl profile -P Turbo >/dev/null 2>&1 || true
    elif command -v nbfc >/dev/null 2>&1; then
        nbfc set -f 100 >/dev/null 2>&1 || true
    fi

    echo "on" > "$STATE_FILE"
    notify-send -u normal -t 2000 "❄️ ${VENDOR} Cooler Boost" "ENABLED (100% Maximum Fan Speed)"
else
    # Disable Cooler Boost (Restore Auto Profile)
    if command -v isw >/dev/null 2>&1; then
        sudo /usr/bin/isw -b off >/dev/null 2>&1 || sudo isw -b off >/dev/null 2>&1
    elif command -v asusctl >/dev/null 2>&1; then
        asusctl profile -P Balanced >/dev/null 2>&1 || true
    elif command -v nbfc >/dev/null 2>&1; then
        nbfc set -a >/dev/null 2>&1 || true
    fi

    echo "off" > "$STATE_FILE"
    notify-send -u normal -t 2000 "❄️ ${VENDOR} Cooler Boost" "DISABLED (Auto Fan Profile)"
fi
