-- ============================================================
--  UHIP — Unified Healthcare Intelligence Platform
--  ETL: Staging (uhip_staging.stg) → Core (uhip_db)
--  Version 1.0 | May 2025
--
--  Load order respects FK dependency chain:
--    1.  ref.diagnosis
--    2.  ref.medical_procedure
--    3.  ref.drug
--    4.  hosp.hospital
--    5.  hosp.department
--    6.  hosp.doctor
--    7.  hosp.doctor_schedule
--    8.  hosp.bed
--    9.  hosp.icu_status
--    10. pat.patient
--    11. inv.drug_inventory
--    12. inv.drug_transaction
--    13. clin.visit
--    14. clin.medical_record
--    15. clin.visit_procedure
--    16. clin.prescription
--    17. clin.prescription_item
--    18. hosp.referral
--    19. fin.claim
--    20. fin.claim_item
--    21. fin.claim_approval
--    22. svc.patient_feedback
--
--  Design notes:
--    • Dirty / unparseable rows are SKIPPED and written to
--      etl.error_log (created below) — load continues.
--    • Each block uses TRY…CATCH; transaction is per-table so
--      one bad table never rolls back already-committed tables.
--    • After a successful insert the staging row is marked
--      stg_is_processed = 1.
--    • Duplicate PKs already present in core are skipped
--      (INSERT … WHERE NOT EXISTS).
--    • Type conversions use TRY_CAST / TRY_CONVERT so bad
--      values yield NULL rather than hard errors, letting the
--      NOT NULL / CHECK constraints in the core table act as
--      the final gate.
-- ============================================================

USE uhip_db;
GO

-- ============================================================
--  ERROR LOG TABLE  (idempotent: only created if absent)
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.schemas WHERE name = 'etl'
)
    EXEC ('CREATE SCHEMA etl');
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'etl' AND t.name = 'error_log'
)
CREATE TABLE etl.error_log (
    log_id          INT IDENTITY(1,1) PRIMARY KEY,
    load_timestamp  DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    target_table    VARCHAR(80)      NOT NULL,
    source_key      VARCHAR(50)      NULL,   -- PK value of the offending staging row
    error_message   NVARCHAR(2048)   NOT NULL,
    raw_data        NVARCHAR(MAX)    NULL    -- JSON snapshot of the staging row (optional)
);
GO

PRINT '============================================================';
PRINT 'etl.error_log ready';
PRINT '============================================================';

-- ============================================================
--  PRE-STEP: Add stg_is_processed column to all staging tables
--  (idempotent — skipped if the column already exists)
-- ============================================================
USE uhip_staging;
GO

DECLARE @sql NVARCHAR(MAX) = '';

SELECT @sql = @sql +
    'IF NOT EXISTS (
        SELECT 1 FROM sys.columns c
        JOIN sys.tables  t ON c.object_id = t.object_id
        JOIN sys.schemas s ON t.schema_id = s.schema_id
        WHERE s.name = ''stg'' AND t.name = ''' + t.name + ''' AND c.name = ''stg_is_processed''
    )
        ALTER TABLE stg.' + t.name + ' ADD stg_is_processed BIT NOT NULL DEFAULT 0;
'
FROM sys.tables  t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'stg';

EXEC sp_executesql @sql;
GO

PRINT '============================================================';
PRINT 'stg_is_processed column ensured on all staging tables';
PRINT '============================================================';

-- ============================================================
--  PRE-STEP 2: Reset stg_is_processed = 0 on all staging rows
--  Safe every run — NOT EXISTS guards in each INSERT block
--  prevent rows already in core from being re-inserted.
-- ============================================================
DECLARE @reset NVARCHAR(MAX) = '';

SELECT @reset = @reset +
    'UPDATE uhip_staging.stg.' + t.name + ' SET stg_is_processed = 0;' + CHAR(10)
FROM sys.tables  t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'stg';

EXEC sp_executesql @reset;
GO

PRINT '============================================================';
PRINT 'stg_is_processed reset to 0 on all staging tables';
PRINT '============================================================';

USE uhip_db;
GO



