# GOFA HUD

Bong bóng hiển thị tốc độ và cảnh báo từ GOFA trên iPhone đã jailbreak và màn hình CarPlay. Bạn có thể xem thông tin GOFA khi dùng Google Maps, nghe nhạc hoặc chuyển sang ứng dụng khác.

## Tính năng

- **Tốc độ và biển giới hạn:** nhận dữ liệu do GOFA cung cấp, kể cả khi ứng dụng chạy nền.
- **Bong bóng trên iPhone và CarPlay:** đã thử trên Home CarPlay, Google Maps và YouTube Music.
- **Kéo đổi vị trí:** đặt bong bóng ở vị trí thuận tiện trên màn hình.
- **Chạm mở GOFA:** mở trên màn hình CarPlay khi kết nối xe; mở trên iPhone khi không kết nối CarPlay.
- **Kéo vào X để tắt:** kéo xuống gần mép dưới để hiện dấu X, rồi thả vào X. Mở lại GOFA và chuyển ứng dụng để hiện lại bong bóng.
- **Tự ẩn khi mở GOFA:** chuyển sang ứng dụng khác để hiện lại.

Luồng cảnh báo camera đã được nối, nhưng cảnh báo camera thực tế vẫn cần kiểm chứng.

## Tương thích

| Thành phần | Trạng thái |
| --- | --- |
| Jailbreak | Dopamine, môi trường rootless |
| Kiến trúc gói | `iphoneos-arm64` |
| Thiết bị đã thử | iPhone 6s |
| iOS đã thử | 15.8.8 |
| GOFA đã thử | 4.2.1 |
| iOS 15 khác | Chưa kiểm tra đầy đủ |
| iOS 16–18 | Chưa được kiểm chứng |
| RootHide / Relaxin | Bản 0.2.0 chưa xác nhận hỗ trợ |

Điều kiện cài đặt iOS ≥ 15 trong gói không có nghĩa là đã tương thích với mọi phiên bản mới hơn. Tweak cần ứng dụng GOFA được cài riêng.

## Cài đặt

1. Mở [trang GOFA HUD](https://manhtien9x.github.io/gofahud-repo/) bằng Safari trên iPhone, bấm **Thêm vào Sileo**. Hoặc thêm nguồn `https://manhtien9x.github.io/gofahud-repo/` trong Sileo → Nguồn → +.
2. Tìm **GOFA HUD**, cài gói và Respring.
3. Mở GOFA, cấp quyền vị trí **Luôn luôn** và bật **Vị trí chính xác**.
4. Chuyển ứng dụng để dùng bong bóng.

Tải file `.deb` trong [GitHub Releases](https://github.com/manhtien9x/gofahud-repo/releases/tag/v0.2.0).

## Thông tin bản thử nghiệm

- Phiên bản: **0.2.0**; mã gói: `local.gofahud`.
- Tốc độ quá hạn không được coi là dữ liệu mới. Nếu thiếu dữ liệu, mở lại GOFA và kiểm tra quyền vị trí.
- Gói có ghi nhật ký chẩn đoán cục bộ trên thiết bị phục vụ kiểm tra.
- Gỡ trong Sileo → Đã cài đặt → GOFA HUD → Gỡ cài đặt, rồi Respring.

Repository này chứa trang giới thiệu, chỉ mục nguồn Sileo và gói phát hành.

## Ghi nhận

Tham khảo nền tảng GMapHUD của chou. Xem [LICENSE](LICENSE) về giấy phép của nội dung trong repository.
