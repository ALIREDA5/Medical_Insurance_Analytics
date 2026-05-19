-- ============================================================
--  UHIP — Unified Healthcare Intelligence Platform
--  STAGING LAYER  (schema prefix: stg)
--  Version 1.0 | Based on uhip_db v5.0
--
--  Design rules:
--    • All columns are NVARCHAR(MAX) / INT-preserved where safe,
--      but NO constraints of any kind:
--        - No PRIMARY KEY
--        - No FOREIGN KEY
--        - No CHECK
--        - No UNIQUE
--        - No DEFAULT
--        - No indexes
--    • One extra meta-column per table:
--        stg_load_timestamp  DATETIME2   — when the row was loaded
--        stg_source_file     VARCHAR(260)— optional: source file name
--        stg_is_processed    BIT         — 0 = pending, 1 = moved to core
--    • All domain columns kept as VARCHAR to accept raw/dirty data
--      without rejection.
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'uhip_staging')
BEGIN
    ALTER DATABASE uhip_staging SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE uhip_staging;
END
GO

CREATE DATABASE uhip_staging
    COLLATE Arabic_CI_AS;
GO

PRINT '============================================================';
PRINT 'uhip_staging database created';
PRINT '============================================================';

USE uhip_staging;
GO

CREATE SCHEMA stg;
GO

PRINT '============================================================';
PRINT 'Schema stg created';
PRINT '============================================================';

-- ============================================================
--  ref.diagnosis  →  stg.diagnosis
-- ============================================================
CREATE TABLE stg.diagnosis (
    diagnosis_code      VARCHAR(4),
    diagnosis_name      VARCHAR(100),
    diagnosis_category  VARCHAR(30),
    severity_level      VARCHAR(10),
);
GO
PRINT 'stg.diagnosis created';

-- ============================================================
--  ref.medical_procedure  →  stg.medical_procedure
-- ============================================================
CREATE TABLE stg.medical_procedure (
    procedure_code      VARCHAR(4),
    procedure_name      VARCHAR(120),
    procedure_category  VARCHAR(30),
    expected_amount     VARCHAR(20),   -- raw; may contain commas or currency symbols
    complexity_score    VARCHAR(5),
);
GO
PRINT 'stg.medical_procedure created';

-- ============================================================
--  ref.drug  →  stg.drug
-- ============================================================
CREATE TABLE stg.drug (
    drug_id             VARCHAR(5),
    drug_name           VARCHAR(80),
    generic_name        VARCHAR(60),
    manufacturer        VARCHAR(50),
    drug_category       VARCHAR(30),
    unit_amount         VARCHAR(20),   -- raw decimal
);
GO
PRINT 'stg.drug created';

-- ============================================================
--  hosp.hospital  →  stg.hospital
-- ============================================================
CREATE TABLE stg.hospital (
    hospital_id     VARCHAR(4),
    hospital_name   VARCHAR(80),
    hospital_type   VARCHAR(15),
    governorate     VARCHAR(20),
    district        VARCHAR(25),
    phone           VARCHAR(15),
    total_beds      VARCHAR(10),
    icu_capacity    VARCHAR(10),
    longitude       VARCHAR(20),
    latitude        VARCHAR(20),
    manager_name    VARCHAR(100),
    manager_email   VARCHAR(150),
    manager_phone   VARCHAR(20),
);
GO
PRINT 'stg.hospital created';

-- ============================================================
--  hosp.department  →  stg.department
-- ============================================================
CREATE TABLE stg.department (
    department_id   VARCHAR(8),
    hospital_id     VARCHAR(4),
    department_name VARCHAR(40),
    floor_number    Numeric,
    manager_name    VARCHAR(100),
    manager_email   VARCHAR(150),
    manager_phone   Numeric,
);
GO
PRINT 'stg.department created';

-- ============================================================
--  hosp.doctor  →  stg.doctor
-- ============================================================
CREATE TABLE stg.doctor (
    doctor_id           VARCHAR(7),
	hospital_id			VARCHAR(4),
    department_id       VARCHAR(8),
    first_name          VARCHAR(50),
    last_name           VARCHAR(50),
    specialty           VARCHAR(40),
    years_experience    VARCHAR(5),
    phone               VARCHAR(12),
    employment_status   VARCHAR(10),
);
GO
PRINT 'stg.doctor created';

