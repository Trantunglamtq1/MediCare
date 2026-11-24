-- MediCare v1: SQLite 3.37+; run through database/manage.py.
-- Connections MUST enable foreign_keys and recursive_triggers before writes.


-- Tài khoản dùng chung Android/web; hash do backend tạo.
CREATE TABLE users(
    id INTEGER PRIMARY KEY,
    email TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(trim(email))>3),
    full_name TEXT NOT NULL CHECK(length(trim(full_name))>0),
    password_hash TEXT CHECK(password_hash IS NULL OR length(password_hash)>=20),
    phone TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','disabled')),
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER)),
    CHECK(status='disabled' OR password_hash IS NOT NULL)
) STRICT;


-- Danh mục vai trò toàn hệ thống.
CREATE TABLE roles(
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL
) STRICT;


CREATE TABLE user_roles(
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    PRIMARY KEY(user_id,role_id)
) STRICT;

-- Phiên đăng nhập; chỉ lưu digest token.
CREATE TABLE refresh_sessions(
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_digest TEXT NOT NULL UNIQUE CHECK(length(token_digest)=64 AND token_digest NOT GLOB '*[^0-9a-f]*'),
    expires_at INTEGER NOT NULL CHECK(expires_at>0),
    revoked_at INTEGER,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER)),
    CHECK(expires_at>created_at),
    CHECK(revoked_at IS NULL OR revoked_at>=created_at)
) STRICT;


-- Hồ sơ bệnh nhân; có thể chưa có tài khoản.
CREATE TABLE patients(
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    user_id INTEGER UNIQUE REFERENCES users(id) ON DELETE RESTRICT,
    full_name TEXT NOT NULL CHECK(length(trim(full_name))>0),
    birth_date TEXT CHECK(birth_date IS NULL OR (length(birth_date)=10 AND date(birth_date,'+0 days') IS NOT NULL AND date(birth_date,'+0 days')=birth_date)),
    sex TEXT NOT NULL DEFAULT 'unknown' CHECK(sex IN ('male','female','other','unknown')),
    phone TEXT,
    address TEXT,
    emergency_contact TEXT,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER))
) STRICT;


-- Cơ sở khám; nhiều cơ sở trong cùng hệ thống.
CREATE TABLE clinics(
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    timezone TEXT NOT NULL DEFAULT 'Asia/Ho_Chi_Minh' CHECK(length(trim(timezone))>0),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
) STRICT;


-- Danh mục chuyên khoa.
CREATE TABLE specialties(
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL
) STRICT;


-- Hồ sơ bác sĩ liên kết một tài khoản.
CREATE TABLE doctors(
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE RESTRICT,
    license_number TEXT NOT NULL UNIQUE,
    biography TEXT,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
) STRICT;


CREATE TABLE doctor_specialties(
    doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE RESTRICT,
    specialty_id INTEGER NOT NULL REFERENCES specialties(id) ON DELETE RESTRICT,
    PRIMARY KEY(doctor_id,specialty_id)
) STRICT;

-- Phân công bác sĩ tại cơ sở.
CREATE TABLE doctor_clinics(
    id INTEGER PRIMARY KEY,
    doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE RESTRICT,
    clinic_id INTEGER NOT NULL REFERENCES clinics(id) ON DELETE RESTRICT,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
    UNIQUE(doctor_id,clinic_id)
) STRICT;


-- Ca làm việc cụ thể theo UTC; không trùng giờ bác sĩ.
CREATE TABLE doctor_shifts(
    id INTEGER PRIMARY KEY,
    assignment_id INTEGER NOT NULL REFERENCES doctor_clinics(id) ON DELETE RESTRICT,
    starts_at INTEGER NOT NULL CHECK(starts_at>0),
    ends_at INTEGER NOT NULL CHECK(ends_at>starts_at),
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK(status IN ('scheduled','cancelled'))
) STRICT;


-- Lịch hẹn bệnh nhân trong ca làm việc.
CREATE TABLE appointments(
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE RESTRICT,
    shift_id INTEGER NOT NULL REFERENCES doctor_shifts(id) ON DELETE RESTRICT,
    starts_at INTEGER NOT NULL CHECK(starts_at>0),
    ends_at INTEGER NOT NULL CHECK(ends_at>starts_at),
    status TEXT NOT NULL DEFAULT 'booked' CHECK(status IN ('booked','confirmed','checked_in','completed','cancelled','no_show')),
    reason TEXT,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER)),
    UNIQUE(id,patient_id)
) STRICT;


-- Dị ứng và phản ứng do nhân viên/bệnh nhân khai báo.
CREATE TABLE patient_allergies(
    id INTEGER PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE RESTRICT,
    allergen TEXT NOT NULL CHECK(length(trim(allergen))>0),
    reaction TEXT,
    severity TEXT NOT NULL DEFAULT 'unknown' CHECK(severity IN ('mild','moderate','severe','unknown')),
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER)),
    UNIQUE(patient_id,allergen)
) STRICT;


