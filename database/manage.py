"""Create/check MediCare SQLite databases using only the Python standard library."""
import argparse
from contextlib import closing
import hashlib
from pathlib import Path
import re
import sqlite3
import sys

ROOT = Path(__file__).resolve().parent


def connect(path):
    if sqlite3.sqlite_version_info < (3, 37, 0):
        raise ValueError('SQLite 3.37+ is required for STRICT tables')
    db = sqlite3.connect(str(path), timeout=5, isolation_level=None)
    try:
        db.execute('PRAGMA foreign_keys=ON')
        db.execute('PRAGMA recursive_triggers=ON')
        db.execute('PRAGMA busy_timeout=5000')
        db.execute('PRAGMA synchronous=FULL')
        if db.execute('PRAGMA journal_mode').fetchone()[0] not in ('delete', 'memory'):
            raise ValueError('This baseline uses DELETE journaling; configure other modes separately on a patched runtime')
        if db.execute('PRAGMA foreign_keys').fetchone()[0] != 1:
            raise ValueError('SQLite foreign key support is required')
        return db
    except Exception:
        db.close()
        raise


def execute_sql(db, content):
    """Honor quoted semicolons and multi-statement trigger bodies."""
    buffer = ''
    for char in content:
        buffer += char
        if char == ';' and sqlite3.complete_statement(buffer):
            # Transaction ownership belongs to this runner, never to migration files.
            without_comments = re.sub(r'--[^\n]*|/\*.*?\*/', '', buffer, flags=re.S).strip()
            if re.match(r'(?i)^(BEGIN|COMMIT|END|ROLLBACK|SAVEPOINT|RELEASE|ATTACH|DETACH|VACUUM|PRAGMA)\b', without_comments):
                raise ValueError('Migration/seed must not control transactions or connection pragmas')
            db.execute(buffer)
            buffer = ''
    remainder = re.sub(r'--[^\n]*|/\*.*?\*/', '', buffer, flags=re.S).strip()
    if remainder:
        raise ValueError('Incomplete SQL statement; include a terminating semicolon')


def migrate(db, migrations=ROOT / 'migrations'):
    files = sorted(Path(migrations).glob('*.sql'))
    if not files:
        raise ValueError('No migration files found')
    catalog = {}
    for expected, file in enumerate(files, 1):
        match = re.match(r'^(\d+)_.*\.sql$', file.name)
        if not match or int(match[1]) != expected:
            raise ValueError('Migration versions must be consecutive starting at 001')
        content = file.read_bytes()
        catalog[expected] = (file.name, hashlib.sha256(content).hexdigest(), content.decode('utf-8'))
    try:
        db.execute('BEGIN IMMEDIATE')
        tables = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")}
        if tables and 'schema_migrations' not in tables:
            raise ValueError('Refusing to adopt an existing unversioned database')
        db.execute('''CREATE TABLE IF NOT EXISTS schema_migrations(
            version INTEGER PRIMARY KEY, filename TEXT NOT NULL UNIQUE,
            checksum TEXT NOT NULL, applied_at INTEGER NOT NULL DEFAULT(CAST(strftime('%s','now') AS INTEGER))
        ) STRICT''')
        db.commit()
        while True:
            db.execute('BEGIN IMMEDIATE')
            applied = db.execute('SELECT version,filename,checksum FROM schema_migrations ORDER BY version').fetchall()
            for expected, (version, filename, checksum) in enumerate(applied, 1):
                if version != expected or version not in catalog:
                    raise ValueError('Unknown or nonconsecutive applied migration version')
                if catalog[version][:2] != (filename, checksum):
                    raise ValueError(f'Migration checksum/filename mismatch: {filename}')
            version = len(applied) + 1
            if version not in catalog:
                db.commit()
                break
            filename, checksum, content = catalog[version]
            execute_sql(db, content)
            if db.execute('PRAGMA foreign_key_check').fetchall():
                raise ValueError('Migration introduced foreign key violations')
            db.execute('INSERT INTO schema_migrations(version,filename,checksum) VALUES(?,?,?)', (version, filename, checksum))
            db.execute(f'PRAGMA user_version={version}')
            db.commit()
    except Exception:
        db.rollback()
        raise


def seed_demo(db):
    try:
        db.execute('BEGIN IMMEDIATE')
        # Do not mingle synthetic records with any existing business data.
        tables = [row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT IN ('roles','schema_migrations') AND name NOT LIKE 'sqlite_%'")]
        if any(db.execute(f'SELECT 1 FROM "{table}" LIMIT 1').fetchone() for table in tables):
            raise ValueError('Demo requires an empty business database; choose a new --db path')
        execute_sql(db, (ROOT / 'seeds/demo.sql').read_text(encoding='utf-8'))
        db.commit()
    except Exception:
        db.rollback()
        raise


def check(db):
    integrity = db.execute('PRAGMA integrity_check').fetchall()
    violations = db.execute('PRAGMA foreign_key_check').fetchall()
    if integrity != [('ok',)] or violations:
        raise ValueError(f'Integrity failure: {integrity}; foreign key violations: {violations}')
    version = db.execute('PRAGMA user_version').fetchone()[0]
    if not version or not db.execute("SELECT 1 FROM sqlite_master WHERE name='schema_migrations'").fetchone():
        raise ValueError('Not an initialized MediCare database')
    tables = db.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").fetchone()[0]
    views = db.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='view'").fetchone()[0]
    return f'OK: SQLite {sqlite3.sqlite_version}; schema v{version}; {tables} tables; {views} views; integrity ok; 0 foreign key violations'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('init', 'demo', 'check'))
    parser.add_argument('--db', type=Path)
    args = parser.parse_args()
    path = args.db or ROOT / 'data' / ('medicare.demo.sqlite' if args.command == 'demo' else 'medicare.sqlite')
    try:
        if args.command == 'check' and not path.is_file():
            raise ValueError(f'Database does not exist: {path}')
        if args.command != 'check':
            path.parent.mkdir(parents=True, exist_ok=True)
        with closing(connect(path)) as db:
            if args.command in ('init', 'demo'):
                migrate(db)
            if args.command == 'demo':
                seed_demo(db)
            print(check(db))
            print(f'Database: {path.resolve()}')
        return 0
    except (sqlite3.Error, ValueError, OSError) as exc:
        print(f'Error: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
