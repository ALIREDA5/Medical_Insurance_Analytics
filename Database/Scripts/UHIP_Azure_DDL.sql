-- ============================================================
--  UHIP — Unified Healthcare Intelligence Platform
--  Azure SQL Database DDL Script  (Idempotent — Tables Only)
--  Version 5.0 | May 2025 | Azure SQL Compatible
--
--  INSTRUCTIONS:
--    1. Create an Azure SQL Database named 'uhip_db' in the portal
--       (or via Azure CLI / Bicep / ARM) with collation Arabic_CI_AS
--    2. Connect to uhip_db and run this script
--    3. Safe to re-run — every object is skipped if it already exists
--
--  Schemas  : ref | hosp | pat | inv | clin | fin | svc
--  Tables   : 22 tables across 7 schemas
--  Indexes  : non-clustered covering indexes on FK / filter columns
-- ============================================================

-- ============================================================
--  SCHEMAS  (skipped if already exist)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ref')
    EXEC('CREATE SCHEMA ref');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'hosp')
    EXEC('CREATE SCHEMA hosp');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'pat')
    EXEC('CREATE SCHEMA pat');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'inv')
    EXEC('CREATE SCHEMA inv');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'clin')
    EXEC('CREATE SCHEMA clin');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'fin')
    EXEC('CREATE SCHEMA fin');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'svc')
    EXEC('CREATE SCHEMA svc');
GO

-- ============================================================
--  STEP 1 — REFERENCE TABLES  (schema: ref)
-- ============================================================

-- ------------------------------------------------------------
--  ref.diagnosis
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'ref' AND t.name = 'diagnosis')
BEGIN
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
    PRINT 'Created: ref.diagnosis';
END
ELSE
    PRINT 'Skipped (exists): ref.diagnosis';
GO

-- ------------------------------------------------------------
--  ref.medical_procedure
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'ref' AND t.name = 'medical_procedure')
BEGIN
    CREATE TABLE ref.medical_procedure (
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
    PRINT 'Created: ref.medical_procedure';
END
ELSE
    PRINT 'Skipped (exists): ref.medical_procedure';
GO

-- ------------------------------------------------------------
--  ref.drug
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'ref' AND t.name = 'drug')
BEGIN
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
    PRINT 'Created: ref.drug';
END
ELSE
    PRINT 'Skipped (exists): ref.drug';
GO

-- ============================================================
--  STEP 2 — CORE FACILITY  (schema: hosp)
-- ============================================================

-- ------------------------------------------------------------
--  hosp.hospital
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'hosp' AND t.name = 'hospital')
BEGIN
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
    PRINT 'Created: hosp.hospital';
END
ELSE
    PRINT 'Skipped (exists): hosp.hospital';
GO

-- ============================================================
--  STEP 3 — DEPARTMENTS  (schema: hosp)
-- ============================================================

-- ------------------------------------------------------------
--  hosp.department
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'hosp' AND t.name = 'department')
BEGIN
    CREATE TABLE hosp.department (
        department_id   VARCHAR(8)    NOT NULL,
        hospital_id     VARCHAR(4)    NOT NULL,
        department_name VARCHAR(40)   NOT NULL
            CONSTRAINT chk_department_department_name CHECK (department_name IN (
                'Emergency','ICU','Internal Medicine','Cardiology','Pulmonology',
                'Neurology','Gastroenterology','Nephrology','Endocrinology',
                'Orthopedics','General Surgery','Pediatrics',
                'Obstetrics & Gynecology','Dermatology','ENT','Psychiatry',
                'Oncology','Radiology','Laboratory','Pharmacy'
            )),
        floor_number    VARCHAR(2)    NOT NULL
            CONSTRAINT chk_department_floor_number CHECK (floor_number IN ('1','2','3')),
        manager_name    VARCHAR(100)  NULL,
        manager_email   VARCHAR(150)  NULL,
        manager_phone   VARCHAR(20)   NULL,

        CONSTRAINT pk_department PRIMARY KEY (department_id),
        CONSTRAINT fk_department_hospital
            FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id)
    );
    PRINT 'Created: hosp.department';
