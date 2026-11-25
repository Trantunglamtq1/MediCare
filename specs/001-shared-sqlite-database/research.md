# Research and Decisions

All plan unknowns resolved; no external service is required to run this feature.

1. **Decision**: SQLite 3.37+ STRICT tables. **Rationale**: reject wrong storage types,
   including fractional monetary values. **Alternative**: flexible affinity for old embedded
   Android engines; rejected because Android consumes the backend API rather than this server file.
   [SQLite types](https://www.sqlite.org/datatype3.html), [STRICT](https://www.sqlite.org/stricttables.html).
2. **Decision**: foreign keys enabled before each transaction; composite FKs preserve patient/drug
   ownership; indexes support child lookups. **Alternative**: application-only references; rejected
   because direct SQL could create cross-patient records.
   [Foreign keys](https://www.sqlite.org/foreignkeys.html).
3. **Decision**: integer UTC seconds for instants and validated date/local-time text for civil schedules.
   Timezone identifiers are application validated and converted to UTC doses. **Alternative**:
   naive local timestamps; rejected because ordering and timezone changes become ambiguous.
4. **Decision**: half-open overlap triggers for doctor shifts/appointments and patient appointments,
   including updates, plus frozen ownership of referenced scheduling parents. **Alternative**:
   unique start times; rejected because different starts can still overlap.
5. **Decision**: integer VND money, snapshot invoice prices, derived invoice balances, append-only
   receipts/refunds/stock ledger and compensating records. **Alternative**: floating prices and
   mutable totals; rejected because rounding and history drift are unacceptable.
6. **Decision**: versioned migration SQL with SHA-256 checksums applied with BEGIN IMMEDIATE;
   run statements individually (including complete trigger definitions), roll back on failure.
   **Alternative**: executescript inside an outer transaction; rejected because driver transaction
   behavior can break the intended atomic wrapper. Use busy_timeout, recursive_triggers=ON and default DELETE journal. Current runtime is SQLite 3.50.4; official WAL docs report a WAL-reset fix in 3.51.3 (backports 3.50.7/3.44.6). WAL deployment is deferred to a patched runtime.
   [SQLite transactions](https://www.sqlite.org/lang_transaction.html),
   [WAL](https://www.sqlite.org/wal.html),
   [Python sqlite3](https://docs.python.org/3/library/sqlite3.html).
7. **Decision**: initialize an empty database by default; demo seed is explicit, synthetic and
   refuses a nonempty business database. No real patient data or usable account passwords.
8. **Decision**: clinical signing, insurer workflows, inpatient beds and laboratory machines are
   future modules. Broad outpatient coverage is explicit; universal hospital readiness is not claimed.
