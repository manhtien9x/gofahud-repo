# GOFA HUD 0.3.3 — Gửi logs

Chạm Gửi logs trong Cài đặt → GOFA HUD. Tweak gom đầy đủ log đọc được và CrashReporter thành file TXT, rồi tự mở bảng chia sẻ file của iOS. Bạn chọn Mail, Gmail, Tin nhắn, Zalo, Telegram hoặc ứng dụng đã cài có hỗ trợ nhận file. Không tự gửi đến người nhận nào.

Gom log trên queue nền, chặn bấm lặp, báo lỗi khi không tạo được file, mở UIActivityViewController với URL của file TXT trên main thread. Không lọc danh sách ứng dụng chia sẻ. Giữ nguyên toàn bộ bộ gom log của 0.3.2.

Nút Gửi logs của bản 0.3.3 đã được người dùng xác nhận hoạt động trên iOS 15.8.8. RootHide và iOS 14 Rootful đã đóng gói, cần kiểm thử lại bản mới trên máy. Nguồn GOFA 4.2.2 đã xác nhận nhận tốc độ và giới hạn khi chạy nền trên iOS 15.8.8; camera thực tế và CarPlay với GOFA 4.2.2 cần thử lại.