END
ELSE
    PRINT 'Skipped (exists): hosp.department';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_department_hospital_id')
BEGIN
    CREATE INDEX ix_department_hospital_id ON hosp.department (hospital_id);
    PRINT 'Created index: ix_department_hospital_id';
END
GO

-- ============================================================
--  STEP 4 — DOCTORS  (schema: hosp)
-- ============================================================

-- ------------------------------------------------------------
--  hosp.doctor
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'hosp' AND t.name = 'doctor')
BEGIN
    CREATE TABLE hosp.doctor (
        doctor_id           VARCHAR(7)  NOT NULL,
        hospital_id         VARCHAR(4)  NOT NULL,
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
        CONSTRAINT fk_doctor_hospital
            FOREIGN KEY (hospital_id)   REFERENCES hosp.hospital   (hospital_id),
        CONSTRAINT fk_doctor_department
            FOREIGN KEY (department_id) REFERENCES hosp.department (department_id)
    );
    PRINT 'Created: hosp.doctor';
END
ELSE
    PRINT 'Skipped (exists): hosp.doctor';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_doctor_department_id')
BEGIN
    CREATE INDEX ix_doctor_department_id ON hosp.doctor (department_id);
    PRINT 'Created index: ix_doctor_department_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_doctor_hospital_id')
BEGIN
    CREATE INDEX ix_doctor_hospital_id ON hosp.doctor (hospital_id);
    PRINT 'Created index: ix_doctor_hospital_id';
END
GO

-- ============================================================
--  STEP 5 — HOSPITAL RESOURCES  (schema: hosp)
-- ============================================================

-- ------------------------------------------------------------
--  hosp.doctor_schedule
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'hosp' AND t.name = 'doctor_schedule')
BEGIN
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
    PRINT 'Created: hosp.doctor_schedule';
END
ELSE
    PRINT 'Skipped (exists): hosp.doctor_schedule';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_doctor_schedule_doctor_id')
BEGIN
    CREATE INDEX ix_doctor_schedule_doctor_id ON hosp.doctor_schedule (doctor_id);
    PRINT 'Created index: ix_doctor_schedule_doctor_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_doctor_schedule_shift_date')
BEGIN
    CREATE INDEX ix_doctor_schedule_shift_date ON hosp.doctor_schedule (shift_date);
    PRINT 'Created index: ix_doctor_schedule_shift_date';
END
GO

-- ------------------------------------------------------------
--  hosp.bed
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'hosp' AND t.name = 'bed')
BEGIN
    CREATE TABLE hosp.bed (
        bed_id              VARCHAR(9)  NOT NULL,
        hospital_id         VARCHAR(4)  NOT NULL,
        department_id       VARCHAR(8)  NOT NULL,
        bed_number          VARCHAR(10) NOT NULL,
        bed_type            VARCHAR(10) NOT NULL
            CONSTRAINT chk_bed_bed_type CHECK (bed_type IN ('ICU','Emergency','Standard')),
        availability_status VARCHAR(20) NOT NULL
            CONSTRAINT chk_bed_availability_status CHECK (availability_status IN (
                'Occupied','Available','Under Maintenance'
            )),

        CONSTRAINT pk_bed PRIMARY KEY (bed_id),
        CONSTRAINT fk_bed_hospital
            FOREIGN KEY (hospital_id)   REFERENCES hosp.hospital   (hospital_id),
        CONSTRAINT fk_bed_department
            FOREIGN KEY (department_id) REFERENCES hosp.department (department_id)
    );
    PRINT 'Created: hosp.bed';
END
ELSE
    PRINT 'Skipped (exists): hosp.bed';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_bed_department_id')
BEGIN
    CREATE INDEX ix_bed_department_id ON hosp.bed (department_id);
    PRINT 'Created index: ix_bed_department_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_bed_hospital_id')
BEGIN
    CREATE INDEX ix_bed_hospital_id ON hosp.bed (hospital_id);
    PRINT 'Created index: ix_bed_hospital_id';
END
GO

