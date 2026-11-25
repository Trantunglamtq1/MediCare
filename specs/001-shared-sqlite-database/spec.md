# Feature Specification: Shared MediCare data model

**Feature Branch**: `codex/sqlite-database`
**Created**: 2026-11-24
**Status**: Clarified
**Input**: “thiết kế database dùng sql lite đi”; “database sẽ dùng chung cho cả hệ thống nên cần bao quát tất cả các nghiệp vụ”.

## Clarifications

### Session 2026-11-24

- Q: MediCare phục vụ nghiệp vụ nào? → A: Database dùng chung toàn hệ thống, bao quát các nghiệp vụ.
- Interpretation: cover all three offered domains: appointments, outpatient clinic operations and personal medication tracking. Backend owns the shared database; mobile/web integration is a later feature.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Shared identities and appointments (Priority: P1)

Patients, clinicians and clinic staff share identities, specialties, clinic assignments and appointments.
**Why this priority**: Other clinical workflows depend on correct patient/clinician identity.
**Independent Test**: Create a clinic, assigned doctor, shift and patient; book and reschedule visits.
**Acceptance Scenarios**:

1. **Given** an available doctor shift, **When** a patient books within it, **Then** the appointment retains patient and assigned doctor/clinic identity.
2. **Given** a booked visit, **When** an overlapping active visit is requested for that doctor or patient, **Then** it is rejected; touching interval boundaries and cancelled visits do not conflict.

### User Story 2 - Encounter and personal medication history (Priority: P1)

Clinicians record outpatient encounters, diagnoses, observations, allergies, service orders and prescriptions.
Patients retain a personal medicine list, medication schedules and intake history.
**Why this priority**: These are the central care and medication records.
**Independent Test**: Record a visit and prescription, then derive a patient-specific medication plan and intake.
**Acceptance Scenarios**:

1. **Given** a visit, **When** an encounter or prescription is attached to another patient, **Then** the write is rejected.
2. **Given** a prescription item, **When** a linked personal medication plan refers to another patient or drug, **Then** the write is rejected.
3. **Given** a medication plan, **When** the same scheduled dose is submitted twice, **Then** duplicate history is rejected.

### User Story 3 - Pharmacy and billing history (Priority: P2)

Staff track medicine lots and stock movements, charge for care, record receipts and refunds.
**Why this priority**: Reliable pharmacy and money records support clinic operations.
**Independent Test**: Receive a batch, dispense stock, issue an invoice, collect and refund a receipt.
**Acceptance Scenarios**:

1. **Given** a stocked lot, **When** dispensing exceeds its balance, **Then** the write is rejected.
2. **Given** an issued invoice, **When** a receipt exceeds its outstanding amount or a refund exceeds the original receipt, **Then** the write is rejected.
3. **Given** financial or inventory history, **When** an existing ledger entry is edited/deleted, **Then** history is preserved through rejection and corrections use compensating entries.

### User Story 4 - Reproducible handoff (Priority: P2)

Developers can create an empty database, inspect a synthetic demo and understand the relationships.
**Why this priority**: The schema must be usable before clients are implemented.
**Independent Test**: Initialize a database twice, inspect its version/integrity and run documented checks.
**Acceptance Scenarios**:

1. **Given** a fresh location, **When** initialization runs, **Then** the complete schema and static reference roles exist.
2. **Given** an initialized database, **When** initialization runs again, **Then** existing records survive and migrations are not duplicated.
3. **Given** a failed migration, **When** it contains partial valid writes followed by invalid content, **Then** neither partial schema nor a migration record persists.

### Edge Cases

- Same doctor works across clinics; shifts and visits must still not overlap.
- Patient has no login; historical visits must still be representable.
- Adjacent visits are valid; cancelled visits release time.
- Receipt/refund retries have unique external/idempotency references.
- Invalid state values, fractional monetary amounts, invalid dates and missing parents fail.
- Deactivating accounts must preserve clinical and financial references.
- Concurrent conflicting appointment/stock/payment writes must serialize or fail without corrupting balances.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Model users, many-to-many roles and revocable login sessions; patients may exist without user accounts.
- **FR-002**: Model clinics, specialties, doctors, assignments, shifts and appointments; prevent overlapping shifts and active doctor/patient visits on insert/update, and visits outside their shift.
- **FR-003**: Model encounters, coded diagnoses, observations, patient allergies and service catalog/orders; encounters must refer to their appointment's patient.
- **FR-004**: Model prescription headers/items with quantities, instructions and patient ownership; catalog entries do not provide treatment recommendations.
- **FR-005**: Model personal medicine stock, medication plans with local schedule/timezone, and deduplicated intake events; prescription links must match patient and medication.
- **FR-006**: Model clinic medicine lots with expiry dates and append-only movements; balances cannot become negative.
- **FR-007**: Model invoice lines with price snapshots, issued invoices, receipts and refunds; use exact money, prevent overcollection/overrefund and preserve posted history.
- **FR-008**: Model notification delivery state and append-only audit events without claiming to implement notification sending or automatic audit capture.
- **FR-009**: Supply versioned initialization, explicit optional synthetic demo, relationship documentation, data dictionary and executable integrity checks; reruns preserve data and failed migrations roll back.
- **FR-010**: Specify account deactivation, per-connection integrity setup and application responsibilities, including permission enforcement, clinical authorization, backups and scheduling timezone conversion.

### Key Entities

- Identity: user, role, session, patient.
- Care delivery: clinic, specialty, doctor assignment, shift, appointment, encounter, diagnosis, observation, allergy, service order.
- Medication: medicine, prescription/item, personal stock, plan/time, intake, clinic batch, movement.
- Finance and support: invoice/item, receipt, refund, notification, audit event.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All four stories have a reproducible example and a passing acceptance check.
- **SC-002**: Every tested invalid relationship, overlap, stock deficit, overcollection and overrefund is rejected; no orphan rows remain.
- **SC-003**: Reinitialization preserves all existing example records; a deliberately failed migration leaves zero partial changes.
- **SC-004**: Every business entity appears in both the relationship documentation and data dictionary.

## Assumptions

- Deliverable is a database design plus runnable schema/tooling, not completed backend/mobile/web features.
- Initial scope is outpatient care across multiple clinic sites within one system, personal medication management and basic pharmacy/billing. Roles are system-wide; site-scoped authorization will be enforced by backend policy.
- VND is the initial invoice currency, expressed as integer đồng. Fractional medicine doses are textual instructions; stock/accounting units are integer dispensable units.
- Server timestamps are UTC instants; personal schedules include an IANA timezone and local times for backend conversion.
- Clinical notes are editable drafts in this baseline; medical signing/versioning, inpatient care, insurance claims, advanced lab/PACS, procurement/accounting and offline synchronization require separate specifications.
- No full requirements document or regulatory deployment target has been supplied. This is a reviewable baseline for the stated domains, not a claim of universal hospital coverage or production readiness.
