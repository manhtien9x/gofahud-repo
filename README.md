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
- [iOS 14 Rootful](./GOFAHUD-0.3.1-1-rootful.deb): Dành cho iOS 14 Rootful.

## Hướng dẫn sử dụng

### 1. Cài đúng phiên bản

Thêm nguồn https://manhtien9x.github.io/gofahud-repo/ vào Sileo hoặc Zebra. Chọn gói theo môi trường jailbreak:

- **iOS 14 Rootful:** dùng gói Rootful.
- **Dopamine Rootless trên iOS 15–16:** dùng gói Rootless.
- **RootHide:** dùng gói RootHide và cài rootless-compat từ 0.9.

Cài gói, Respring rồi mở GOFA 4.2.1. Vào **Cài đặt → GOFA → Vị trí**, chọn **Luôn luôn** và bật **Vị trí chính xác**. Đợi GOFA nhận thông tin rồi về Home hoặc chuyển sang ứng dụng khác để hiện bong bóng.

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

### 6. Xuất log khi cần kiểm tra lỗi

Sau khi gặp lỗi, vào **Cài đặt → GOFA HUD → Chẩn đoán / Xuất log → Xuất**. Đợi gom dữ liệu, chọn **Lưu vào Tệp** rồi lưu file **GOFAHUD-full-logs-….txt** vào Tải về. Gửi file TXT này kèm mô tả lỗi và thời điểm xảy ra.

File TXT gom nội dung các tệp đọc được trong Logs, CrashReporter và log GOFA, kèm đường dẫn, SHA-256, thời gian bắt đầu/kết thúc xuất và danh sách tệp không đọc được hoặc thay đổi trong lúc gom. Dữ liệu nhị phân được lưu dạng Base64. Chức năng không tự tải log lên mạng; file có thể chứa thông tin thiết bị và vị trí, hãy gửi riêng khi nhờ kiểm tra.

### 7. Nếu bong bóng không hiện hoặc thiếu dữ liệu

- Kiểm tra máy đang ở trạng thái jailbreak, đã bật chạy tweak và bật GOFA HUD trong Cài đặt. Respring rồi mở GOFA lại.
- Kiểm tra đã cài đúng gói Rootful/Rootless/RootHide và các dependency mà Sileo/Zebra yêu cầu; không cài chồng các gói khác môi trường.
- Nếu thiếu tốc độ hoặc biển báo, kiểm tra dữ liệu trong GOFA trước, quyền vị trí Luôn luôn và Vị trí chính xác. Mở GOFA để nhận dữ liệu rồi chuyển app; không bật chế độ TEST khi đối chiếu dữ liệu thật.
- Nếu vẫn lỗi, xuất TXT ngay sau khi thử lại và gửi kèm phiên bản iOS, GOFA, GOFA HUD cùng môi trường jailbreak.

Đã kiểm thử thành công trên iOS 14.1, 15.8.8, 16.3 và 16.7 theo xác nhận của người dùng ngày 15/10/2026. Chọn đúng gói theo môi trường jailbreak; cần GOFA 4.2.1. Không xác nhận iOS17/18.

Mã tích hợp từ GMapHUD của chou theo giấy phép MIT được ghi trong source/upstream.

## Rootful 0.3.1-1

Sửa cầu nối gọi nhầm jbctl của Dopamine trên Taurine Rootful. Giữ các tính năng giao diện và xuất TXT. Rootless/RootHide giữ bản 0.3.1 đã kiểm thử.