-- ============================================================
--  hosp.doctor_schedule  →  stg.doctor_schedule
-- ============================================================
CREATE TABLE stg.doctor_schedule (
    schedule_id     VARCHAR(11),
    doctor_id       VARCHAR(7),
    shift_date      VARCHAR(10),   -- raw date string
    shift_start     VARCHAR(5),
    shift_end       VARCHAR(5),

);
GO
PRINT 'stg.doctor_schedule created';

-- ============================================================
--  hosp.bed  →  stg.bed
-- ============================================================
CREATE TABLE stg.bed (
    bed_id              VARCHAR(9),
	hospital_id     VARCHAR(4),
    department_id       VARCHAR(8),
    bed_number          VARCHAR(10),
    bed_type            VARCHAR(10),
    availability_status VARCHAR(20),
);
GO
PRINT 'stg.bed created';

-- ============================================================
--  hosp.icu_status  →  stg.icu_status
-- ============================================================
CREATE TABLE stg.icu_status (
    icu_status_id   VARCHAR(9),
    hospital_id     VARCHAR(4),
    occupied_beds   VARCHAR(10),
    available_beds  VARCHAR(10),
    update_time     VARCHAR(30),   -- raw datetime string

);
GO
PRINT 'stg.icu_status created';

-- ============================================================
--  pat.patient  →  stg.patient
-- ============================================================
CREATE TABLE stg.patient (
    patient_id          VARCHAR(12),
    national_id         NUMERIC,
    first_name          VARCHAR(50),
    last_name           VARCHAR(50),
    gender              VARCHAR(6),
    birth_date          VARCHAR(10),   -- raw date string
    phone               NUMERIC,
    street              VARCHAR(150),
    city                VARCHAR(20),
    governorate         VARCHAR(20),
    blood_type          VARCHAR(3),
    emergency_contact   NUMERIC,
);
GO
PRINT 'stg.patient created';

-- ============================================================
--  inv.drug_inventory  →  stg.drug_inventory
-- ============================================================
CREATE TABLE stg.drug_inventory (
    inventory_id        VARCHAR(9),
    hospital_id         VARCHAR(4),
    drug_id             VARCHAR(5),
    quantity_available  VARCHAR(10),
    reorder_level       VARCHAR(10),
    expiration_date     VARCHAR(10),   -- raw date string
);
GO
PRINT 'stg.drug_inventory created';

-- ============================================================
--  inv.drug_transaction  →  stg.drug_transaction
-- ============================================================
CREATE TABLE stg.drug_transaction (
    transaction_id      VARCHAR(9),
    drug_id             VARCHAR(5),
    hospital_id         VARCHAR(4),
    transaction_type    VARCHAR(12),
    quantity            VARCHAR(10),
    transaction_date    VARCHAR(10),
    performed_by        VARCHAR(60),
);
GO
PRINT 'stg.drug_transaction created';

-- ============================================================
--  clin.visit  →  stg.visit
-- ============================================================
CREATE TABLE stg.visit (
    visit_id        VARCHAR(12),
    patient_id      VARCHAR(12),
    hospital_id     VARCHAR(4),
    doctor_id       VARCHAR(7),
    department_id   VARCHAR(8),
    visit_date      VARCHAR(10),
    visit_type      VARCHAR(15),
    diagnosis_code  VARCHAR(4),
    symptoms        VARCHAR(100),
    visit_status    VARCHAR(10),
    waiting_time    VARCHAR(10),
    total_amount    VARCHAR(20),

);
GO
PRINT 'stg.visit created';

-- ============================================================
--  clin.medical_record  →  stg.medical_record
-- ============================================================
CREATE TABLE stg.medical_record (
    record_id           VARCHAR(12),
    visit_id            VARCHAR(12),
    procedure_code      VARCHAR(4),
    diagnosis_notes     VARCHAR(300),
    treatment_notes     VARCHAR(200),
    follow_up_required  VARCHAR(3),

);
GO
PRINT 'stg.medical_record created';

