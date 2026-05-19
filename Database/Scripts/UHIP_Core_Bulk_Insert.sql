-- ============================================================
--  UHIP — Complete Data Insert Script
--  Unified Healthcare Intelligence Platform
--  Port Said Governorate, Egypt
--  Version 5.0 | May 2025
-- ============================================================
--  Run this script AFTER UHIP_Database_Script_v5.sql
--
--  Strategy (v5.0 — ALL tables use BULK INSERT):
--    All tables now load from CSV files placed in @csv_path.
--
--  Before running:
--    1. Export the following CSVs from your data source or use
--       the helper scripts to generate them from the previous
--       inline VALUES:
--         diagnoses.csv              (120 rows)
--         procedures.csv             (201 rows)
--         drugs.csv                  (175 rows)
--         hospitals.csv              (8 rows)   ← includes longitude, latitude
--         departments.csv            (138 rows)
--         doctors.csv                (523 rows)
--         beds.csv                   (~3,500 rows)
--         icu_status.csv             (976 rows)
--         drug_inventory.csv         (1,400 rows)
--         drug_transactions.csv      (2,800 rows)
--         doctor_schedules.csv       (large)
--         patients.csv               (large)
--         visits.csv                 (large)
--         medical_records.csv        (large)
--         visit_procedures.csv       (large)
--         prescriptions.csv          (large)
--         prescription_items.csv     (large)
--         referrals.csv              (9,000 rows)
--         claims.csv                 (large)
--         claim_items_fixed.csv      (large)
--         claim_approvals.csv        (large)
--         patient_feedback.csv       (22,000 rows)
--
--    2. Place all CSV files under the path below (default C:\UHIP_Data\)
--    3. Ensure the SQL Server service account has READ access to that folder
--
--  CSV files must:
--    - Have a header row (FIRSTROW = 2)
--    - Use comma delimiter and double-quote field quoting
--    - Use UTF-8 encoding
--    - Contain ONLY the data columns listed in each section below
--      (no audit columns — those use DEFAULT values)
-- ============================================================

USE uhip_db;
GO

PRINT '============================================================';
PRINT ' UHIP Data Load v5.0 — Started';
PRINT '============================================================';
GO
-- ============================================================
-- ref.diagnosis  (120 rows) — BULK INSERT | columns: diagnosis_code,diagnosis_name,diagnosis_category,severity_level
-- ============================================================
PRINT 'Bulk loading ref.diagnosis (120 rows)...';
GO

BULK INSERT ref.diagnosis
FROM 'C:\UHIP_Data\diagnoses.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'ref.diagnosis loaded.';
GO

-- ============================================================
-- ref.medical_procedure  (201 rows) — BULK INSERT | columns: procedure_code,procedure_name,procedure_category,expected_amount,complexity_score
-- ============================================================
PRINT 'Bulk loading ref.medical_procedure (201 rows)...';
GO

BULK INSERT ref.medical_procedure
FROM 'C:\UHIP_Data\procedures.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'ref.medical_procedure loaded.';
GO

-- ============================================================
-- ref.drug  (175 rows) — BULK INSERT | columns: drug_id,drug_name,generic_name,manufacturer,drug_category,unit_amount
-- ============================================================
PRINT 'Bulk loading ref.drug (175 rows)...';
GO

BULK INSERT ref.drug
FROM 'C:\UHIP_Data\drugs.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'ref.drug loaded.';
GO

-- ============================================================
-- hosp.hospital  (8 rows) — BULK INSERT | columns: hospital_id,hospital_name,hospital_type,governorate,district,address,phone,total_beds,icu_capacity,longitude,latitude,manager_name,manager_email,manager_phone
-- ============================================================
PRINT 'Bulk loading hosp.hospital (8 rows)...';
GO

BULK INSERT hosp.hospital
FROM 'C:\UHIP_Data\hospitals.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'hosp.hospital loaded.';
GO

-- ============================================================
-- hosp.department  (138 rows) — BULK INSERT | columns: department_id,hospital_id,department_name,floor_number,manager_name,manager_email,manager_phone
-- ============================================================
PRINT 'Bulk loading hosp.department (138 rows)...';
GO

BULK INSERT hosp.department
FROM 'C:\UHIP_Data\departments.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'hosp.department loaded.';
GO

