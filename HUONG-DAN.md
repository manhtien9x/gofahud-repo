## Hướng dẫn sử dụng

### 1. Cài đúng phiên bản

Thêm nguồn https://manhtien9x.github.io/gofahud-repo/ vào Sileo hoặc Zebra. Chọn gói theo môi trường jailbreak:

- **iOS 14 Rootful:** dùng gói Rootful.
- **Dopamine Rootless trên iOS 15–16:** dùng gói Rootless.
- **RootHide:** dùng gói RootHide và cài rootless-compat từ 0.9.

Cài gói, Respring rồi mở GOFA 4.2.1 hoặc 4.2.2 (iOS 14 dùng GOFA 4.2.1). Vào **Cài đặt → GOFA → Vị trí**, chọn **Luôn luôn** và bật **Vị trí chính xác**. Đợi GOFA nhận thông tin rồi về Home hoặc chuyển sang ứng dụng khác để hiện bong bóng.

### 2. Điều khiển bong bóng

- **Di chuyển:** nhấn giữ và kéo bong bóng tới vị trí thuận tiện.
- **Mở GOFA:** chạm một lần. Khi kết nối CarPlay, GOFA mở trên màn hình xe; khi không kết nối, GOFA mở trên iPhone.
- **Tắt bong bóng:** kéo xuống gần mép dưới để hiện dấu X, rồi thả bong bóng vào X.
- **Hiện lại:** mở GOFA rồi về Home hoặc chuyển sang ứng dụng khác.

### 3. Chỉnh giao diện

Vào **Cài đặt → GOFA HUD** để bật/tắt hiển thị. Mở mục **iPhone** hoặc **CarPlay** để chỉnh riêng cho từng màn hình: bố cục Ngang/Dọc, kích cỡ 50–150%, vị trí, thứ tự các phần và màu sáng/tối. Xem preview khi chỉnh; dùng Đặt lại nếu muốn trở về thiết lập ban đầu.

Không có cảnh báo thì bong bóng thu gọn. Khi GOFA cung cấp cảnh báo camera, khu dân cư hoặc cấm vượt, bong bóng tự mở rộng và hiển thị biểu tượng cùng khoảng cách bên dưới. Ký hiệu **--** nghĩa là chưa có dữ liệu hợp lệ.

### 4. Dùng trên CarPlay

Kết nối CarPlay, mở GOFA một lần để nhận dữ liệu rồi chuyển sang Google Maps, ứng dụng nhạc hoặc Home CarPlay. Bong bóng tiếp tục hiển thị trên các màn hình này; có thể kéo đổi vị trí, chạm mở GOFA hoặc kéo vào X để tắt.

Trong Cài đặt GOFA HUD, bạn có thể bật các tùy chọn tự mở GOFA khi dùng CarPlay và tự thoát GOFA sau 20 giây ngắt kết nối. Nếu kết nối lại trong thời gian này, lệnh tự thoát được hủy. Chỉ thao tác và chỉnh giao diện khi xe đang đỗ.

### 5. Thử giao diện và cảnh báo

Các nút **42/50, 48/50, 62/50** trong Cài đặt dùng dữ liệu minh họa để xem bố cục và cảnh báo. Khi thử, bong bóng có nhãn **TEST**, tự kết thúc sau 60 giây; bấm **Tắt thử** để quay lại dữ liệu thật ngay. Có thể bật viền cảnh báo trên bong bóng hoặc màn hình trong phần tùy chỉnh vượt tốc độ.

### 6. Gửi logs khi cần kiểm tra lỗi

Sau khi gặp lỗi, vào **Cài đặt → GOFA HUD → Gửi logs**. Đợi gom dữ liệu; bảng chia sẻ iOS sẽ tự mở với file **GOFAHUD-full-logs-….txt**. Chọn ứng dụng để gửi hoặc **Lưu vào Tệp** để giữ bản sao. Kèm mô tả lỗi và thời điểm xảy ra khi gửi.

File TXT gom nội dung các tệp đọc được trong Logs, CrashReporter và log GOFA, kèm đường dẫn, SHA-256, thời gian bắt đầu/kết thúc xuất và danh sách tệp không đọc được hoặc thay đổi trong lúc gom. Dữ liệu nhị phân được lưu dạng Base64. Chức năng không tự tải log lên mạng; file có thể chứa thông tin thiết bị và vị trí, hãy gửi riêng khi nhờ kiểm tra.

### 7. Nếu bong bóng không hiện hoặc thiếu dữ liệu

- Kiểm tra máy đang ở trạng thái jailbreak, đã bật chạy tweak và bật GOFA HUD trong Cài đặt. Respring rồi mở GOFA lại.
- Kiểm tra đã cài đúng gói Rootful/Rootless/RootHide và các dependency mà Sileo/Zebra yêu cầu; không cài chồng các gói khác môi trường.
- Nếu thiếu tốc độ hoặc biển báo, kiểm tra dữ liệu trong GOFA trước, quyền vị trí Luôn luôn và Vị trí chính xác. Mở GOFA để nhận dữ liệu rồi chuyển app; không bật chế độ TEST khi đối chiếu dữ liệu thật.
- Nếu vẫn lỗi, xuất TXT ngay sau khi thử lại và gửi kèm phiên bản iOS, GOFA, GOFA HUD cùng môi trường jailbreak.
