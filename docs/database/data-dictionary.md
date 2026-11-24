# Từ điển dữ liệu MediCare SQLite

Sinh từ introspection schema v2. Migration SQL là nguồn chuẩn cho CHECK, enum và trigger.

**35 bảng = 34 bảng nghiệp vụ + `schema_migrations`; 2 view tính toán.**

- `INTEGER` thời điểm: Unix seconds UTC; ngày `TEXT`: YYYY-MM-DD; giờ nhắc: HH:MM.
- `*_minor`: số nguyên đồng VND. `id INTEGER PRIMARY KEY` tự sinh khi bỏ qua lúc INSERT.
- `NOT NULL` và khóa chính là bắt buộc. ID khóa chính không nhận NULL lưu trữ, dù PRAGMA báo notnull=0.
- FK mặc định RESTRICT; xem từng quan hệ bên dưới. Không dùng xóa dây chuyền cho lịch sử khám/tài chính.

## Danh sách bảng

| Bảng | Ý nghĩa |
| --- | --- |
| `appointments` | Lịch hẹn bệnh nhân trong ca làm việc. |
| `audit_logs` | Nhật ký append-only; backend phải ghi cùng giao dịch nghiệp vụ. |
| `clinics` | Cơ sở khám; nhiều cơ sở trong cùng hệ thống. |
| `diagnosis_catalog` | Danh mục chẩn đoán; code có thể theo hệ mã đã chọn. |
| `doctor_clinics` | Phân công bác sĩ tại cơ sở. |
| `doctor_shifts` | Ca làm việc cụ thể theo UTC; không trùng giờ bác sĩ. |
| `doctor_specialties` | Bác sĩ có nhiều chuyên khoa. |
| `doctors` | Hồ sơ bác sĩ liên kết một tài khoản. |
| `encounter_diagnoses` | Các chẩn đoán của lượt khám. |
| `encounters` | Hồ sơ lượt khám ngoại trú; ghi chú bản nháp. |
| `invoice_items` | Chi tiết hóa đơn lưu snapshot tên, số lượng và đơn giá. |
| `invoices` | Hóa đơn VND gắn một lượt khám; trạng thái thanh toán suy ra. |
| `medication_batches` | Lô thuốc theo cơ sở; tồn kho tính từ sổ biến động. |
| `medication_intakes` | Lịch sử từng lần uống theo thời điểm UTC và snapshot liều. |
| `medication_plan_times` | Giờ địa phương và bitmask thứ trong tuần (Mon=1 ... Sun=64). |
| `medication_plans` | Kế hoạch uống thuốc cá nhân; có thể từ đơn thuốc. |
| `medications` | Danh mục thuốc; thông tin không phải hướng dẫn điều trị. |
| `notifications` | Hàng đợi thông báo; gửi thực tế do backend thực hiện. |
| `observations` | Chỉ số/ghi nhận hoặc kết quả nhập tay trong lượt khám. |
| `patient_allergies` | Dị ứng và phản ứng do nhân viên/bệnh nhân khai báo. |
| `patients` | Hồ sơ bệnh nhân; có thể chưa có tài khoản. |
| `payments` | Phiếu thu đã ghi nhận; không lưu thông tin thẻ thanh toán. |
| `personal_medications` | Tủ thuốc cá nhân; độc lập tồn kho phòng khám. |
| `prescription_items` | Dòng đơn thuốc với hướng dẫn do bác sĩ nhập. |
| `prescriptions` | Đơn thuốc của lượt khám và bệnh nhân tương ứng. |
| `refresh_sessions` | Phiên đăng nhập; chỉ lưu digest token. |
| `refunds` | Phiếu hoàn tiền append-only gắn phiếu thu gốc. |
| `roles` | Danh mục vai trò toàn hệ thống. |
| `schema_migrations` | Lịch sử migration do manage.py quản lý; version, filename và SHA-256. |
| `service_orders` | Chỉ định dịch vụ cho lượt khám cùng cơ sở. |
| `services` | Danh mục dịch vụ và giá hiện tại theo cơ sở. |
| `specialties` | Danh mục chuyên khoa. |
| `stock_movements` | Sổ tồn kho append-only; điều chỉnh bằng dòng bù. |
| `user_roles` | Liên kết tài khoản với nhiều vai trò. |
| `users` | Tài khoản dùng chung Android/web; hash do backend tạo. |

