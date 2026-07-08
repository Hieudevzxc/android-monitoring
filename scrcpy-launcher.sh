#!/bin/bash

# Configuration directories for caching last connected Wi-Fi IP
CONFIG_DIR="$HOME/.config/scrcpy-launcher"
WIFI_IP_FILE="$CONFIG_DIR/last_wifi_ip.txt"

# Start adb server to ensure it is running and detect devices
adb start-server >/dev/null 2>&1

# Get list of devices (ignore header and empty lines)
DEVICES_OUT=$(adb devices | tail -n +2 | grep -v '^$')

# Count number of lines (devices)
if [ -z "$DEVICES_OUT" ]; then
    NUM_DEVICES=0
else
    NUM_DEVICES=$(echo "$DEVICES_OUT" | wc -l)
fi

# Auto-connect if no devices found but we have a saved WiFi IP and not running setup
if [ "$NUM_DEVICES" -eq 0 ] && [ -f "$WIFI_IP_FILE" ] && [ "$1" != "--wifi-setup" ]; then
    LAST_IP=$(cat "$WIFI_IP_FILE")
    # Show user a passive notification that we are trying to connect
    zenity --notification --text="Đang kết nối không dây tới điện thoại ($LAST_IP)..." --timeout=2 >/dev/null 2>&1 &
    
    # Try to connect via adb
    adb connect "$LAST_IP:5555" >/dev/null 2>&1
    
    # Re-evaluate device list
    DEVICES_OUT=$(adb devices | tail -n +2 | grep -v '^$')
    if [ -z "$DEVICES_OUT" ]; then
        NUM_DEVICES=0
    else
        NUM_DEVICES=$(echo "$DEVICES_OUT" | wc -l)
    fi
fi

# Wi-Fi wireless setup action
if [ "$1" = "--wifi-setup" ]; then
    # 1. Check if any USB device is connected (must be connected via USB first to authorize and enable tcpip)
    # Check if there is a device that is not an IP address (contains no ':')
    USB_DEV=$(echo "$DEVICES_OUT" | grep -v ':' | awk '{print $1}' | head -n 1)
    USB_STATUS=$(echo "$DEVICES_OUT" | grep -v ':' | awk '{print $2}' | head -n 1)
    
    if [ -z "$USB_DEV" ]; then
        zenity --error --title="Thiết lập Wi-Fi" --text="<b>Không tìm thấy thiết bị USB nào!</b>\n\nĐể thiết lập kết nối không dây (Wi-Fi), bạn cần cắm cáp USB nối điện thoại với máy tính trước (chỉ thực hiện một lần)." --width=450
        exit 1
    fi
    
    if [ "$USB_STATUS" = "unauthorized" ]; then
        zenity --warning --title="Thiết lập Wi-Fi" --text="<b>Thiết bị chưa được ủy quyền!</b>\n\nVui lòng nhấn cho phép USB Debugging trên màn hình điện thoại trước." --width=450
        exit 1
    fi
    
    # 2. Start TCP/IP mode on port 5555
    zenity --info --title="Thiết lập Wi-Fi" --text="Đang chuẩn bị thiết lập kết nối không dây trên điện thoại của bạn...\nVui lòng giữ cáp kết nối." --width=400 --timeout=3 &
    
    adb -s "$USB_DEV" tcpip 5555 >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        zenity --error --title="Thiết lập Wi-Fi" --text="Không thể chuyển thiết bị sang chế độ kết nối mạng (TCP/IP). Vui lòng thử lại."
        exit 1
    fi
    
    # 3. Get IP Address
    IP_ADDR=$(adb -s "$USB_DEV" shell ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -n 1)
    if [ -z "$IP_ADDR" ]; then
        # Fallback
        IP_ADDR=$(adb -s "$USB_DEV" shell ip route | grep src | awk '{print $9}' | head -n 1)
    fi
    
    if [ -z "$IP_ADDR" ]; then
        zenity --error --title="Thiết lập Wi-Fi" --text="Không thể lấy địa chỉ IP của điện thoại. Đảm bảo điện thoại và máy tính của bạn đang kết nối chung một mạng Wi-Fi." --width=450
        exit 1
    fi
    
    # 4. Connect to IP
    adb connect "$IP_ADDR:5555" >/dev/null 2>&1
    
    # Verify connection
    CONN_CHECK=$(adb devices | grep "$IP_ADDR:5555" | grep "device")
    if [ -n "$CONN_CHECK" ]; then
        # Save IP to file
        mkdir -p "$CONFIG_DIR"
        echo "$IP_ADDR" > "$WIFI_IP_FILE"
        
        zenity --info --title="Thiết lập Wi-Fi" --text="<b>Thiết lập kết nối Wi-Fi thành công!</b>\n\n- Địa chỉ IP điện thoại: <b>$IP_ADDR</b>\n\nBạn có thể <b>RÚT CÁP USB</b> ra ngay bây giờ. Hãy mở lại ứng dụng 'Điều khiển Android' để sử dụng không dây." --width=450
    else
        zenity --error --title="Thiết lập Wi-Fi" --text="Không thể kết nối đến điện thoại qua Wi-Fi.\nĐảm bảo cả máy tính và điện thoại đều đang kết nối vào <b>cùng một mạng Wi-Fi</b> và thử lại." --width=450
    fi
    exit 0
