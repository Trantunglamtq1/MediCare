# MediCare Constitution

## Core Principles

### I. Shared source of truth

The backend MUST own canonical system data. Android and web MUST access shared data through
backend interfaces. Device caches MUST NOT be presented as shared system databases.

### II. Data integrity

Persistent relations MUST enforce ownership and referential integrity. Money MUST use integer
minor units. Clinical and financial history MUST survive ordinary account deactivation.
Atomic business operations MUST use transactions.

### III. Explicit scope and traceability

Features MUST document confirmed requirements, assumptions and boundaries. Each requirement
MUST map to implementation tasks and verification evidence. Unspecified medical workflows
MUST NOT be described as complete merely because extension points exist.

### IV. Verify meaningful failures

Schema changes MUST be exercised against SQLite, including invalid relations, overlapping
appointments, ownership mismatches and migration rollback. Test data MUST be synthetic.
Validation MUST report actual results and unresolved limitations.

### V. Protect sensitive records

Passwords MUST be stored as application-generated hashes. Tokens MUST be stored as digests.
Secrets and patient database files MUST NOT be committed. Authorization, encryption and
clinical decision-making MUST NOT be claimed as implemented by a schema alone.

## Data and Architecture Constraints

SQLite is the selected database engine. Connections MUST enable foreign keys before writes.
Versioned migrations MUST be transactional and recorded. Existing databases MUST NOT be
overwritten during initialization. Backend and client technologies remain undecided.

## Development Workflow

Follow constitution -> specify -> clarify -> plan -> checklist -> tasks -> analyze -> implement
-> converge, reusing existing artifacts. Apply the shorter scopes allowed by AGENTS.md.
Required checks MUST pass before convergence is reported. Publishing remains a separate
action unless the current user request explicitly authorizes it.

## Governance

This constitution governs repository work alongside AGENTS.md and current user instructions.
Amendments MUST record rationale and downstream impact. Breaking principle changes increment
the major version; new principles increment the minor version; wording corrections increment
the patch version. Reviews MUST check compliance and record exceptions with reasons.

**Version**: 1.0.0 | **Ratified**: 2026-11-24 | **Last Amended**: 2026-11-24