## appointments

Lịch hẹn bệnh nhân trong ca làm việc.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `code` | `TEXT` | Có | — |
| `patient_id` | `INTEGER` | Có | — |
| `shift_id` | `INTEGER` | Có | — |
| `starts_at` | `INTEGER` | Có | — |
| `ends_at` | `INTEGER` | Có | — |
| `status` | `TEXT` | Có | `'booked'` |
| `reason` | `TEXT` | Không | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(shift_id)` → `doctor_shifts(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(patient_id)` → `patients(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_appointments_time`: (starts_at, ends_at); partial.
- `ix_appointments_patient_id`: (patient_id).
- `ix_appointments_shift_id`: (shift_id).
- `sqlite_autoindex_appointments_2`: (id, patient_id) UNIQUE.
- `sqlite_autoindex_appointments_1`: (code) UNIQUE.

## audit_logs

Nhật ký append-only; backend phải ghi cùng giao dịch nghiệp vụ.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `actor_user_id` | `INTEGER` | Không | — |
| `action` | `TEXT` | Có | — |
| `entity_type` | `TEXT` | Có | — |
| `entity_key` | `TEXT` | Có | — |
| `summary` | `TEXT` | Có | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(actor_user_id)` → `users(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_audit_entity`: (entity_type, entity_key, created_at).
- `ix_audit_logs_actor_user_id`: (actor_user_id).

## clinics

Cơ sở khám; nhiều cơ sở trong cùng hệ thống.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `code` | `TEXT` | Có | — |
| `name` | `TEXT` | Có | — |
| `address` | `TEXT` | Không | — |
| `phone` | `TEXT` | Không | — |
| `timezone` | `TEXT` | Có | `'Asia/Ho_Chi_Minh'` |
| `is_active` | `INTEGER` | Có | `1` |

**Index/unique**:

- `sqlite_autoindex_clinics_1`: (code) UNIQUE.

## diagnosis_catalog

Danh mục chẩn đoán; code có thể theo hệ mã đã chọn.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `code` | `TEXT` | Có | — |
| `name` | `TEXT` | Có | — |
| `coding_system` | `TEXT` | Có | `'local'` |

**Index/unique**:

- `sqlite_autoindex_diagnosis_catalog_1`: (code) UNIQUE.

## doctor_clinics

Phân công bác sĩ tại cơ sở.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `doctor_id` | `INTEGER` | Có | — |
| `clinic_id` | `INTEGER` | Có | — |
| `is_active` | `INTEGER` | Có | `1` |

**Khóa ngoại**:

- `(clinic_id)` → `clinics(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(doctor_id)` → `doctors(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_doctor_clinics_clinic_id`: (clinic_id).
- `sqlite_autoindex_doctor_clinics_1`: (doctor_id, clinic_id) UNIQUE.

## doctor_shifts

Ca làm việc cụ thể theo UTC; không trùng giờ bác sĩ.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `assignment_id` | `INTEGER` | Có | — |
| `starts_at` | `INTEGER` | Có | — |
| `ends_at` | `INTEGER` | Có | — |
| `status` | `TEXT` | Có | `'scheduled'` |

**Khóa ngoại**:

- `(assignment_id)` → `doctor_clinics(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_doctor_shifts_time`: (starts_at, ends_at); partial.
- `ix_doctor_shifts_assignment_id`: (assignment_id).

## doctor_specialties

Bác sĩ có nhiều chuyên khoa.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `doctor_id` | `INTEGER` | PK(1) | — |
| `specialty_id` | `INTEGER` | PK(2) | — |

**Khóa ngoại**:

- `(specialty_id)` → `specialties(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(doctor_id)` → `doctors(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_doctor_specialties_specialty_id`: (specialty_id).
- `sqlite_autoindex_doctor_specialties_1`: (doctor_id, specialty_id) UNIQUE.

## doctors

Hồ sơ bác sĩ liên kết một tài khoản.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `user_id` | `INTEGER` | Có | — |
| `license_number` | `TEXT` | Có | — |
| `biography` | `TEXT` | Không | — |
| `is_active` | `INTEGER` | Có | `1` |

**Khóa ngoại**:

- `(user_id)` → `users(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `sqlite_autoindex_doctors_2`: (license_number) UNIQUE.
- `sqlite_autoindex_doctors_1`: (user_id) UNIQUE.

## encounter_diagnoses

Các chẩn đoán của lượt khám.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `encounter_id` | `INTEGER` | Có | — |
| `diagnosis_id` | `INTEGER` | Có | — |
| `is_primary` | `INTEGER` | Có | `0` |
| `notes` | `TEXT` | Không | — |

**Khóa ngoại**:

- `(diagnosis_id)` → `diagnosis_catalog(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(encounter_id)` → `encounters(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_encounter_diagnoses_diagnosis_id`: (diagnosis_id).
- `ux_encounter_primary_diagnosis`: (encounter_id) UNIQUE; partial.
- `sqlite_autoindex_encounter_diagnoses_1`: (encounter_id, diagnosis_id) UNIQUE.

## encounters

Hồ sơ lượt khám ngoại trú; ghi chú bản nháp.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `appointment_id` | `INTEGER` | Có | — |
| `patient_id` | `INTEGER` | Có | — |
| `chief_complaint` | `TEXT` | Không | — |
| `examination_notes` | `TEXT` | Không | — |
| `treatment_notes` | `TEXT` | Không | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(appointment_id, patient_id)` → `appointments(id, patient_id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_encounters_appointment_id_patient_id`: (appointment_id, patient_id).
- `sqlite_autoindex_encounters_2`: (id, patient_id) UNIQUE.
- `sqlite_autoindex_encounters_1`: (appointment_id) UNIQUE.

## invoice_items

Chi tiết hóa đơn lưu snapshot tên, số lượng và đơn giá.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `invoice_id` | `INTEGER` | Có | — |
| `description` | `TEXT` | Có | — |
| `quantity` | `INTEGER` | Có | — |
| `unit_price_minor` | `INTEGER` | Có | — |
| `discount_minor` | `INTEGER` | Có | `0` |

**Khóa ngoại**:

- `(invoice_id)` → `invoices(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_invoice_items_invoice_id`: (invoice_id).

## invoices

Hóa đơn VND gắn một lượt khám; trạng thái thanh toán suy ra.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `code` | `TEXT` | Có | — |
| `encounter_id` | `INTEGER` | Có | — |
| `patient_id` | `INTEGER` | Có | — |
| `currency` | `TEXT` | Có | `'VND'` |
| `status` | `TEXT` | Có | `'draft'` |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(encounter_id, patient_id)` → `encounters(id, patient_id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_invoices_encounter_id_patient_id`: (encounter_id, patient_id).
- `sqlite_autoindex_invoices_2`: (encounter_id) UNIQUE.
- `sqlite_autoindex_invoices_1`: (code) UNIQUE.

## medication_batches

Lô thuốc theo cơ sở; tồn kho tính từ sổ biến động.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `clinic_id` | `INTEGER` | Có | — |
| `medication_id` | `INTEGER` | Có | — |
| `lot_number` | `TEXT` | Có | — |
| `expires_on` | `TEXT` | Có | — |

**Khóa ngoại**:

- `(medication_id)` → `medications(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(clinic_id)` → `clinics(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_medication_batches_medication_id`: (medication_id).
- `sqlite_autoindex_medication_batches_1`: (clinic_id, medication_id, lot_number) UNIQUE.

## medication_intakes

Lịch sử từng lần uống theo thời điểm UTC và snapshot liều.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `plan_id` | `INTEGER` | Có | — |
| `scheduled_at` | `INTEGER` | Có | — |
| `status` | `TEXT` | Có | — |
| `taken_at` | `INTEGER` | Không | — |
| `dose_snapshot` | `TEXT` | Có | — |
| `recorded_by` | `INTEGER` | Không | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(recorded_by)` → `users(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(plan_id)` → `medication_plans(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_medication_intakes_recorded_by`: (recorded_by).
- `sqlite_autoindex_medication_intakes_1`: (plan_id, scheduled_at) UNIQUE.

## medication_plan_times

Giờ địa phương và bitmask thứ trong tuần (Mon=1 ... Sun=64).

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `plan_id` | `INTEGER` | Có | — |
| `local_time` | `TEXT` | Có | — |
| `weekdays_mask` | `INTEGER` | Có | `127` |

**Khóa ngoại**:

- `(plan_id)` → `medication_plans(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `sqlite_autoindex_medication_plan_times_1`: (plan_id, local_time, weekdays_mask) UNIQUE.

## medication_plans

Kế hoạch uống thuốc cá nhân; có thể từ đơn thuốc.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `patient_id` | `INTEGER` | Có | — |
| `medication_id` | `INTEGER` | Có | — |
| `prescription_item_id` | `INTEGER` | Không | — |
| `dose_text` | `TEXT` | Có | — |
| `starts_on` | `TEXT` | Có | — |
| `ends_on` | `TEXT` | Không | — |
| `timezone` | `TEXT` | Có | `'Asia/Ho_Chi_Minh'` |
| `status` | `TEXT` | Có | `'active'` |

**Khóa ngoại**:

- `(prescription_item_id, patient_id, medication_id)` → `prescription_items(id, patient_id, medication_id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(medication_id)` → `medications(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(patient_id)` → `patients(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_medication_plans_due`: (status, starts_on, ends_on).
- `ix_medication_plans_patient_id`: (patient_id).
- `ix_medication_plans_medication_id`: (medication_id).
- `ix_medication_plans_prescription_item_id_patient_id_medication_id`: (prescription_item_id, patient_id, medication_id).

## medications

Danh mục thuốc; thông tin không phải hướng dẫn điều trị.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `code` | `TEXT` | Có | — |
| `name` | `TEXT` | Có | — |
| `active_ingredient` | `TEXT` | Không | — |
| `strength` | `TEXT` | Không | — |
| `dosage_form` | `TEXT` | Không | — |
| `stock_unit` | `TEXT` | Có | — |
| `is_active` | `INTEGER` | Có | `1` |

**Index/unique**:

- `sqlite_autoindex_medications_1`: (code) UNIQUE.

## notifications

Hàng đợi thông báo; gửi thực tế do backend thực hiện.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `user_id` | `INTEGER` | Có | — |
| `kind` | `TEXT` | Có | — |
| `channel` | `TEXT` | Có | — |
| `title` | `TEXT` | Có | — |
| `body` | `TEXT` | Có | — |
| `status` | `TEXT` | Có | `'pending'` |
| `attempts` | `INTEGER` | Có | `0` |
| `scheduled_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |
| `sent_at` | `INTEGER` | Không | — |
| `read_at` | `INTEGER` | Không | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(user_id)` → `users(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_notifications_queue`: (status, scheduled_at).
- `ix_notifications_user_id`: (user_id).

## observations

Chỉ số/ghi nhận hoặc kết quả nhập tay trong lượt khám.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `encounter_id` | `INTEGER` | Có | — |
| `code` | `TEXT` | Có | — |
| `numeric_value` | `REAL` | Không | — |
| `text_value` | `TEXT` | Không | — |
| `unit` | `TEXT` | Không | — |
| `observed_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(encounter_id)` → `encounters(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_observations_encounter_id`: (encounter_id).

## patient_allergies

Dị ứng và phản ứng do nhân viên/bệnh nhân khai báo.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `patient_id` | `INTEGER` | Có | — |
| `allergen` | `TEXT` | Có | — |
| `reaction` | `TEXT` | Không | — |
| `severity` | `TEXT` | Có | `'unknown'` |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(patient_id)` → `patients(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `sqlite_autoindex_patient_allergies_1`: (patient_id, allergen) UNIQUE.

## patients

Hồ sơ bệnh nhân; có thể chưa có tài khoản.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `code` | `TEXT` | Có | — |
| `user_id` | `INTEGER` | Không | — |
| `full_name` | `TEXT` | Có | — |
| `birth_date` | `TEXT` | Không | — |
| `sex` | `TEXT` | Có | `'unknown'` |
| `phone` | `TEXT` | Không | — |
| `address` | `TEXT` | Không | — |
| `emergency_contact` | `TEXT` | Không | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(user_id)` → `users(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `sqlite_autoindex_patients_2`: (user_id) UNIQUE.
- `sqlite_autoindex_patients_1`: (code) UNIQUE.

## payments

Phiếu thu đã ghi nhận; không lưu thông tin thẻ thanh toán.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `invoice_id` | `INTEGER` | Có | — |
| `amount_minor` | `INTEGER` | Có | — |
| `method` | `TEXT` | Có | — |
| `request_key` | `TEXT` | Có | — |
| `provider_reference` | `TEXT` | Không | — |
| `recorded_by` | `INTEGER` | Không | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(recorded_by)` → `users(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(invoice_id)` → `invoices(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_payments_invoice_id`: (invoice_id).
- `ix_payments_recorded_by`: (recorded_by).
- `sqlite_autoindex_payments_1`: (request_key) UNIQUE.

## personal_medications

Tủ thuốc cá nhân; độc lập tồn kho phòng khám.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `patient_id` | `INTEGER` | Có | — |
| `medication_id` | `INTEGER` | Có | — |
| `on_hand` | `INTEGER` | Có | `0` |
| `notes` | `TEXT` | Không | — |

**Khóa ngoại**:

- `(medication_id)` → `medications(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(patient_id)` → `patients(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_personal_medications_medication_id`: (medication_id).
- `sqlite_autoindex_personal_medications_1`: (patient_id, medication_id) UNIQUE.

## prescription_items

Dòng đơn thuốc với hướng dẫn do bác sĩ nhập.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `prescription_id` | `INTEGER` | Có | — |
| `patient_id` | `INTEGER` | Có | — |
| `medication_id` | `INTEGER` | Có | — |
| `dose_text` | `TEXT` | Có | — |
| `route` | `TEXT` | Không | — |
| `frequency_text` | `TEXT` | Không | — |
| `duration_days` | `INTEGER` | Không | — |
| `quantity` | `INTEGER` | Có | — |
| `instructions` | `TEXT` | Không | — |

**Khóa ngoại**:

- `(prescription_id, patient_id)` → `prescriptions(id, patient_id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(medication_id)` → `medications(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_prescription_items_medication_id`: (medication_id).
- `ix_prescription_items_prescription_id_patient_id`: (prescription_id, patient_id).
- `sqlite_autoindex_prescription_items_1`: (id, patient_id, medication_id) UNIQUE.

## prescriptions

Đơn thuốc của lượt khám và bệnh nhân tương ứng.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `code` | `TEXT` | Có | — |
| `encounter_id` | `INTEGER` | Có | — |
| `patient_id` | `INTEGER` | Có | — |
| `status` | `TEXT` | Có | `'active'` |
| `notes` | `TEXT` | Không | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(encounter_id, patient_id)` → `encounters(id, patient_id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_prescriptions_encounter_id_patient_id`: (encounter_id, patient_id).
- `sqlite_autoindex_prescriptions_2`: (id, patient_id) UNIQUE.
- `sqlite_autoindex_prescriptions_1`: (code) UNIQUE.

## refresh_sessions

Phiên đăng nhập; chỉ lưu digest token.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `user_id` | `INTEGER` | Có | — |
| `token_digest` | `TEXT` | Có | — |
| `expires_at` | `INTEGER` | Có | — |
| `revoked_at` | `INTEGER` | Không | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(user_id)` → `users(id)`; DELETE CASCADE, UPDATE NO ACTION.

**Index/unique**:

- `ix_refresh_sessions_user_id`: (user_id).
- `sqlite_autoindex_refresh_sessions_1`: (token_digest) UNIQUE.

## refunds

Phiếu hoàn tiền append-only gắn phiếu thu gốc.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `payment_id` | `INTEGER` | Có | — |
| `amount_minor` | `INTEGER` | Có | — |
| `reason` | `TEXT` | Có | — |
| `request_key` | `TEXT` | Có | — |
| `provider_reference` | `TEXT` | Không | — |
| `recorded_by` | `INTEGER` | Không | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(recorded_by)` → `users(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(payment_id)` → `payments(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_refunds_payment_id`: (payment_id).
- `ix_refunds_recorded_by`: (recorded_by).
- `sqlite_autoindex_refunds_1`: (request_key) UNIQUE.

## roles

Danh mục vai trò toàn hệ thống.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `code` | `TEXT` | Có | — |
| `name` | `TEXT` | Có | — |

**Index/unique**:

- `sqlite_autoindex_roles_1`: (code) UNIQUE.

## schema_migrations

Lịch sử migration do manage.py quản lý; version, filename và SHA-256.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `version` | `INTEGER` | PK(1) | — |
| `filename` | `TEXT` | Có | — |
| `checksum` | `TEXT` | Có | — |
| `applied_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Index/unique**:

- `sqlite_autoindex_schema_migrations_1`: (filename) UNIQUE.

## service_orders

Chỉ định dịch vụ cho lượt khám cùng cơ sở.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `encounter_id` | `INTEGER` | Có | — |
| `service_id` | `INTEGER` | Có | — |
| `quantity` | `INTEGER` | Có | `1` |
| `status` | `TEXT` | Có | `'ordered'` |
| `result_notes` | `TEXT` | Không | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(service_id)` → `services(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(encounter_id)` → `encounters(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_service_orders_encounter_id`: (encounter_id).
- `ix_service_orders_service_id`: (service_id).

## services

Danh mục dịch vụ và giá hiện tại theo cơ sở.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `clinic_id` | `INTEGER` | Có | — |
| `code` | `TEXT` | Có | — |
| `name` | `TEXT` | Có | — |
| `price_minor` | `INTEGER` | Có | — |
| `is_active` | `INTEGER` | Có | `1` |

**Khóa ngoại**:

- `(clinic_id)` → `clinics(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `sqlite_autoindex_services_1`: (clinic_id, code) UNIQUE.

## specialties

Danh mục chuyên khoa.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `code` | `TEXT` | Có | — |
| `name` | `TEXT` | Có | — |

**Index/unique**:

- `sqlite_autoindex_specialties_1`: (code) UNIQUE.

## stock_movements

Sổ tồn kho append-only; điều chỉnh bằng dòng bù.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `batch_id` | `INTEGER` | Có | — |
| `prescription_item_id` | `INTEGER` | Không | — |
| `quantity_delta` | `INTEGER` | Có | — |
| `kind` | `TEXT` | Có | — |
| `request_key` | `TEXT` | Có | — |
| `reason` | `TEXT` | Không | — |
| `recorded_by` | `INTEGER` | Không | — |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Khóa ngoại**:

- `(recorded_by)` → `users(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(prescription_item_id)` → `prescription_items(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(batch_id)` → `medication_batches(id)`; DELETE RESTRICT, UPDATE NO ACTION.

**Index/unique**:

- `ix_stock_movements_batch_id`: (batch_id).
- `ix_stock_movements_prescription_item_id`: (prescription_item_id).
- `ix_stock_movements_recorded_by`: (recorded_by).
- `sqlite_autoindex_stock_movements_1`: (request_key) UNIQUE.

## user_roles

Liên kết tài khoản với nhiều vai trò.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `user_id` | `INTEGER` | PK(1) | — |
| `role_id` | `INTEGER` | PK(2) | — |

**Khóa ngoại**:

- `(role_id)` → `roles(id)`; DELETE RESTRICT, UPDATE NO ACTION.
- `(user_id)` → `users(id)`; DELETE CASCADE, UPDATE NO ACTION.

**Index/unique**:

- `ix_user_roles_role_id`: (role_id).
- `sqlite_autoindex_user_roles_1`: (user_id, role_id) UNIQUE.

## users

Tài khoản dùng chung Android/web; hash do backend tạo.

| Cột | Kiểu | Bắt buộc/PK | Mặc định |
| --- | --- | --- | --- |
| `id` | `INTEGER` | PK(1) | — |
| `email` | `TEXT` | Có | — |
| `full_name` | `TEXT` | Có | — |
| `password_hash` | `TEXT` | Không | — |
| `phone` | `TEXT` | Không | — |
| `status` | `TEXT` | Có | `'active'` |
| `created_at` | `INTEGER` | Có | `CAST(strftime('%s','now') AS INTEGER)` |

**Index/unique**:

- `sqlite_autoindex_users_1`: (email) UNIQUE.

## Views

- `stock_balances`: batch_id, clinic_id, medication_id, lot_number, expires_on, balance.
- `invoice_balances`: invoice_id, patient_id, status, total_minor, paid_minor (đã trừ hoàn tiền), due_minor.

## CHECK và trigger

Xem [migration SQL](../../database/migrations/001_initial.sql) để đọc toàn bộ ràng buộc.
Quy tắc nghiệp vụ và trách nhiệm backend được giải thích trong [thiết kế](design.md).