fi

if [ "$NUM_DEVICES" -eq 0 ]; then
    zenity --error --title="Android Mirroring" --text="<b>Không tìm thấy thiết bị Android nào!</b>\n\nĐể kết nối điện thoại, vui lòng thực hiện:\n1. Kết nối điện thoại với máy tính bằng <b>cáp USB</b> chất lượng tốt.\n2. Mở điện thoại, vào <b>Cài đặt -> Hệ thống -> Tùy chọn nhà phát triển</b> và bật <b>Gỡ lỗi USB (USB Debugging)</b>.\n\n<i>* Nếu không thấy Tùy chọn nhà phát triển, vào Cài đặt -> Thông tin điện thoại -> Nhấn liên tục 7 lần vào 'Số hiệu bản dựng' (Build Number).</i>" --width=450
    exit 1
fi

# Define default options array
SCRCPY_OPTS=("--window-title" "Android Mirroring" "--prefer-text")

# Check arguments
RUN_CONFIG=false
if [ "$1" = "--config" ]; then
    RUN_CONFIG=true
elif [ "$1" = "--screen-on" ]; then
    SCRCPY_OPTS+=("--power-off-on-close")
else
    # Default Quick Start
    SCRCPY_OPTS+=("-S" "--power-off-on-close")
fi

if [ "$RUN_CONFIG" = true ]; then
    # Show Zenity Form to customize options
    CONFIG_OUT=$(zenity --forms --title="Cấu hình Android Mirroring" \
      --text="Thiết lập các tùy chọn trước khi kết nối:" \
      --add-combo="Tắt màn hình vật lý điện thoại" --combo-values="Có|Không" \
      --add-combo="Khóa màn hình điện thoại khi tắt" --combo-values="Có|Không" \
      --add-combo="Giới hạn độ phân giải" --combo-values="Mặc định|1080p|720p|480p" \
      --add-combo="Tự động truyền âm thanh" --combo-values="Có|Không" \
      --add-combo="Chế độ chỉ xem (Không điều khiển)" --combo-values="Không|Có" \
      --width=450)
      
    if [ $? -ne 0 ]; then
        exit 0
    fi
    
    # Read the values
    IFS='|' read -r opt_screen_off opt_lock_close opt_res opt_audio opt_readonly <<< "$CONFIG_OUT"
    
    if [ "$opt_screen_off" = "Có" ]; then
        SCRCPY_OPTS+=("-S")
    fi
    if [ "$opt_lock_close" = "Có" ]; then
        SCRCPY_OPTS+=("--power-off-on-close")
    fi
    if [ "$opt_res" = "1080p" ]; then
        SCRCPY_OPTS+=("-m" "1920")
    elif [ "$opt_res" = "720p" ]; then
        SCRCPY_OPTS+=("-m" "1280")
    elif [ "$opt_res" = "480p" ]; then
        SCRCPY_OPTS+=("-m" "854")
    fi
    if [ "$opt_audio" = "Không" ]; then
        SCRCPY_OPTS+=("--no-audio")
    fi
    if [ "$opt_readonly" = "Có" ]; then
        SCRCPY_OPTS+=("-r")
    fi
