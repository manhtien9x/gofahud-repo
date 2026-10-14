# GOFA HUD 0.2.0 — Dopamine rootless

Gói lấy đúng các binary đã ký và đang chạy trên iPhone được kiểm thử ngày 12/10/2026. Không bao gồm GOFA/Google Maps, APK, mật khẩu SSH, dữ liệu cá nhân hoặc log chuyến đi.

Cài bằng Sileo/Filza, sau đó Respring và mở lại GOFA. Yêu cầu iOS 15 trở lên, Dopamine rootless, GOFA 4.2.1. Đã thử trực tiếp trên iPhone 6s iOS 15.8.8; các phiên bản iOS/GOFA khác chưa được kiểm chứng. Nguồn GOFA có kiểm tra phiên bản/UUID để tránh đọc sai model.

- iPhone: bong bóng nổi trên các ứng dụng, kéo đổi vị trí, chạm mở GOFA, kéo vào X để tắt; mở GOFA rồi bấm Home sẽ hiện lại.
- CarPlay: đã thử trên Home, Google Maps và YouTube Music; kéo đổi vị trí, chạm mở GOFA trên màn hình xe, kéo vào X để tắt; mở GOFA rồi chuyển app khác sẽ hiện lại. Kích thước mỗi chiều còn 70% bản ban đầu.
- Tốc độ dương hết hạn sau 5 giây không có mẫu mới. Mẫu 0 có thể được giữ kèm nhãn chờ dữ liệu. Giới hạn phản ánh quyết định GOFA; camera thật còn cần thử trên đường.

Nhật ký ở `/var/mobile/Library/Logs/GofaHUD-drive.jsonl`, có giờ Việt Nam, mốc phiên CarPlay, tốc độ/biển/camera và chất lượng mẫu; giữ tối đa khoảng 40 MB. Không ghi tọa độ đường đi. Đây là bản thử có ghi chẩn đoán.

Gỡ trong trình quản lý gói rồi Respring. Log và thiết lập cá nhân được giữ lại. Lệnh hỗ trợ `/var/jb/usr/libexec/gofahud-tests/gofahud-test-speed carplay-show` bật lại bong bóng CarPlay khi cần.

Gói không kèm SidePlay/ZZSidePlayDock3. Bản ghi nhận Safe Mode trong buổi thử chỉ ra ZZSidePlayDock3 trong hai báo cáo SpringBoard; sau phục hồi, phần GOFA đã được nạp lại và người dùng xác nhận các thao tác đúng.