-- ------------------------------------------------------------
--  hosp.icu_status
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'hosp' AND t.name = 'icu_status')
BEGIN
    CREATE TABLE hosp.icu_status (
        icu_status_id   VARCHAR(9)  NOT NULL,
        hospital_id     VARCHAR(4)  NOT NULL,
        occupied_beds   INT         NOT NULL
            CONSTRAINT chk_icu_status_occupied_beds  CHECK (occupied_beds  >= 0),
        available_beds  INT         NOT NULL
            CONSTRAINT chk_icu_status_available_beds CHECK (available_beds >= 0),
        update_time     DATETIME2   NOT NULL,

        CONSTRAINT pk_icu_status PRIMARY KEY (icu_status_id),
        CONSTRAINT fk_icu_status_hospital
            FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id)
    );
    PRINT 'Created: hosp.icu_status';
END
ELSE
    PRINT 'Skipped (exists): hosp.icu_status';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_icu_status_hospital_id')
BEGIN
    CREATE INDEX ix_icu_status_hospital_id ON hosp.icu_status (hospital_id);
    PRINT 'Created index: ix_icu_status_hospital_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_icu_status_update_time')
BEGIN
    CREATE INDEX ix_icu_status_update_time ON hosp.icu_status (update_time);
    PRINT 'Created index: ix_icu_status_update_time';
END
GO

-- ============================================================
--  STEP 6 — PATIENTS  (schema: pat)
-- ============================================================

-- ------------------------------------------------------------
--  pat.patient
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'pat' AND t.name = 'patient')
BEGIN
    CREATE TABLE pat.patient (
        patient_id          VARCHAR(12)  NOT NULL,
        national_id         NUMERIC      NOT NULL,
        first_name          VARCHAR(50)  NOT NULL,
        last_name           VARCHAR(50)  NOT NULL,
        gender              VARCHAR(6)   NOT NULL
            CONSTRAINT chk_patient_gender CHECK (gender IN ('Male','Female')),
        birth_date          DATE         NOT NULL,
        phone               NUMERIC      NULL,
        street              VARCHAR(150) NULL,
        city                VARCHAR(20)  NULL,
        governorate         VARCHAR(20)  NOT NULL
            CONSTRAINT df_patient_governorate DEFAULT 'Port Said',
        blood_type          VARCHAR(3)   NULL
            CONSTRAINT chk_patient_blood_type CHECK (blood_type IN (
                'A+','A-','B+','B-','AB+','AB-','O+','O-'
            )),
        emergency_contact   NUMERIC      NULL,

        CONSTRAINT pk_patient             PRIMARY KEY (patient_id),
        CONSTRAINT uq_patient_national_id UNIQUE (national_id)
    );
    PRINT 'Created: pat.patient';
END
ELSE
    PRINT 'Skipped (exists): pat.patient';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_patient_last_name_first_name')
BEGIN
    CREATE INDEX ix_patient_last_name_first_name ON pat.patient (last_name, first_name);
    PRINT 'Created index: ix_patient_last_name_first_name';
END
GO

-- ============================================================
--  STEP 7 — PHARMACY & INVENTORY  (schema: inv)
-- ============================================================

-- ------------------------------------------------------------
--  inv.drug_inventory
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'inv' AND t.name = 'drug_inventory')
BEGIN
    CREATE TABLE inv.drug_inventory (
        inventory_id        VARCHAR(9)  NOT NULL,
        hospital_id         VARCHAR(4)  NOT NULL,
        drug_id             VARCHAR(5)  NOT NULL,
        quantity_available  INT         NOT NULL
            CONSTRAINT chk_drug_inventory_quantity_available CHECK (quantity_available >= 0),
        reorder_level       INT         NOT NULL
            CONSTRAINT chk_drug_inventory_reorder_level      CHECK (reorder_level      >= 0),
        expiration_date     DATE        NULL,

        CONSTRAINT pk_drug_inventory               PRIMARY KEY (inventory_id),
        CONSTRAINT uq_drug_inventory_hospital_drug UNIQUE (hospital_id, drug_id),
        CONSTRAINT fk_drug_inventory_hospital
            FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id),
        CONSTRAINT fk_drug_inventory_drug
            FOREIGN KEY (drug_id)     REFERENCES ref.drug      (drug_id)
    );
    PRINT 'Created: inv.drug_inventory';