fi

# Function to run scrcpy and log error if any
run_scrcpy_with_device() {
    local dev_id="$1"
    TEMP_LOG=$(mktemp)
    
    # Run scrcpy in the background
    scrcpy -s "$dev_id" "${SCRCPY_OPTS[@]}" > "$TEMP_LOG" 2>&1 &
    local scrcpy_pid=$!
    
    # Run python control bar in the background
    /usr/local/bin/scrcpy-control-bar.py "$dev_id" "$scrcpy_pid" &
    local bar_pid=$!
    
    # Wait for scrcpy to exit
    wait $scrcpy_pid
    local exit_code=$?
    
    # Clean up the control bar
    kill $bar_pid >/dev/null 2>&1
    
    if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ]; then
        local err_msg=$(cat "$TEMP_LOG")
        zenity --error --title="Lỗi khởi động Android Mirroring" --text="Không thể khởi động kết nối điện thoại.\n\n<b>Chi tiết lỗi:</b>\n<span font_family='monospace'>$err_msg</span>" --width=500
    fi
    rm -f "$TEMP_LOG"
}

# Check status of devices and execute
if [ "$NUM_DEVICES" -eq 1 ]; then
    SERIAL=$(echo "$DEVICES_OUT" | awk '{print $1}')
    STATUS=$(echo "$DEVICES_OUT" | awk '{print $2}')
    
    if [ "$STATUS" = "unauthorized" ]; then
        zenity --warning --title="Android Mirroring" --text="<b>Thiết bị chưa được ủy quyền!</b>\n\nVui lòng kiểm tra màn hình điện thoại của bạn.\nMột hộp thoại yêu cầu cấp quyền gỡ lỗi USB sẽ xuất hiện.\n\nHãy chọn <b>'Luôn cho phép từ máy tính này'</b> rồi nhấn <b>'Cho phép' (Allow)</b>, sau đó mở lại ứng dụng này." --width=450
        exit 1
    elif [ "$STATUS" = "offline" ]; then
        zenity --error --title="Android Mirroring" --text="<b>Thiết bị đang ngoại tuyến (Offline)!</b>\n\nVui lòng thử rút cáp USB ra và cắm lại, hoặc tắt và bật lại 'Gỡ lỗi USB' trong cài đặt điện thoại." --width=450
        exit 1
    else
        run_scrcpy_with_device "$SERIAL"
    fi
else
    # Multiple devices connected
    LIST_ITEMS=()
    while read -r line; do
        serial=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')
        LIST_ITEMS+=("$serial" "$status")
    done <<< "$DEVICES_OUT"
    
    SELECTED=$(zenity --list --title="Android Mirroring" --text="Phát hiện nhiều thiết bị. Vui lòng chọn thiết bị muốn kết nối:" --column="Mã thiết bị (Serial)" --column="Trạng thái" "${LIST_ITEMS[@]}" --width=450 --height=300)
    
    if [ -n "$SELECTED" ]; then
        # Check the status of the selected device
        SEL_STATUS=$(echo "$DEVICES_OUT" | grep "$SELECTED" | awk '{print $2}')
        if [ "$SEL_STATUS" = "unauthorized" ]; then
            zenity --warning --title="Android Mirroring" --text="<b>Thiết bị chưa được ủy quyền!</b>\n\nVui lòng mở điện thoại chọn 'Cho phép' cho yêu cầu Gỡ lỗi USB." --width=450
        elif [ "$SEL_STATUS" = "offline" ]; then
            zenity --error --title="Android Mirroring" --text="<b>Thiết bị đang ngoại tuyến!</b>" --width=450
        else
            run_scrcpy_with_device "$SELECTED"
        fi
    fi
fi
