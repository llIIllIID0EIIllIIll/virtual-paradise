#!/bin/bash
# ==============================================================================
#  MSI Cooler Boost Toggle Script
# ==============================================================================
# Toggles embedded controller (EC) fan speed between 100% Boost and Auto mode via ISW.

STATE_FILE="/tmp/cooler_boost_state"

# Read state; default to disabled if status file does not exist
if [ ! -f "$STATE_FILE" ]; then
    echo "off" > "$STATE_FILE"
fi

STATE=$(cat "$STATE_FILE")

if [ "$STATE" == "off" ]; then
    sudo /usr/bin/isw -b on
    echo "on" > "$STATE_FILE"
    notify-send -u normal -t 2000 "❄️ MSI Cooler Boost" "ENABLED (100% Maximum Fan Speed)"
else
    sudo /usr/bin/isw -b off
    echo "off" > "$STATE_FILE"
    notify-send -u normal -t 2000 "❄️ MSI Cooler Boost" "DISABLED (Auto Fan Profile)"
fi
