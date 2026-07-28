#!/bin/bash

# ==============================================================================
# SCRIPT GIÁM SÁT VPS - TỰ ĐỘNG CẢNH BÁO TELEGRAM & TỰ PHỤC HỒI HỆ THỐNG
# ==============================================================================

# Đường dẫn file lưu cấu hình biến môi trường độc lập
CONFIG_FILE="/root/.vps_monitor_config"

# --- BƯỚC CẤU HÌNH BAN ĐẦU (Chạy lần đầu sẽ hỏi người dùng nhập) ---
if [ ! -f "$CONFIG_FILE" ]; then
    echo "=================================================================="
    echo " CẤU HÌNH BOT TELEGRAM CHO SCRIPT GIÁM SÁT (Chỉ nhập lần đầu) "
    echo "=================================================================="
    read -p "1. Nhập Telegram Bot Token (vídụ: 123456:ABC-DEF...): " TELEGRAM_TOKEN
    read -p "2. Nhập Telegram Chat ID của bạn (ví dụ: 987654321): " TELEGRAM_CHAT_ID
    read -p "3. Ngưỡng CPU cảnh báo (%) [Mặc định: 85]: " CPU_THRESHOLD
    CPU_THRESHOLD=${CPU_THRESHOLD:-85}
    read -p "4. Ngưỡng RAM cảnh báo (%) [Mặc định: 85]: " RAM_THRESHOLD
    RAM_THRESHOLD=${RAM_THRESHOLD:-85}
    read -p "5. Đường dẫn Access Log của Web server [Mặc định: /var/log/httpd/domains/winevn.com.log]: " LOG_PATH
    LOG_PATH=${LOG_PATH:-/var/log/httpd/domains/winevn.com.log}

    # Lưu trực tiếp vào file cấu hình
    cat << EOF > "$CONFIG_FILE"
TELEGRAM_TOKEN="$TELEGRAM_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
CPU_THRESHOLD=$CPU_THRESHOLD
RAM_THRESHOLD=$RAM_THRESHOLD
LOG_PATH="$LOG_PATH"
EOF
    echo "✓ Đã lưu cấu hình vào $CONFIG_FILE"
    echo "=================================================================="
fi

# Load các biến cấu hình vào môi trường chạy
source "$CONFIG_FILE"

# Kiểm tra đang chạy với Bash
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: Script phải chạy bằng bash, không dùng 'sh vps_monitor.sh'."
    echo "Hãy chạy: bash vps_monitor.sh hoặc ./vps_monitor.sh"
    exit 1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

check_command() {
    if ! command -v "$1" > /dev/null 2>&1; then
        log "ERROR: Lệnh cần thiết '$1' không tồn tại trên hệ thống."
        exit 1
    fi
}

check_command curl
check_command top
check_command awk
check_command grep
check_command free

log "Đã load cấu hình: CPU_THRESHOLD=${CPU_THRESHOLD}, RAM_THRESHOLD=${RAM_THRESHOLD}, LOG_PATH=${LOG_PATH}"