END
ELSE
    PRINT 'Skipped (exists): inv.drug_inventory';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_drug_inventory_hospital_id')
BEGIN
    CREATE INDEX ix_drug_inventory_hospital_id ON inv.drug_inventory (hospital_id);
    PRINT 'Created index: ix_drug_inventory_hospital_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_drug_inventory_drug_id')
BEGIN
    CREATE INDEX ix_drug_inventory_drug_id ON inv.drug_inventory (drug_id);
    PRINT 'Created index: ix_drug_inventory_drug_id';
END
GO

-- ------------------------------------------------------------
--  inv.drug_transaction
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'inv' AND t.name = 'drug_transaction')
BEGIN
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
    PRINT 'Created: inv.drug_transaction';
END
ELSE
    PRINT 'Skipped (exists): inv.drug_transaction';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_drug_transaction_drug_id')
BEGIN
    CREATE INDEX ix_drug_transaction_drug_id ON inv.drug_transaction (drug_id);
    PRINT 'Created index: ix_drug_transaction_drug_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_drug_transaction_hospital_id')
BEGIN
    CREATE INDEX ix_drug_transaction_hospital_id ON inv.drug_transaction (hospital_id);
    PRINT 'Created index: ix_drug_transaction_hospital_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_drug_transaction_transaction_date')
BEGIN
    CREATE INDEX ix_drug_transaction_transaction_date ON inv.drug_transaction (transaction_date);
    PRINT 'Created index: ix_drug_transaction_transaction_date';
END
GO

-- ============================================================
--  STEP 8 — VISITS — central FACT table  (schema: clin)
-- ============================================================

-- ------------------------------------------------------------
--  clin.visit
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'clin' AND t.name = 'visit')
BEGIN
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
        waiting_time    INT           NULL,
        total_amount    DECIMAL(10,2) NULL,

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
    PRINT 'Created: clin.visit';
END
ELSE
    PRINT 'Skipped (exists): clin.visit';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_visit_patient_id')
BEGIN
    CREATE INDEX ix_visit_patient_id ON clin.visit (patient_id);
    PRINT 'Created index: ix_visit_patient_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_visit_hospital_id')
BEGIN
    CREATE INDEX ix_visit_hospital_id ON clin.visit (hospital_id);
    PRINT 'Created index: ix_visit_hospital_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_visit_doctor_id')
BEGIN
    CREATE INDEX ix_visit_doctor_id ON clin.visit (doctor_id);
    PRINT 'Created index: ix_visit_doctor_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_visit_visit_date')
BEGIN
    CREATE INDEX ix_visit_visit_date ON clin.visit (visit_date);
    PRINT 'Created index: ix_visit_visit_date';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_visit_visit_status')
BEGIN
    CREATE INDEX ix_visit_visit_status ON clin.visit (visit_status);
    PRINT 'Created index: ix_visit_visit_status';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_visit_diagnosis_code')
BEGIN
    CREATE INDEX ix_visit_diagnosis_code ON clin.visit (diagnosis_code);
    PRINT 'Created index: ix_visit_diagnosis_code';
END
GO

-- ============================================================
--  STEP 9 — VISIT DETAILS  (schema: clin)
-- ============================================================

-- ------------------------------------------------------------
--  clin.medical_record
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'clin' AND t.name = 'medical_record')
BEGIN
    CREATE TABLE clin.medical_record (
        record_id           VARCHAR(12)  NOT NULL,
        visit_id            VARCHAR(12)  NOT NULL,
        procedure_code      VARCHAR(4)   NULL,
        diagnosis_notes     VARCHAR(300) NULL,
        treatment_notes     VARCHAR(200) NULL,
        follow_up_required  VARCHAR(3)   NOT NULL
            CONSTRAINT chk_medical_record_follow_up_required CHECK (follow_up_required IN ('Yes','No')),

        CONSTRAINT pk_medical_record          PRIMARY KEY (record_id),
        CONSTRAINT uq_medical_record_visit_id UNIQUE (visit_id),
        CONSTRAINT fk_medical_record_visit
            FOREIGN KEY (visit_id) REFERENCES clin.visit (visit_id)
    );
    PRINT 'Created: clin.medical_record';
