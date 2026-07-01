# VPS Monitor - Tự Động Cảnh Báo Telegram & Tự Phục Hồi Hệ Thống

Script Bash giúp tự động giám sát hiệu năng CPU, RAM, Load Average và I/O Wait của VPS. Khi hệ thống chạm ngưỡng nguy hiểm có nguy cơ treo web, script sẽ tự động phân tích nguyên nhân, thống kê Top 10 IP truy cập nhiều nhất, gửi báo cáo chi tiết qua Telegram và chủ động khởi động lại (Restart) các dịch vụ Nginx, Apache (`httpd`), và PHP-FPM để cứu website online trở lại.

* **Mã nguồn dự án:** [vps_monitor.sh](https://github.com/micromeo/wordpress_tips/blob/main/vps-monitor/vps_monitor.sh)

---

## 📑 MỤC LỤC
1. [Hướng dẫn tạo Bot Telegram & Lấy ID](#1-hướng-dẫn-tạo-bot-telegram--lấy-id)
2. [Hướng dẫn cài đặt lên VPS](#2-hướng-dẫn-cài-đặt-lên-vps)
3. [Cấu hình chạy tự động (Cronjob)](#3-cấu-hình-chạy-tự-động-cronjob)
4. [Hướng dẫn kiểm thử (Test)](#4-hướng-dẫn-kiểm-thử-test)

---

## 1. Hướng dẫn tạo Bot Telegram & Lấy ID

Để script có thể gửi tin nhắn, bạn cần một **Bot Token** và một **Chat ID** (Cá nhân hoặc Group).

### Bước 1.1: Tạo Bot và lấy Token
1. Mở Telegram, tìm kiếm robot chính thức có tên **@BotFather**.
2. Gửi lệnh `/newbot`.
3. Nhập tên cho Bot của bạn (Ví dụ: `My VPS Monitor Bot`).
4. Nhập Username cho Bot (Phải kết thúc bằng chữ `bot`, ví dụ: `winevn_monitor_bot`).
5. Sau khi thành công, @BotFather sẽ gửi cho bạn một đoạn mã **API Token** có dạng:  
   `123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ` (Hãy lưu lại chuỗi này).

### Bước 1.2: Lấy Chat ID cá nhân hoặc ID Group
* **Nếu nhận cảnh báo về Chat cá nhân:**
  1. Tìm kiếm Bot **@userinfobot** trên Telegram và bấm `Start`.
  2. Bot sẽ trả về một dãy số tại mục `Id:` (Ví dụ: `987654321`). Đó chính là **Chat ID** của bạn.
* **Nếu nhận cảnh báo về Group (Nhóm):**
  1. Thêm con Bot bạn vừa tạo ở Bước 1.1 vào Group.
  2. Thêm tiếp con Bot có tên **@RawDataBot** vào Group đó.
  3. Ngay khi vào nhóm, @RawDataBot sẽ trả về một đoạn mã JSON. Hãy tìm dòng `"chat": { "id": -100xxxxxxxxxx`.
  4. Chuỗi số có dấu trừ phía trước (Ví dụ: `-100123456789`) chính là **Group Chat ID**. Sau khi lấy xong bạn có thể kích `@RawDataBot` ra khỏi nhóm.

---

## 2. Hướng dẫn cài đặt lên VPS

Thực hiện tuần tự các lệnh sau với quyền `root` qua SSH:

```bash
# 1. Tải script trực tiếp từ GitHub về thư mục root của VPS
curl -o /root/vps_monitor.sh [https://raw.githubusercontent.com/micromeo/wordpress_tips/main/vps-monitor/vps_monitor.sh](https://raw.githubusercontent.com/micromeo/wordpress_tips/main/vps-monitor/vps_monitor.sh)

# 2. Cấp quyền thực thi cho file script
chmod +x /root/vps_monitor.sh

# 3. Chạy script lần đầu tiên để cấu hình thông số
sh /root/vps_monitor.sh

## 3. Ảnh Demo
<img width="559" height="922" alt="Screenshot 2026-07-01 at 22 24 43" src="https://github.com/user-attachments/assets/b0073f92-b2cb-46e1-a1ab-5f9a52dda06b" />

