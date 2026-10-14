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
| 0.2.0 | Rootless | Dành cho Dopamine rootless; `iphoneos-arm64`. |
| 0.2.1 beta6 rh1 | RootHide | `iphoneos-arm64e`; cần rootless-compat >= 0.9; có log cài đặt và chẩn đoán. |

## Cài đặt

Mở https://manhtien9x.github.io/gofahud-repo/ bằng Safari, bấm **Thêm vào Sileo**. Làm mới nguồn và cài GOFA HUD đúng kiến trúc của môi trường jailbreak.

Cài xong Respring, mở GOFA và cấp quyền vị trí **Luôn luôn**, bật **Vị trí chính xác**. Cần cài riêng GOFA 4.2.1.

Hai gói dành cho hai môi trường khác nhau. Đây là bản thử nghiệm; chưa xác nhận tương thích với mọi phiên bản iOS. Cảnh báo camera thực tế còn cần kiểm chứng. Các beta rootless 0.2.1 đang lỗi CarPlay không được đưa vào chỉ mục nguồn.

Gỡ gói trong Sileo rồi Respring. Log chẩn đoán của bản RootHide nằm trong `/var/mobile/Library/Logs/`.

Tham khảo nền tảng GMapHUD của chou. Xem [LICENSE](LICENSE).