# Lấy địa chỉ IP Public của VPS để hiển thị trong báo cáo
SERVER_IP=$(curl -s https://api.ipify.org || echo "Unknown_IP")
HOSTNAME=$(hostname)

# --- THU THẬP THÔNG SỐ HỆ THỐNG ---
# 1. Tính toán % CPU sử dụng thực tế
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
CPU_INT=${CPU_USAGE%.*} # Chuyển về số nguyên để so sánh

# 2. Tính toán % RAM sử dụng thực tế (Không tính buffer/cache)
RAM_TOTAL=$(free | grep Mem | awk '{print $2}')
RAM_AVAILABLE=$(free | grep Mem | awk '{print $7}')
RAM_USED_PCT=$(( (RAM_TOTAL - RAM_AVAILABLE) * 100 / RAM_TOTAL ))

# --- HÀM GỬI THÔNG BÁO TELEGRAM ---
send_telegram() {
    local message="$1"
    local tmpfile="/tmp/vps_monitor_telegram_$$.txt"
    local http_status
    local response_body

    send_request() {
        http_status=$(curl -s -o "$tmpfile" -w "%{http_code}" -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${message}" \
            -d "parse_mode=Markdown")
        response_body=$(cat "$tmpfile" 2>/dev/null)
    }

    send_request

    if [ "$http_status" != "200" ]; then
        if echo "$response_body" | grep -q '"migrate_to_chat_id"'; then
            local new_chat_id
            new_chat_id=$(echo "$response_body" | sed -n 's/.*"migrate_to_chat_id"[[:space:]]*:[[:space:]]*\(-[0-9]\+\).*/\1/p')
            if [ -n "$new_chat_id" ]; then
                log "WARNING: Group chat đã nâng cấp thành supergroup. Cập nhật TELEGRAM_CHAT_ID=$new_chat_id"
                TELEGRAM_CHAT_ID="$new_chat_id"
                if sed -i.bak -E "s|^TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=\"${TELEGRAM_CHAT_ID}\"|" "$CONFIG_FILE"; then
                    rm -f "${CONFIG_FILE}.bak" 2>/dev/null
                    log "INFO: Đã cập nhật chat ID mới vào $CONFIG_FILE"
                else
                    log "WARNING: Không thể cập nhật $CONFIG_FILE tự động."
                fi
                send_request
            fi
        fi
    fi

    rm -f "$tmpfile"

    if [ "$http_status" != "200" ]; then
        log "ERROR: Telegram send failed HTTP=$http_status, response=${response_body}"
        return 1
    fi

    log "INFO: Telegram gửi thành công."
    return 0
}

# --- DAILY SUMMARY (SEND AT 17:00 ONCE PER DAY) ---
SUMMARY_HHMM="1700"
NOW_HHMM=$(date +%H%M)
TODAY_DATE=$(date +%F)
LAST_SUMMARY_FILE="/var/tmp/vps_monitor_last_summary_date"

# Prepare TOP_IPS for summary
if [ -f "$LOG_PATH" ]; then
    TOP_IPS=$(tail -n 50000 "$LOG_PATH" | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 10 | awk '{print "🔹 " $2 " - (Lượt gọi: " $1 ")"}')
else
    TOP_IPS="⚠️ Không tìm thấy file log tại đường dẫn cấu hình."
fi

IO_WAIT=$(top -bn1 | grep "Cpu(s)" | awk '{print $10}')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')

if [ "$NOW_HHMM" = "$SUMMARY_HHMM" ]; then
    if [ -f "$LAST_SUMMARY_FILE" ] && [ "$(cat $LAST_SUMMARY_FILE)" = "$TODAY_DATE" ]; then
        log "INFO: Daily summary already sent today."
    else
        TITLE="Monitoring trạng thái của VPS sử dụng trong ngày hôm nay website winevn.com"
        TITLE_UPPER=$(echo "$TITLE" | tr '[:lower:]' '[:upper:]')
        read -r -d '' SUMMARY_MSG << EOF
${TITLE_UPPER}

📊 HIỆU NĂNG HỆ THỐNG:
• CPU sử dụng: ${CPU_USAGE}%
• RAM sử dụng: ${RAM_USED_PCT}%
• Load Average: ${LOAD_AVG}
• Tắc nghẽn Ổ cứng (I/O Wait): ${IO_WAIT}%

👥 TOP 10 IP TRUY CẬP NHIỀU NHẤT GẦN ĐÂY:
${TOP_IPS}
EOF
        if send_telegram "$SUMMARY_MSG"; then
            echo "$TODAY_DATE" > "$LAST_SUMMARY_FILE"
            log "INFO: Daily summary sent and recorded."
        else
            log "ERROR: Failed to send daily summary."
        fi
    fi
fi

# --- KIỂM TRA NẾU VƯỢT NGƯỠNG NGUY HIỂM ---
if [ "$CPU_INT" -gt "$CPU_THRESHOLD" ] || [ "$RAM_USED_PCT" -gt "$RAM_THRESHOLD" ]; then
    log "WARNING: Ngưỡng vượt: CPU=${CPU_INT}% (ngưỡng ${CPU_THRESHOLD}%), RAM=${RAM_USED_PCT}% (ngưỡng ${RAM_THRESHOLD}%)"
    
    # 1. Tìm tiến trình "ngốn" tài nguyên nhất
    TOP_PROCESS=$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -n 2 | tail -n 1)
    TOP_PID=$(echo "$TOP_PROCESS" | awk '{print $1}')
    TOP_USER=$(echo "$TOP_PROCESS" | awk '{print $2}')
    TOP_P_CPU=$(echo "$TOP_PROCESS" | awk '{print $3}')
    TOP_P_MEM=$(echo "$TOP_PROCESS" | awk '{print $4}')
    TOP_COMMAND=$(echo "$TOP_PROCESS" | awk '{print $5}')

    # 2. Dự đoán Nguyên nhân thông minh
    REASON="Chưa xác định rõ."
    if [[ "$TOP_COMMAND" == *"php"* ]]; then
        REASON="Mã nguồn PHP bị treo/vòng lặp vô hạn (Loop), hoặc đang gánh lượng request quá lớn."
    elif [[ "$TOP_COMMAND" == *"mysql"* ]]; then
        REASON="Hệ quản trị Database đang xử lý các câu lệnh SQL quá nặng, thiếu index hoặc bị phân mảnh."
    elif [[ "$TOP_COMMAND" == *"nginx"* || "$TOP_COMMAND" == *"httpd"* ]]; then
        REASON="Web Server bị quá tải kết nối hoặc đang hứng chịu tấn công từ chối dịch vụ (DDoS/Spam)."
    fi

    # 3. Thống kê top 10 IP truy cập nhiều nhất (Bổ sung thêm mã HTTP 3xx/5xx để phân tích loop)
    TOP_IPS=""
    if [ -f "$LOG_PATH" ]; then
        TOP_IPS=$(tail -n 50000 "$LOG_PATH" | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 10 | awk '{print "🔹 " $2 " - (Lượt gọi: " $1 ")"}')
    else
        TOP_IPS="⚠️ Không tìm thấy file log tại đường dẫn cấu hình."
    fi

    # 4. Thu thập thêm thông tin quan trọng (Bổ sung thông số I/O Wait)
    IO_WAIT=$(top -bn1 | grep "Cpu(s)" | awk '{print $10}')
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')

    # --- SOẠN BẢN TIN CẢNH BÁO ---
    read -r -d '' ALERT_MSG << EOF
⚠️🔴 [CẢNH BÁO] VPS CÓ DẤU HIỆU QUÁ TẢI!
----------------------------------
🖥️ Máy chủ: ${HOSTNAME} (${SERVER_IP})
⏰ Thời gian: $(date "+%H:%M:%S %d/%m/%Y")

📊 HIỆU NĂNG HỆ THỐNG:
• CPU sử dụng: ${CPU_USAGE}% (Ngưỡng: ${CPU_THRESHOLD}%)
• RAM sử dụng: ${RAM_USED_PCT}% (Ngưỡng: ${RAM_THRESHOLD}%)
• Load Average: ${LOAD_AVG}
• Tắc nghẽn Ổ cứng (I/O Wait): ${IO_WAIT}%

🔥 TIẾN TRÌNH GÂY NGHẼN CAO NHẤT:
• Lệnh: ${TOP_COMMAND} (PID: ${TOP_PID})
• Thuộc sở hữu User: ${TOP_USER}
• Mức tiêu thụ: ${TOP_P_CPU}% CPU | ${TOP_P_MEM}% RAM

🧠 PHÂN TÍCH NGUYÊN NHÂN:
👉 ${REASON}

👥 TOP 10 IP TRUY CẬP NHIỀU NHẤT GẦN ĐÂY:
${TOP_IPS}
----------------------------------
🚨 ĐANG KÍCH HOẠT CƠ CHẾ TỰ PHỤC HỒI (RESTART SERVICES)...
EOF

    # Gửi báo cáo lỗi qua Telegram
    send_telegram "$ALERT_MSG"

    # --- CƠ CHẾ TỰ PHỤC HỒI (RESTART) ---
    send_telegram "⏳ Đang thực hiện lệnh: systemctl restart php8.1-fpm nginx httpd..."
    
    # Thực hiện restart dịch vụ PHP-FPM phù hợp với phiên bản đang dùng
    PHP_FPM_SERVICES=("php8.1-fpm" "php8.0-fpm" "php7.4-fpm" "php-fpm")
    PHP_FPM_RESTARTED=0
    for svc in "${PHP_FPM_SERVICES[@]}"; do
        if systemctl list-unit-files --type=service | grep -q "^${svc}.service"; then
            systemctl restart "$svc" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                send_telegram "✅ Đã restart dịch vụ PHP-FPM: ${svc}"
                PHP_FPM_RESTARTED=1
            else
                send_telegram "⚠️ Không thể restart dịch vụ PHP-FPM: ${svc}"
            fi
            break
        fi
    done
    if [ "$PHP_FPM_RESTARTED" -eq 0 ]; then
        send_telegram "⚠️ Không tìm thấy dịch vụ PHP-FPM thích hợp trên hệ thống."
    fi

    systemctl restart nginx > /dev/null 2>&1
    RESTART_NGINX_STATUS=$?
    
    systemctl restart httpd > /dev/null 2>&1
    RESTART_HTTPD_STATUS=$?

    # --- THÔNG BÁO KẾT QUẢ RESTART ---
    log "INFO: Restart nginx trả về ${RESTART_NGINX_STATUS}."
    log "INFO: Restart httpd trả về ${RESTART_HTTPD_STATUS}."
    if [ $RESTART_NGINX_STATUS -eq 0 ] && [ $RESTART_HTTPD_STATUS -eq 0 ]; then
        send_telegram "✅ Tự động phục hồi THÀNH CÔNG! Nginx và Apache (httpd) đã hoạt động bình thường trở lại."
    else
        log "ERROR: Restart service thất bại, kiểm tra lại hệ thống."
        send_telegram "❌ Tự động phục hồi THẤT BẠI hoặc có dịch vụ không thể khởi động lại. Vui lòng vào SSH kiểm tra khẩn cấp!"
    fi

else
    log "INFO: Hệ thống bình thường; CPU=${CPU_INT}% RAM=${RAM_USED_PCT}%. Không gửi Telegram."
fi
