-- ============================================================
--  UHIP — Unified Healthcare Intelligence Platform
--  Port Said Governorate, Egypt
--  SQL Server Database Creation Script
--  Version 5.0 | May 2025 | Naming-Convention Compliant
--  Changes from v4.0:
--    hosp.hospital    : longitude, latitude columns were already in DDL;
--                       now also populated in the bulk-insert script
--    Bulk Insert file : all inline INSERT VALUES converted to BULK INSERT
-- ============================================================
--  Conventions applied (db_naming_conventions.docx v1.0):
--    [1]  DB name     : uhip_db  (<system>_db format, lowercase)
--    [2]  Schemas     : ref | hosp | pat | inv | clin | fin | svc
--    [3]  Table names : singular nouns  (patient, visit, hospital …)
--    [4]  FK names    : fk_<child_table>_<referenced_table>
--    [5]  CHK names   : chk_<table>_<column>
--    [6]  Default constraints named: df_<table>_<column>
--    [7]  Indexes     : ix_<table>_<column(s)>  (full table name)
--    [8]  Money cols  : _amount suffix  (total_amount, item_amount …)
--    [9]  Timestamp   : updated_at  (not last_updated)
--    [10] Casing      : longitude lowercase  (not Longitude)
--    [11] Audit cols  : removed from all tables
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'uhip_db')
BEGIN
    ALTER DATABASE uhip_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE uhip_db;
END
GO

CREATE DATABASE uhip_db
    COLLATE Arabic_CI_AS;
GO

PRINT '============================================================';
PRINT 'Database created';
PRINT '============================================================';

USE uhip_db;
GO

-- ============================================================
--  SCHEMAS
--  ref  — reference / lookup tables (diagnoses, procedures, drugs)
--  hosp — hospital facility & resources
--  pat  — patient registry
--  inv  — pharmacy & inventory
--  clin — clinical encounters (visits, records, prescriptions)
--  fin  — insurance claims & approvals
--  svc  — citizen-facing services (feedback)
-- ============================================================
CREATE SCHEMA ref;  
GO
CREATE SCHEMA hosp; 
GO
CREATE SCHEMA pat;  
GO
CREATE SCHEMA inv;  
GO
CREATE SCHEMA clin; 
GO
CREATE SCHEMA fin;  
GO
CREATE SCHEMA svc;  
GO

PRINT '============================================================';
PRINT 'Schemas created';
PRINT '============================================================';

-- ============================================================
--  STEP 1 — REFERENCE TABLES  (schema: ref)
-- ============================================================

PRINT '============================================================';
PRINT 'schema: ref';
PRINT '============================================================';

-- ------------------------------------------------------------
--  ref.diagnosis
--  ICD-style diagnosis reference catalog 
-- ------------------------------------------------------------
CREATE TABLE ref.diagnosis (
    diagnosis_code      VARCHAR(4)    NOT NULL,
    diagnosis_name      VARCHAR(100)  NOT NULL,
    diagnosis_category  VARCHAR(30)   NOT NULL
        CONSTRAINT chk_diagnosis_diagnosis_category CHECK (diagnosis_category IN (
            'Cardiovascular','Respiratory','Endocrine','Gastrointestinal',
            'Neurological','Urological','Musculoskeletal','Trauma',
            'Infectious','Hematological','Mental Health','Skin','ENT','Pediatric'
        )),
    severity_level      VARCHAR(10)   NOT NULL
        CONSTRAINT chk_diagnosis_severity_level CHECK (severity_level IN (
            'Mild','Moderate','Severe','Critical','Chronic'
        )),

    CONSTRAINT pk_diagnosis PRIMARY KEY (diagnosis_code)
);
GO

PRINT '============================================================';
PRINT 'Diagnosis table created';
PRINT '============================================================';

GO
-- ------------------------------------------------------------
--  ref.procedure
--  Medical procedure reference catalog 
-- ------------------------------------------------------------
CREATE TABLE ref.medical_procedure  (
    procedure_code      VARCHAR(4)    NOT NULL,
    procedure_name      VARCHAR(120)  NOT NULL,
    procedure_category  VARCHAR(30)   NOT NULL
        CONSTRAINT chk_procedure_procedure_category CHECK (procedure_category IN (
            'Laboratory','Radiology','Cardiology','Cardiology Intervention',
            'Surgery','Orthopedic','Orthopedic Surgery','Endoscopy','ICU',
            'Nephrology','Hematology','Neurology','Pulmonology','Physiotherapy',
            'Emergency','Nursing','Consultation','Diagnostic Assessment',
            'Dermatology','Urology'
        )),
    expected_amount     DECIMAL(10,2) NOT NULL
        CONSTRAINT chk_procedure_expected_amount CHECK (expected_amount >= 0),
    complexity_score    TINYINT       NOT NULL
        CONSTRAINT chk_procedure_complexity_score CHECK (complexity_score BETWEEN 1 AND 5),

    CONSTRAINT pk_procedure PRIMARY KEY (procedure_code)
);
GO

PRINT '============================================================';
PRINT 'Procedure table created';
PRINT '============================================================';