-- ============================================================
-- hosp.doctor  (523 rows) — BULK INSERT | columns: doctor_id,department_id,first_name,last_name,specialty,years_experience,phone,employment_status
-- ============================================================
PRINT 'Bulk loading hosp.doctor (523 rows)...';
GO

BULK INSERT hosp.doctor
FROM 'C:\UHIP_Data\doctors.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'hosp.doctor loaded.';
GO

-- ============================================================
-- hosp.bed  (~3,500 rows) — BULK INSERT | columns: bed_id,department_id,bed_number,bed_type,bed_status
-- ============================================================
PRINT 'Bulk loading hosp.bed (~3,500 rows)...';
GO

BULK INSERT hosp.bed
FROM 'C:\UHIP_Data\beds.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'hosp.bed loaded.';
GO

-- ============================================================
-- hosp.icu_status  (976 rows) — BULK INSERT | columns: icu_status_id,hospital_id,occupied_beds,available_beds,update_time
-- ============================================================
PRINT 'Bulk loading hosp.icu_status (976 rows)...';
GO

BULK INSERT hosp.icu_status
FROM 'C:\UHIP_Data\icu_status.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'hosp.icu_status loaded.';
GO

-- ============================================================
-- inv.drug_inventory  (1,400 rows) — BULK INSERT | columns: inventory_id,hospital_id,drug_id,quantity_available,reorder_level,expiration_date
-- ============================================================
PRINT 'Bulk loading inv.drug_inventory (1,400 rows)...';
GO

BULK INSERT inv.drug_inventory
FROM 'C:\UHIP_Data\drug_inventory.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'inv.drug_inventory loaded.';
GO

-- ============================================================
-- inv.drug_transaction  (2,800 rows) — BULK INSERT | columns: transaction_id,drug_id,hospital_id,transaction_type,quantity,transaction_date,performed_by
-- ============================================================
PRINT 'Bulk loading inv.drug_transaction (2,800 rows)...';
GO

BULK INSERT inv.drug_transaction
FROM 'C:\UHIP_Data\drug_transactions.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'inv.drug_transaction loaded.';
GO

-- ============================================================
-- hosp.doctor_schedule  (large rows) — BULK INSERT | columns: schedule_id,doctor_id,shift_date,shift_start,shift_end
-- ============================================================
PRINT 'Bulk loading hosp.doctor_schedule (large rows)...';
GO

BULK INSERT hosp.doctor_schedule
FROM 'C:\UHIP_Data\doctor_schedules.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'hosp.doctor_schedule loaded.';
GO

-- ============================================================
-- pat.patient  (large rows) — BULK INSERT | columns: patient_id,national_id,first_name,last_name,gender,birth_date,phone,street,city,governorate,blood_type,emergency_contact
-- ============================================================
PRINT 'Bulk loading pat.patient (large rows)...';
GO

BULK INSERT pat.patient
FROM 'C:\UHIP_Data\patients.txt'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = '\t',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001',
    TABLOCK
);
GO

PRINT 'pat.patient loaded.';
GO

-- ============================================================
-- clin.visit  (large rows) — BULK INSERT | columns: visit_id,patient_id,hospital_id,doctor_id,department_id,diagnosis_code,visit_date,visit_type,visit_status,waiting_time,total_amount,symptoms
-- ============================================================
PRINT 'Bulk loading clin.visit (large rows)...';
GO

BULK INSERT clin.visit
FROM 'C:\UHIP_Data\visits.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'clin.visit loaded.';
GO

-- ============================================================
-- clin.medical_record  (large rows) — BULK INSERT | columns: record_id,visit_id,patient_id,doctor_id,treatment_notes,follow_up_date,follow_up_required
-- ============================================================
PRINT 'Bulk loading clin.medical_record (large rows)...';
GO

BULK INSERT clin.medical_record
FROM 'C:\UHIP_Data\medical_records.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'clin.medical_record loaded.';
GO

-- ============================================================
-- clin.visit_procedure  (large rows) — BULK INSERT | columns: visit_procedure_id,visit_id,procedure_code,performed_date,notes
-- ============================================================
PRINT 'Bulk loading clin.visit_procedure (large rows)...';
GO

BULK INSERT clin.visit_procedure
FROM 'C:\UHIP_Data\visit_procedures.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'clin.visit_procedure loaded.';
GO

-- ============================================================
-- clin.prescription  (large rows) — BULK INSERT | columns: prescription_id,visit_id,patient_id,doctor_id,prescription_date,notes
-- ============================================================
PRINT 'Bulk loading clin.prescription (large rows)...';
GO

