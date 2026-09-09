#!/usr/bin/env bash
# ==============================================================================
#  Universal Hardware Cooler Boost Toggle Script
# ==============================================================================
# Automatically detects the hardware vendor / machine model and toggles fan
# speeds between 100% Boost and Auto mode via ISW, Asusctl, NBFC, or EC tools.

STATE_FILE="/tmp/cooler_boost_state"
ACTION="${1:-toggle}"

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

detect_product() {
    if [[ -r /sys/class/dmi/id/product_name ]]; then
        cat /sys/class/dmi/id/product_name
    elif [[ -r /sys/devices/virtual/dmi/id/product_name ]]; then
        cat /sys/devices/virtual/dmi/id/product_name
    fi
}

VENDOR=$(detect_vendor)
PRODUCT=$(detect_product)

# Find acer-nitro-ec hwmon path if driver is loaded
find_acer_nitro_hwmon() {
    for h in /sys/class/hwmon/hwmon*; do
        if [[ -r "$h/name" ]]; then
            local n
            n=$(< "$h/name")
            if [[ "$n" == "acer_nitro_ec" || "$n" == "acer-nitro-ec" ]]; then
                echo "$h"
                return 0
            fi
        fi
    done
    return 1
}

# --- 2. Read State ---
if [ ! -f "$STATE_FILE" ]; then
    echo "off" > "$STATE_FILE"
fi

CURRENT_STATE=$(cat "$STATE_FILE")

case "$ACTION" in
    on|enable|start)
        TARGET_ACTION="enable" ;;
    off|disable|stop)
        TARGET_ACTION="disable" ;;
    status)
        echo "Cooler Boost hiện tại: ${CURRENT_STATE^^} (${VENDOR} ${PRODUCT})"
        exit 0
        ;;
    *)
        if [ "$CURRENT_STATE" == "on" ]; then
            TARGET_ACTION="disable"
        else
            TARGET_ACTION="enable"
        fi
        ;;
esac

# --- 3. Execute Fan Profile ---
APPLIED=0
ACER_HWMON=$(find_acer_nitro_hwmon || true)

if [ "$TARGET_ACTION" == "enable" ]; then
    # Enable Cooler Boost (100% Maximum Fan Speed)
    if [[ -n "$ACER_HWMON" ]]; then
        # acer-nitro-ec driver: 0 = Turbo mode (100% full speed)
        if [[ -w "$ACER_HWMON/pwm1_enable" ]]; then
            echo 0 > "$ACER_HWMON/pwm1_enable" 2>/dev/null && \
            echo 0 > "$ACER_HWMON/pwm2_enable" 2>/dev/null && APPLIED=1
        elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
            sudo -n tee "$ACER_HWMON/pwm1_enable" "$ACER_HWMON/pwm2_enable" <<< "0" >/dev/null 2>&1 && \
            sudo -n chmod 0666 "$ACER_HWMON"/pwm* 2>/dev/null || true
            APPLIED=1
        elif [[ -t 0 ]] && command -v sudo &>/dev/null; then
            sudo tee "$ACER_HWMON/pwm1_enable" "$ACER_HWMON/pwm2_enable" <<< "0" >/dev/null 2>&1 && \
            sudo chmod 0666 "$ACER_HWMON"/pwm* 2>/dev/null || true
            APPLIED=1
        elif command -v pkexec &>/dev/null && [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]]; then
            pkexec sh -c "echo 0 > '$ACER_HWMON/pwm1_enable' && echo 0 > '$ACER_HWMON/pwm2_enable' && chmod 0666 '$ACER_HWMON'/pwm*" >/dev/null 2>&1 && APPLIED=1
        fi
    elif command -v nbfc >/dev/null 2>&1; then
        nbfc set -f 100 >/dev/null 2>&1 || nbfc set -s 100 >/dev/null 2>&1
        APPLIED=1
    elif command -v isw >/dev/null 2>&1; then
        sudo /usr/bin/isw -b on >/dev/null 2>&1 || sudo isw -b on >/dev/null 2>&1
        APPLIED=1
    elif command -v asusctl >/dev/null 2>&1; then
        asusctl profile -P Turbo >/dev/null 2>&1 || true
        APPLIED=1
    fi

    if [ $APPLIED -eq 1 ]; then
        echo "on" > "$STATE_FILE"
        if [[ ! -t 1 ]]; then
            notify-send -u normal -t 2000 -h string:x-canonical-private-synchronous:cooler_boost "󰈐 ${VENDOR} Cooler Boost" "ENABLED (100% Maximum Fan Speed)" 2>/dev/null || true
        fi
        echo "✅ ${VENDOR} Cooler Boost: ĐÃ BẬT THÀNH CÔNG (Quạt tản nhiệt đang chạy 100% công suất tối đa)."
    else
        if [[ -n "$ACER_HWMON" ]]; then
            notify-send -u critical -t 5000 "󰈐 ${VENDOR} Cooler Boost" "Thiếu quyền ghi vào fan sysfs!\nHãy chạy: sudo chmod 0666 ${ACER_HWMON}/pwm*" 2>/dev/null || true
            echo "❌ Lỗi: Không thể ghi vào ${ACER_HWMON}/pwm1_enable (Permission Denied)!"
            echo "  Driver đã nhận diện tại ${ACER_HWMON}, nhưng cần cấp quyền truy cập:"
            echo "    sudo chmod 0666 ${ACER_HWMON}/pwm*"
            echo "  Hoặc chạy lại ./install.sh để tự động cài đặt udev rule vĩnh viễn."
        else
            notify-send -u critical -t 5000 "󰈐 ${VENDOR} Cooler Boost" "Chưa cài driver điều khiển quạt!\nCần nbfc-linux hoặc acer-nitro-ec-dkms" 2>/dev/null || true
            echo "❌ Lỗi: Không thể bật Cooler Boost cho ${VENDOR} ${PRODUCT}!"
            echo "  Hệ thống chưa có driver/công cụ điều khiển quạt phần cứng."
            echo "  Hãy chọn 1 trong các cách cài đặt sau:"
            echo "    Cách 1: yay -S acer-nitro-ec-dkms"
            echo "    Cách 2: yay -S nbfc-linux && sudo systemctl enable --now nbfc_service"
        fi
        exit 1
    fi
