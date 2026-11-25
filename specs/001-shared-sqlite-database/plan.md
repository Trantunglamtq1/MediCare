# Implementation Plan: Shared MediCare SQLite database

**Branch**: `codex/sqlite-database` | **Date**: 2026-11-24 | **Spec**: [spec.md](spec.md)

## Summary

Provide a normalized SQLite baseline covering all three clarified outpatient/personal-medication
domains. Backend owns one database file; Android/web use APIs. Deliver versioned SQL, a safe
initializer, synthetic demo, negative integration checks, ERD and data dictionary. Do not implement clients.

## Technical Context

**Language/Version**: SQLite SQL 3.37+; Python 3.10+ standard library for portable tooling.
**Primary Dependencies**: sqlite3, unittest, hashlib, argparse; no pip packages.
**Storage**: SQLite local backend disk; STRICT tables; foreign_keys=ON per connection,
busy_timeout=5000ms; DELETE rollback journal by default; recursive_triggers=ON.
**Testing**: unittest integration tests using in-memory and temporary file databases.
**Target Platform**: Windows/Linux backend tooling, independent of the eventual server framework.
**Project Type**: database schema and command-line initialization utility.
**Performance Goals**: indexed FK/lookup paths; no unverified throughput/SLA promise.
**Constraints**: one writer at a time; no multi-host/network-share file access; UTC integer seconds;
VND integer money (maximum line/payment amounts constrained to avoid integer overflow);
IANA timezone plus local reminder times; no plaintext secrets or real patient fixtures.
**Scale/Scope**: one shared system with multiple clinic sites, outpatient visits and personal meds.
Load testing and production capacity planning are deferred until traffic requirements exist.

## Constitution Check

Pre-design and post-design: PASS. Backend owns canonical data; ownership enforced through composite
FKs/triggers; money and inventory are integer units; history is protected; schema changes are
transactional; synthetic failure scenarios are mandatory. Backend authorization and encryption
are explicitly outside schema enforcement. No constitutional exceptions.

## Project Structure

### Documentation (this feature)

`spec.md`, `research.md`, `data-model.md`, `contracts/database-cli.md`, `quickstart.md`,
`checklists/`, `tasks.md`, `analysis.md`, `convergence.md` under this feature directory.

### Source Code (repository root)

```text
database/
├── migrations/001_initial.sql
├── migrations/002_history_guards.sql
├── seeds/demo.sql
├── manage.py
├── tests/test_database.py
├── README.md
└── data/                         # ignored local SQLite files
docs/database/
├── design.md                     # architecture, ERD, constraints, boundaries
└── data-dictionary.md            # every column/type/FK from schema introspection
```

**Structure Decision**: retain the requested monorepo layout; all database code is in database/.
Migration SQL is the canonical schema, avoiding a second divergent schema.sql copy.

## Phases and Verification

1. Identity/clinic/appointment tables and overlap validation (US1).
2. Encounter, services, prescriptions and personal medication tables (US2).
3. Medicine lots, immutable stock ledger, draft/issued/void invoices, immutable receipts/refunds (US3).
4. Initialization, demo, introspected documentation and executable checks (US4).
5. Run all integrity checks, a two-connection race for conflicting writes, rerun initialization,
   verify failed migration rollback, clean ignored runtime outputs and assess convergence.

Use half-open intervals [start, end). Active visits are booked, confirmed, checked_in;
completed/no_show retain their historical interval, while cancelled visits do not reserve time.
In this baseline all non-cancelled visits block overlapping historical appointments as well.
Assignments and shifts cannot be reassigned after dependent scheduling records exist.
Encounter appointment/patient ownership cannot be reparented. Issued invoice lines and posted
stock/payment/refund rows cannot be edited/deleted; corrections use refunds/adjusting movements.
Invoice totals and stock balances are derived views. Application validates business transitions,
timezone identifiers, notification consent, clinical authorization, password algorithms and access policy.

## Complexity Tracking

No constitutional violations. Cross-row overlap/balance guards use triggers because CHECK
constraints cannot express aggregate relational invariants; derived totals avoid sync bugs.
Migration 002 closes parent mutation paths for historical doctor/prescription/unit identity and
enforces the invoice line limit when moving lines, without changing applied migration 001.