GO
-- ------------------------------------------------------------
--  ref.drug
--  Egyptian pharmaceutical market catalog 
-- ------------------------------------------------------------
CREATE TABLE ref.drug (
    drug_id         VARCHAR(5)    NOT NULL,
    drug_name       VARCHAR(80)   NOT NULL,
    generic_name    VARCHAR(60)   NOT NULL,
    manufacturer    VARCHAR(50)   NOT NULL,
    drug_category   VARCHAR(30)   NOT NULL
        CONSTRAINT chk_drug_drug_category CHECK (drug_category IN (
            'Antibiotic','Antidiabetic','Antihypertensive','Analgesic/NSAID',
            'Lipid-Lowering','Cardiac','Respiratory','Corticosteroid',
            'Psychotropic/CNS','Oncology','Antifungal','Anticoagulant',
            'Antiparasitic','Antiviral','Gastrointestinal','Hematological',
            'Neurological','Ophthalmology','Dermatology','Urological','Vitamins/Supplements'
        )),
    unit_amount     DECIMAL(8,2)  NOT NULL
        CONSTRAINT chk_drug_unit_amount CHECK (unit_amount >= 0),

    CONSTRAINT pk_drug PRIMARY KEY (drug_id)
);
GO

PRINT '============================================================';
PRINT 'Drug table created';
PRINT '============================================================';

-- ============================================================
--  STEP 2 — CORE FACILITY  (schema: hosp)
-- ============================================================

PRINT '============================================================';
PRINT 'schema: hosp';
PRINT '============================================================';
-- ------------------------------------------------------------
--  hosp.hospital
--  Master list of 8 healthcare facilities in Port Said
-- ------------------------------------------------------------

CREATE TABLE hosp.hospital (
    hospital_id     VARCHAR(4)    NOT NULL,
    hospital_name   VARCHAR(80)   NOT NULL,
    hospital_type   VARCHAR(15)   NOT NULL
        CONSTRAINT chk_hospital_hospital_type CHECK (hospital_type IN (
            'Government','Private','Specialized','Teaching'
        )),
    governorate     VARCHAR(20)   NOT NULL
        CONSTRAINT df_hospital_governorate DEFAULT 'Port Said',
    district        VARCHAR(25)   NOT NULL
        CONSTRAINT chk_hospital_district CHECK (district IN (
            'El Sharq','Port Fouad','El Arab','El Manakh',
            'El Zohour','El Dawahy','Mubarak District'
        )),
    phone           VARCHAR(15)   NULL,
    total_beds      INT           NOT NULL
        CONSTRAINT chk_hospital_total_beds CHECK (total_beds > 0),
    icu_capacity    INT           NOT NULL
        CONSTRAINT chk_hospital_icu_capacity CHECK (icu_capacity > 0),
    longitude       DECIMAL(9,6)  NULL,
    latitude        DECIMAL(9,6)  NULL,
    manager_name    VARCHAR(100)  NULL,
    manager_email   VARCHAR(150)  NULL,
    manager_phone   VARCHAR(20)   NULL,

    CONSTRAINT pk_hospital PRIMARY KEY (hospital_id)
);
GO

PRINT '============================================================';
PRINT 'hospital table created';
PRINT '============================================================';

-- ============================================================
--  STEP 3 — DEPARTMENTS  (schema: hosp)
-- ============================================================

-- ------------------------------------------------------------
--  hosp.department
--  Clinical departments within each hospital
-- ------------------------------------------------------------
CREATE TABLE hosp.department (
    department_id   VARCHAR(8)  NOT NULL,
    hospital_id     VARCHAR(4)  NOT NULL,
    department_name VARCHAR(40) NOT NULL
        CONSTRAINT chk_department_department_name CHECK (department_name IN (
            'Emergency','ICU','Internal Medicine','Cardiology','Pulmonology',
            'Neurology','Gastroenterology','Nephrology','Endocrinology',
            'Orthopedics','General Surgery','Pediatrics',
            'Obstetrics & Gynecology','Dermatology','ENT','Psychiatry',
            'Oncology','Radiology','Laboratory','Pharmacy'
        )),
    floor_number    VARCHAR(2)  NOT NULL
        CONSTRAINT chk_department_floor_number CHECK (floor_number IN ('1','2','3')),
    manager_name    VARCHAR(100)  NULL,
    manager_email   VARCHAR(150)  NULL,
    manager_phone   VARCHAR(20)   NULL,

    CONSTRAINT pk_department PRIMARY KEY (department_id),
    CONSTRAINT fk_department_hospital
        FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id)
);
GO

CREATE INDEX ix_department_hospital_id ON hosp.department (hospital_id);
GO
PRINT '============================================================';
PRINT 'department table created';
PRINT '============================================================';

-- ============================================================
--  STEP 4 — DOCTORS  (schema: hosp)
-- ============================================================

