# GOFA HUD — source 0.3.3-1 (roothide)
## Bản sửa GOFA 4.2.2

0.3.2 bổ sung profile dữ liệu GOFA 4.2.2 build 3 và giữ hỗ trợ 4.2.1. Xem [GOFA-4.2.2.md](GOFA-4.2.2.md) để biết thay đổi và phạm vi kiểm thử mới. Đã xác nhận tốc độ/giới hạn khi chạy nền trên iOS 15.8.8 ngày 20/10/2026; arm64e mới biên dịch, cần kiểm thử lại trên máy. Camera thực tế và CarPlay với GOFA 4.2.2 chưa kiểm chứng.

Thông tin kiểm thử nền của các bản trước:

Source của bản đã kiểm thử trên iPhone 6s, iOS 15.8.8, Dopamine rootless, GOFA 4.2.1. Bong bóng iPhone và CarPlay lấy cùng nguồn GOFA; CarPlay đã thử qua Home, Google Maps và YouTube Music, kéo vị trí, chạm mở GOFA trên xe, kéo vào X tắt và hiện lại khi rời GOFA. Kích thước CarPlay còn 70% mỗi chiều. Camera thật còn cần kiểm chứng trên đường.

## Thành phần

- `probe/`: đọc publisher Swift và SignMessage GOFA, có chốt phiên bản/UUID.
- `common/`: trạng thái cảnh báo, timestamp/hết hạn, giải mã HUD và xử lý trình bày.
- `tweak/`: bong bóng iPhone/CarPlay, mở app, lifecycle, dịch vụ nguồn và bộ ghi chuyến thử.
- `tests/`, `protocol/`: các bộ kiểm tra và cấu trúc protobuf HUD.
- `layout/DEBIAN`: script cài/gỡ; `layout/Library/LaunchDaemons`: dịch vụ chạy nền.
- `RELEASE.manifest.json`: checksum bản deb đã phát hành và CDHash các binary đã thử.

Không kèm APK/GOFA, SDK Apple, toolchain, thông tin SSH, log hoặc dữ liệu điện thoại. Không kèm adapter Flutter/hook Google Maps cũ không dùng trong 0.2.0. Các probe chẩn đoán đang có trong bản thử được giữ trong source.

## Build với Theos

Cần Theos và iPhoneOS SDK/toolchain hợp lệ. Trong thư mục source:

```sh
THEOS=/path/to/theos sh build.sh
```

Kết quả ở `packages/`. Makefile khai báo 6 tweak + 2 tool, rootless arm64, deployment target iOS 15. Đây là cấu hình Theos đã chuẩn bị; chưa chạy build Theos hoàn chỉnh trong môi trường Windows hiện tại.

Tài liệu: https://theos.dev/docs/rootless và https://theos.dev/docs/installation-linux (Windows dùng WSL).

## Build portable đã dùng trong dự án

Cần Python 3, Zig 0.13.0, LLVM LLD hỗ trợ Mach-O và SDK iPhoneOS 15.6. Đặt `GOFA_ZIG`, `GOFA_LLD`, `GOFA_SDK` là đường dẫn thực, rồi chạy:

```sh
python3 tools/build_portable.py
```

Kết quả chưa ký nằm ở `build/`. Cần ký bằng ldid trước khi đóng gói và cài. Bản phát hành 0.2.0 đã lấy binary ký trực tiếp từ máy thử; build lại từ source không bảo đảm cùng checksum với bản phát hành.

Giữ LICENSE MIT của GMapHUD. Nguồn nền: https://github.com/bechou0410/gmaphud. GOFA 4.2.1 là profile đã kiểm chứng; không đọc model của phiên bản khác khi chưa xác minh.

## Trạng thái phát hành 0.3.2

Rootless/RootHide: GOFA 4.2.1 hoặc 4.2.2. iOS 14 Rootful: GOFA 4.2.1, vì GOFA 4.2.2 yêu cầu iOS 15 trở lên.

Bản 0.3.2 đã xác nhận nhận tốc độ và giới hạn từ GOFA 4.2.2 khi chạy nền trên iOS 15.8.8. RootHide và iOS 14 Rootful đã đóng gói, cần kiểm thử lại bản mới trên máy. Các bản trước đã được xác nhận hoạt động trên iOS 14.1, 15.8.8, 16.3 và 16.7. Camera thực tế và CarPlay với GOFA 4.2.2 cần thử lại.

## Gửi logs — 0.3.3

Chạm Gửi logs trong Cài đặt → GOFA HUD. Tweak gom đầy đủ log đọc được và CrashReporter thành file TXT, rồi tự mở bảng chia sẻ file của iOS. Bạn chọn Mail, Gmail, Tin nhắn, Zalo, Telegram hoặc ứng dụng đã cài có hỗ trợ nhận file. Không tự gửi đến người nhận nào.

Nút Gửi logs của bản 0.3.3 đã được người dùng xác nhận hoạt động trên iOS 15.8.8. RootHide và iOS 14 Rootful đã đóng gói, cần kiểm thử lại bản mới trên máy. Nguồn GOFA 4.2.2 đã xác nhận nhận tốc độ và giới hạn khi chạy nền trên iOS 15.8.8; camera thực tế và CarPlay với GOFA 4.2.2 cần thử lại.

## Gửi logs — 0.3.3-1

Thêm nhãn Test hiển thị bong bóng phía trên các nút thử; phần giải thích đặt sát dưới ô cài đặt và thu gọn khoảng cách giữa các mục. Chạm Gửi logs trong Cài đặt → GOFA HUD. Tweak gom đầy đủ log đọc được và CrashReporter thành file TXT, rồi tự mở bảng chia sẻ file của iOS. Bạn chọn Mail, Gmail, Tin nhắn, Zalo, Telegram hoặc ứng dụng đã cài có hỗ trợ nhận file. Không tự gửi đến người nhận nào.

Chức năng Gửi logs đã được người dùng xác nhận hoạt động trên iOS 15.8.8. RootHide và iOS 14 Rootful đã đóng gói, cần kiểm thử lại bản mới trên máy. Nguồn GOFA 4.2.2 đã xác nhận nhận tốc độ và giới hạn khi chạy nền trên iOS 15.8.8; camera thực tế và CarPlay với GOFA 4.2.2 cần thử lại.
