# Database Tool Contract

Run from repository root: `python database/manage.py <command> [--db PATH]`.

| Command | Contract |
| --- | --- |
| init | Create parent folder if necessary; migrate an empty or known-version SQLite DB; no sample patients by default; default path database/data/medicare.sqlite |
| demo | Require an empty business database; initialize then insert synthetic data transactionally; default path database/data/medicare.demo.sqlite; reject repeated demo/nonempty database |
| check | Require an existing file; run foreign_key_check and integrity_check; print schema version, table/view counts; no schema migration |

Exit 0 on success, nonzero with a concise message on failure. No overwrite/reset command exists.
Migration files use ordered numeric prefixes; recorded SHA-256 must match and unknown applied
versions/missing older files fail. Foreign keys must be enabled before transactions.
Migration ledger itself and each migration's writes are transactional; do not log a failed migration.

Backend connection contract: SQLite 3.37+, `PRAGMA foreign_keys=ON`, `busy_timeout=5000`, `recursive_triggers=ON`, default DELETE journal,
local file storage, transactions for multi-row business operations; no direct client file sharing.
New entity IDs use INTEGER PK; UTC seconds are INTEGER, dates YYYY-MM-DD, civil times HH:MM.