-- Danh mục chẩn đoán; code có thể theo hệ mã đã chọn.
CREATE TABLE diagnosis_catalog(
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    coding_system TEXT NOT NULL DEFAULT 'local'
) STRICT;


-- Hồ sơ lượt khám ngoại trú; ghi chú bản nháp.
CREATE TABLE encounters(
    id INTEGER PRIMARY KEY,
    appointment_id INTEGER NOT NULL UNIQUE,
    patient_id INTEGER NOT NULL,
    chief_complaint TEXT,
    examination_notes TEXT,
    treatment_notes TEXT,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER)),
    UNIQUE(id,patient_id),
    FOREIGN KEY(appointment_id,patient_id) REFERENCES appointments(id,patient_id) ON DELETE RESTRICT
) STRICT;


-- Các chẩn đoán của lượt khám.
CREATE TABLE encounter_diagnoses(
    id INTEGER PRIMARY KEY,
    encounter_id INTEGER NOT NULL REFERENCES encounters(id) ON DELETE RESTRICT,
    diagnosis_id INTEGER NOT NULL REFERENCES diagnosis_catalog(id) ON DELETE RESTRICT,
    is_primary INTEGER NOT NULL DEFAULT 0 CHECK(is_primary IN (0,1)),
    notes TEXT,
    UNIQUE(encounter_id,diagnosis_id)
) STRICT;


CREATE UNIQUE INDEX ux_encounter_primary_diagnosis ON encounter_diagnoses(encounter_id) WHERE is_primary=1;

-- Chỉ số/ghi nhận hoặc kết quả nhập tay trong lượt khám.
CREATE TABLE observations(
    id INTEGER PRIMARY KEY,
    encounter_id INTEGER NOT NULL REFERENCES encounters(id) ON DELETE RESTRICT,
    code TEXT NOT NULL,
    numeric_value REAL,
    text_value TEXT,
    unit TEXT,
    observed_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER)),
    CHECK((numeric_value IS NOT NULL) != (text_value IS NOT NULL))
) STRICT;


-- Danh mục dịch vụ và giá hiện tại theo cơ sở.
CREATE TABLE services(
    id INTEGER PRIMARY KEY,
    clinic_id INTEGER NOT NULL REFERENCES clinics(id) ON DELETE RESTRICT,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    price_minor INTEGER NOT NULL CHECK(price_minor BETWEEN 0 AND 1000000000000),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
    UNIQUE(clinic_id,code)
) STRICT;


-- Chỉ định dịch vụ cho lượt khám cùng cơ sở.
CREATE TABLE service_orders(
    id INTEGER PRIMARY KEY,
    encounter_id INTEGER NOT NULL REFERENCES encounters(id) ON DELETE RESTRICT,
    service_id INTEGER NOT NULL REFERENCES services(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity BETWEEN 1 AND 1000000),
    status TEXT NOT NULL DEFAULT 'ordered' CHECK(status IN ('ordered','completed','cancelled')),
    result_notes TEXT,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER))
) STRICT;


-- Danh mục thuốc; thông tin không phải hướng dẫn điều trị.
CREATE TABLE medications(
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    active_ingredient TEXT,
    strength TEXT,
    dosage_form TEXT,
    stock_unit TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
) STRICT;


-- Đơn thuốc của lượt khám và bệnh nhân tương ứng.
CREATE TABLE prescriptions(
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    encounter_id INTEGER NOT NULL,
    patient_id INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','cancelled')),
    notes TEXT,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER)),
    UNIQUE(id,patient_id),
    FOREIGN KEY(encounter_id,patient_id) REFERENCES encounters(id,patient_id) ON DELETE RESTRICT
) STRICT;


-- Dòng đơn thuốc với hướng dẫn do bác sĩ nhập.
CREATE TABLE prescription_items(
    id INTEGER PRIMARY KEY,
    prescription_id INTEGER NOT NULL,
    patient_id INTEGER NOT NULL,
    medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
    dose_text TEXT NOT NULL CHECK(length(trim(dose_text))>0),
    route TEXT,
    frequency_text TEXT,
    duration_days INTEGER CHECK(duration_days>0),
    quantity INTEGER NOT NULL CHECK(quantity BETWEEN 1 AND 1000000000),
    instructions TEXT,
    UNIQUE(id,patient_id,medication_id),
    FOREIGN KEY(prescription_id,patient_id) REFERENCES prescriptions(id,patient_id) ON DELETE RESTRICT
) STRICT;


