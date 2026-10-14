# GOFA HUD 0.2.1 — rootless

Mã nguồn tương ứng với bản phát hành, gồm phần hiển thị trên iPhone/CarPlay, cầu nối GOFA, các bài kiểm tra, protocol và script cài đặt. Cần GOFA 4.2.1.

## Môi trường

Dopamine Rootless, iOS 15 và 16. Thư viện arm64 và arm64e. Phần arm64e dùng Apple clang để sửa lỗi nạp CarPlay.

## Build

Makefile dành cho Theos; dùng macOS/Xcode để biên dịch arm64e đúng ABI. Các script trong tools ghi lại bước build. release-layout và layout/DEBIAN lưu cấu hình/script của gói đã phát hành. Khi xây dựng lại, phải cập nhật CDHash trong postinst theo chữ ký của tệp mới, không tái sử dụng hash của bản phát hành. RootHide cần chạy thêm Patcher chính thức; script postinst sử dụng đường dẫn jbroot thực. Bản iOS 14 dùng build_portable.py với GOFA_SDK, GOFA_ZIG và GOFA_LLD.

Không bao gồm SDK Apple, toolchain, mã nguồn ứng dụng GOFA hoặc dữ liệu cá nhân/log từ điện thoại. SOURCE-SHA256.json ghi hash của các tệp nguồn; RELEASE.json ghi hash của DEB.
