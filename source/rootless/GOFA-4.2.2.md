# GOFA HUD 0.3.2 — GOFA 4.2.2

Thêm profile cho GOFA 4.2.2 build 3, UUID 083A8351-4BD5-3F58-B014-AA10B06180D7. Giữ nguyên profile GOFA 4.2.1. Mỗi profile kiểm tra version và UUID trước khi đọc model.

BleManager: signGosafeMessage đổi 160 → 176, lastUserSpeed đổi 200 → 296, connectedPeripheral đổi 104 → 120. Đã đối chiếu reflection của app thật; SignMessage và LocationUpdateEvent giữ cấu trúc tương ứng. Bắt đối tượng sau init gốc để không phụ thuộc việc khởi tạo Bluetooth. Không tự khởi tạo hoặc kết nối thiết bị HUD.

Đã nhận dữ liệu thật trên iOS 15.8.8 với GOFA 4.2.2: giới hạn 50 km/h, tốc độ 3 km/h, mẫu fresh khi GOFA ở nền; người dùng xác nhận đã nhận dữ liệu ngày 20/10/2026. Arm64e biên dịch bằng Apple clang, cần thử lại trên thiết bị. Cảnh báo camera thật và phiên CarPlay của bản mới chưa kiểm thử.