BULK INSERT clin.prescription
FROM 'C:\UHIP_Data\prescriptions.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'clin.prescription loaded.';
GO

-- ============================================================
-- clin.prescription_item  (647,752 rows) — BULK INSERT | columns: prescription_item_id,prescription_id,drug_id,dosage,frequency,duration_days,quantity
-- ============================================================
PRINT 'Bulk loading clin.prescription_item (647,752 rows)...';
GO

BULK INSERT clin.prescription_item
FROM 'C:\UHIP_Data\prescription_items.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'clin.prescription_item loaded.';
GO

-- ============================================================
-- hosp.referral  (9,000 rows) — BULK INSERT | columns: referral_id,patient_id,from_hospital_id,to_hospital_id,referral_reason,referral_date,referral_status
-- ============================================================
PRINT 'Bulk loading hosp.referral (9,000 rows)...';
GO

BULK INSERT hosp.referral
FROM 'C:\UHIP_Data\referrals.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'hosp.referral loaded.';
GO

-- ============================================================
-- fin.claim  (273,254 rows) — BULK INSERT | columns: claim_id,patient_id,visit_id,hospital_id,claim_date,claim_amount,approved_amount,claim_status
-- ============================================================
PRINT 'Bulk loading fin.claim (273,254 rows)...';
GO

BULK INSERT fin.claim
FROM 'C:\UHIP_Data\claims.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'fin.claim loaded.';
GO

-- ============================================================
-- fin.claim_item  (974,322 rows) — BULK INSERT | columns: claim_item_id,claim_id,procedure_code,drug_id,item_amount,quantity
-- ============================================================
PRINT 'Bulk loading fin.claim_item (974,322 rows)...';
GO

BULK INSERT fin.claim_item
FROM 'C:\UHIP_Data\claim_items.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'fin.claim_item loaded.';
GO

-- ============================================================
-- fin.claim_approval  (273,254 rows) — BULK INSERT | columns: approval_id,claim_id,reviewed_by,approval_status,approval_date,rejection_reason
-- ============================================================
PRINT 'Bulk loading fin.claim_approval (273,254 rows)...';
GO

BULK INSERT fin.claim_approval
FROM 'C:\UHIP_Data\claim_approvals.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'fin.claim_approval loaded.';
GO

-- ============================================================
-- svc.patient_feedback  (22,000 rows) — BULK INSERT | columns: feedback_id,patient_id,hospital_id,doctor_id,rating,comments,feedback_date
-- ============================================================
PRINT 'Bulk loading svc.patient_feedback (22,000 rows)...';
GO

BULK INSERT svc.patient_feedback
FROM 'C:\UHIP_Data\patient_feedback.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = 'UTF-8',
    FORMAT          = 'CSV',
    FIELDQUOTE      = '"',
    TABLOCK
);
GO

PRINT 'svc.patient_feedback loaded.';
GO

-- ============================================================
--  CSV COLUMN ALIGNMENT NOTES
--  CSV files must contain EXACTLY the data columns listed above.
--  Audit columns (created_at, created_by, updated_at, updated_by,
--  is_deleted, deleted_at) are NOT included — they use DEFAULT values.
--
--  If you hit "Bulk load data conversion error" on fin.claim_item, run:
--
--    ALTER TABLE fin.claim_item NOCHECK CONSTRAINT
--      chk_claim_item_procedure_or_drug;
--    -- (run BULK INSERT for fin.claim_item)
--    ALTER TABLE fin.claim_item CHECK CONSTRAINT
--      chk_claim_item_procedure_or_drug;
-- ============================================================


-- ============================================================
--  VERIFICATION — row counts per table after load
-- ============================================================
PRINT '============================================================';
PRINT ' Verification row counts:';
PRINT '============================================================';
GO

SELECT
    s.name + '.' + t.name   AS full_table_name,
    p.rows                   AS row_count
FROM      sys.tables     t
JOIN      sys.schemas    s  ON t.schema_id = s.schema_id
JOIN      sys.partitions p  ON t.object_id = p.object_id
WHERE     p.index_id IN (0, 1)
ORDER BY  s.name, t.name;
GO

PRINT '============================================================';
PRINT ' UHIP data load v5.0 complete — all tables via BULK INSERT.';
PRINT '============================================================';
GO