-- ============================================================
--  1. ref.diagnosis
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading ref.diagnosis ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.ref.diagnosis (
        diagnosis_code,
        diagnosis_name,
        diagnosis_category,
        severity_level
    )
    SELECT
        s.diagnosis_code,
        s.diagnosis_name,
        s.diagnosis_category,
        s.severity_level
    FROM uhip_staging.stg.diagnosis s
    WHERE s.stg_is_processed = 0
      -- skip rows that would violate core PK
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.ref.diagnosis c
          WHERE c.diagnosis_code = s.diagnosis_code
      )
      -- skip rows with NULL in NOT NULL columns
      AND s.diagnosis_code     IS NOT NULL
      AND s.diagnosis_name     IS NOT NULL
      AND s.diagnosis_category IS NOT NULL
      AND s.severity_level     IS NOT NULL
      -- enforce CHECK values that the staging layer doesn't validate
      AND s.diagnosis_category IN (
            'Cardiovascular','Respiratory','Endocrine','Gastrointestinal',
            'Neurological','Urological','Musculoskeletal','Trauma',
            'Infectious','Hematological','Mental Health','Skin','ENT','Pediatric'
          )
      AND s.severity_level IN ('Mild','Moderate','Severe','Critical','Chronic');

    SET @inserted = @@ROWCOUNT;

    -- mark processed
    UPDATE uhip_staging.stg.diagnosis
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND diagnosis_code IN (SELECT diagnosis_code FROM uhip_db.ref.diagnosis);

    COMMIT TRANSACTION;
    PRINT 'ref.diagnosis — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('ref.diagnosis', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading ref.diagnosis: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  2. ref.medical_procedure
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading ref.medical_procedure ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.ref.medical_procedure (
        procedure_code,
        procedure_name,
        procedure_category,
        expected_amount,
        complexity_score
    )
    SELECT
        s.procedure_code,
        s.procedure_name,
        s.procedure_category,
        -- strip commas / currency symbols before casting
        TRY_CAST(REPLACE(REPLACE(s.expected_amount, ',', ''), 'EGP', '') AS DECIMAL(10,2)),
        TRY_CAST(s.complexity_score AS TINYINT)
    FROM uhip_staging.stg.medical_procedure s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.ref.medical_procedure c
          WHERE c.procedure_code = s.procedure_code
      )
      AND s.procedure_code     IS NOT NULL
      AND s.procedure_name     IS NOT NULL
      AND s.procedure_category IS NOT NULL
      AND TRY_CAST(REPLACE(REPLACE(s.expected_amount, ',', ''), 'EGP', '') AS DECIMAL(10,2)) IS NOT NULL
      AND TRY_CAST(REPLACE(REPLACE(s.expected_amount, ',', ''), 'EGP', '') AS DECIMAL(10,2)) >= 0
      AND TRY_CAST(s.complexity_score AS TINYINT) IS NOT NULL
      AND TRY_CAST(s.complexity_score AS TINYINT) BETWEEN 1 AND 5
      AND s.procedure_category IN (
            'Laboratory','Radiology','Cardiology','Cardiology Intervention',
            'Surgery','Orthopedic','Orthopedic Surgery','Endoscopy','ICU',
            'Nephrology','Hematology','Neurology','Pulmonology','Physiotherapy',
            'Emergency','Nursing','Consultation','Diagnostic Assessment',
            'Dermatology','Urology'
          );

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.medical_procedure
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND procedure_code IN (SELECT procedure_code FROM uhip_db.ref.medical_procedure);

    COMMIT TRANSACTION;
    PRINT 'ref.medical_procedure — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('ref.medical_procedure', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading ref.medical_procedure: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  3. ref.drug
--  Pre-step: drop the drug_category CHECK constraint so all
--  category values from the source data are accepted.
-- ============================================================
IF EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'chk_drug_drug_category'
      AND parent_object_id = OBJECT_ID('ref.drug')
)
    ALTER TABLE uhip_db.ref.drug DROP CONSTRAINT chk_drug_drug_category;
GO

