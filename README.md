# GOFA HUD 0.3.1

Bong bóng cảnh báo GOFA trên iPhone và CarPlay.

## Tính năng

- **Tốc độ và biển giới hạn:** Nhận dữ liệu từ GOFA, kể cả khi ứng dụng chạy nền. Bong bóng nổi trên iPhone và các ứng dụng CarPlay.
- **Bong bóng tự co giãn:** Không có cảnh báo thì thu gọn. Khi GOFA cung cấp camera, khu dân cư hoặc cấm vượt, tự thêm ô biểu tượng và khoảng cách bên dưới.
- **Tùy chỉnh trong Cài đặt:** Chọn Ngang/Dọc, kích cỡ 50–150%, vị trí, thứ tự các phần và màu sáng/tối. Thiết lập riêng cho iPhone và CarPlay; có preview minh họa.
- **Mở GOFA bằng một chạm:** Chạm để mở GOFA trên CarPlay khi đang kết nối xe, hoặc trên iPhone khi không dùng CarPlay.
- **Kéo để di chuyển hoặc tắt:** Kéo đổi vị trí. Kéo vào dấu X để tắt; mở lại GOFA rồi chuyển ứng dụng để bong bóng hiện lại.
- **Cảnh báo vượt tốc độ:** Màu tốc độ đổi khi gần/vượt giới hạn. Có tùy chọn viền cảnh báo trên bong bóng hoặc màn hình.
- **Tự động hóa:** Tùy chọn tự mở GOFA và tự thoát sau 20 giây ngắt CarPlay; kết nối lại sẽ hủy đếm giờ.
- **Chẩn đoán và xuất TXT:** Xuất nguyên nội dung các tệp đọc được trong Logs, CrashReporter và log GOFA vào một TXT. Có SHA-256, thời gian và danh sách phần thiếu; không tự tải lên mạng.

## Các gói

- [Rootless](./GOFAHUD-0.3.1-rootless.deb): iOS 15–16, Dopamine Rootless.
- [RootHide](./GOFAHUD-0.3.1-roothide.deb): RootHide; cần rootless-compat từ 0.9.
- [iOS 14 Rootful](./GOFAHUD-0.3.1-rootful.deb): Dành cho iOS 14 Rootful.

## Cài đặt

Thêm https://manhtien9x.github.io/gofahud-repo/ vào Sileo hoặc Zebra, cài đúng gói, Respring và mở GOFA. Cấp quyền vị trí Luôn luôn và Vị trí chính xác. Tùy chỉnh tại Cài đặt → GOFA HUD.

Các gói mới iOS14.1/16.3/16.7 chưa kiểm thử lại thực tế; cảnh báo dân cư/cấm vượt thật cần đối chiếu. Không xác nhận iOS17/18.

Mã tích hợp từ GMapHUD của chou theo giấy phép MIT được ghi trong source/upstream.
