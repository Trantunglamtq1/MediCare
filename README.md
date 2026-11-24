# MediCare

Kho mã nguồn MediCare, được tổ chức cho ứng dụng Android, backend, web và cơ sở dữ liệu.

## Cấu trúc thư mục

```text
MediCare/
├── android/
├── backend/
├── web/
├── database/
├── docs/
├── .github/
│   └── workflows/
├── .gitignore
├── AGENTS.md
└── README.md
```

| Thư mục | Mục đích |
| --- | --- |
| `android/` | Mã nguồn ứng dụng Android |
| `backend/` | Mã nguồn API và xử lý nghiệp vụ |
| `web/` | Mã nguồn giao diện web |
| `database/` | Schema, migration và dữ liệu mẫu |
| `docs/` | Tài liệu dự án |
| `.github/workflows/` | Cấu hình GitHub Actions |

Các thư mục hiện chứa `.gitkeep` để Git lưu lại cấu trúc ban đầu. Có thể xóa tệp này khi thêm nội dung thực tế.

## Trạng thái

Đã khởi tạo cấu trúc kho mã nguồn. Chưa lựa chọn công nghệ, thêm mã ứng dụng hoặc cấu hình CI/CD.

## Làm việc với dự án

- Tham khảo `AGENTS.md` trước khi phát triển tính năng.
- Lưu cấu hình bí mật ở môi trường local; không commit mật khẩu, token hoặc dữ liệu cá nhân.
- Bổ sung hướng dẫn cài đặt, chạy và kiểm thử khi từng thành phần được triển khai.