-- Tủ thuốc cá nhân; độc lập tồn kho phòng khám.
CREATE TABLE personal_medications(
    id INTEGER PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE RESTRICT,
    medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
    on_hand INTEGER NOT NULL DEFAULT 0 CHECK(on_hand BETWEEN 0 AND 1000000000),
    notes TEXT,
    UNIQUE(patient_id,medication_id)
) STRICT;


-- Kế hoạch uống thuốc cá nhân; có thể từ đơn thuốc.
CREATE TABLE medication_plans(
    id INTEGER PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE RESTRICT,
    medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
    prescription_item_id INTEGER,
    dose_text TEXT NOT NULL CHECK(length(trim(dose_text))>0),
    starts_on TEXT NOT NULL CHECK(length(starts_on)=10 AND date(starts_on,'+0 days') IS NOT NULL AND date(starts_on,'+0 days')=starts_on),
    ends_on TEXT CHECK(ends_on IS NULL OR (length(ends_on)=10 AND date(ends_on,'+0 days') IS NOT NULL AND date(ends_on,'+0 days')=ends_on AND ends_on>=starts_on)),
    timezone TEXT NOT NULL DEFAULT 'Asia/Ho_Chi_Minh' CHECK(length(trim(timezone))>0),
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','paused','completed')),
    FOREIGN KEY(prescription_item_id,patient_id,medication_id) REFERENCES prescription_items(id,patient_id,medication_id) ON DELETE RESTRICT
) STRICT;


-- Giờ địa phương và bitmask thứ trong tuần (Mon=1 ... Sun=64).
CREATE TABLE medication_plan_times(
    id INTEGER PRIMARY KEY,
    plan_id INTEGER NOT NULL REFERENCES medication_plans(id) ON DELETE RESTRICT,
    local_time TEXT NOT NULL CHECK(length(local_time)=5 AND local_time GLOB '[0-2][0-9]:[0-5][0-9]' AND local_time<'24:00'),
    weekdays_mask INTEGER NOT NULL DEFAULT 127 CHECK(weekdays_mask BETWEEN 1 AND 127),
    UNIQUE(plan_id,local_time,weekdays_mask)
) STRICT;


-- Lịch sử từng lần uống theo thời điểm UTC và snapshot liều.
CREATE TABLE medication_intakes(
    id INTEGER PRIMARY KEY,
    plan_id INTEGER NOT NULL REFERENCES medication_plans(id) ON DELETE RESTRICT,
    scheduled_at INTEGER NOT NULL CHECK(scheduled_at>0),
    status TEXT NOT NULL CHECK(status IN ('taken','skipped','missed')),
    taken_at INTEGER CHECK(taken_at IS NULL OR taken_at>0),
    dose_snapshot TEXT NOT NULL CHECK(length(trim(dose_snapshot))>0),
    recorded_by INTEGER REFERENCES users(id) ON DELETE RESTRICT,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER)),
    CHECK((status='taken' AND taken_at IS NOT NULL) OR (status!='taken' AND taken_at IS NULL)),
    UNIQUE(plan_id,scheduled_at)
) STRICT;


-- Lô thuốc theo cơ sở; tồn kho tính từ sổ biến động.
CREATE TABLE medication_batches(
    id INTEGER PRIMARY KEY,
    clinic_id INTEGER NOT NULL REFERENCES clinics(id) ON DELETE RESTRICT,
    medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
    lot_number TEXT NOT NULL,
    expires_on TEXT NOT NULL CHECK(length(expires_on)=10 AND date(expires_on,'+0 days') IS NOT NULL AND date(expires_on,'+0 days')=expires_on),
    UNIQUE(clinic_id,medication_id,lot_number)
) STRICT;


-- Sổ tồn kho append-only; điều chỉnh bằng dòng bù.
CREATE TABLE stock_movements(
    id INTEGER PRIMARY KEY,
    batch_id INTEGER NOT NULL REFERENCES medication_batches(id) ON DELETE RESTRICT,
    prescription_item_id INTEGER REFERENCES prescription_items(id) ON DELETE RESTRICT,
    quantity_delta INTEGER NOT NULL CHECK(quantity_delta BETWEEN -1000000000 AND 1000000000 AND quantity_delta!=0),
    kind TEXT NOT NULL CHECK(kind IN ('receipt','dispense','adjustment')),
    request_key TEXT NOT NULL UNIQUE,
    reason TEXT,
    recorded_by INTEGER REFERENCES users(id) ON DELETE RESTRICT,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER)),
    CHECK((kind='receipt' AND quantity_delta>0) OR (kind='dispense' AND quantity_delta<0) OR kind='adjustment')
) STRICT;


-- Hóa đơn VND gắn một lượt khám; trạng thái thanh toán suy ra.
CREATE TABLE invoices(
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    encounter_id INTEGER NOT NULL UNIQUE,
    patient_id INTEGER NOT NULL,
    currency TEXT NOT NULL DEFAULT 'VND' CHECK(currency='VND'),
    status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','issued','void')),
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER)),
    FOREIGN KEY(encounter_id,patient_id) REFERENCES encounters(id,patient_id) ON DELETE RESTRICT
) STRICT;


