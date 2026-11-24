# Validation Evidence — 2026-11-24

Environment: Windows PowerShell, Python 3.14, bundled SQLite 3.50.4, DELETE journal.

- `python -m unittest discover -s database/tests -v`: **39 passed, 0 failures, 0 skips**.
  Initial red run failed because manage.py did not exist; tests were authored before implementation.
  First completed baseline passed 32 checks; seven additional history/migration/parser checks
  passed after hardening with migration 002.
- Three two-connection races (appointments, stock, payments): exactly one succeeds and the
  conflicting write is rejected in each case; no skipped concurrency checks.
- Fresh init, repeated init and `check`: schema v2, 35 tables (34 business + migration ledger),
  2 views; integrity ok; zero foreign key violations.
- Explicit synthetic demo: complete care/medication/pharmacy/billing path. Initial stock 100,
  dispensed 10, remaining 90. Invoice 150,000 VND, received 100,000, outstanding 50,000.
- v1 -> v2 upgrade preserves synthetic patients and business rows; v1 checksum unchanged.
- A failing migration rolls back partial schema and does not record that failed migration.
  Modified checksum, unknown applied version and unversioned existing DB are rejected.
- Repeated demo refuses existing business data. Synthetic account emails use example.invalid;
  all demo accounts disabled and have no usable password hashes.
- Every table/column/FK documented by introspection; full ERD generated from the same schema.
- SQLite database files and sidecars excluded by .gitignore; no real patient data included.

No backend/mobile/web application tests apply because application code is not part of this feature.
No production load, clinical signing, regulatory, authorization or encryption claims are made.