-- ------------------------------------------------------------
--  hosp.doctor
--  Physician registry across 8 hospitals
-- ------------------------------------------------------------
CREATE TABLE hosp.doctor (
    doctor_id           VARCHAR(7)  NOT NULL,
	hospital_id     VARCHAR(4) NOT NULL,
    department_id       VARCHAR(8)  NOT NULL,
    first_name          VARCHAR(50) NOT NULL,
    last_name           VARCHAR(50) NOT NULL,
    specialty           VARCHAR(40) NOT NULL,
    years_experience    INT         NOT NULL
        CONSTRAINT chk_doctor_years_experience CHECK (years_experience BETWEEN 1 AND 38),
    phone               VARCHAR(12) NULL,
    employment_status   VARCHAR(10) NOT NULL
        CONSTRAINT chk_doctor_employment_status CHECK (employment_status IN ('Active','On Leave')),

    CONSTRAINT pk_doctor PRIMARY KEY (doctor_id),
    CONSTRAINT fk_doctor_department
        FOREIGN KEY (department_id) REFERENCES hosp.department (department_id)
);
GO

CREATE INDEX ix_doctor_department_id ON hosp.doctor (department_id);
GO

PRINT '============================================================';
PRINT 'doctor table created';
PRINT '============================================================';

-- ============================================================
--  STEP 5 — HOSPITAL RESOURCES  (schema: hosp)
-- ============================================================

-- ------------------------------------------------------------
--  hosp.doctor_schedule
--  Daily shift records (full 12-month study period)
-- ------------------------------------------------------------
CREATE TABLE hosp.doctor_schedule (
    schedule_id     VARCHAR(11) NOT NULL,
    doctor_id       VARCHAR(7)  NOT NULL,
    shift_date      DATE        NOT NULL,
    shift_start     VARCHAR(5)  NOT NULL
        CONSTRAINT chk_doctor_schedule_shift_start CHECK (shift_start IN ('08:00','14:00','20:00')),
    shift_end       VARCHAR(5)  NOT NULL
        CONSTRAINT chk_doctor_schedule_shift_end   CHECK (shift_end   IN ('14:00','20:00','08:00')),

    CONSTRAINT pk_doctor_schedule PRIMARY KEY (schedule_id),
    CONSTRAINT fk_doctor_schedule_doctor
        FOREIGN KEY (doctor_id) REFERENCES hosp.doctor (doctor_id)
);
GO

CREATE INDEX ix_doctor_schedule_doctor_id  ON hosp.doctor_schedule (doctor_id);
CREATE INDEX ix_doctor_schedule_shift_date ON hosp.doctor_schedule (shift_date);
GO

PRINT '============================================================';
PRINT 'doctor_schedule table created';
PRINT '============================================================';
-- ------------------------------------------------------------
--  hosp.bed
--  Physical bed inventory snapshot
-- ------------------------------------------------------------
CREATE TABLE hosp.bed (
    bed_id              VARCHAR(9)  NOT NULL,
	hospital_id     VARCHAR(4) NOT NULL,
    department_id       VARCHAR(8)  NOT NULL,
    bed_number          VARCHAR(10) NOT NULL,
    bed_type            VARCHAR(10) NOT NULL
        CONSTRAINT chk_bed_bed_type CHECK (bed_type IN ('ICU','Emergency','Standard')),
    availability_status VARCHAR(20) NOT NULL
        CONSTRAINT chk_bed_availability_status CHECK (availability_status IN (
            'Occupied','Available','Under Maintenance'
        )),

    CONSTRAINT pk_bed PRIMARY KEY (bed_id),
    CONSTRAINT fk_bed_department
        FOREIGN KEY (department_id) REFERENCES hosp.department (department_id)
);
GO

CREATE INDEX ix_bed_department_id ON hosp.bed (department_id);
GO

PRINT '============================================================';
PRINT 'bed table created';
PRINT '============================================================';
-- ------------------------------------------------------------
--  hosp.icu_status
--  Time-series ICU occupancy snapshots (every 3 days)
-- ------------------------------------------------------------
CREATE TABLE hosp.icu_status (
    icu_status_id   VARCHAR(9) NOT NULL,
    hospital_id     VARCHAR(4) NOT NULL,
    occupied_beds   INT        NOT NULL
        CONSTRAINT chk_icu_status_occupied_beds  CHECK (occupied_beds  >= 0),
    available_beds  INT        NOT NULL
        CONSTRAINT chk_icu_status_available_beds CHECK (available_beds >= 0),
    update_time     DATETIME2  NOT NULL,

    CONSTRAINT pk_icu_status PRIMARY KEY (icu_status_id),
    CONSTRAINT fk_icu_status_hospital
        FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id)
);
GO

CREATE INDEX ix_icu_status_hospital_id  ON hosp.icu_status (hospital_id);
CREATE INDEX ix_icu_status_update_time  ON hosp.icu_status (update_time);
GO
PRINT '============================================================';
PRINT 'icu_status table created';
PRINT '============================================================';