-- ============================================================
--  clin.visit_procedure  →  stg.visit_procedure
-- ============================================================
CREATE TABLE stg.visit_procedure (
    visit_procedure_id  VARCHAR(12),
    visit_id            VARCHAR(12),
    procedure_code      VARCHAR(4),
    procedure_amount    VARCHAR(20),
    procedure_date      VARCHAR(10),

);
GO
PRINT 'stg.visit_procedure created';

-- ============================================================
--  clin.prescription  →  stg.prescription
-- ============================================================
CREATE TABLE stg.prescription (
    prescription_id     VARCHAR(12),
    visit_id            VARCHAR(12),
    doctor_id           VARCHAR(7),
    prescription_date   VARCHAR(10),
    notes               VARCHAR(100),

);
GO
PRINT 'stg.prescription created';

-- ============================================================
--  clin.prescription_item  →  stg.prescription_item
-- ============================================================
CREATE TABLE stg.prescription_item (
    prescription_item_id  VARCHAR(12),
    prescription_id       VARCHAR(12),
    drug_id               VARCHAR(5),
    dosage                VARCHAR(10),
    frequency             VARCHAR(25),
    duration_days         VARCHAR(5),
    quantity              VARCHAR(10),

);
GO
PRINT 'stg.prescription_item created';

-- ============================================================
--  hosp.referral  →  stg.referral
-- ============================================================
CREATE TABLE stg.referral (
    referral_id         VARCHAR(9),
    patient_id          VARCHAR(12),
    from_hospital_id    VARCHAR(4),
    to_hospital_id      VARCHAR(4),
    referral_reason     VARCHAR(80),
    referral_date       VARCHAR(10),
    referral_status     VARCHAR(10),

);
GO
PRINT 'stg.referral created';

-- ============================================================
--  fin.claim  →  stg.claim
-- ============================================================
CREATE TABLE stg.claim (
    claim_id        VARCHAR(12),
    patient_id      VARCHAR(12),
    visit_id        VARCHAR(12),
    hospital_id     VARCHAR(4),
    claim_date      VARCHAR(10),
    claim_amount    VARCHAR(20),
    approved_amount VARCHAR(20),
    claim_status    VARCHAR(20),

);
GO
PRINT 'stg.claim created';

-- ============================================================
--  fin.claim_item  →  stg.claim_item
-- ============================================================
CREATE TABLE stg.claim_item (
    claim_item_id   VARCHAR(12),
    claim_id        VARCHAR(12),
    procedure_code  VARCHAR(4),
    drug_id         VARCHAR(5),
    item_amount     Numeric,
    quantity        Numeric,

);
GO
PRINT 'stg.claim_item created';

-- ============================================================
--  fin.claim_approval  →  stg.claim_approval
-- ============================================================
CREATE TABLE stg.claim_approval (
    approval_id         VARCHAR(12),
    claim_id            VARCHAR(12),
    reviewed_by         VARCHAR(50),
    approval_status     VARCHAR(20),
    approval_date       VARCHAR(10),
    rejection_reason    VARCHAR(80),

);
GO
PRINT 'stg.claim_approval created';

-- ============================================================
--  svc.patient_feedback  →  stg.patient_feedback
-- ============================================================
CREATE TABLE stg.patient_feedback (
    feedback_id     VARCHAR(12),
    patient_id      VARCHAR(12),
    hospital_id     VARCHAR(4),
    doctor_id       VARCHAR(7),
    rating          TINYINT,
    comments        VARCHAR(200),
    feedback_date   VARCHAR(10),

);
GO
PRINT 'stg.patient_feedback created';

-- ============================================================
--  VERIFICATION
-- ============================================================
SELECT
    s.name       AS schema_name,
    t.name       AS table_name,
    p.rows       AS row_count
FROM      sys.tables     t
JOIN      sys.schemas    s ON t.schema_id = s.schema_id
JOIN      sys.partitions p ON t.object_id = p.object_id
WHERE     p.index_id IN (0,1)
ORDER BY  s.name, t.name;
GO

PRINT '============================================================';
PRINT 'uhip_staging created — 22 tables, schema: stg';
PRINT 'No PKs | No FKs | No CHECKs | No UNIQUEs | No indexes';
PRINT 'Meta cols: stg_load_timestamp, stg_source_file, stg_is_processed';
PRINT '============================================================';
GO