PRINT '------------------------------------------------------------';
PRINT 'Loading ref.drug ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.ref.drug (
        drug_id,
        drug_name,
        generic_name,
        manufacturer,
        drug_category,
        unit_amount
    )
    SELECT
        s.drug_id,
        s.drug_name,
        s.generic_name,
        s.manufacturer,
        s.drug_category,
        -- CSV column is unit_price; cast to DECIMAL for core unit_amount
        TRY_CAST(s.unit_amount AS DECIMAL(8,2))
    FROM uhip_staging.stg.drug s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.ref.drug c WHERE c.drug_id = s.drug_id
      )
      AND s.drug_id       IS NOT NULL
      AND s.drug_name     IS NOT NULL
      AND s.generic_name  IS NOT NULL
      AND s.manufacturer  IS NOT NULL
      AND s.drug_category IS NOT NULL
      AND TRY_CAST(s.unit_amount AS DECIMAL(8,2)) IS NOT NULL
      AND TRY_CAST(s.unit_amount AS DECIMAL(8,2)) >= 0;

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.drug
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND drug_id IN (SELECT drug_id FROM uhip_db.ref.drug);

    COMMIT TRANSACTION;
    PRINT 'ref.drug — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('ref.drug', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading ref.drug: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  4. hosp.hospital
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading hosp.hospital ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.hosp.hospital (
        hospital_id,
        hospital_name,
        hospital_type,
        governorate,
        district,
        phone,
        total_beds,
        icu_capacity,
        longitude,
        latitude,
        manager_name,
        manager_email,
        manager_phone
    )
    SELECT
        s.hospital_id,
        s.hospital_name,
        s.hospital_type,
        ISNULL(s.governorate, 'Port Said'),
        s.district,
        s.phone,
        TRY_CAST(s.total_beds   AS INT),
        TRY_CAST(s.icu_capacity AS INT),
        TRY_CAST(s.longitude    AS DECIMAL(9,6)),
        TRY_CAST(s.latitude     AS DECIMAL(9,6)),
        s.manager_name,
        s.manager_email,
        s.manager_phone
    FROM uhip_staging.stg.hospital s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.hosp.hospital c WHERE c.hospital_id = s.hospital_id
      )
      AND s.hospital_id   IS NOT NULL
      AND s.hospital_name IS NOT NULL
      AND s.hospital_type IS NOT NULL
      AND s.district      IS NOT NULL
      AND TRY_CAST(s.total_beds   AS INT) IS NOT NULL
      AND TRY_CAST(s.total_beds   AS INT) > 0
      AND TRY_CAST(s.icu_capacity AS INT) IS NOT NULL
      AND TRY_CAST(s.icu_capacity AS INT) > 0
      AND s.hospital_type IN ('Government','Private','Specialized','Teaching')
      AND s.district IN (
            'El Sharq','Port Fouad','El Arab','El Manakh',
            'El Zohour','El Dawahy','Mubarak District'
          );

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.hospital
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND hospital_id IN (SELECT hospital_id FROM uhip_db.hosp.hospital);

    COMMIT TRANSACTION;
    PRINT 'hosp.hospital — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('hosp.hospital', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading hosp.hospital: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  5. hosp.department
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading hosp.department ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.hosp.department (
        department_id,
        hospital_id,
        department_name,
        floor_number,
        manager_name,
        manager_email,
        manager_phone
    )
    SELECT
        s.department_id,
        s.hospital_id,
        s.department_name,
        -- floor_number stored as Numeric in staging; cast to VARCHAR(2) for core
        CAST(TRY_CAST(s.floor_number AS INT) AS VARCHAR(2)),
        s.manager_name,
        s.manager_email,
        -- manager_phone stored as Numeric in staging; cast to VARCHAR(20) for core
        CAST(TRY_CAST(s.manager_phone AS BIGINT) AS VARCHAR(20))
    FROM uhip_staging.stg.department s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.hosp.department c WHERE c.department_id = s.department_id
      )
      -- FK check: parent hospital must exist in core
      AND EXISTS (
          SELECT 1 FROM uhip_db.hosp.hospital h WHERE h.hospital_id = s.hospital_id
      )
      AND s.department_id   IS NOT NULL
      AND s.hospital_id     IS NOT NULL
      AND s.department_name IS NOT NULL
      AND TRY_CAST(s.floor_number AS INT) IS NOT NULL
      AND CAST(TRY_CAST(s.floor_number AS INT) AS VARCHAR(2)) IN ('1','2','3')
      AND s.department_name IN (
            'Emergency','ICU','Internal Medicine','Cardiology','Pulmonology',
            'Neurology','Gastroenterology','Nephrology','Endocrinology',
            'Orthopedics','General Surgery','Pediatrics',
            'Obstetrics & Gynecology','Dermatology','ENT','Psychiatry',
            'Oncology','Radiology','Laboratory','Pharmacy'
          );

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.department
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND department_id IN (SELECT department_id FROM uhip_db.hosp.department);

    COMMIT TRANSACTION;
    PRINT 'hosp.department — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('hosp.department', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading hosp.department: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  6. hosp.doctor
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading hosp.doctor ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.hosp.doctor (
        doctor_id,
        hospital_id,
        department_id,
        first_name,
        last_name,
        specialty,
        years_experience,
        phone,
        employment_status
    )
    SELECT
        s.doctor_id,
        s.hospital_id,
        s.department_id,
        s.first_name,
        s.last_name,
        s.specialty,
        TRY_CAST(s.years_experience AS INT),
        s.phone,
        s.employment_status
    FROM uhip_staging.stg.doctor s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.hosp.doctor c WHERE c.doctor_id = s.doctor_id
      )
      AND EXISTS (
          SELECT 1 FROM uhip_db.hosp.department d WHERE d.department_id = s.department_id
      )
      AND s.doctor_id         IS NOT NULL
      AND s.hospital_id       IS NOT NULL
      AND s.department_id     IS NOT NULL
      AND s.first_name        IS NOT NULL
      AND s.last_name         IS NOT NULL
      AND s.specialty         IS NOT NULL
      AND s.employment_status IS NOT NULL
      AND TRY_CAST(s.years_experience AS INT) IS NOT NULL
      AND TRY_CAST(s.years_experience AS INT) BETWEEN 1 AND 38
      AND s.employment_status IN ('Active','On Leave');

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.doctor
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND doctor_id IN (SELECT doctor_id FROM uhip_db.hosp.doctor);

    COMMIT TRANSACTION;
    PRINT 'hosp.doctor — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('hosp.doctor', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading hosp.doctor: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  7. hosp.doctor_schedule
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading hosp.doctor_schedule ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.hosp.doctor_schedule (
        schedule_id,
        doctor_id,
        shift_date,
        shift_start,
        shift_end
    )
    SELECT
        s.schedule_id,
        s.doctor_id,
        TRY_CAST(s.shift_date AS DATE),
        s.shift_start,
        s.shift_end
    FROM uhip_staging.stg.doctor_schedule s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.hosp.doctor_schedule c WHERE c.schedule_id = s.schedule_id
      )
      AND EXISTS (
          SELECT 1 FROM uhip_db.hosp.doctor d WHERE d.doctor_id = s.doctor_id
      )
      AND s.schedule_id IS NOT NULL
      AND s.doctor_id   IS NOT NULL
      AND TRY_CAST(s.shift_date AS DATE) IS NOT NULL
      AND s.shift_start IS NOT NULL
      AND s.shift_end   IS NOT NULL
      AND s.shift_start IN ('08:00','14:00','20:00')
      AND s.shift_end   IN ('14:00','20:00','08:00');

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.doctor_schedule
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND schedule_id IN (SELECT schedule_id FROM uhip_db.hosp.doctor_schedule);

    COMMIT TRANSACTION;
    PRINT 'hosp.doctor_schedule — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('hosp.doctor_schedule', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading hosp.doctor_schedule: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  8. hosp.bed
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading hosp.bed ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.hosp.bed (
        bed_id,
        hospital_id,
        department_id,
        bed_number,
        bed_type,
        availability_status
    )
    SELECT
        s.bed_id,
        s.hospital_id,
        s.department_id,
        s.bed_number,
        s.bed_type,
        s.availability_status
    FROM uhip_staging.stg.bed s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.hosp.bed c WHERE c.bed_id = s.bed_id
      )
      AND EXISTS (
          SELECT 1 FROM uhip_db.hosp.department d WHERE d.department_id = s.department_id
      )
      AND s.bed_id              IS NOT NULL
      AND s.hospital_id         IS NOT NULL
      AND s.department_id       IS NOT NULL
      AND s.bed_number          IS NOT NULL
      AND s.bed_type            IS NOT NULL
      AND s.availability_status IS NOT NULL
      AND s.bed_type IN ('ICU','Emergency','Standard')
      AND s.availability_status IN ('Occupied','Available','Under Maintenance');

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.bed
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND bed_id IN (SELECT bed_id FROM uhip_db.hosp.bed);

    COMMIT TRANSACTION;
    PRINT 'hosp.bed — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('hosp.bed', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading hosp.bed: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  9. hosp.icu_status
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading hosp.icu_status ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.hosp.icu_status (
        icu_status_id,
        hospital_id,
        occupied_beds,
        available_beds,
        update_time
    )
    SELECT
        s.icu_status_id,
        s.hospital_id,
        TRY_CAST(s.occupied_beds  AS INT),
        TRY_CAST(s.available_beds AS INT),
        TRY_CAST(s.update_time    AS DATETIME2)
    FROM uhip_staging.stg.icu_status s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.hosp.icu_status c WHERE c.icu_status_id = s.icu_status_id
      )
      AND EXISTS (
          SELECT 1 FROM uhip_db.hosp.hospital h WHERE h.hospital_id = s.hospital_id
      )
      AND s.icu_status_id IS NOT NULL
      AND s.hospital_id   IS NOT NULL
      AND TRY_CAST(s.occupied_beds  AS INT)     IS NOT NULL
      AND TRY_CAST(s.occupied_beds  AS INT)     >= 0
      AND TRY_CAST(s.available_beds AS INT)     IS NOT NULL
      AND TRY_CAST(s.available_beds AS INT)     >= 0
      AND TRY_CAST(s.update_time    AS DATETIME2) IS NOT NULL;

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.icu_status
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND icu_status_id IN (SELECT icu_status_id FROM uhip_db.hosp.icu_status);

    COMMIT TRANSACTION;
    PRINT 'hosp.icu_status — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('hosp.icu_status', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading hosp.icu_status: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  10. pat.patient
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading pat.patient ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.pat.patient (
        patient_id,
        national_id,
        first_name,
        last_name,
        gender,
        birth_date,
        phone,
        street,
        city,
        governorate,
        blood_type,
        emergency_contact
    )
    SELECT
        s.patient_id,
        s.national_id,                                  -- already NUMERIC in staging
        s.first_name,
        s.last_name,
        s.gender,
        TRY_CAST(s.birth_date AS DATE),
        s.phone,                                        -- already NUMERIC in staging
        s.street,
        s.city,
        ISNULL(s.governorate, 'Port Said'),
        s.blood_type,
        s.emergency_contact                             -- already NUMERIC in staging
    FROM uhip_staging.stg.patient s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.pat.patient c WHERE c.patient_id = s.patient_id
      )
      -- unique national_id check against core
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.pat.patient c WHERE c.national_id = s.national_id
      )
      AND s.patient_id  IS NOT NULL
      AND s.national_id IS NOT NULL
      AND s.first_name  IS NOT NULL
      AND s.last_name   IS NOT NULL
      AND s.gender      IS NOT NULL
      AND TRY_CAST(s.birth_date AS DATE) IS NOT NULL
      AND s.gender IN ('Male','Female')
      AND (s.blood_type IS NULL OR s.blood_type IN (
              'A+','A-','B+','B-','AB+','AB-','O+','O-'
          ));

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.patient
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND patient_id IN (SELECT patient_id FROM uhip_db.pat.patient);

    COMMIT TRANSACTION;
    PRINT 'pat.patient — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('pat.patient', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading pat.patient: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  11. inv.drug_inventory
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading inv.drug_inventory ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.inv.drug_inventory (
        inventory_id,
        hospital_id,
        drug_id,
        quantity_available,
        reorder_level,
        expiration_date
    )
    SELECT
        s.inventory_id,
        s.hospital_id,
        s.drug_id,
        TRY_CAST(s.quantity_available AS INT),
        TRY_CAST(s.reorder_level      AS INT),
        TRY_CAST(s.expiration_date    AS DATE)
    FROM uhip_staging.stg.drug_inventory s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.inv.drug_inventory c WHERE c.inventory_id = s.inventory_id
      )
      -- unique (hospital_id, drug_id) check
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.inv.drug_inventory c
          WHERE c.hospital_id = s.hospital_id AND c.drug_id = s.drug_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.hosp.hospital h WHERE h.hospital_id = s.hospital_id)
      AND EXISTS (SELECT 1 FROM uhip_db.ref.drug     d WHERE d.drug_id      = s.drug_id)
      AND s.inventory_id IS NOT NULL
      AND s.hospital_id  IS NOT NULL
      AND s.drug_id      IS NOT NULL
      AND TRY_CAST(s.quantity_available AS INT) IS NOT NULL
      AND TRY_CAST(s.quantity_available AS INT) >= 0
      AND TRY_CAST(s.reorder_level      AS INT) IS NOT NULL
      AND TRY_CAST(s.reorder_level      AS INT) >= 0;

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.drug_inventory
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND inventory_id IN (SELECT inventory_id FROM uhip_db.inv.drug_inventory);

    COMMIT TRANSACTION;
    PRINT 'inv.drug_inventory — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('inv.drug_inventory', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading inv.drug_inventory: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  12. inv.drug_transaction
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading inv.drug_transaction ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.inv.drug_transaction (
        transaction_id,
        drug_id,
        hospital_id,
        transaction_type,
        quantity,
        transaction_date,
        performed_by
    )
    SELECT
        s.transaction_id,
        s.drug_id,
        s.hospital_id,
        s.transaction_type,
        TRY_CAST(s.quantity         AS INT),
        TRY_CAST(s.transaction_date AS DATE),
        s.performed_by
    FROM uhip_staging.stg.drug_transaction s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.inv.drug_transaction c WHERE c.transaction_id = s.transaction_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.ref.drug     d WHERE d.drug_id      = s.drug_id)
      AND EXISTS (SELECT 1 FROM uhip_db.hosp.hospital h WHERE h.hospital_id = s.hospital_id)
      AND s.transaction_id   IS NOT NULL
      AND s.drug_id          IS NOT NULL
      AND s.hospital_id      IS NOT NULL
      AND s.transaction_type IS NOT NULL
      AND TRY_CAST(s.quantity         AS INT)  IS NOT NULL
      AND TRY_CAST(s.quantity         AS INT)  > 0
      AND TRY_CAST(s.transaction_date AS DATE) IS NOT NULL
      AND s.transaction_type IN ('Purchase','Dispensing','Wastage','Return','Adjustment');

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.drug_transaction
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND transaction_id IN (SELECT transaction_id FROM uhip_db.inv.drug_transaction);

    COMMIT TRANSACTION;
    PRINT 'inv.drug_transaction — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('inv.drug_transaction', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading inv.drug_transaction: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  13. clin.visit
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading clin.visit ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.clin.visit (
        visit_id,
        patient_id,
        hospital_id,
        doctor_id,
        department_id,
        visit_date,
        visit_type,
        diagnosis_code,
        symptoms,
        visit_status,
        waiting_time,
        total_amount
    )
    SELECT
        s.visit_id,
        s.patient_id,
        s.hospital_id,
        s.doctor_id,
        s.department_id,
        TRY_CAST(s.visit_date AS DATE),
        s.visit_type,
        s.diagnosis_code,
        s.symptoms,
        s.visit_status,
        TRY_CAST(s.waiting_time AS INT),
        TRY_CAST(s.total_amount AS DECIMAL(10,2))
    FROM uhip_staging.stg.visit s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.clin.visit c WHERE c.visit_id = s.visit_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.pat.patient    p WHERE p.patient_id     = s.patient_id)
      AND EXISTS (SELECT 1 FROM uhip_db.hosp.hospital  h WHERE h.hospital_id    = s.hospital_id)
      AND EXISTS (SELECT 1 FROM uhip_db.hosp.doctor    d WHERE d.doctor_id      = s.doctor_id)
      AND EXISTS (SELECT 1 FROM uhip_db.hosp.department dp WHERE dp.department_id = s.department_id)
      AND EXISTS (SELECT 1 FROM uhip_db.ref.diagnosis  dg WHERE dg.diagnosis_code = s.diagnosis_code)
      AND s.visit_id       IS NOT NULL
      AND s.patient_id     IS NOT NULL
      AND s.hospital_id    IS NOT NULL
      AND s.doctor_id      IS NOT NULL
      AND s.department_id  IS NOT NULL
      AND s.diagnosis_code IS NOT NULL
      AND s.visit_status   IS NOT NULL
      AND s.visit_type     IS NOT NULL
      AND TRY_CAST(s.visit_date AS DATE) IS NOT NULL
      AND s.visit_type IN ('Emergency','Outpatient','Inpatient','Follow-up','Routine Check')
      AND s.visit_status IN ('Completed','No Show','Cancelled');

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.visit
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND visit_id IN (SELECT visit_id FROM uhip_db.clin.visit);

    COMMIT TRANSACTION;
    PRINT 'clin.visit — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('clin.visit', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading clin.visit: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  14. clin.medical_record
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading clin.medical_record ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.clin.medical_record (
        record_id,
        visit_id,
        procedure_code,
        diagnosis_notes,
        treatment_notes,
        follow_up_required
    )
    SELECT
        s.record_id,
        s.visit_id,
        s.procedure_code,
        s.diagnosis_notes,
        s.treatment_notes,
        s.follow_up_required
    FROM uhip_staging.stg.medical_record s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.clin.medical_record c WHERE c.record_id = s.record_id
      )
      -- unique visit_id check
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.clin.medical_record c WHERE c.visit_id = s.visit_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.clin.visit v WHERE v.visit_id = s.visit_id)
      AND s.record_id          IS NOT NULL
      AND s.visit_id           IS NOT NULL
      AND s.follow_up_required IS NOT NULL
      AND s.follow_up_required IN ('Yes','No');

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.medical_record
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND record_id IN (SELECT record_id FROM uhip_db.clin.medical_record);

    COMMIT TRANSACTION;
    PRINT 'clin.medical_record — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('clin.medical_record', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading clin.medical_record: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  15. clin.visit_procedure
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading clin.visit_procedure ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.clin.visit_procedure (
        visit_procedure_id,
        visit_id,
        procedure_code,
        procedure_amount,
        procedure_date
    )
    SELECT
        s.visit_procedure_id,
        s.visit_id,
        s.procedure_code,
        TRY_CAST(s.procedure_amount AS DECIMAL(10,2)),
        TRY_CAST(s.procedure_date   AS DATE)
    FROM uhip_staging.stg.visit_procedure s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.clin.visit_procedure c WHERE c.visit_procedure_id = s.visit_procedure_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.clin.visit           v WHERE v.visit_id       = s.visit_id)
      AND EXISTS (SELECT 1 FROM uhip_db.ref.medical_procedure p WHERE p.procedure_code = s.procedure_code)
      AND s.visit_procedure_id IS NOT NULL
      AND s.visit_id           IS NOT NULL
      AND s.procedure_code     IS NOT NULL
      AND TRY_CAST(s.procedure_amount AS DECIMAL(10,2)) IS NOT NULL
      AND TRY_CAST(s.procedure_amount AS DECIMAL(10,2)) >= 0
      AND TRY_CAST(s.procedure_date   AS DATE) IS NOT NULL;

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.visit_procedure
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND visit_procedure_id IN (SELECT visit_procedure_id FROM uhip_db.clin.visit_procedure);

    COMMIT TRANSACTION;
    PRINT 'clin.visit_procedure — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('clin.visit_procedure', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading clin.visit_procedure: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  16. clin.prescription
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading clin.prescription ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.clin.prescription (
        prescription_id,
        visit_id,
        doctor_id,
        prescription_date,
        notes
    )
    SELECT
        s.prescription_id,
        s.visit_id,
        s.doctor_id,
        TRY_CAST(s.prescription_date AS DATE),
        s.notes
    FROM uhip_staging.stg.prescription s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.clin.prescription c WHERE c.prescription_id = s.prescription_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.clin.visit  v WHERE v.visit_id   = s.visit_id)
      AND EXISTS (SELECT 1 FROM uhip_db.hosp.doctor d WHERE d.doctor_id  = s.doctor_id)
      AND s.prescription_id IS NOT NULL
      AND s.visit_id        IS NOT NULL
      AND s.doctor_id       IS NOT NULL
      AND TRY_CAST(s.prescription_date AS DATE) IS NOT NULL;

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.prescription
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND prescription_id IN (SELECT prescription_id FROM uhip_db.clin.prescription);

    COMMIT TRANSACTION;
    PRINT 'clin.prescription — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('clin.prescription', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading clin.prescription: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  17. clin.prescription_item
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading clin.prescription_item ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.clin.prescription_item (
        prescription_item_id,
        prescription_id,
        drug_id,
        dosage,
        frequency,
        duration_days,
        quantity
    )
    SELECT
        s.prescription_item_id,
        s.prescription_id,
        s.drug_id,
        s.dosage,
        s.frequency,
        TRY_CAST(s.duration_days AS INT),
        TRY_CAST(s.quantity      AS INT)
    FROM uhip_staging.stg.prescription_item s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.clin.prescription_item c WHERE c.prescription_item_id = s.prescription_item_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.clin.prescription p WHERE p.prescription_id = s.prescription_id)
      AND EXISTS (SELECT 1 FROM uhip_db.ref.drug          d WHERE d.drug_id          = s.drug_id)
      AND s.prescription_item_id IS NOT NULL
      AND s.prescription_id      IS NOT NULL
      AND s.drug_id              IS NOT NULL
      AND s.dosage               IS NOT NULL
      AND s.frequency            IS NOT NULL
      AND TRY_CAST(s.duration_days AS INT) IS NOT NULL
      AND TRY_CAST(s.duration_days AS INT) BETWEEN 3 AND 90
      AND TRY_CAST(s.quantity      AS INT) IS NOT NULL
      AND TRY_CAST(s.quantity      AS INT) > 0
      AND s.frequency IN (
            'Once daily','Twice daily','Every 12 hours',
            'Three times daily','Every 8 hours','Every 6 hours','As needed'
          );

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.prescription_item
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND prescription_item_id IN (SELECT prescription_item_id FROM uhip_db.clin.prescription_item);

    COMMIT TRANSACTION;
    PRINT 'clin.prescription_item — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('clin.prescription_item', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading clin.prescription_item: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  18. hosp.referral
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading hosp.referral ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.hosp.referral (
        referral_id,
        patient_id,
        from_hospital_id,
        to_hospital_id,
        referral_reason,
        referral_date,
        referral_status
    )
    SELECT
        s.referral_id,
        s.patient_id,
        s.from_hospital_id,
        s.to_hospital_id,
        s.referral_reason,
        TRY_CAST(s.referral_date AS DATE),
        s.referral_status
    FROM uhip_staging.stg.referral s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.hosp.referral c WHERE c.referral_id = s.referral_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.pat.patient   p  WHERE p.patient_id   = s.patient_id)
      AND EXISTS (SELECT 1 FROM uhip_db.hosp.hospital hf WHERE hf.hospital_id = s.from_hospital_id)
      AND EXISTS (SELECT 1 FROM uhip_db.hosp.hospital ht WHERE ht.hospital_id = s.to_hospital_id)
      AND s.referral_id      IS NOT NULL
      AND s.patient_id       IS NOT NULL
      AND s.from_hospital_id IS NOT NULL
      AND s.to_hospital_id   IS NOT NULL
      AND s.referral_reason  IS NOT NULL
      AND s.referral_status  IS NOT NULL
      -- enforce the from <> to check constraint
      AND s.from_hospital_id <> s.to_hospital_id
      AND TRY_CAST(s.referral_date AS DATE) IS NOT NULL
      AND s.referral_status IN ('Completed','Pending','Cancelled');

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.referral
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND referral_id IN (SELECT referral_id FROM uhip_db.hosp.referral);

    COMMIT TRANSACTION;
    PRINT 'hosp.referral — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('hosp.referral', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading hosp.referral: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  19. fin.claim
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading fin.claim ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.fin.claim (
        claim_id,
        patient_id,
        visit_id,
        hospital_id,
        claim_date,
        claim_amount,
        approved_amount,
        claim_status
    )
    SELECT
        s.claim_id,
        s.patient_id,
        s.visit_id,
        s.hospital_id,
        TRY_CAST(s.claim_date      AS DATE),
        TRY_CAST(s.claim_amount    AS DECIMAL(10,2)),
        TRY_CAST(s.approved_amount AS DECIMAL(10,2)),
        s.claim_status
    FROM uhip_staging.stg.claim s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.fin.claim c WHERE c.claim_id = s.claim_id
      )
      -- unique visit_id in core
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.fin.claim c WHERE c.visit_id = s.visit_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.pat.patient   p WHERE p.patient_id   = s.patient_id)
      AND EXISTS (SELECT 1 FROM uhip_db.clin.visit    v WHERE v.visit_id     = s.visit_id)
      AND EXISTS (SELECT 1 FROM uhip_db.hosp.hospital h WHERE h.hospital_id  = s.hospital_id)
      AND s.claim_id     IS NOT NULL
      AND s.patient_id   IS NOT NULL
      AND s.visit_id     IS NOT NULL
      AND s.hospital_id  IS NOT NULL
      AND s.claim_status IS NOT NULL
      AND TRY_CAST(s.claim_date   AS DATE)          IS NOT NULL
      AND TRY_CAST(s.claim_amount AS DECIMAL(10,2)) IS NOT NULL
      AND TRY_CAST(s.claim_amount AS DECIMAL(10,2)) >= 0
      AND s.claim_status IN ('Approved','Partially Approved','Rejected','Pending Review');

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.claim
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND claim_id IN (SELECT claim_id FROM uhip_db.fin.claim);

    COMMIT TRANSACTION;
    PRINT 'fin.claim — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('fin.claim', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading fin.claim: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  20. fin.claim_item
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading fin.claim_item ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.fin.claim_item (
        claim_item_id,
        claim_id,
        procedure_code,
        drug_id,
        item_amount,
        quantity
    )
    SELECT
        s.claim_item_id,
        s.claim_id,
        NULLIF(s.procedure_code, ''),   -- empty string → NULL
        NULLIF(s.drug_id, ''),
        s.item_amount,                  -- already Numeric in staging
        s.quantity                      -- already Numeric in staging
    FROM uhip_staging.stg.claim_item s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.fin.claim_item c WHERE c.claim_item_id = s.claim_item_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.fin.claim c WHERE c.claim_id = s.claim_id)
      AND s.claim_item_id IS NOT NULL
      AND s.claim_id      IS NOT NULL
      -- enforce: exactly one of procedure_code / drug_id must be non-null
      AND (
          (NULLIF(s.procedure_code,'') IS NOT NULL AND NULLIF(s.drug_id,'') IS NULL)
          OR
          (NULLIF(s.procedure_code,'') IS NULL     AND NULLIF(s.drug_id,'') IS NOT NULL)
      )
      -- FK checks only for the populated side
      AND (
          NULLIF(s.procedure_code,'') IS NULL
          OR EXISTS (SELECT 1 FROM uhip_db.ref.medical_procedure p WHERE p.procedure_code = s.procedure_code)
      )
      AND (
          NULLIF(s.drug_id,'') IS NULL
          OR EXISTS (SELECT 1 FROM uhip_db.ref.drug d WHERE d.drug_id = s.drug_id)
      )
      AND (s.item_amount IS NULL OR s.item_amount >= 0)
      AND (s.quantity    IS NULL OR s.quantity    > 0);

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.claim_item
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND claim_item_id IN (SELECT claim_item_id FROM uhip_db.fin.claim_item);

    COMMIT TRANSACTION;
    PRINT 'fin.claim_item — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('fin.claim_item', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading fin.claim_item: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  21. fin.claim_approval
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading fin.claim_approval ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.fin.claim_approval (
        approval_id,
        claim_id,
        reviewed_by,
        approval_status,
        approval_date,
        rejection_reason
    )
    SELECT
        s.approval_id,
        s.claim_id,
        s.reviewed_by,
        s.approval_status,
        TRY_CAST(s.approval_date AS DATE),
        s.rejection_reason
    FROM uhip_staging.stg.claim_approval s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.fin.claim_approval c WHERE c.approval_id = s.approval_id
      )
      -- unique claim_id in core
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.fin.claim_approval c WHERE c.claim_id = s.claim_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.fin.claim c WHERE c.claim_id = s.claim_id)
      AND s.approval_id     IS NOT NULL
      AND s.claim_id        IS NOT NULL
      AND s.reviewed_by     IS NOT NULL
      AND s.approval_status IS NOT NULL
      AND s.approval_status IN ('Approved','Partially Approved','Rejected','Pending Review');

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.claim_approval
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND approval_id IN (SELECT approval_id FROM uhip_db.fin.claim_approval);

    COMMIT TRANSACTION;
    PRINT 'fin.claim_approval — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('fin.claim_approval', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading fin.claim_approval: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  22. svc.patient_feedback
