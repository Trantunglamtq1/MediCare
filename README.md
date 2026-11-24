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

Đã thiết kế database SQLite dùng chung cho backend, Android và web: 34 bảng nghiệp vụ,
schema có phiên bản, dữ liệu giả lập và kiểm tra tích hợp. Backend sẽ quản lý database;
Android/web truy cập qua API. Chưa triển khai mã ứng dụng hoặc cấu hình CI/CD.

## Database SQLite

Xem [hướng dẫn database](database/README.md), [thiết kế và ERD](docs/database/design.md)
và [từ điển dữ liệu](docs/database/data-dictionary.md).

```powershell
python database/manage.py init
python database/manage.py demo
python -m unittest discover -s database/tests -v
```

Cần Python 3.10+ với SQLite 3.37+; không cần thư viện ngoài. Các tệp database nằm trong
`database/data/` và không được commit. Công nghệ backend và giao diện sẽ lựa chọn sau.

## Làm việc với dự án

- Tham khảo `AGENTS.md` trước khi phát triển tính năng.
- Lưu cấu hình bí mật ở môi trường local; không commit mật khẩu, token hoặc dữ liệu cá nhân.
- Bổ sung hướng dẫn cài đặt, chạy và kiểm thử khi từng thành phần được triển khai.