-- Chi tiết hóa đơn lưu snapshot tên, số lượng và đơn giá.
CREATE TABLE invoice_items(
    id INTEGER PRIMARY KEY,
    invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
    description TEXT NOT NULL CHECK(length(trim(description))>0),
    quantity INTEGER NOT NULL CHECK(quantity BETWEEN 1 AND 1000000),
    unit_price_minor INTEGER NOT NULL CHECK(unit_price_minor BETWEEN 0 AND 1000000000000),
    discount_minor INTEGER NOT NULL DEFAULT 0 CHECK(discount_minor>=0),
    CHECK(discount_minor<=quantity*unit_price_minor),
    CHECK(quantity*unit_price_minor-discount_minor<=1000000000000)
) STRICT;


-- Phiếu thu đã ghi nhận; không lưu thông tin thẻ thanh toán.
CREATE TABLE payments(
    id INTEGER PRIMARY KEY,
    invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
    amount_minor INTEGER NOT NULL CHECK(amount_minor BETWEEN 1 AND 1000000000000),
    method TEXT NOT NULL CHECK(method IN ('cash','bank_transfer','card','wallet')),
    request_key TEXT NOT NULL UNIQUE,
    provider_reference TEXT,
    recorded_by INTEGER REFERENCES users(id) ON DELETE RESTRICT,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER))
) STRICT;


-- Phiếu hoàn tiền append-only gắn phiếu thu gốc.
CREATE TABLE refunds(
    id INTEGER PRIMARY KEY,
    payment_id INTEGER NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
    amount_minor INTEGER NOT NULL CHECK(amount_minor BETWEEN 1 AND 1000000000000),
    reason TEXT NOT NULL CHECK(length(trim(reason))>0),
    request_key TEXT NOT NULL UNIQUE,
    provider_reference TEXT,
    recorded_by INTEGER REFERENCES users(id) ON DELETE RESTRICT,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER))
) STRICT;


-- Hàng đợi thông báo; gửi thực tế do backend thực hiện.
CREATE TABLE notifications(
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    kind TEXT NOT NULL,
    channel TEXT NOT NULL CHECK(channel IN ('in_app','push','email','sms')),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','sent','failed')),
    attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts>=0),
    scheduled_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER)),
    sent_at INTEGER,
    read_at INTEGER,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER))
) STRICT;


-- Nhật ký append-only; backend phải ghi cùng giao dịch nghiệp vụ.
CREATE TABLE audit_logs(
    id INTEGER PRIMARY KEY,
    actor_user_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_key TEXT NOT NULL,
    summary TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER))
) STRICT;


CREATE VIEW stock_balances AS
SELECT b.id AS batch_id,b.clinic_id,b.medication_id,b.lot_number,b.expires_on,
       COALESCE(SUM(m.quantity_delta),0) AS balance
FROM medication_batches b LEFT JOIN stock_movements m ON m.batch_id=b.id GROUP BY b.id;

CREATE VIEW invoice_balances AS
SELECT x.*,x.total_minor-x.paid_minor AS due_minor FROM (
 SELECT i.id AS invoice_id,i.patient_id,i.status,
 COALESCE((SELECT SUM(quantity*unit_price_minor-discount_minor) FROM invoice_items WHERE invoice_id=i.id),0) AS total_minor,
 COALESCE((SELECT SUM(amount_minor) FROM payments WHERE invoice_id=i.id),0)
 -COALESCE((SELECT SUM(r.amount_minor) FROM refunds r JOIN payments p ON p.id=r.payment_id WHERE p.invoice_id=i.id),0) AS paid_minor
 FROM invoices i
) x;

CREATE TRIGGER shifts_overlap_insert BEFORE INSERT ON doctor_shifts

BEGIN
    SELECT RAISE(ABORT, 'doctor shift overlap') WHERE NEW.status='scheduled' AND EXISTS(
        SELECT 1 FROM doctor_shifts s JOIN doctor_clinics a ON a.id=s.assignment_id
        JOIN doctor_clinics n ON n.id=NEW.assignment_id
        WHERE a.doctor_id=n.doctor_id AND s.status='scheduled'
        AND s.starts_at<NEW.ends_at AND NEW.starts_at<s.ends_at );
END;


CREATE TRIGGER appointments_validate_insert BEFORE INSERT ON appointments