else
    # Disable Cooler Boost (Restore Auto Profile)
    if [[ -n "$ACER_HWMON" ]]; then
        # acer-nitro-ec driver: 2 = Auto mode
        if [[ -w "$ACER_HWMON/pwm1_enable" ]]; then
            echo 2 > "$ACER_HWMON/pwm1_enable" 2>/dev/null && \
            echo 2 > "$ACER_HWMON/pwm2_enable" 2>/dev/null && APPLIED=1
        elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
            sudo -n tee "$ACER_HWMON/pwm1_enable" "$ACER_HWMON/pwm2_enable" <<< "2" >/dev/null 2>&1 && \
            sudo -n chmod 0666 "$ACER_HWMON"/pwm* 2>/dev/null || true
            APPLIED=1
        elif [[ -t 0 ]] && command -v sudo &>/dev/null; then
            sudo tee "$ACER_HWMON/pwm1_enable" "$ACER_HWMON/pwm2_enable" <<< "2" >/dev/null 2>&1 && \
            sudo chmod 0666 "$ACER_HWMON"/pwm* 2>/dev/null || true
            APPLIED=1
        elif command -v pkexec &>/dev/null && [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]]; then
            pkexec sh -c "echo 2 > '$ACER_HWMON/pwm1_enable' && echo 2 > '$ACER_HWMON/pwm2_enable' && chmod 0666 '$ACER_HWMON'/pwm*" >/dev/null 2>&1 && APPLIED=1
        fi
    elif command -v nbfc >/dev/null 2>&1; then
        nbfc set -a >/dev/null 2>&1
        APPLIED=1
    elif command -v isw >/dev/null 2>&1; then
        sudo /usr/bin/isw -b off >/dev/null 2>&1 || sudo isw -b off >/dev/null 2>&1
        APPLIED=1
    elif command -v asusctl >/dev/null 2>&1; then
        asusctl profile -P Balanced >/dev/null 2>&1 || true
        APPLIED=1
    fi

    if [ $APPLIED -eq 1 ]; then
        echo "off" > "$STATE_FILE"
        if [[ ! -t 1 ]]; then
            notify-send -u normal -t 2000 -h string:x-canonical-private-synchronous:cooler_boost "󰈐 ${VENDOR} Cooler Boost" "DISABLED (Auto Fan Profile)" 2>/dev/null || true
        fi
        echo "✅ ${VENDOR} Cooler Boost: ĐÃ TẮT THÀNH CÔNG (Quạt đã trở về chế độ tự động thông minh)."
    else
        if [[ -n "$ACER_HWMON" ]]; then
            notify-send -u critical -t 5000 "󰈐 ${VENDOR} Cooler Boost" "Thiếu quyền ghi vào fan sysfs!\nHãy chạy: sudo chmod 0666 ${ACER_HWMON}/pwm*" 2>/dev/null || true
            echo "❌ Lỗi: Không thể ghi vào ${ACER_HWMON}/pwm1_enable (Permission Denied)!"
            echo "  Driver đã nhận diện tại ${ACER_HWMON}, nhưng cần cấp quyền truy cập:"
            echo "    sudo chmod 0666 ${ACER_HWMON}/pwm*"
        else
            notify-send -u critical -t 5000 "󰈐 ${VENDOR} Cooler Boost" "Chưa cài driver điều khiển quạt!\nCần nbfc-linux hoặc acer-nitro-ec-dkms" 2>/dev/null || true
            echo "❌ Lỗi: Không thể tắt Cooler Boost cho ${VENDOR} ${PRODUCT} (chưa có driver)."
        fi
        exit 1
    fi
fi
