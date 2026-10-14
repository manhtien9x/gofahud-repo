# GOFA HUD

Bong bóng tốc độ và biển báo GOFA trên iPhone và CarPlay.

## Tính năng

- Hiển thị dữ liệu tốc độ, biển giới hạn từ GOFA khi chuyển ứng dụng.
- Kéo đổi vị trí; chạm mở GOFA trên màn hình đang sử dụng.
- Kéo vào X để tắt. Mở GOFA rồi chuyển ứng dụng để hiện lại.
- Tự ẩn khi GOFA ở phía trước.

## Phiên bản

| Phiên bản | Tương thích | Ghi chú |
| --- | --- | --- |
| 0.2.1-2 | iOS 14 / Taurine Rootful | arm64; GOFA 4.2.1; org.coolstar.libhooker; sửa dependency và probe Swift gây văng app. |
| 0.2.1 | Rootless | Dopamine, iOS 15 và 16; một gói `iphoneos-arm64` có cả arm64 + arm64e; có log cài đặt và chẩn đoán. |
| 0.2.1 | RootHide | `iphoneos-arm64e`; cần rootless-compat >= 0.9; có log cài đặt và chẩn đoán. |

## Cài đặt

Mở https://manhtien9x.github.io/gofahud-repo/ bằng Safari, bấm **Thêm vào Sileo**. Làm mới nguồn và cài GOFA HUD đúng kiến trúc của môi trường jailbreak.

Cài xong Respring, mở GOFA và cấp quyền vị trí **Luôn luôn**, bật **Vị trí chính xác**. Cần cài riêng GOFA 4.2.1.

Ba gói dành cho ba môi trường khác nhau. Đây là bản thử nghiệm; chưa xác nhận tương thích với mọi phiên bản iOS. Cảnh báo camera thực tế còn cần kiểm chứng. Bản Rootless 0.2.1 sửa lỗi nạp thư viện khiến CarPlay không kết nối được trên bản cũ.

Gỡ gói trong Sileo rồi Respring. Log chẩn đoán nằm trong `/var/mobile/Library/Logs/`.

Tham khảo nền tảng GMapHUD của chou. Xem [LICENSE](LICENSE).

## Bản iOS 14

Taurine Rootful, iOS 14, arm64; chưa có arm64e. Đã có bong bóng trên iPhone và CarPlay; đăng nhập sau bản sửa 0.2.1-2 cần xác nhận lại. Log tại `/var/mobile/Library/Logs/`; crash GOFA trong `CrashReporter`.
