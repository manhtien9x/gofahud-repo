# GOFA HUD 0.3.4 — Tự nhận nguồn GOFA

GOFA HUD 0.3.4 — GOFA 4.2.3 và tự nhận cấu trúc nguồn dữ liệu.

Khắc phục mất biển giới hạn sau cập nhật GOFA 4.2.3. Trên iOS 15 trở lên, tự tìm trường theo tên, kiểu và vị trí thật thay vì chỉ dựa vào số phiên bản. Tách nguồn tốc độ và biển báo; có nguồn dự phòng lấy giới hạn GOFA đang hiển thị. Chỉ cập nhật khi giá trị đổi, không làm mới giả tuổi dữ liệu lưu lại. Nếu cấu trúc không phù hợp, dừng riêng nguồn đó và ghi nguyên nhân vào Gửi logs.

Rootless/RootHide: GOFA 4.2.1, 4.2.2 và 4.2.3. Trên iOS 15 trở lên, build mới có thể tự nhận nếu cấu trúc dữ liệu vẫn xác thực được; không bảo đảm mọi cập nhật GOFA. iOS 14 Rootful dùng GOFA 4.2.1 và giữ profile đã xác minh, không bật tự phản chiếu Swift.

Bản 0.3.4 đã xác nhận tốc độ, biển giới hạn và đường tự nhận build chưa biết trên iOS 15.8.8 với GOFA 4.2.3; 14 kiểm tra cấu trúc đạt. Các bản RootHide/Rootful đã đóng gói nhưng cần thử lại trên máy tương ứng. Cần kiểm tra đổi biển khi di chuyển, camera thật và CarPlay với GOFA mới.

Đính kèm ba DEB và ba source ZIP: Rootless, RootHide và iOS 14 Rootful.

Repo Sileo/Zebra: https://manhtien9x.github.io/gofahud-repo/
