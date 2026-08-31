#!/bin/bash

STATE_FILE="/tmp/cooler_boost_state"

# Đọc trạng thái, mặc định là tắt nếu file chưa tồn tại
if [ ! -f "$STATE_FILE" ]; then
    echo "off" > "$STATE_FILE"
fi

STATE=$(cat "$STATE_FILE")

if [ "$STATE" == "off" ]; then
    sudo /usr/bin/isw -b on
    echo "on" > "$STATE_FILE"
    notify-send -u normal -t 2000 "❄️ MSI Cooler Boost" "Đã BẬT (100% Công suất)"
else
    sudo /usr/bin/isw -b off
    echo "off" > "$STATE_FILE"
    notify-send -u normal -t 2000 "❄️ MSI Cooler Boost" "Đã TẮT (Chế độ Tự động)"
fi