-- ============================================================
--  STEP 6 — PATIENTS  (schema: pat)
-- ============================================================
PRINT '============================================================';
PRINT 'schema: pat';
PRINT '============================================================';
-- ------------------------------------------------------------
--  pat.patient
--  Master patient registry
-- ------------------------------------------------------------
CREATE TABLE pat.patient (
    patient_id          VARCHAR(12)  NOT NULL,
    national_id         NUMERIC  NOT NULL,
    first_name          VARCHAR(50)  NOT NULL,
    last_name           VARCHAR(50)  NOT NULL,
    gender              VARCHAR(6)   NOT NULL
        CONSTRAINT chk_patient_gender CHECK (gender IN ('Male','Female')),
    birth_date          DATE         NOT NULL,
    phone               NUMERIC  NULL,
    street              VARCHAR(150) NULL,
    city                VARCHAR(20)  NULL,
    governorate         VARCHAR(20)  NOT NULL
        CONSTRAINT df_patient_governorate DEFAULT 'Port Said',
    blood_type          VARCHAR(3)   NULL
        CONSTRAINT chk_patient_blood_type CHECK (blood_type IN (
            'A+','A-','B+','B-','AB+','AB-','O+','O-'
        )),
    emergency_contact   NUMERIC  NULL,

    CONSTRAINT pk_patient   PRIMARY KEY (patient_id),
    CONSTRAINT uq_patient_national_id UNIQUE (national_id)
);
GO

CREATE INDEX ix_patient_last_name_first_name ON pat.patient (last_name, first_name);
GO
PRINT '============================================================';
PRINT 'patient table created';
PRINT '============================================================';


-- ============================================================
--  STEP 7 — PHARMACY & INVENTORY  (schema: inv)
-- ============================================================
PRINT '============================================================';
PRINT 'schema: inv';
PRINT '============================================================';
-- ------------------------------------------------------------
--  inv.drug_inventory
--  Current stock levels (8 hospitals × 175 drugs = 1,400 rows)
-- ------------------------------------------------------------
CREATE TABLE inv.drug_inventory (
    inventory_id        VARCHAR(9)   NOT NULL,
    hospital_id         VARCHAR(4)   NOT NULL,
    drug_id             VARCHAR(5)   NOT NULL,
    quantity_available  INT          NOT NULL
        CONSTRAINT chk_drug_inventory_quantity_available CHECK (quantity_available >= 0),
    reorder_level       INT          NOT NULL
        CONSTRAINT chk_drug_inventory_reorder_level      CHECK (reorder_level      >= 0),
    expiration_date     DATE         NULL,

    CONSTRAINT pk_drug_inventory          PRIMARY KEY (inventory_id),
    CONSTRAINT uq_drug_inventory_hospital_drug UNIQUE (hospital_id, drug_id),
    CONSTRAINT fk_drug_inventory_hospital
        FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id),
    CONSTRAINT fk_drug_inventory_drug
        FOREIGN KEY (drug_id)     REFERENCES ref.drug      (drug_id)
);
GO

CREATE INDEX ix_drug_inventory_hospital_id ON inv.drug_inventory (hospital_id);
CREATE INDEX ix_drug_inventory_drug_id     ON inv.drug_inventory (drug_id);
GO
PRINT '============================================================';
PRINT 'drug_inventory table created';
PRINT '============================================================';
-- ------------------------------------------------------------
--  inv.drug_transaction
--  Pharmacy movement log (350 transactions × 8 hospitals)
-- ------------------------------------------------------------
CREATE TABLE inv.drug_transaction (
    transaction_id      VARCHAR(9)  NOT NULL,
    drug_id             VARCHAR(5)  NOT NULL,
    hospital_id         VARCHAR(4)  NOT NULL,
    transaction_type    VARCHAR(12) NOT NULL
        CONSTRAINT chk_drug_transaction_transaction_type CHECK (transaction_type IN (
            'Purchase','Dispensing','Wastage','Return','Adjustment'
        )),
    quantity            INT         NOT NULL
        CONSTRAINT chk_drug_transaction_quantity CHECK (quantity > 0),
    transaction_date    DATE        NOT NULL,
    performed_by        VARCHAR(60) NULL,

    CONSTRAINT pk_drug_transaction PRIMARY KEY (transaction_id),
    CONSTRAINT fk_drug_transaction_drug
        FOREIGN KEY (drug_id)     REFERENCES ref.drug      (drug_id),
    CONSTRAINT fk_drug_transaction_hospital
        FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id)
);
GO

CREATE INDEX ix_drug_transaction_drug_id          ON inv.drug_transaction (drug_id);
CREATE INDEX ix_drug_transaction_hospital_id      ON inv.drug_transaction (hospital_id);
CREATE INDEX ix_drug_transaction_transaction_date ON inv.drug_transaction (transaction_date);
GO

