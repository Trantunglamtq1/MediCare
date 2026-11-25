"""Acceptance checks against actual SQLite, with synthetic data only."""
import importlib.util
from pathlib import Path
import sqlite3
import shutil
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('database_manage', ROOT / 'manage.py')
manage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manage)


class DatabaseTests(unittest.TestCase):
    def setUp(self):
        self.db = manage.connect(':memory:')
        manage.migrate(self.db)
        manage.seed_demo(self.db)

    def tearDown(self):
        self.db.close()

    def reject(self, sql, params=()):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute(sql, params)

    def appointment(self, code, patient=2, start=1800003600, end=1800005400, status='booked', shift=1):
        return self.db.execute('INSERT INTO appointments(code,patient_id,shift_id,starts_at,ends_at,status) VALUES(?,?,?,?,?,?)',
                               (code, patient, shift, start, end, status))

    def test_full_demo_integrity(self):
        self.assertEqual(self.db.execute('PRAGMA integrity_check').fetchone()[0], 'ok')
        self.assertEqual(self.db.execute('PRAGMA foreign_key_check').fetchall(), [])
        self.assertEqual(self.db.execute('SELECT balance FROM stock_balances WHERE batch_id=1').fetchone()[0], 90)
        self.assertEqual(self.db.execute('SELECT total_minor,paid_minor,due_minor FROM invoice_balances WHERE invoice_id=1').fetchone(), (150000, 100000, 50000))

    def test_foreign_keys_and_recursive_triggers_enabled(self):
        self.assertEqual(self.db.execute('PRAGMA foreign_keys').fetchone()[0], 1)
        self.assertEqual(self.db.execute('PRAGMA recursive_triggers').fetchone()[0], 1)
        self.reject("INSERT INTO user_roles VALUES(999,1)")

    def test_case_insensitive_unique_email(self):
        self.reject("INSERT INTO users(email,full_name,status) VALUES('DEMO.DOCTOR@example.invalid','duplicate','disabled')")

    def test_invalid_dates_and_money_types(self):
        self.reject("UPDATE patients SET birth_date='2026-02-30' WHERE id=1")
        self.reject("UPDATE services SET price_minor=1.25 WHERE id=1")
        self.reject("UPDATE services SET price_minor=-1 WHERE id=1")

    def test_adjacent_appointments_allowed(self):
        self.appointment('ADJACENT')

    def test_overlapping_doctor_appointment_rejected(self):
        with self.assertRaisesRegex(sqlite3.IntegrityError, 'overlap'):
            self.appointment('OVERLAP', start=1800001800, end=1800004500)

    def test_patient_overlap_different_doctor(self):
        with self.assertRaisesRegex(sqlite3.IntegrityError, 'overlap'):
            self.appointment('PATIENT', patient=1, start=1800001800, end=1800004500, shift=2)

    def test_cancelled_overlap_allowed_and_reactivation_rejected(self):
        self.appointment('CANCEL', start=1800001800, end=1800004500, status='cancelled')
        self.reject("UPDATE appointments SET status='confirmed' WHERE code='CANCEL'")

    def test_reschedule_overlap_rejected(self):
        self.appointment('RESCHEDULE')
        self.reject("UPDATE appointments SET starts_at=1800001800 WHERE code='RESCHEDULE'")

    def test_outside_shift_and_invalid_interval(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.appointment('OUTSIDE', start=1799999000)
        with self.assertRaises(sqlite3.IntegrityError):
            self.appointment('REVERSED', start=1800005000, end=1800004000)

    def test_overlapping_doctor_shifts_across_clinics(self):
        self.reject("INSERT INTO doctor_shifts(assignment_id,starts_at,ends_at) VALUES(3,1800001000,1800007000)")

    def test_scheduling_parent_mutations_rejected(self):
        self.reject('UPDATE doctor_clinics SET doctor_id=2 WHERE id=1')
        self.reject('UPDATE doctor_shifts SET starts_at=1800001000 WHERE id=1')
        self.reject("UPDATE doctor_shifts SET status='cancelled' WHERE id=1")
        self.reject('UPDATE appointments SET patient_id=2 WHERE id=1')

    def test_wrong_patient_encounter_rejected(self):
        self.reject('INSERT INTO encounters(appointment_id,patient_id,chief_complaint) VALUES(1,2,\'wrong\')')

    def test_wrong_patient_prescription_rejected(self):
        self.reject("INSERT INTO prescriptions(code,encounter_id,patient_id) VALUES('BAD',1,2)")

    def test_wrong_prescription_item_patient_rejected(self):
        self.reject("INSERT INTO prescription_items(prescription_id,patient_id,medication_id,dose_text,quantity) VALUES(1,2,1,'sample',1)")

    def test_plan_must_match_prescription_patient_and_drug(self):
        self.reject('UPDATE medication_plans SET patient_id=2 WHERE id=1')
        self.reject('UPDATE medication_plans SET medication_id=2 WHERE id=1')

    def test_duplicate_intake_and_taken_time(self):
        self.reject("INSERT INTO medication_intakes(plan_id,scheduled_at,status,taken_at,dose_snapshot) VALUES(1,1800000000,'taken',1800000010,'demo')")
        self.reject("INSERT INTO medication_intakes(plan_id,scheduled_at,status,dose_snapshot) VALUES(1,1800086400,'taken','demo')")

    def test_plan_history_cannot_be_reparented(self):
        self.reject("UPDATE medication_plans SET dose_text='changed' WHERE id=1")

    def test_invalid_reminder_time_and_weekday_mask(self):
        self.reject("INSERT INTO medication_plan_times(plan_id,local_time,weekdays_mask) VALUES(1,'25:00',127)")
        self.reject("INSERT INTO medication_plan_times(plan_id,local_time,weekdays_mask) VALUES(1,'08:00',0)")

    def test_cross_clinic_service_order_rejected(self):
        self.reject('INSERT INTO service_orders(encounter_id,service_id,quantity) VALUES(1,2,1)')

    def test_negative_stock_rejected(self):
        self.reject("INSERT INTO stock_movements(batch_id,quantity_delta,kind,request_key) VALUES(1,-91,'dispense','oversell')")

    def test_stock_append_only_and_batch_identity_frozen(self):
        self.reject('UPDATE stock_movements SET quantity_delta=999 WHERE id=1')
        self.reject('DELETE FROM stock_movements WHERE id=1')
        self.reject('UPDATE medication_batches SET medication_id=2 WHERE id=1')

    def test_stock_request_key_unique(self):
        self.reject("INSERT INTO stock_movements(batch_id,quantity_delta,kind,request_key) VALUES(1,10,'receipt','demo-receive')")

    def test_issued_invoice_lines_and_identity_frozen(self):
        self.reject('UPDATE invoice_items SET unit_price_minor=1 WHERE id=1')
        self.reject('DELETE FROM invoice_items WHERE id=1')
        self.reject("INSERT INTO invoice_items(invoice_id,description,quantity,unit_price_minor) VALUES(1,'new',1,1)")
        self.reject("UPDATE invoices SET status='draft' WHERE id=1")
        self.reject("UPDATE invoices SET code='rewrite' WHERE id=1")

    def test_invoice_issue_and_void_guards(self):
        self.reject("UPDATE invoices SET status='void' WHERE id=1")
        self.db.execute("INSERT INTO invoices(code,encounter_id,patient_id) VALUES('EMPTY',2,2)")
        self.reject("UPDATE invoices SET status='issued' WHERE code='EMPTY'")

    def test_payment_overcollection_rejected(self):
        self.reject("INSERT INTO payments(invoice_id,amount_minor,method,request_key) VALUES(1,50001,'cash','too-much')")

    def test_refund_limit_and_recollection(self):
        self.db.execute("INSERT INTO refunds(payment_id,amount_minor,reason,request_key) VALUES(1,20000,'demo correction','refund1')")
        self.assertEqual(self.db.execute('SELECT due_minor FROM invoice_balances WHERE invoice_id=1').fetchone()[0], 70000)
        self.reject("INSERT INTO refunds(payment_id,amount_minor,reason,request_key) VALUES(1,80001,'too much','refund2')")
        self.db.execute("INSERT INTO payments(invoice_id,amount_minor,method,request_key) VALUES(1,70000,'cash','recollect')")
        self.assertEqual(self.db.execute('SELECT due_minor FROM invoice_balances WHERE invoice_id=1').fetchone()[0], 0)

    def test_posted_ledgers_and_audit_cannot_be_replaced(self):
        for table in ('payments', 'stock_movements', 'audit_logs'):
            with self.subTest(table=table):
                self.reject(f'INSERT OR REPLACE INTO {table} SELECT * FROM {table} WHERE id=1')
        self.reject('UPDATE payments SET amount_minor=1 WHERE id=1')
        self.reject('DELETE FROM audit_logs WHERE id=1')

    def test_migration_rerun_preserves_data(self):
        manage.migrate(self.db)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM patients').fetchone()[0], 2)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM schema_migrations').fetchone()[0], 2)

    def test_identity_and_unit_history_guards(self):
        self.reject('UPDATE doctors SET user_id=3 WHERE id=1')
        self.reject('UPDATE prescriptions SET encounter_id=2,patient_id=2 WHERE id=1')
        self.reject("UPDATE medications SET stock_unit='box' WHERE id=1")
        self.reject('UPDATE prescription_items SET medication_id=2 WHERE id=1')

    def test_draft_invoice_line_limit_applies_to_moves(self):
        self.db.execute("INSERT INTO invoices(id,code,encounter_id,patient_id) VALUES(2,'DRAFT',2,2)")
        self.db.executemany("INSERT INTO invoice_items(invoice_id,description,quantity,unit_price_minor) VALUES(2,?,1,1)", [(f'item{i}',) for i in range(1000)])
        self.reject("INSERT INTO invoice_items(invoice_id,description,quantity,unit_price_minor) VALUES(2,'too many',1,1)")
        # A third, independently scheduled visit gives another draft invoice to move a line from.
        self.appointment('THIRD')
        self.db.execute("INSERT INTO encounters(id,appointment_id,patient_id) SELECT 3,id,patient_id FROM appointments WHERE code='THIRD'")
        self.db.execute("INSERT INTO invoices(id,code,encounter_id,patient_id) VALUES(3,'OTHER',3,2)")
        cursor = self.db.execute("INSERT INTO invoice_items(invoice_id,description,quantity,unit_price_minor) VALUES(3,'move',1,1)")
        self.reject('UPDATE invoice_items SET invoice_id=2 WHERE id=?', (cursor.lastrowid,))

    def test_version_one_upgrade_preserves_demo(self):
        with tempfile.TemporaryDirectory() as folder:
            shutil.copy(ROOT / 'migrations/001_initial.sql', folder)
            db = manage.connect(':memory:')
            try:
                manage.migrate(db, Path(folder))
                manage.seed_demo(db)
                self.assertEqual(db.execute('PRAGMA user_version').fetchone()[0], 1)
                manage.migrate(db)
                self.assertEqual(db.execute('PRAGMA user_version').fetchone()[0], 2)
                self.assertEqual(db.execute('SELECT COUNT(*) FROM patients').fetchone()[0], 2)
            finally:
                db.close()

    def test_unknown_applied_version_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            shutil.copy(ROOT / 'migrations/001_initial.sql', folder)
            with self.assertRaisesRegex(ValueError, 'Unknown'):
                manage.migrate(self.db, Path(folder))

    def test_sql_parser_handles_trigger_and_quoted_semicolon(self):
        self.db.execute('CREATE TABLE parser_sample(id INTEGER PRIMARY KEY, value TEXT) STRICT')
        manage.execute_sql(self.db, "INSERT INTO parser_sample(value) VALUES('semi;colon'); -- comment\n")
        self.assertEqual(self.db.execute('SELECT value FROM parser_sample').fetchone()[0], 'semi;colon')

    def test_unversioned_database_refused(self):
        db = manage.connect(':memory:')
        try:
            db.execute('CREATE TABLE existing(value TEXT)')
            with self.assertRaisesRegex(ValueError, 'unversioned'):
                manage.migrate(db)
            self.assertIsNone(db.execute("SELECT name FROM sqlite_master WHERE name='schema_migrations'").fetchone())
        finally:
            db.close()

    def test_refund_and_audit_append_only(self):
        self.db.execute("INSERT INTO refunds(id,payment_id,amount_minor,reason,request_key) VALUES(1,1,100,'test','refund-ledger')")
        self.reject('UPDATE refunds SET amount_minor=1 WHERE id=1')
        self.reject('DELETE FROM refunds WHERE id=1')
        self.reject('INSERT OR REPLACE INTO refunds SELECT * FROM refunds WHERE id=1')
        # Explicit BEFORE INSERT guards also block replacement with recursive triggers disabled.
        self.db.execute('PRAGMA recursive_triggers=OFF')
        self.reject('INSERT OR REPLACE INTO payments SELECT * FROM payments WHERE id=1')
        self.reject('INSERT OR REPLACE INTO audit_logs SELECT * FROM audit_logs WHERE id=1')

    def test_demo_refuses_existing_business_data(self):
        with self.assertRaises(ValueError):
            manage.seed_demo(self.db)

    def test_failed_migration_rolls_back_and_checksum_tampering_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            (path / '001_first.sql').write_text('CREATE TABLE sample(id INTEGER PRIMARY KEY) STRICT;\n', encoding='utf-8')
            (path / '002_bad.sql').write_text('CREATE TABLE partial(id INTEGER);\nINVALID SQL;\n', encoding='utf-8')
            db = manage.connect(':memory:')
            try:
                with self.assertRaises(sqlite3.Error):
                    manage.migrate(db, path)
                self.assertIsNone(db.execute("SELECT name FROM sqlite_master WHERE name='partial'").fetchone())
                self.assertEqual(db.execute('SELECT COUNT(*) FROM schema_migrations').fetchone()[0], 1)
                (path / '001_first.sql').write_text('CREATE TABLE changed(id INTEGER);', encoding='utf-8')
                with self.assertRaisesRegex(ValueError, 'checksum'):
                    manage.migrate(db, path)
            finally:
                db.close()

    def test_two_connection_conflicts(self):
        for case in ('appointment', 'stock', 'payment'):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / 'race.sqlite'
                db = manage.connect(path)
                manage.migrate(db)
                manage.seed_demo(db)
                db.close()
                barrier = threading.Barrier(2)
                outcomes = []

                def worker(index):
                    conn = manage.connect(path)
                    try:
                        barrier.wait(timeout=5)
                        if case == 'appointment':
                            conn.execute("INSERT INTO appointments(code,patient_id,shift_id,starts_at,ends_at) VALUES(?,2,1,1800003600,1800005400)", (f'race{index}',))
                        elif case == 'stock':
                            conn.execute("INSERT INTO stock_movements(batch_id,quantity_delta,kind,request_key) VALUES(1,-60,'dispense',?)", (f'race{index}',))
                        else:
                            conn.execute("INSERT INTO payments(invoice_id,amount_minor,method,request_key) VALUES(1,40000,'cash',?)", (f'race{index}',))
                        outcomes.append('ok')
                    except sqlite3.IntegrityError:
                        outcomes.append('rejected')
                    except Exception as exc:
                        outcomes.append(type(exc).__name__)
                    finally:
                        conn.close()

                threads = [threading.Thread(target=worker, args=(i,)) for i in (1, 2)]
                for thread in threads:
                    thread.start()
                for thread in threads:
                    thread.join(timeout=15)
                self.assertEqual(sorted(outcomes), ['ok', 'rejected'])


if __name__ == '__main__':
    unittest.main()