BEGIN
    SELECT RAISE(ABORT, 'appointment outside active shift') WHERE NEW.status!='cancelled' AND NOT EXISTS(SELECT 1 FROM doctor_shifts s
        WHERE s.id=NEW.shift_id AND s.status='scheduled'
        AND s.starts_at<=NEW.starts_at AND NEW.ends_at<=s.ends_at);
    SELECT RAISE(ABORT, 'doctor or patient appointment overlap') WHERE NEW.status!='cancelled' AND EXISTS(
        SELECT 1 FROM appointments a JOIN doctor_shifts s ON s.id=a.shift_id
        JOIN doctor_clinics d ON d.id=s.assignment_id
        JOIN doctor_shifts ns ON ns.id=NEW.shift_id JOIN doctor_clinics nd ON nd.id=ns.assignment_id
        WHERE a.status!='cancelled' AND (a.patient_id=NEW.patient_id OR d.doctor_id=nd.doctor_id)
        AND a.starts_at<NEW.ends_at AND NEW.starts_at<a.ends_at );
END;


CREATE TRIGGER service_order_clinic_insert BEFORE INSERT ON service_orders

BEGIN
    SELECT RAISE(ABORT, 'service belongs to another clinic') WHERE EXISTS(
        SELECT 1 FROM encounters e JOIN appointments a ON a.id=e.appointment_id
        JOIN doctor_shifts sh ON sh.id=a.shift_id JOIN doctor_clinics dc ON dc.id=sh.assignment_id
        JOIN services sv ON sv.id=NEW.service_id WHERE e.id=NEW.encounter_id AND sv.clinic_id!=dc.clinic_id);
END;


CREATE TRIGGER shifts_overlap_update BEFORE UPDATE ON doctor_shifts

BEGIN
    SELECT RAISE(ABORT, 'doctor shift overlap') WHERE NEW.status='scheduled' AND EXISTS(
        SELECT 1 FROM doctor_shifts s JOIN doctor_clinics a ON a.id=s.assignment_id
        JOIN doctor_clinics n ON n.id=NEW.assignment_id
        WHERE a.doctor_id=n.doctor_id AND s.status='scheduled'
        AND s.starts_at<NEW.ends_at AND NEW.starts_at<s.ends_at AND s.id!=OLD.id);
END;


CREATE TRIGGER appointments_validate_update BEFORE UPDATE ON appointments

BEGIN
    SELECT RAISE(ABORT, 'appointment outside active shift') WHERE NEW.status!='cancelled' AND NOT EXISTS(SELECT 1 FROM doctor_shifts s
        WHERE s.id=NEW.shift_id AND s.status='scheduled'
        AND s.starts_at<=NEW.starts_at AND NEW.ends_at<=s.ends_at);
    SELECT RAISE(ABORT, 'doctor or patient appointment overlap') WHERE NEW.status!='cancelled' AND EXISTS(
        SELECT 1 FROM appointments a JOIN doctor_shifts s ON s.id=a.shift_id
        JOIN doctor_clinics d ON d.id=s.assignment_id
        JOIN doctor_shifts ns ON ns.id=NEW.shift_id JOIN doctor_clinics nd ON nd.id=ns.assignment_id
        WHERE a.status!='cancelled' AND (a.patient_id=NEW.patient_id OR d.doctor_id=nd.doctor_id)
        AND a.starts_at<NEW.ends_at AND NEW.starts_at<a.ends_at AND a.id!=OLD.id);
END;


CREATE TRIGGER service_order_clinic_update BEFORE UPDATE ON service_orders

BEGIN
    SELECT RAISE(ABORT, 'service belongs to another clinic') WHERE EXISTS(
        SELECT 1 FROM encounters e JOIN appointments a ON a.id=e.appointment_id
        JOIN doctor_shifts sh ON sh.id=a.shift_id JOIN doctor_clinics dc ON dc.id=sh.assignment_id
        JOIN services sv ON sv.id=NEW.service_id WHERE e.id=NEW.encounter_id AND sv.clinic_id!=dc.clinic_id);
END;


CREATE TRIGGER assignment_identity_frozen BEFORE UPDATE OF doctor_id,clinic_id ON doctor_clinics
WHEN NEW.doctor_id!=OLD.doctor_id OR NEW.clinic_id!=OLD.clinic_id
BEGIN
    SELECT RAISE(ABORT, 'referenced assignment identity is frozen') WHERE EXISTS(SELECT 1 FROM doctor_shifts WHERE assignment_id=OLD.id);
END;


CREATE TRIGGER shift_identity_frozen BEFORE UPDATE OF assignment_id,starts_at,ends_at ON doctor_shifts
WHEN NEW.assignment_id!=OLD.assignment_id OR NEW.starts_at!=OLD.starts_at OR NEW.ends_at!=OLD.ends_at
BEGIN
    SELECT RAISE(ABORT, 'referenced shift is frozen') WHERE EXISTS(SELECT 1 FROM appointments WHERE shift_id=OLD.id);
END;


