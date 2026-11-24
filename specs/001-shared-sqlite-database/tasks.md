# Tasks: Shared MediCare SQLite database

**Input**: spec.md, plan.md, research.md, data-model.md, contracts/database-cli.md.
**Tests**: Explicit in FR-009, SC-001–SC-003 and constitution IV.

## Phase 1: Setup

- [x] T001 Initialize project-local Spec Kit and constitution in .specify/memory/constitution.md.
- [x] T002 Extend .gitignore to exclude SQLite runtime sidecars and database/data/.

## Phase 2: Foundational

- [x] T003 Specify connection/migration contract and SQLite 3.37+ minimum in database/manage.py; enable foreign_keys, recursive_triggers, busy_timeout; default DELETE journal.
- [x] T004 Add migration rollback/reinitialization contract tests in database/tests/test_database.py before migration runner implementation.

## Phase 3: US1 - Shared identities and appointments (P1)

**Goal**: Book visits for correct patients and doctors across sites.
**Independent Test**: Valid visit, same-doctor/patient overlap rejection, adjacent visit success.

- [x] T005 [US1] Write scheduling/identity integration tests in database/tests/test_database.py; intervals use “end > start” and half-open boundaries.
- [x] T006 [US1] Implement identity/roles/sessions/patients/clinic assignments and shifts in database/migrations/001_initial.sql; “unique case-insensitive email”, “optional unique user_id”, “no plaintext passwords/tokens”.
- [x] T007 [US1] Implement appointments and insert/update/parent mutation guards in database/migrations/001_initial.sql; “non-cancelled doctor/patient intervals cannot overlap”.

## Phase 4: US2 - Clinical and personal medication records (P1)

**Goal**: Preserve correct care/prescription ownership and track personal doses.
**Independent Test**: Care/prescription plan succeeds; cross-patient/drug links and duplicate doses fail.

- [x] T008 [US2] Write ownership/dose tests in database/tests/test_database.py before clinical SQL.
- [x] T009 [US2] Implement encounters, diagnosis_catalog, encounter_diagnoses, observations, patient_allergies and services/orders in database/migrations/001_initial.sql; “order encounter and service must have same clinic”.
- [x] T010 [US2] Implement medications, prescriptions/items and personal plans/times/intakes in database/migrations/001_initial.sql; “optional item link matches patient and medicine”, “unique plan/scheduled dose”, “taken requires taken_at”.

## Phase 5: US3 - Stock and billing (P2)

**Goal**: Record dispensing and payments without losing history or exceeding balances.
**Independent Test**: Receive/dispense, issue/collect/refund; deficits and history rewrites fail.

- [x] T011 [US3] Write stock/payment/refund/REPLACE rejection tests in database/tests/test_database.py before ledger SQL.
- [x] T012 [US3] Implement medication_batches and stock_movements in database/migrations/001_initial.sql; “derived stock cannot be negative”, “ledger immutable”.
- [x] T013 [US3] Implement invoices/items/payments/refunds and balance views in database/migrations/001_initial.sql; “empty invoices cannot issue”, “issued invoices cannot return to draft”, “no payment above balance, no refund above receipt”.

## Phase 6: US4 - Runnable handoff (P2)

**Goal**: Recreate and inspect the database without losing existing data.
**Independent Test**: Init twice, optional demo, integrity check and failed-migration rollback.

- [x] T014 [US4] Implement atomic, checksum-validated init/demo/check commands in database/manage.py per contracts/database-cli.md; add static roles in database/migrations/001_initial.sql.
- [x] T015 [US4] Implement notifications and append-only audit_logs in database/migrations/001_initial.sql (FR-008), plus synthetic complete flow in database/seeds/demo.sql.
- [x] T016 [US4] Document every entity/column/FK in docs/database/data-dictionary.md and ERD/architecture/limitations in docs/database/design.md; add usage in database/README.md and README.md (FR-009–FR-010, SC-004).

## Phase 7: Polish and Cross-Cutting Concerns

- [x] T017 Run negative/positive integration tests and two-connection conflict scenarios in database/tests/test_database.py; validate quickstart.md commands and record results in specs/001-shared-sqlite-database/validation.md.
- [x] T018 Assess every FR/SC/story/plan decision against implementation; record handoff in specs/001-shared-sqlite-database/convergence.md outside the read-only converge operation.

## Dependencies and Execution Order

T001–T004 foundation -> US1 -> US2 -> US3 -> US4 -> T017–T018.
The domains can be tested independently with synthetic prerequisite fixtures, though one canonical
migration file requires sequential edits. Tests are written and observed failing before SQL/tooling.

## Parallel Examples

After table design, documentation drafting (T016) can run alongside test-case design for each
story (T005/T008/T011) in separate files. No [P] markers on current tasks because SQL/tests
share files; actual implementation remains sequential. Research may run independently of writing.

## Implementation Strategy

Deliver a verified US1 scheduling slice, then add care and personal medication, then pharmacy
and finance. Finish all requested domains before handoff. Do not publish or push this feature
without an instruction covering the new changes.

## Additional Implementation Hardening

- [x] T019 Preserve history and invoice line-move limits in database/migrations/002_history_guards.sql; add seven checks in database/tests/test_database.py (Constitution II, FR-007, FR-009).
