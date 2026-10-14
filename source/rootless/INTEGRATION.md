# Chuyển tính năng GMapHUD sang GOFA HUD

Nguồn đối chiếu: bechou0410/gmaphud, commit 8d4ff89957346ba07d6f3882cf4a4910e4192ab8 (0.2.2), giấy phép MIT. Giữ giấy phép trong upstream/GMapHUD-LICENSE. Chưa phát hành lên repo.

| Phần | Trạng thái mã nguồn bản thử |
|---|---|
| Trang chính và trang con iPhone/CarPlay | Đã chuyển; dùng Preferences và các cell gốc đã đổi domain |
| Ngang/dọc, kích cỡ 50–150%, đặt lại | Đã nối với overlay |
| Công tắc tổng và theo màn hình | Đã nối với overlay; thao tác X dùng trạng thái riêng |
| Chọn góc | Đã nối với vị trí overlay; vẫn kéo tự do được |
| Sắp xếp tốc độ/giới hạn/cảnh báo | Chuyển cell kéo sắp xếp từ upstream; renderer GOFA dùng thứ tự đã lưu |
| Preview | Chuyển mẫu minh họa CarPlay và cell xem trước; dữ liệu mẫu, không phải dữ liệu đường thật |
| Màu sáng/tối | Đã nối; không dùng màu bản đồ Google Maps vì overlay hiện trên mọi ứng dụng |
| Vượt tốc độ | Viền bong bóng hoặc màn hình; chưa kiểm thử trên xe |
| Tự mở/thoát nguồn | Chuyển supervisor upstream, nguồn cố định GOFA, namespace riêng; mặc định tắt, thoát sau 20 giây mất CarPlay |
| Thử hiển thị | 42/50, 48/50, 62/50, tắt; nhãn TEST, tự hết sau 60 giây; không đổi GPS |
| Chẩn đoán/xuất log | Báo cáo trạng thái và log giới hạn dung lượng; sao chép/xuất bằng share sheet |
| Full Map và Dashboard có cấu hình độc lập | Chưa chuyển; overlay toàn hệ thống hiện dùng một cấu hình CarPlay |
| Vị trí tinh chỉnh bằng phần trăm X/Y | Chưa chuyển; hiện chọn góc và kéo trực tiếp |
| Artwork biển báo và hai cảnh báo cùng lúc | Chưa chuyển đầy đủ; model GOFA hiện truyền một cảnh báo camera |
| Nguồn VietMap/Waze | Chưa chuyển; GOFA HUD hiện vẫn lấy GOFA |
| Payload Swift Mirror và transport đồng bộ của upstream | Chưa chuyển; giữ cầu nối GOFA hiện có trong bản thử giao diện |
| Xuất crash .ips kèm báo cáo | Chưa chuyển; báo cáo hiện chưa đính kèm crash gốc |

Biên dịch thành công không thay cho kiểm thử thiết bị. Bản thử riêng iPhone 6s gồm arm64; chưa xây arm64e tương ứng và chưa đưa lên nguồn công khai. Không xác nhận iOS 18.

Các thay đổi này là bước tích hợp đang diễn ra, chưa phải bản sao đầy đủ toàn bộ GMapHUD. Cần kiểm tra các điều khiển hiện có rồi tiếp tục các mục còn thiếu.