CREATE TRIGGER shift_cancel_guard BEFORE UPDATE OF status ON doctor_shifts
WHEN NEW.status='cancelled'
BEGIN
    SELECT RAISE(ABORT, 'cancel appointments before cancelling shift') WHERE EXISTS(SELECT 1 FROM appointments WHERE shift_id=OLD.id AND status!='cancelled');
END;


CREATE TRIGGER appointment_clinical_identity_frozen BEFORE UPDATE OF patient_id,shift_id,starts_at,ends_at ON appointments
WHEN NEW.patient_id!=OLD.patient_id OR NEW.shift_id!=OLD.shift_id OR NEW.starts_at!=OLD.starts_at OR NEW.ends_at!=OLD.ends_at
BEGIN
    SELECT RAISE(ABORT, 'encounter appointment identity is frozen') WHERE EXISTS(SELECT 1 FROM encounters WHERE appointment_id=OLD.id);
END;


CREATE TRIGGER encounter_identity_frozen BEFORE UPDATE OF appointment_id,patient_id ON encounters
WHEN NEW.appointment_id!=OLD.appointment_id OR NEW.patient_id!=OLD.patient_id
BEGIN
    SELECT RAISE(ABORT,'encounter identity is frozen');
END;


CREATE TRIGGER service_clinic_frozen BEFORE UPDATE OF clinic_id ON services
WHEN NEW.clinic_id!=OLD.clinic_id
BEGIN
    SELECT RAISE(ABORT, 'referenced service clinic is frozen') WHERE EXISTS(SELECT 1 FROM service_orders WHERE service_id=OLD.id);
END;


CREATE TRIGGER plan_history_frozen BEFORE UPDATE OF patient_id,medication_id,dose_text,timezone,starts_on,ends_on ON medication_plans
WHEN NEW.patient_id!=OLD.patient_id OR NEW.medication_id!=OLD.medication_id OR NEW.dose_text!=OLD.dose_text OR NEW.timezone!=OLD.timezone OR NEW.starts_on!=OLD.starts_on OR NEW.ends_on IS NOT OLD.ends_on
BEGIN
    SELECT RAISE(ABORT, 'logged plan identity and dose are frozen') WHERE EXISTS(SELECT 1 FROM medication_intakes WHERE plan_id=OLD.id);
END;


CREATE TRIGGER batch_identity_frozen BEFORE UPDATE OF clinic_id,medication_id,lot_number ON medication_batches
WHEN NEW.clinic_id!=OLD.clinic_id OR NEW.medication_id!=OLD.medication_id OR NEW.lot_number!=OLD.lot_number
BEGIN
    SELECT RAISE(ABORT, 'stock batch identity is frozen') WHERE EXISTS(SELECT 1 FROM stock_movements WHERE batch_id=OLD.id);
END;


CREATE TRIGGER stock_nonnegative BEFORE INSERT ON stock_movements

BEGIN
    SELECT RAISE(ABORT, 'stock balance outside allowed range') WHERE COALESCE((SELECT SUM(quantity_delta) FROM stock_movements WHERE batch_id=NEW.batch_id),0)+NEW.quantity_delta NOT BETWEEN 0 AND 1000000000000;
END;


CREATE TRIGGER dispense_prescription_match BEFORE INSERT ON stock_movements

BEGIN
    SELECT RAISE(ABORT, 'dispensing medication or clinic mismatch') WHERE NEW.prescription_item_id IS NOT NULL AND EXISTS(
    SELECT 1 FROM prescription_items pi JOIN prescriptions p ON p.id=pi.prescription_id
    JOIN encounters e ON e.id=p.encounter_id JOIN appointments a ON a.id=e.appointment_id
    JOIN doctor_shifts sh ON sh.id=a.shift_id JOIN doctor_clinics dc ON dc.id=sh.assignment_id
    JOIN medication_batches b ON b.id=NEW.batch_id WHERE pi.id=NEW.prescription_item_id
    AND (pi.medication_id!=b.medication_id OR dc.clinic_id!=b.clinic_id));
END;


CREATE TRIGGER invoice_initial_state BEFORE INSERT ON invoices

BEGIN
    SELECT RAISE(ABORT, 'invoice must begin as draft') WHERE NEW.status!='draft';
END;


CREATE TRIGGER invoice_state BEFORE UPDATE ON invoices

