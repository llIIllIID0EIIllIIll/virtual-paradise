#!/bin/bash
# Memory Details Notification

MEM_INFO=$(free -h | awk '/Mem:/ {print "Used: " $3 "  |  Free: " $4 "\nAvailable: " $7 "  |  Total: " $2}')
SWAP_INFO=$(free -h | awk '/Swap:/ {print "Swap: " $3 " used / " $2 " total"}')

notify-send -u normal "󰍛 Memory & Swap Details" "${MEM_INFO}\n${SWAP_INFO}"