PRINT '============================================================';
PRINT 'drug_transaction table created';
PRINT '============================================================';
-- ============================================================
--  STEP 8 — VISITS — central FACT table  (schema: clin)
-- ============================================================
PRINT '============================================================';
PRINT 'schema: clin';
PRINT '============================================================';
-- ------------------------------------------------------------
--  clin.visit
--  All hospital encounters — central FACT table
-- ------------------------------------------------------------
CREATE TABLE clin.visit (
    visit_id        VARCHAR(12)   NOT NULL,
    patient_id      VARCHAR(12)   NOT NULL,
    hospital_id     VARCHAR(4)    NOT NULL,
    doctor_id       VARCHAR(7)    NOT NULL,
    department_id   VARCHAR(8)    NOT NULL,
    visit_date      DATE          NOT NULL,
    visit_type      VARCHAR(15)   NOT NULL
        CONSTRAINT chk_visit_visit_type CHECK (visit_type IN (
            'Emergency','Outpatient','Inpatient','Follow-up','Routine Check'
        )),
    diagnosis_code  VARCHAR(4)    NOT NULL,
    symptoms        VARCHAR(100)  NULL,
    visit_status    VARCHAR(10)   NOT NULL
        CONSTRAINT chk_visit_visit_status CHECK (visit_status IN (
            'Completed','No Show','Cancelled'
        )),
    waiting_time    INT           NULL,            -- NULL if not Completed
    total_amount    DECIMAL(10,2) NULL,            -- NULL if not Completed

    CONSTRAINT pk_visit PRIMARY KEY (visit_id),
    CONSTRAINT fk_visit_patient
        FOREIGN KEY (patient_id)     REFERENCES pat.patient      (patient_id),
    CONSTRAINT fk_visit_hospital
        FOREIGN KEY (hospital_id)    REFERENCES hosp.hospital    (hospital_id),
    CONSTRAINT fk_visit_doctor
        FOREIGN KEY (doctor_id)      REFERENCES hosp.doctor      (doctor_id),
    CONSTRAINT fk_visit_department
        FOREIGN KEY (department_id)  REFERENCES hosp.department  (department_id),
    CONSTRAINT fk_visit_diagnosis
        FOREIGN KEY (diagnosis_code) REFERENCES ref.diagnosis    (diagnosis_code)
);
GO

CREATE INDEX ix_visit_patient_id     ON clin.visit (patient_id);
CREATE INDEX ix_visit_hospital_id    ON clin.visit (hospital_id);
CREATE INDEX ix_visit_doctor_id      ON clin.visit (doctor_id);
CREATE INDEX ix_visit_visit_date     ON clin.visit (visit_date);
CREATE INDEX ix_visit_visit_status   ON clin.visit (visit_status);
CREATE INDEX ix_visit_diagnosis_code ON clin.visit (diagnosis_code);
GO

PRINT '============================================================';
PRINT 'visit table created';
PRINT '============================================================';

-- ============================================================
--  STEP 9 — VISIT DETAILS  (schema: clin)
-- ============================================================

-- ------------------------------------------------------------
--  clin.medical_record
--  Clinical documentation per completed visit (1:1 with visit)
-- ------------------------------------------------------------
CREATE TABLE clin.medical_record (
    record_id           VARCHAR(12)  NOT NULL,
    visit_id            VARCHAR(12)  NOT NULL,
    procedure_code      VARCHAR(4)   NULL,
    diagnosis_notes     VARCHAR(300) NULL,
    treatment_notes     VARCHAR(200) NULL,
    follow_up_required  VARCHAR(3)   NOT NULL
        CONSTRAINT chk_medical_record_follow_up_required CHECK (follow_up_required IN ('Yes','No')),

    CONSTRAINT pk_medical_record        PRIMARY KEY (record_id),
    CONSTRAINT uq_medical_record_visit_id UNIQUE (visit_id),
    CONSTRAINT fk_medical_record_visit
        FOREIGN KEY (visit_id) REFERENCES clin.visit (visit_id)
);
GO
PRINT '============================================================';
PRINT 'medical_record table created';
PRINT '============================================================';
-- ------------------------------------------------------------
--  clin.visit_procedure
--  Procedures performed during each completed visit (avg ~2/visit)
-- ------------------------------------------------------------
CREATE TABLE clin.visit_procedure (
    visit_procedure_id  VARCHAR(12)   NOT NULL,
    visit_id            VARCHAR(12)   NOT NULL,
    procedure_code      VARCHAR(4)    NOT NULL,
    procedure_amount    DECIMAL(10,2) NOT NULL
        CONSTRAINT chk_visit_procedure_procedure_amount CHECK (procedure_amount >= 0),
    procedure_date      DATE          NOT NULL,

    CONSTRAINT pk_visit_procedure PRIMARY KEY (visit_procedure_id),
    CONSTRAINT fk_visit_procedure_visit
        FOREIGN KEY (visit_id)       REFERENCES clin.visit    (visit_id),
    CONSTRAINT fk_visit_procedure_procedure
        FOREIGN KEY (procedure_code) REFERENCES ref.medical_procedure  (procedure_code)
);
GO

CREATE INDEX ix_visit_procedure_visit_id       ON clin.visit_procedure (visit_id);
CREATE INDEX ix_visit_procedure_procedure_code ON clin.visit_procedure (procedure_code);
GO
PRINT '============================================================';
PRINT 'visit_procedure table created';
PRINT '============================================================';

-- ============================================================
--  STEP 10 — PRESCRIPTIONS  (schema: clin)
-- ============================================================

-- ------------------------------------------------------------
--  clin.prescription
--  Prescription header (~75% of completed visits)
-- ------------------------------------------------------------
CREATE TABLE clin.prescription (
    prescription_id     VARCHAR(12)  NOT NULL,
    visit_id            VARCHAR(12)  NOT NULL,
    doctor_id           VARCHAR(7)   NOT NULL,
    prescription_date   DATE         NOT NULL,
    notes               VARCHAR(100) NULL,

    CONSTRAINT pk_prescription PRIMARY KEY (prescription_id),
    CONSTRAINT fk_prescription_visit
        FOREIGN KEY (visit_id)  REFERENCES clin.visit  (visit_id),
    CONSTRAINT fk_prescription_doctor
        FOREIGN KEY (doctor_id) REFERENCES hosp.doctor (doctor_id)
);
GO