END
ELSE
    PRINT 'Skipped (exists): clin.medical_record';
GO

-- ------------------------------------------------------------
--  clin.visit_procedure
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'clin' AND t.name = 'visit_procedure')
BEGIN
    CREATE TABLE clin.visit_procedure (
        visit_procedure_id  VARCHAR(12)   NOT NULL,
        visit_id            VARCHAR(12)   NOT NULL,
        procedure_code      VARCHAR(4)    NOT NULL,
        procedure_amount    DECIMAL(10,2) NOT NULL
            CONSTRAINT chk_visit_procedure_procedure_amount CHECK (procedure_amount >= 0),
        procedure_date      DATE          NOT NULL,

        CONSTRAINT pk_visit_procedure PRIMARY KEY (visit_procedure_id),
        CONSTRAINT fk_visit_procedure_visit
            FOREIGN KEY (visit_id)       REFERENCES clin.visit            (visit_id),
        CONSTRAINT fk_visit_procedure_procedure
            FOREIGN KEY (procedure_code) REFERENCES ref.medical_procedure (procedure_code)
    );
    PRINT 'Created: clin.visit_procedure';
END
ELSE
    PRINT 'Skipped (exists): clin.visit_procedure';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_visit_procedure_visit_id')
BEGIN
    CREATE INDEX ix_visit_procedure_visit_id ON clin.visit_procedure (visit_id);
    PRINT 'Created index: ix_visit_procedure_visit_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_visit_procedure_procedure_code')
BEGIN
    CREATE INDEX ix_visit_procedure_procedure_code ON clin.visit_procedure (procedure_code);
    PRINT 'Created index: ix_visit_procedure_procedure_code';
END
GO

-- ============================================================
--  STEP 10 — PRESCRIPTIONS  (schema: clin)
-- ============================================================

-- ------------------------------------------------------------
--  clin.prescription
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'clin' AND t.name = 'prescription')
BEGIN
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
    PRINT 'Created: clin.prescription';
END
ELSE
    PRINT 'Skipped (exists): clin.prescription';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_prescription_visit_id')
BEGIN
    CREATE INDEX ix_prescription_visit_id ON clin.prescription (visit_id);
    PRINT 'Created index: ix_prescription_visit_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_prescription_doctor_id')
BEGIN
    CREATE INDEX ix_prescription_doctor_id ON clin.prescription (doctor_id);
    PRINT 'Created index: ix_prescription_doctor_id';
END
GO

-- ------------------------------------------------------------
--  clin.prescription_item
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'clin' AND t.name = 'prescription_item')
BEGIN
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
    PRINT 'Created: clin.prescription_item';
END
ELSE
    PRINT 'Skipped (exists): clin.prescription_item';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_prescription_item_prescription_id')
BEGIN
    CREATE INDEX ix_prescription_item_prescription_id ON clin.prescription_item (prescription_id);
    PRINT 'Created index: ix_prescription_item_prescription_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_prescription_item_drug_id')
BEGIN
    CREATE INDEX ix_prescription_item_drug_id ON clin.prescription_item (drug_id);
    PRINT 'Created index: ix_prescription_item_drug_id';
END
GO

-- ============================================================
--  STEP 11 — REFERRALS  (schema: hosp)
-- ============================================================

-- ------------------------------------------------------------
--  hosp.referral
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'hosp' AND t.name = 'referral')
BEGIN
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
    PRINT 'Created: hosp.referral';
END
ELSE
    PRINT 'Skipped (exists): hosp.referral';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_referral_patient_id')
BEGIN
    CREATE INDEX ix_referral_patient_id ON hosp.referral (patient_id);
    PRINT 'Created index: ix_referral_patient_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_referral_from_hospital_id')