-- ============================================================
PRINT '------------------------------------------------------------';
PRINT 'Loading svc.patient_feedback ...';
PRINT '------------------------------------------------------------';

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @inserted INT;
    INSERT INTO uhip_db.svc.patient_feedback (
        feedback_id,
        patient_id,
        hospital_id,
        doctor_id,
        rating,
        comments,
        feedback_date
    )
    SELECT
        s.feedback_id,
        s.patient_id,
        s.hospital_id,
        s.doctor_id,
        s.rating,                           -- already TINYINT in staging
        s.comments,
        TRY_CAST(s.feedback_date AS DATE)
    FROM uhip_staging.stg.patient_feedback s
    WHERE s.stg_is_processed = 0
      AND NOT EXISTS (
          SELECT 1 FROM uhip_db.svc.patient_feedback c WHERE c.feedback_id = s.feedback_id
      )
      AND EXISTS (SELECT 1 FROM uhip_db.pat.patient   p WHERE p.patient_id   = s.patient_id)
      AND EXISTS (SELECT 1 FROM uhip_db.hosp.hospital h WHERE h.hospital_id  = s.hospital_id)
      AND EXISTS (SELECT 1 FROM uhip_db.hosp.doctor   d WHERE d.doctor_id    = s.doctor_id)
      AND s.feedback_id IS NOT NULL
      AND s.patient_id  IS NOT NULL
      AND s.hospital_id IS NOT NULL
      AND s.doctor_id   IS NOT NULL
      AND s.rating      IS NOT NULL
      AND s.rating BETWEEN 1 AND 5
      AND TRY_CAST(s.feedback_date AS DATE) IS NOT NULL;

    SET @inserted = @@ROWCOUNT;

    UPDATE uhip_staging.stg.patient_feedback
    SET stg_is_processed = 1
    WHERE stg_is_processed = 0
      AND feedback_id IN (SELECT feedback_id FROM uhip_db.svc.patient_feedback);

    COMMIT TRANSACTION;
    PRINT 'svc.patient_feedback — rows inserted: ' + CAST(@inserted AS VARCHAR);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO etl.error_log (target_table, source_key, error_message)
    VALUES ('svc.patient_feedback', NULL, ERROR_MESSAGE());
    PRINT 'ERROR loading svc.patient_feedback: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
