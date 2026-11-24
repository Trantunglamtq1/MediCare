# Database MediCare — SQLite

Database dùng chung do backend quản lý. Android và web đọc/ghi qua API.

## Thành phần

- [Migration v1 — schema SQL đầy đủ](migrations/001_initial.sql): 34 bảng nghiệp vụ, 2 view,
  khóa ngoại, index và trigger kiểm tra nghiệp vụ.
- [Migration v2 — bảo vệ lịch sử](migrations/002_history_guards.sql): giữ định danh bác sĩ,
  đơn thuốc/đơn vị tồn kho và giới hạn chi tiết hóa đơn khi chuyển dòng.
- [Thiết kế và ERD](../docs/database/design.md).
- [Từ điển dữ liệu](../docs/database/data-dictionary.md).
- [Dữ liệu giả lập](seeds/demo.sql): tài khoản disabled, không có mật khẩu đăng nhập thật.
- `manage.py`: khởi tạo/migrate, demo và kiểm tra; thêm bảng kỹ thuật schema_migrations.

## Tạo database

Cần Python 3.10+ dùng SQLite 3.37+. Không cần cài thư viện ngoài.
Chạy từ thư mục gốc repo:

```powershell
python database/manage.py init
python database/manage.py check
```

Database rỗng: `database/data/medicare.sqlite`. Có 5 vai trò mẫu; chưa có bệnh nhân/tài khoản.
Chạy init lại sẽ giữ dữ liệu và kiểm tra checksum migration đã áp dụng.

Tạo một database riêng có dữ liệu minh họa:

```powershell
python database/manage.py demo
python database/manage.py check --db database/data/medicare.demo.sqlite
```

Demo chứa hai bác sĩ, hai bệnh nhân, hai cơ sở và ví dụ đầy đủ đến xuất thuốc/hóa đơn.
Chỉ là dữ liệu giả lập, tên thuốc và liều không có ý nghĩa điều trị. Không seed demo vào database
đã có nghiệp vụ; công cụ sẽ từ chối. Chọn đường dẫn mới nếu cần bản demo khác:

```powershell
python database/manage.py demo --db database/data/another-demo.sqlite
python -m unittest discover -s database/tests -v
```

Có thể mở tệp `.sqlite` bằng công cụ xem SQLite. Nếu chạy SQL thủ công, phải bật
`PRAGMA foreign_keys=ON; PRAGMA recursive_triggers=ON;` và quản lý transaction phù hợp.
Migration không tự thiết lập các PRAGMA kết nối; sử dụng manage.py là cách khuyến nghị.

## Quy ước

- Timestamps INTEGER = UTC Unix seconds; ngày TEXT = YYYY-MM-DD; giờ nhắc = HH:MM + IANA timezone.
- Tiền INTEGER đồng VND; tồn kho INTEGER đơn vị cấp phát. Số lẻ liều uống nằm trong hướng dẫn,
  không dùng để trừ trực tiếp đơn vị tồn kho.
- Nhật ký tồn kho, phiếu thu/hoàn, audit là append-only. Sửa sai bằng bản ghi bù.
- File database và sidecar được Git bỏ qua; chỉ version schema/seed/tooling.
- Journal mặc định DELETE. Mọi kết nối ứng dụng phải bật khóa ngoại và recursive triggers.
- Không sửa migration cũ sau khi đã áp dụng; thêm migration mới với số thứ tự liên tục.
- Tệp này là thiết kế/schema, chưa triển khai API, phân quyền thực thi hoặc gửi nhắc thuốc.