BEGIN
    CREATE INDEX ix_referral_from_hospital_id ON hosp.referral (from_hospital_id);
    PRINT 'Created index: ix_referral_from_hospital_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_referral_to_hospital_id')
BEGIN
    CREATE INDEX ix_referral_to_hospital_id ON hosp.referral (to_hospital_id);
    PRINT 'Created index: ix_referral_to_hospital_id';
END
GO

-- ============================================================
--  STEP 12 — INSURANCE CLAIMS  (schema: fin)
-- ============================================================

-- ------------------------------------------------------------
--  fin.claim
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'fin' AND t.name = 'claim')
BEGIN
    CREATE TABLE fin.claim (
        claim_id        VARCHAR(12)   NOT NULL,
        patient_id      VARCHAR(12)   NOT NULL,
        visit_id        VARCHAR(12)   NOT NULL,
        hospital_id     VARCHAR(4)    NOT NULL,
        claim_date      DATE          NOT NULL,
        claim_amount    DECIMAL(10,2) NOT NULL
            CONSTRAINT chk_claim_claim_amount CHECK (claim_amount >= 0),
        approved_amount DECIMAL(10,2) NULL,
        claim_status    VARCHAR(20)   NOT NULL
            CONSTRAINT chk_claim_claim_status CHECK (claim_status IN (
                'Approved','Partially Approved','Rejected','Pending Review'
            )),

        CONSTRAINT pk_claim           PRIMARY KEY (claim_id),
        CONSTRAINT uq_claim_visit_id  UNIQUE (visit_id),
        CONSTRAINT fk_claim_patient
            FOREIGN KEY (patient_id)  REFERENCES pat.patient   (patient_id),
        CONSTRAINT fk_claim_visit
            FOREIGN KEY (visit_id)    REFERENCES clin.visit    (visit_id),
        CONSTRAINT fk_claim_hospital
            FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id)
    );
    PRINT 'Created: fin.claim';
END
ELSE
    PRINT 'Skipped (exists): fin.claim';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_claim_patient_id')
BEGIN
    CREATE INDEX ix_claim_patient_id ON fin.claim (patient_id);
    PRINT 'Created index: ix_claim_patient_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_claim_hospital_id')
BEGIN
    CREATE INDEX ix_claim_hospital_id ON fin.claim (hospital_id);
    PRINT 'Created index: ix_claim_hospital_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_claim_claim_date')
BEGIN
    CREATE INDEX ix_claim_claim_date ON fin.claim (claim_date);
    PRINT 'Created index: ix_claim_claim_date';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_claim_claim_status')
BEGIN
    CREATE INDEX ix_claim_claim_status ON fin.claim (claim_status);
    PRINT 'Created index: ix_claim_claim_status';
END
GO

-- ------------------------------------------------------------
--  fin.claim_item
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'fin' AND t.name = 'claim_item')
BEGIN
    CREATE TABLE fin.claim_item (
        claim_item_id   VARCHAR(12)   NOT NULL,
        claim_id        VARCHAR(12)   NOT NULL,
        procedure_code  VARCHAR(4)    NULL,
        drug_id         VARCHAR(5)    NULL,
        item_amount     DECIMAL(10,2) NULL
            CONSTRAINT chk_claim_item_item_amount CHECK (item_amount >= 0),
        quantity        INT           NULL
            CONSTRAINT chk_claim_item_quantity CHECK (quantity > 0),
        CONSTRAINT chk_claim_item_procedure_or_drug CHECK (
            (procedure_code IS NOT NULL AND drug_id IS NULL) OR
            (procedure_code IS NULL     AND drug_id IS NOT NULL)
        ),

        CONSTRAINT pk_claim_item PRIMARY KEY (claim_item_id),
        CONSTRAINT fk_claim_item_claim
            FOREIGN KEY (claim_id)       REFERENCES fin.claim             (claim_id),
        CONSTRAINT fk_claim_item_procedure
            FOREIGN KEY (procedure_code) REFERENCES ref.medical_procedure (procedure_code),
        CONSTRAINT fk_claim_item_drug
            FOREIGN KEY (drug_id)        REFERENCES ref.drug              (drug_id)
    );
    PRINT 'Created: fin.claim_item';
