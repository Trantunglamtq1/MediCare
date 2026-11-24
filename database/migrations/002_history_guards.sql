-- Close parent-update paths that could change the meaning of retained history.
CREATE TRIGGER invoice_line_move_limit BEFORE UPDATE OF invoice_id ON invoice_items
WHEN NEW.invoice_id!=OLD.invoice_id
BEGIN
    SELECT RAISE(ABORT,'invoice line limit exceeded')
    WHERE (SELECT COUNT(*) FROM invoice_items WHERE invoice_id=NEW.invoice_id)>=1000;
END;

CREATE TRIGGER doctor_account_frozen BEFORE UPDATE OF user_id ON doctors
WHEN NEW.user_id!=OLD.user_id
BEGIN
    SELECT RAISE(ABORT,'assigned doctor account is frozen')
    WHERE EXISTS(SELECT 1 FROM doctor_clinics WHERE doctor_id=OLD.id);
END;

CREATE TRIGGER prescription_origin_frozen BEFORE UPDATE OF encounter_id,patient_id ON prescriptions
WHEN NEW.encounter_id!=OLD.encounter_id OR NEW.patient_id!=OLD.patient_id
BEGIN
    SELECT RAISE(ABORT,'prescription origin is frozen');
END;

CREATE TRIGGER dispensed_item_identity_frozen BEFORE UPDATE OF prescription_id,patient_id,medication_id ON prescription_items
WHEN NEW.prescription_id!=OLD.prescription_id OR NEW.patient_id!=OLD.patient_id OR NEW.medication_id!=OLD.medication_id
BEGIN
    SELECT RAISE(ABORT,'dispensed prescription item identity is frozen')
    WHERE EXISTS(SELECT 1 FROM stock_movements WHERE prescription_item_id=OLD.id);
END;

CREATE TRIGGER medication_stock_unit_frozen BEFORE UPDATE OF stock_unit ON medications
WHEN NEW.stock_unit!=OLD.stock_unit
BEGIN
    SELECT RAISE(ABORT,'referenced medication stock unit is frozen')
    WHERE EXISTS(SELECT 1 FROM medication_batches WHERE medication_id=OLD.id)
       OR EXISTS(SELECT 1 FROM personal_medications WHERE medication_id=OLD.id)
       OR EXISTS(SELECT 1 FROM prescription_items WHERE medication_id=OLD.id);
END;
