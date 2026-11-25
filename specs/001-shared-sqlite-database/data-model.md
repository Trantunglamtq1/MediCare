# Data Model

Fields/SQL types and every relationship will be published in `docs/database/data-dictionary.md`.
The migration is canonical. All tables use STRICT storage, required PKs and restrictive deletes;
only user-role links and sessions may cascade when deleting otherwise unreferenced users.

| Domain | Entities and identity | Relationships and validation |
| --- | --- | --- |
| Identity | users: unique case-insensitive email; roles: unique code; user_roles; refresh_sessions: unique token digest | one user may have many roles/sessions; active/disabled accounts; no plaintext passwords/tokens |
| Patients | patients: unique patient_code, optional unique user_id; patient_allergies | patients independent of accounts; valid birth date, sex enum; allergies retained |
| Clinics | clinics: unique code; specialties: unique code; doctors: unique user/license; doctor_specialties; doctor_clinics: unique doctor/clinic | doctor may work at many sites; assignments immutable once used by shifts |
| Scheduling | doctor_shifts; appointments: unique appointment_code | start/end positive UTC integers, end > start; no overlapping doctor shifts; visits inside shift; non-cancelled doctor/patient intervals cannot overlap; referenced parents cannot be reassigned |
| Clinical | encounters: unique appointment, patient; diagnosis_catalog: unique code; encounter_diagnoses; observations | composite FK enforces appointment/patient match; notes remain drafts; categorical diagnosis data has no automated medical interpretation |
| Services | services: unique clinic/code; service_orders | nonnegative VND price; order encounter and service must have same clinic; integer units > 0 |
| Prescription | medications: unique code; prescriptions: encounter/patient; prescription_items: prescription/patient/medicine | correct patient ownership; integer quantity > 0; dose/route/frequency recorded as clinical text, no prescribing logic |
| Personal medication | personal_medications: unique patient/medicine; medication_plans; medication_plan_times; medication_intakes | on_hand >= 0; optional item link matches patient and medicine; valid date range, IANA timezone text, HH:MM times, weekday mask 1..127; unique plan/time/mask and plan/scheduled dose; taken requires taken_at |
| Pharmacy | medication_batches: unique clinic/medicine/lot; stock_movements: unique request_key | expiry valid; movement units nonzero; receipt positive, dispensing negative; derived stock cannot be negative; ledger immutable |
| Billing | invoices: unique encounter/code; invoice_items; payments: unique request_key; refunds: unique request_key | invoice belongs to encounter patient; exact VND integers; lines have immutable price snapshots after issue; no payment above balance, no refund above receipt; void requires zero net paid |
| Support | notifications; audit_logs | delivery pending/sent/failed, read_at separate; audit append-only; no automatic notification or audit service claimed |

## State and Mutation Rules

- Appointments: booked, confirmed, checked_in, completed, cancelled, no_show; lifecycle transitions
  are application validated; all non-cancelled statuses retain the occupied interval.
- Shifts: scheduled/cancelled; cancellation is rejected while non-cancelled appointments remain.
- Encounters: draft only in baseline; clinical signing/versioning deferred.
- Prescriptions: active/cancelled, plans: active/paused/completed; intake: taken/skipped/missed.
- Invoices: draft -> issued -> void; only draft lines editable; empty invoices cannot issue;
  issued invoices cannot return to draft. Paid/outstanding states derive from balance view.
- Payments/refunds/stock/audit entries: insert only. Corrections append compensating records.
- Deactivate users/doctors/clinics rather than deleting referenced historical identities.
- Integer line/receipt/refund values are bounded; backend enforces operational invoice size limits.