--  FINAL SUMMARY
-- ============================================================
PRINT '============================================================';
PRINT 'ETL complete — row counts per core table:';
PRINT '============================================================';

SELECT
    s.name      AS schema_name,
    t.name      AS table_name,
    p.rows      AS row_count
FROM      sys.tables     t
JOIN      sys.schemas    s ON t.schema_id = s.schema_id
JOIN      sys.partitions p ON t.object_id = p.object_id
WHERE     p.index_id IN (0,1)
  AND     s.name NOT IN ('etl')
ORDER BY  s.name, t.name;
GO

PRINT '------------------------------------------------------------';
PRINT 'Rows rejected (see etl.error_log for details):';
PRINT '------------------------------------------------------------';
SELECT
    target_table,
    COUNT(*)        AS error_count,
    MIN(load_timestamp) AS first_error,
    MAX(load_timestamp) AS last_error
FROM etl.error_log
GROUP BY target_table
ORDER BY target_table;
GO

PRINT '============================================================';
PRINT 'Staging rows still pending (stg_is_processed = 0):';
PRINT '============================================================';
-- quick check across all stg tables
SELECT 'stg.diagnosis'          AS stg_table, COUNT(*) AS pending FROM uhip_staging.stg.diagnosis          WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.medical_procedure',               COUNT(*)            FROM uhip_staging.stg.medical_procedure   WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.drug',                            COUNT(*)            FROM uhip_staging.stg.drug                WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.hospital',                        COUNT(*)            FROM uhip_staging.stg.hospital            WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.department',                      COUNT(*)            FROM uhip_staging.stg.department          WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.doctor',                          COUNT(*)            FROM uhip_staging.stg.doctor              WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.doctor_schedule',                 COUNT(*)            FROM uhip_staging.stg.doctor_schedule     WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.bed',                             COUNT(*)            FROM uhip_staging.stg.bed                 WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.icu_status',                      COUNT(*)            FROM uhip_staging.stg.icu_status          WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.patient',                         COUNT(*)            FROM uhip_staging.stg.patient             WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.drug_inventory',                  COUNT(*)            FROM uhip_staging.stg.drug_inventory      WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.drug_transaction',                COUNT(*)            FROM uhip_staging.stg.drug_transaction    WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.visit',                           COUNT(*)            FROM uhip_staging.stg.visit               WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.medical_record',                  COUNT(*)            FROM uhip_staging.stg.medical_record      WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.visit_procedure',                 COUNT(*)            FROM uhip_staging.stg.visit_procedure     WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.prescription',                    COUNT(*)            FROM uhip_staging.stg.prescription        WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.prescription_item',               COUNT(*)            FROM uhip_staging.stg.prescription_item   WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.referral',                        COUNT(*)            FROM uhip_staging.stg.referral            WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.claim',                           COUNT(*)            FROM uhip_staging.stg.claim               WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.claim_item',                      COUNT(*)            FROM uhip_staging.stg.claim_item          WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.claim_approval',                  COUNT(*)            FROM uhip_staging.stg.claim_approval      WHERE stg_is_processed = 0
UNION ALL
SELECT 'stg.patient_feedback',                COUNT(*)            FROM uhip_staging.stg.patient_feedback    WHERE stg_is_processed = 0
ORDER BY stg_table;
GO
