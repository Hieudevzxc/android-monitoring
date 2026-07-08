#!/bin/bash

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

if [ "$NUM_DEVICES" -eq 0 ]; then
    zenity --error --title="Android Mirroring" --text="<b>Không tìm thấy thiết bị Android nào!</b>\n\nĐể kết nối điện thoại, vui lòng thực hiện:\n1. Kết nối điện thoại với máy tính bằng <b>cáp USB</b> chất lượng tốt.\n2. Mở điện thoại, vào <b>Cài đặt -> Hệ thống -> Tùy chọn nhà phát triển</b> và bật <b>Gỡ lỗi USB (USB Debugging)</b>.\n\n<i>* Nếu không thấy Tùy chọn nhà phát triển, vào Cài đặt -> Thông tin điện thoại -> Nhấn liên tục 7 lần vào 'Số hiệu bản dựng' (Build Number).</i>" --width=450
    exit 1
fi

# Define default options array
SCRCPY_OPTS=()

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

# Check status of devices
# adb devices output formats:
# <serial>   device
# <serial>   unauthorized
# <serial>   offline

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