CREATE INDEX ix_prescription_visit_id    ON clin.prescription (visit_id);
CREATE INDEX ix_prescription_doctor_id  ON clin.prescription (doctor_id);
GO
PRINT '============================================================';
PRINT 'prescription table created';
PRINT '============================================================';
-- ------------------------------------------------------------
--  clin.prescription_item
--  Individual drug line items within prescriptions
-- ------------------------------------------------------------
CREATE TABLE clin.prescription_item (
    prescription_item_id  VARCHAR(12) NOT NULL,
    prescription_id       VARCHAR(12) NOT NULL,
    drug_id               VARCHAR(5)  NOT NULL,
    dosage                VARCHAR(10) NOT NULL,
    frequency             VARCHAR(25) NOT NULL
        CONSTRAINT chk_prescription_item_frequency CHECK (frequency IN (
            'Once daily','Twice daily','Every 12 hours',
            'Three times daily','Every 8 hours','Every 6 hours','As needed'
        )),
    duration_days         INT         NOT NULL
        CONSTRAINT chk_prescription_item_duration_days CHECK (duration_days BETWEEN 3 AND 90),
    quantity              INT         NOT NULL
        CONSTRAINT chk_prescription_item_quantity CHECK (quantity > 0),

    CONSTRAINT pk_prescription_item PRIMARY KEY (prescription_item_id),
    CONSTRAINT fk_prescription_item_prescription
        FOREIGN KEY (prescription_id) REFERENCES clin.prescription (prescription_id),
    CONSTRAINT fk_prescription_item_drug
        FOREIGN KEY (drug_id)         REFERENCES ref.drug           (drug_id)
);
GO

CREATE INDEX ix_prescription_item_prescription_id ON clin.prescription_item (prescription_id);
CREATE INDEX ix_prescription_item_drug_id         ON clin.prescription_item (drug_id);
GO
PRINT '============================================================';
PRINT 'prescription_item table created';
PRINT '============================================================';

-- ============================================================
--  STEP 11 — REFERRALS  (schema: hosp)
-- ============================================================

-- ------------------------------------------------------------
--  hosp.referral
--  Inter-hospital patient transfer records
-- ------------------------------------------------------------
CREATE TABLE hosp.referral (
    referral_id         VARCHAR(9)  NOT NULL,
    patient_id          VARCHAR(12) NOT NULL,
    from_hospital_id    VARCHAR(4)  NOT NULL,
    to_hospital_id      VARCHAR(4)  NOT NULL,
    referral_reason     VARCHAR(80) NOT NULL,
    referral_date       DATE        NOT NULL,
    referral_status     VARCHAR(10) NOT NULL
        CONSTRAINT chk_referral_referral_status CHECK (referral_status IN (
            'Completed','Pending','Cancelled'
        )),

    CONSTRAINT pk_referral PRIMARY KEY (referral_id),
    CONSTRAINT chk_referral_from_to_hospital
        CHECK (from_hospital_id <> to_hospital_id),
    CONSTRAINT fk_referral_patient
        FOREIGN KEY (patient_id)       REFERENCES pat.patient   (patient_id),
    CONSTRAINT fk_referral_from_hospital
        FOREIGN KEY (from_hospital_id) REFERENCES hosp.hospital (hospital_id),
    CONSTRAINT fk_referral_to_hospital
        FOREIGN KEY (to_hospital_id)   REFERENCES hosp.hospital (hospital_id)
);
GO

CREATE INDEX ix_referral_patient_id       ON hosp.referral (patient_id);
CREATE INDEX ix_referral_from_hospital_id ON hosp.referral (from_hospital_id);
CREATE INDEX ix_referral_to_hospital_id   ON hosp.referral (to_hospital_id);
GO
PRINT '============================================================';
PRINT 'referral table created';
PRINT '============================================================';

-- ============================================================
--  STEP 12 — INSURANCE CLAIMS  (schema: fin)
-- ============================================================
PRINT '============================================================';
PRINT 'schema: fin';
PRINT '============================================================';
-- ------------------------------------------------------------
--  fin.claim
--  Insurance claim submissions (62% of completed visits)
-- ------------------------------------------------------------
CREATE TABLE fin.claim (
    claim_id        VARCHAR(12)   NOT NULL,
    patient_id      VARCHAR(12)   NOT NULL,
    visit_id        VARCHAR(12)   NOT NULL,
    hospital_id     VARCHAR(4)    NOT NULL,
    claim_date      DATE          NOT NULL,
    claim_amount    DECIMAL(10,2) NOT NULL
        CONSTRAINT chk_claim_claim_amount CHECK (claim_amount >= 0),
    approved_amount DECIMAL(10,2) NULL,           -- NULL when Pending Review
    claim_status    VARCHAR(20)   NOT NULL
        CONSTRAINT chk_claim_claim_status CHECK (claim_status IN (
            'Approved','Partially Approved','Rejected','Pending Review'
        )),

    CONSTRAINT pk_claim         PRIMARY KEY (claim_id),
    CONSTRAINT uq_claim_visit_id  UNIQUE (visit_id),
    CONSTRAINT fk_claim_patient
        FOREIGN KEY (patient_id)  REFERENCES pat.patient   (patient_id),
    CONSTRAINT fk_claim_visit
        FOREIGN KEY (visit_id)    REFERENCES clin.visit    (visit_id),
    CONSTRAINT fk_claim_hospital
        FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id)
);
GO

