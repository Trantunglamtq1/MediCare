# Quickstart Validation

Prerequisite: Python 3.10+ linked with SQLite 3.37+; no pip install required.
From repository root:

```powershell
python database/manage.py init
python database/manage.py init
python database/manage.py check
python database/manage.py demo
python database/manage.py check --db database/data/medicare.demo.sqlite
python -m unittest discover -s database/tests -v
```

Expected: repeated init preserves data, integrity reports ok and zero FK violations,
demo contains only synthetic records, all acceptance tests pass. Repeated demo must fail.
Inspect demo with a SQLite GUI; table documentation and relationships are in `docs/database/`.
For a separate scratch example, pass a new `--db` path rather than deleting existing data.