END
ELSE
    PRINT 'Skipped (exists): fin.claim_item';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_claim_item_claim_id')
BEGIN
    CREATE INDEX ix_claim_item_claim_id ON fin.claim_item (claim_id);
    PRINT 'Created index: ix_claim_item_claim_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_claim_item_procedure_code')
BEGIN
    CREATE INDEX ix_claim_item_procedure_code ON fin.claim_item (procedure_code);
    PRINT 'Created index: ix_claim_item_procedure_code';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_claim_item_drug_id')
BEGIN
    CREATE INDEX ix_claim_item_drug_id ON fin.claim_item (drug_id);
    PRINT 'Created index: ix_claim_item_drug_id';
END
GO

-- ------------------------------------------------------------
--  fin.claim_approval
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'fin' AND t.name = 'claim_approval')
BEGIN
    CREATE TABLE fin.claim_approval (
        approval_id         VARCHAR(12) NOT NULL,
        claim_id            VARCHAR(12) NOT NULL,
        reviewed_by         VARCHAR(50) NOT NULL,
        approval_status     VARCHAR(20) NOT NULL
            CONSTRAINT chk_claim_approval_approval_status CHECK (approval_status IN (
                'Approved','Partially Approved','Rejected','Pending Review'
            )),
        approval_date       DATE        NULL,
        rejection_reason    VARCHAR(80) NULL,

        CONSTRAINT pk_claim_approval          PRIMARY KEY (approval_id),
        CONSTRAINT uq_claim_approval_claim_id UNIQUE (claim_id),
        CONSTRAINT fk_claim_approval_claim
            FOREIGN KEY (claim_id) REFERENCES fin.claim (claim_id)
    );
    PRINT 'Created: fin.claim_approval';
END
ELSE
    PRINT 'Skipped (exists): fin.claim_approval';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_claim_approval_claim_id')
BEGIN
    CREATE INDEX ix_claim_approval_claim_id ON fin.claim_approval (claim_id);
    PRINT 'Created index: ix_claim_approval_claim_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_claim_approval_approval_status')
BEGIN
    CREATE INDEX ix_claim_approval_approval_status ON fin.claim_approval (approval_status);
    PRINT 'Created index: ix_claim_approval_approval_status';
END
GO

-- ============================================================
--  STEP 13 — CITIZEN SERVICES  (schema: svc)
-- ============================================================

-- ------------------------------------------------------------
--  svc.patient_feedback
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'svc' AND t.name = 'patient_feedback')
BEGIN
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
    PRINT 'Created: svc.patient_feedback';
END
ELSE
    PRINT 'Skipped (exists): svc.patient_feedback';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_patient_feedback_patient_id')
BEGIN
    CREATE INDEX ix_patient_feedback_patient_id ON svc.patient_feedback (patient_id);
    PRINT 'Created index: ix_patient_feedback_patient_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_patient_feedback_hospital_id')
BEGIN
    CREATE INDEX ix_patient_feedback_hospital_id ON svc.patient_feedback (hospital_id);
    PRINT 'Created index: ix_patient_feedback_hospital_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_patient_feedback_doctor_id')
BEGIN
    CREATE INDEX ix_patient_feedback_doctor_id ON svc.patient_feedback (doctor_id);
    PRINT 'Created index: ix_patient_feedback_doctor_id';
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_patient_feedback_feedback_date')
BEGIN
    CREATE INDEX ix_patient_feedback_feedback_date ON svc.patient_feedback (feedback_date);
    PRINT 'Created index: ix_patient_feedback_feedback_date';
END
GO

PRINT '============================================================';
PRINT ' uhip_db Azure DDL complete — idempotent run finished';
PRINT ' 22 tables | 7 schemas | all constraints named';
PRINT ' Each object printed Created or Skipped (exists)';
PRINT '============================================================';
GO