BEGIN
    SELECT RAISE(ABORT, 'issued invoice identity is frozen') WHERE OLD.status!='draft' AND (NEW.id!=OLD.id OR NEW.code!=OLD.code OR NEW.encounter_id!=OLD.encounter_id OR NEW.patient_id!=OLD.patient_id OR NEW.currency!=OLD.currency OR NEW.created_at!=OLD.created_at);
    SELECT RAISE(ABORT, 'invalid invoice transition') WHERE NOT (NEW.status=OLD.status OR (OLD.status='draft' AND NEW.status='issued') OR (OLD.status='issued' AND NEW.status='void'));
    SELECT RAISE(ABORT, 'invoice must have lines and bounded total') WHERE NEW.status='issued' AND OLD.status='draft' AND (NOT EXISTS(SELECT 1 FROM invoice_items WHERE invoice_id=OLD.id) OR (SELECT total_minor FROM invoice_balances WHERE invoice_id=OLD.id)>1000000000000);
    SELECT RAISE(ABORT, 'refund payments before voiding invoice') WHERE NEW.status='void' AND (SELECT paid_minor FROM invoice_balances WHERE invoice_id=OLD.id)!=0;
END;


CREATE TRIGGER invoice_delete BEFORE DELETE ON invoices

BEGIN
    SELECT RAISE(ABORT, 'issued invoice cannot be deleted') WHERE OLD.status!='draft';
END;


CREATE TRIGGER invoice_lines_draft_insert BEFORE INSERT ON invoice_items

BEGIN
    SELECT RAISE(ABORT, 'invoice lines require draft invoice') WHERE COALESCE((SELECT status FROM invoices WHERE id=NEW.invoice_id),'missing')!='draft';
END;


CREATE TRIGGER invoice_lines_draft_update BEFORE UPDATE ON invoice_items

BEGIN
    SELECT RAISE(ABORT, 'invoice lines require draft invoice') WHERE COALESCE((SELECT status FROM invoices WHERE id=OLD.invoice_id),'missing')!='draft' OR COALESCE((SELECT status FROM invoices WHERE id=NEW.invoice_id),'missing')!='draft';
END;


CREATE TRIGGER invoice_lines_draft_delete BEFORE DELETE ON invoice_items

BEGIN
    SELECT RAISE(ABORT, 'invoice lines require draft invoice') WHERE COALESCE((SELECT status FROM invoices WHERE id=OLD.invoice_id),'missing')!='draft';
END;


CREATE TRIGGER invoice_line_limit BEFORE INSERT ON invoice_items

BEGIN
    SELECT RAISE(ABORT, 'invoice line limit exceeded') WHERE (SELECT COUNT(*) FROM invoice_items WHERE invoice_id=NEW.invoice_id)>=1000;
END;


CREATE TRIGGER payment_balance_guard BEFORE INSERT ON payments

BEGIN
    SELECT RAISE(ABORT, 'payments require issued invoice') WHERE COALESCE((SELECT status FROM invoices WHERE id=NEW.invoice_id),'missing')!='issued';
    SELECT RAISE(ABORT, 'payment exceeds invoice balance') WHERE NEW.amount_minor>(SELECT due_minor FROM invoice_balances WHERE invoice_id=NEW.invoice_id);
END;


CREATE TRIGGER refund_balance_guard BEFORE INSERT ON refunds

BEGIN
    SELECT RAISE(ABORT, 'refund exceeds original payment') WHERE NEW.amount_minor>COALESCE((SELECT amount_minor FROM payments WHERE id=NEW.payment_id),0)-COALESCE((SELECT SUM(amount_minor) FROM refunds WHERE payment_id=NEW.payment_id),0);
END;


CREATE TRIGGER stock_movements_no_update BEFORE UPDATE ON stock_movements

BEGIN
    SELECT RAISE(ABORT, 'append-only history');
END;


CREATE TRIGGER stock_movements_no_delete BEFORE DELETE ON stock_movements

BEGIN
    SELECT RAISE(ABORT, 'append-only history');
END;


CREATE TRIGGER stock_movements_no_replace BEFORE INSERT ON stock_movements

BEGIN
    SELECT RAISE(ABORT, 'duplicate immutable ledger entry') WHERE EXISTS(SELECT 1 FROM stock_movements WHERE id=NEW.id) OR EXISTS(SELECT 1 FROM stock_movements WHERE request_key=NEW.request_key);
END;


CREATE TRIGGER payments_no_update BEFORE UPDATE ON payments

BEGIN
    SELECT RAISE(ABORT, 'append-only history');
END;


CREATE TRIGGER payments_no_delete BEFORE DELETE ON payments

BEGIN
    SELECT RAISE(ABORT, 'append-only history');
END;


CREATE TRIGGER payments_no_replace BEFORE INSERT ON payments

BEGIN
    SELECT RAISE(ABORT, 'duplicate immutable ledger entry') WHERE EXISTS(SELECT 1 FROM payments WHERE id=NEW.id) OR EXISTS(SELECT 1 FROM payments WHERE request_key=NEW.request_key);
END;


CREATE TRIGGER refunds_no_update BEFORE UPDATE ON refunds

BEGIN
    SELECT RAISE(ABORT, 'append-only history');
END;


CREATE TRIGGER refunds_no_delete BEFORE DELETE ON refunds