CREATE INDEX ix_claim_patient_id   ON fin.claim (patient_id);
CREATE INDEX ix_claim_hospital_id  ON fin.claim (hospital_id);
CREATE INDEX ix_claim_claim_date   ON fin.claim (claim_date);
CREATE INDEX ix_claim_claim_status ON fin.claim (claim_status);
GO
PRINT '============================================================';
PRINT 'claim table created';
PRINT '============================================================';
-- ------------------------------------------------------------
--  fin.claim_item
--  Itemised billing lines per claim (procedure OR drug, never both)
-- ------------------------------------------------------------
CREATE TABLE fin.claim_item (
    claim_item_id   VARCHAR(12)   NOT NULL,
    claim_id        VARCHAR(12)   NOT NULL,
    procedure_code  VARCHAR(4)    NULL,            -- NULL for drug items
    drug_id         VARCHAR(5)    NULL,            -- NULL for procedure items
    item_amount     DECIMAL(10,2) NULL
        CONSTRAINT chk_claim_item_item_amount CHECK (item_amount >= 0),
    quantity        INT           NULL
        CONSTRAINT chk_claim_item_quantity CHECK (quantity > 0),
    -- Exactly one of procedure_code / drug_id must be populated
    CONSTRAINT chk_claim_item_procedure_or_drug CHECK (
        (procedure_code IS NOT NULL AND drug_id IS NULL) OR
        (procedure_code IS NULL     AND drug_id IS NOT NULL)
    ),

    CONSTRAINT pk_claim_item PRIMARY KEY (claim_item_id),
    CONSTRAINT fk_claim_item_claim
        FOREIGN KEY (claim_id)       REFERENCES fin.claim      (claim_id),
    CONSTRAINT fk_claim_item_procedure
        FOREIGN KEY (procedure_code) REFERENCES ref.medical_procedure   (procedure_code),
    CONSTRAINT fk_claim_item_drug
        FOREIGN KEY (drug_id)        REFERENCES ref.drug       (drug_id)
);
GO

CREATE INDEX ix_claim_item_claim_id        ON fin.claim_item (claim_id);
CREATE INDEX ix_claim_item_procedure_code  ON fin.claim_item (procedure_code);
CREATE INDEX ix_claim_item_drug_id         ON fin.claim_item (drug_id);
GO
PRINT '============================================================';
PRINT 'claim_item table created';
PRINT '============================================================';
-- ------------------------------------------------------------
--  fin.claim_approval
--  Insurer review decision per claim (1:1 with claim)
-- ------------------------------------------------------------
CREATE TABLE fin.claim_approval (
    approval_id         VARCHAR(12) NOT NULL,
    claim_id            VARCHAR(12) NOT NULL,
    reviewed_by         VARCHAR(50) NOT NULL,
    approval_status     VARCHAR(20) NOT NULL
        CONSTRAINT chk_claim_approval_approval_status CHECK (approval_status IN (
            'Approved','Partially Approved','Rejected','Pending Review'
        )),
    approval_date       DATE        NULL,           -- NULL for Pending Review
    rejection_reason    VARCHAR(80) NULL,           -- Populated only when Rejected

    CONSTRAINT pk_claim_approval        PRIMARY KEY (approval_id),
    CONSTRAINT uq_claim_approval_claim_id UNIQUE (claim_id),
    CONSTRAINT fk_claim_approval_claim
        FOREIGN KEY (claim_id) REFERENCES fin.claim (claim_id)
);
GO

CREATE INDEX ix_claim_approval_claim_id        ON fin.claim_approval (claim_id);
CREATE INDEX ix_claim_approval_approval_status ON fin.claim_approval (approval_status);
GO

PRINT '============================================================';
PRINT 'claim_approval table created';
PRINT '============================================================';
-- ============================================================
--  STEP 13 — CITIZEN SERVICES  (schema: svc)
-- ============================================================

-- ------------------------------------------------------------
--  svc.patient_feedback
--  Post-visit patient satisfaction surveys
-- ------------------------------------------------------------
CREATE TABLE svc.patient_feedback (
    feedback_id     VARCHAR(12)  NOT NULL,
    patient_id      VARCHAR(12)  NOT NULL,
    hospital_id     VARCHAR(4)   NOT NULL,
    doctor_id       VARCHAR(7)   NOT NULL,
    rating          TINYINT      NOT NULL
        CONSTRAINT chk_patient_feedback_rating CHECK (rating BETWEEN 1 AND 5),
    comments        VARCHAR(200) NULL,
    feedback_date   DATE         NOT NULL,

    CONSTRAINT pk_patient_feedback PRIMARY KEY (feedback_id),
    CONSTRAINT fk_patient_feedback_patient
        FOREIGN KEY (patient_id)  REFERENCES pat.patient   (patient_id),
    CONSTRAINT fk_patient_feedback_hospital
        FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id),
    CONSTRAINT fk_patient_feedback_doctor
        FOREIGN KEY (doctor_id)   REFERENCES hosp.doctor   (doctor_id)
);
GO

