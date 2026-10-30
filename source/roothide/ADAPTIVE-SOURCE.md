# Tự nhận cấu trúc nguồn GOFA — bản phát triển 0.3.4

Trên iOS 15 trở lên, build GOFA chưa có trong bảng cũ được kiểm tra metadata Swift: tên, kiểu, offset, kích thước, ranh giới và vùng chồng lấn. Dùng offset thật của BleManager, từng trường SignMessage và LocationUpdateEvent thay vì đoán theo phiên bản. Nguồn tốc độ độc lập với nguồn biển báo. Nguồn giới hạn hiển thị được kiểm tra riêng bằng kiểu Swift.Int và offset runtime của maxSpeedLimit; không khóa vào GOFA 4.2.3 hay offset 448. Khi dữ liệu đổi, xuất giá trị mới; không biến số lưu lại thành sự kiện GPS mới. Nếu nguồn HUD gốc thật sự phát thì dừng fallback giao diện.

Giữ profile cũ có version/UUID cho các build đã xác minh. iOS 14 không tự chạy Swift reflection để tránh tái phát lỗi đăng nhập cũ; GOFA 4.2.1 đã xác minh vẫn dùng profile cũ. GOFA mới yêu cầu iOS 15 trở lên.

Ghi lý do tương thích theo từng nguồn vào tmp/gofahud-source-compatibility.json; file nằm trong bộ Gửi logs. Không có dữ liệu tài khoản hoặc tọa độ trong báo cáo tương thích.

Đã chạy 14 kiểm tra hồi quy trực tiếp trên iPhone 6s iOS 15.8.8. Ép bỏ qua bảng version/UUID để thử đường build chưa biết: metadata của GOFA 4.2.3 được xác thực, tốc độ và giới hạn 50 đọc được. Sau đó đã gỡ thư viện kiểm tra và nạp probe dùng bình thường. Chưa có phiên bản GOFA tương lai để kiểm thử thực tế; không thể bảo đảm mọi thay đổi upstream. Chưa thử đổi biển lúc xe di chuyển hoặc camera thật. Đóng gói bản 0.3.4 riêng cho từng môi trường. RootHide và Rootful cần kiểm tra lại trên thiết bị tương ứng.