BEGIN
    SELECT RAISE(ABORT, 'append-only history');
END;


CREATE TRIGGER refunds_no_replace BEFORE INSERT ON refunds

BEGIN
    SELECT RAISE(ABORT, 'duplicate immutable ledger entry') WHERE EXISTS(SELECT 1 FROM refunds WHERE id=NEW.id) OR EXISTS(SELECT 1 FROM refunds WHERE request_key=NEW.request_key);
END;


CREATE TRIGGER audit_logs_no_update BEFORE UPDATE ON audit_logs

BEGIN
    SELECT RAISE(ABORT, 'append-only history');
END;


CREATE TRIGGER audit_logs_no_delete BEFORE DELETE ON audit_logs

BEGIN
    SELECT RAISE(ABORT, 'append-only history');
END;


CREATE TRIGGER audit_logs_no_replace BEFORE INSERT ON audit_logs

BEGIN
    SELECT RAISE(ABORT, 'duplicate immutable ledger entry') WHERE EXISTS(SELECT 1 FROM audit_logs WHERE id=NEW.id);
END;


INSERT INTO roles(code,name) VALUES('admin','Quản trị'),('doctor','Bác sĩ'),('staff','Nhân viên'),('pharmacist','Dược sĩ'),('patient','Bệnh nhân');

CREATE INDEX ix_user_roles_role_id ON user_roles(role_id);

CREATE INDEX ix_refresh_sessions_user_id ON refresh_sessions(user_id);

CREATE INDEX ix_doctor_specialties_specialty_id ON doctor_specialties(specialty_id);

CREATE INDEX ix_doctor_clinics_clinic_id ON doctor_clinics(clinic_id);

CREATE INDEX ix_doctor_shifts_assignment_id ON doctor_shifts(assignment_id);

CREATE INDEX ix_appointments_shift_id ON appointments(shift_id);

CREATE INDEX ix_appointments_patient_id ON appointments(patient_id);

CREATE INDEX ix_encounters_appointment_id_patient_id ON encounters(appointment_id,patient_id);

CREATE INDEX ix_encounter_diagnoses_diagnosis_id ON encounter_diagnoses(diagnosis_id);

CREATE INDEX ix_observations_encounter_id ON observations(encounter_id);

CREATE INDEX ix_service_orders_service_id ON service_orders(service_id);

CREATE INDEX ix_service_orders_encounter_id ON service_orders(encounter_id);

CREATE INDEX ix_prescriptions_encounter_id_patient_id ON prescriptions(encounter_id,patient_id);

CREATE INDEX ix_prescription_items_prescription_id_patient_id ON prescription_items(prescription_id,patient_id);

CREATE INDEX ix_prescription_items_medication_id ON prescription_items(medication_id);

CREATE INDEX ix_personal_medications_medication_id ON personal_medications(medication_id);

CREATE INDEX ix_medication_plans_prescription_item_id_patient_id_medication_id ON medication_plans(prescription_item_id,patient_id,medication_id);

CREATE INDEX ix_medication_plans_medication_id ON medication_plans(medication_id);

CREATE INDEX ix_medication_plans_patient_id ON medication_plans(patient_id);

CREATE INDEX ix_medication_intakes_recorded_by ON medication_intakes(recorded_by);

CREATE INDEX ix_medication_batches_medication_id ON medication_batches(medication_id);

CREATE INDEX ix_stock_movements_recorded_by ON stock_movements(recorded_by);

CREATE INDEX ix_stock_movements_prescription_item_id ON stock_movements(prescription_item_id);

CREATE INDEX ix_stock_movements_batch_id ON stock_movements(batch_id);

CREATE INDEX ix_invoices_encounter_id_patient_id ON invoices(encounter_id,patient_id);

CREATE INDEX ix_invoice_items_invoice_id ON invoice_items(invoice_id);

CREATE INDEX ix_payments_recorded_by ON payments(recorded_by);

CREATE INDEX ix_payments_invoice_id ON payments(invoice_id);

CREATE INDEX ix_refunds_recorded_by ON refunds(recorded_by);

CREATE INDEX ix_refunds_payment_id ON refunds(payment_id);

CREATE INDEX ix_notifications_user_id ON notifications(user_id);

CREATE INDEX ix_audit_logs_actor_user_id ON audit_logs(actor_user_id);

CREATE INDEX ix_appointments_time ON appointments(starts_at,ends_at) WHERE status!='cancelled';

CREATE INDEX ix_doctor_shifts_time ON doctor_shifts(starts_at,ends_at) WHERE status='scheduled';

CREATE INDEX ix_notifications_queue ON notifications(status,scheduled_at);

CREATE INDEX ix_audit_entity ON audit_logs(entity_type,entity_key,created_at);

CREATE INDEX ix_medication_plans_due ON medication_plans(status,starts_on,ends_on);