CREATE INDEX ix_patient_feedback_patient_id    ON svc.patient_feedback (patient_id);
CREATE INDEX ix_patient_feedback_hospital_id   ON svc.patient_feedback (hospital_id);
CREATE INDEX ix_patient_feedback_doctor_id     ON svc.patient_feedback (doctor_id);
CREATE INDEX ix_patient_feedback_feedback_date ON svc.patient_feedback (feedback_date);
GO

PRINT '============================================================';
PRINT 'patient_feedback table created';
PRINT '============================================================';

GO
-- ============================================================
--  VIEWS
-- ============================================================

-- Full visit details (star-schema flattened)
CREATE VIEW vw_visit_detail AS
SELECT
    v.visit_id,
    v.visit_date,
    v.visit_type,
    v.visit_status,
    v.waiting_time,
    v.total_amount,
    v.symptoms,
    p.patient_id,
    p.first_name  + ' ' + p.last_name AS patient_name,
    p.gender,
    DATEDIFF(YEAR, p.birth_date, v.visit_date) AS patient_age,
    p.blood_type,
    h.hospital_id,
    h.hospital_name,
    h.hospital_type,
    h.district,
    d.doctor_id,
    d.first_name  + ' ' + d.last_name AS doctor_name,
    d.specialty,
    dept.department_name,
    diag.diagnosis_code,
    diag.diagnosis_name,
    diag.diagnosis_category,
    diag.severity_level
FROM      clin.visit       v
JOIN      pat.patient      p    ON v.patient_id     = p.patient_id
JOIN      hosp.hospital    h    ON v.hospital_id    = h.hospital_id
JOIN      hosp.doctor      d    ON v.doctor_id      = d.doctor_id
JOIN      hosp.department  dept ON v.department_id  = dept.department_id
JOIN      ref.diagnosis    diag ON v.diagnosis_code = diag.diagnosis_code;
GO

-- Drug inventory alerts (stockout & near-expiry)
CREATE VIEW vw_inventory_alert AS
SELECT
    i.inventory_id,
    h.hospital_name,
    dr.drug_name,
    dr.drug_category,
    i.quantity_available,
    i.reorder_level,
    i.expiration_date,
    CASE
        WHEN i.quantity_available = 0                                    THEN 'Stockout'
        WHEN i.quantity_available <= i.reorder_level                     THEN 'Low Stock'
        ELSE 'OK'
    END AS stock_status,
    CASE
        WHEN i.expiration_date <= DATEADD(DAY, 60, GETUTCDATE())         THEN 'Near Expiry'
        ELSE 'OK'
    END AS expiry_status
FROM      inv.drug_inventory i
JOIN      hosp.hospital      h  ON i.hospital_id = h.hospital_id
JOIN      ref.drug           dr ON i.drug_id     = dr.drug_id;
GO

-- Claim summary with approval outcome
CREATE VIEW vw_claim_summary AS
SELECT
    c.claim_id,
    c.claim_date,
    c.claim_amount,
    c.approved_amount,
    c.claim_status,
    ca.approval_date,
    ca.reviewed_by,
    ca.rejection_reason,
    p.first_name + ' ' + p.last_name AS patient_name,
    h.hospital_name,
    v.visit_date,
    v.visit_type
FROM      fin.claim          c
JOIN      pat.patient        p  ON c.patient_id  = p.patient_id
JOIN      hosp.hospital      h  ON c.hospital_id = h.hospital_id
JOIN      clin.visit         v  ON c.visit_id    = v.visit_id
LEFT JOIN fin.claim_approval ca ON c.claim_id    = ca.claim_id;
GO

-- ICU occupancy rate per hospital
CREATE VIEW vw_icu_occupancy_rate AS
SELECT
    s.hospital_id,
    h.hospital_name,
    s.update_time,
    s.occupied_beds,
    s.available_beds,
    h.icu_capacity,
    CAST(s.occupied_beds * 100.0 / NULLIF(h.icu_capacity, 0) AS DECIMAL(5,2)) AS occupancy_pct
FROM      hosp.icu_status s
JOIN      hosp.hospital   h ON s.hospital_id = h.hospital_id;
GO

PRINT '============================================================';
PRINT 'Views created';
PRINT '============================================================';

-- ============================================================
--  QUICK VERIFICATION QUERY
-- ============================================================
SELECT
    s.name        AS schema_name,
    t.name        AS table_name,
    p.rows        AS row_count
FROM      sys.tables     t
JOIN      sys.schemas    s ON t.schema_id  = s.schema_id
JOIN      sys.partitions p ON t.object_id  = p.object_id
WHERE     p.index_id IN (0, 1)
ORDER BY  s.name, t.name;
GO

PRINT '============================================================';
PRINT ' uhip_db created successfully — naming conventions v1.0';
PRINT ' 22 tables | 7 schemas | 4 views | all constraints named';
PRINT ' hosp.hospital   : longitude + latitude columns present';
PRINT ' hosp.department : manager_name, manager_email, manager_phone present';
PRINT ' Audit columns   : removed from all 22 tables';
PRINT '============================================================';
GO
