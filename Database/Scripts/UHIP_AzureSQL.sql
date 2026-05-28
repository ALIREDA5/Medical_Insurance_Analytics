-- ============================================================
--  UHIP — Unified Healthcare Intelligence Platform
--  Azure SQL Database — Production Edition
--  Port Said Governorate, Egypt
--
--  Compatibility notes
--  ───────────────────
--  • Targets Azure SQL Database (DTU / vCore).
--  • No USE [db] — connect to the target database before running.
--  • SET options are placed per-batch (before each DDL object)
--    so they are recorded in syscomments / sys.sql_modules
--    exactly as Azure SQL requires for schema-bound objects.
--  • ROWVERSION is declared without DEFAULT (Azure SQL rule).
--  • BULK INSERT block uses BLOB_STORAGE data source pattern.
--  • All identifiers are schema-qualified throughout.
-- ============================================================

-- ============================================================
--  SCHEMAS
--  Each CREATE SCHEMA must be the sole statement in its batch.
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
--  REFERENCE TABLES
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ref.diagnosis
IF OBJECT_ID('ref.diagnosis', 'U') IS NULL
BEGIN
    CREATE TABLE ref.diagnosis (
        diagnosis_code      VARCHAR(4)    NOT NULL,
        diagnosis_name      VARCHAR(100)  NOT NULL,
        diagnosis_category  VARCHAR(30)   NOT NULL
            CONSTRAINT chk_diagnosis_category CHECK (
                diagnosis_category IN (
                    'Cardiovascular', 'Respiratory',   'Endocrine',
                    'Gastrointestinal','Neurological',  'Urological',
                    'Musculoskeletal', 'Trauma',        'Infectious',
                    'Hematological',   'Mental Health', 'Skin',
                    'ENT',             'Pediatric'
                )
            ),
        severity_level      VARCHAR(10)   NOT NULL
            CONSTRAINT chk_diagnosis_severity CHECK (
                severity_level IN ('Mild','Moderate','Severe','Critical','Chronic')
            ),

        CONSTRAINT pk_diagnosis PRIMARY KEY CLUSTERED (diagnosis_code)
    );
END;
GO

-- ref.medical_procedure
IF OBJECT_ID('ref.medical_procedure', 'U') IS NULL
BEGIN
    CREATE TABLE ref.medical_procedure (
        procedure_code      VARCHAR(4)    NOT NULL,
        procedure_name      VARCHAR(120)  NOT NULL,
        procedure_category  VARCHAR(30)   NOT NULL,
        expected_amount     DECIMAL(10,2) NOT NULL
            CONSTRAINT chk_procedure_expected_amount CHECK (expected_amount >= 0),
        complexity_score    TINYINT       NOT NULL
            CONSTRAINT chk_procedure_complexity   CHECK (complexity_score BETWEEN 1 AND 5),

        CONSTRAINT pk_procedure PRIMARY KEY CLUSTERED (procedure_code)
    );
END;
GO

-- ref.drug
IF OBJECT_ID('ref.drug', 'U') IS NULL
BEGIN
    CREATE TABLE ref.drug (
        drug_id         VARCHAR(5)    NOT NULL,
        drug_name       VARCHAR(80)   NOT NULL,
        generic_name    VARCHAR(60)   NOT NULL,
        manufacturer    VARCHAR(50)   NOT NULL,
        drug_category   VARCHAR(30)   NOT NULL,
        unit_amount     DECIMAL(8,2)  NOT NULL
            CONSTRAINT chk_drug_unit_amount CHECK (unit_amount >= 0),

        CONSTRAINT pk_drug PRIMARY KEY CLUSTERED (drug_id)
    );
END;
GO

-- ============================================================
--  HOSPITAL
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('hosp.hospital', 'U') IS NULL
BEGIN
    CREATE TABLE hosp.hospital (
        hospital_id     VARCHAR(4)    NOT NULL,
        hospital_name   VARCHAR(80)   NOT NULL,
        hospital_type   VARCHAR(15)   NOT NULL,
        governorate     VARCHAR(20)   NOT NULL
            CONSTRAINT df_hospital_governorate DEFAULT 'Port Said',
        district        VARCHAR(25)   NOT NULL,
        phone           VARCHAR(20)   NULL,
        total_beds      INT           NOT NULL,
        icu_capacity    INT           NOT NULL,
        longitude       DECIMAL(9,6)  NULL,
        latitude        DECIMAL(9,6)  NULL,
        manager_name    VARCHAR(100)  NULL,
        manager_email   VARCHAR(150)  NULL,
        manager_phone   VARCHAR(20)   NULL,

        CONSTRAINT pk_hospital PRIMARY KEY CLUSTERED (hospital_id)
    );
END;
GO

IF OBJECT_ID('hosp.department', 'U') IS NULL
BEGIN
    CREATE TABLE hosp.department (
        department_id   VARCHAR(8)    NOT NULL,
        hospital_id     VARCHAR(4)    NOT NULL,
        department_name VARCHAR(40)   NOT NULL,
        floor_number    VARCHAR(2)    NOT NULL,
        manager_name    VARCHAR(100)  NULL,
        manager_email   VARCHAR(150)  NULL,
        manager_phone   VARCHAR(20)   NULL,

        CONSTRAINT pk_department PRIMARY KEY CLUSTERED (department_id),
        CONSTRAINT fk_department_hospital
            FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id)
    );
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('hosp.department') AND name = 'ix_department_hospital_id'
)
    CREATE INDEX ix_department_hospital_id ON hosp.department (hospital_id);
GO

IF OBJECT_ID('hosp.doctor', 'U') IS NULL
BEGIN
    CREATE TABLE hosp.doctor (
        doctor_id           VARCHAR(7)   NOT NULL,
        hospital_id         VARCHAR(4)   NOT NULL,
        department_id       VARCHAR(8)   NOT NULL,
        first_name          VARCHAR(50)  NOT NULL,
        last_name           VARCHAR(50)  NOT NULL,
        specialty           VARCHAR(40)  NOT NULL,
        years_experience    INT          NOT NULL,
        phone               VARCHAR(20)  NULL,
        employment_status   VARCHAR(10)  NOT NULL,

        CONSTRAINT pk_doctor PRIMARY KEY CLUSTERED (doctor_id),
        CONSTRAINT fk_doctor_hospital
            FOREIGN KEY (hospital_id)   REFERENCES hosp.hospital   (hospital_id),
        CONSTRAINT fk_doctor_department
            FOREIGN KEY (department_id) REFERENCES hosp.department (department_id)
    );
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('hosp.doctor') AND name = 'ix_doctor_department_id'
)
    CREATE INDEX ix_doctor_department_id ON hosp.doctor (department_id);
GO

-- ============================================================
--  PATIENTS
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('pat.patient', 'U') IS NULL
BEGIN
    CREATE TABLE pat.patient (
        patient_id          VARCHAR(12)   NOT NULL,
        -- NUMERIC(14,0) stores the 14-digit Egyptian national ID exactly.
        national_id         NUMERIC(14,0) NOT NULL,
        first_name          VARCHAR(50)   NOT NULL,
        last_name           VARCHAR(50)   NOT NULL,
        gender              VARCHAR(6)    NOT NULL
            CONSTRAINT chk_patient_gender CHECK (gender IN ('Male','Female')),
        birth_date          DATE          NOT NULL,
        phone               VARCHAR(20)   NULL,
        street              VARCHAR(150)  NULL,
        city                VARCHAR(20)   NULL,
        governorate         VARCHAR(20)   NOT NULL
            CONSTRAINT df_patient_governorate DEFAULT 'Port Said',
        blood_type          VARCHAR(3)    NULL,
        emergency_contact   VARCHAR(20)   NULL,

        CONSTRAINT pk_patient          PRIMARY KEY CLUSTERED (patient_id),
        CONSTRAINT uq_patient_national UNIQUE (national_id)
    );
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('pat.patient') AND name = 'ix_patient_name'
)
    CREATE INDEX ix_patient_name ON pat.patient (last_name, first_name);
GO

-- ============================================================
--  INVENTORY
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('inv.drug_inventory', 'U') IS NULL
BEGIN
    CREATE TABLE inv.drug_inventory (
        inventory_id        VARCHAR(9)  NOT NULL,
        hospital_id         VARCHAR(4)  NOT NULL,
        drug_id             VARCHAR(5)  NOT NULL,
        quantity_available  INT         NOT NULL,
        reorder_level       INT         NOT NULL,
        expiration_date     DATE        NULL,

        CONSTRAINT pk_drug_inventory           PRIMARY KEY CLUSTERED (inventory_id),
        CONSTRAINT uq_drug_inventory_hosp_drug UNIQUE (hospital_id, drug_id),
        CONSTRAINT fk_inventory_hospital
            FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id),
        CONSTRAINT fk_inventory_drug
            FOREIGN KEY (drug_id)     REFERENCES ref.drug       (drug_id)
    );
END;
GO

-- ============================================================
--  CLINICAL — VISITS
--  ROWVERSION: Azure SQL does not allow a DEFAULT on rowversion;
--  the engine populates it automatically on every INSERT/UPDATE.
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('clin.visit', 'U') IS NULL
BEGIN
    CREATE TABLE clin.visit (
        visit_id        VARCHAR(12)   NOT NULL,
        patient_id      VARCHAR(12)   NOT NULL,
        hospital_id     VARCHAR(4)    NOT NULL,
        doctor_id       VARCHAR(7)    NOT NULL,
        department_id   VARCHAR(8)    NOT NULL,
        visit_date      DATE          NOT NULL,
        visit_type      VARCHAR(15)   NOT NULL,
        diagnosis_code  VARCHAR(4)    NOT NULL,
        symptoms        VARCHAR(100)  NULL,
        visit_status    VARCHAR(10)   NOT NULL,
        waiting_time    INT           NULL,
        total_amount    DECIMAL(10,2) NULL,
        -- ROWVERSION is auto-maintained; no DEFAULT permitted in Azure SQL.
        row_version     ROWVERSION    NOT NULL,

        CONSTRAINT pk_visit PRIMARY KEY CLUSTERED (visit_id),
        CONSTRAINT fk_visit_patient
            FOREIGN KEY (patient_id)    REFERENCES pat.patient       (patient_id),
        CONSTRAINT fk_visit_hospital
            FOREIGN KEY (hospital_id)   REFERENCES hosp.hospital     (hospital_id),
        CONSTRAINT fk_visit_doctor
            FOREIGN KEY (doctor_id)     REFERENCES hosp.doctor       (doctor_id),
        CONSTRAINT fk_visit_department
            FOREIGN KEY (department_id) REFERENCES hosp.department   (department_id),
        CONSTRAINT fk_visit_diagnosis
            FOREIGN KEY (diagnosis_code) REFERENCES ref.diagnosis    (diagnosis_code)
    );
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('clin.visit') AND name = 'ix_visit_patient_id'
)
    CREATE INDEX ix_visit_patient_id ON clin.visit (patient_id);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('clin.visit') AND name = 'ix_visit_hospital_id'
)
    CREATE INDEX ix_visit_hospital_id ON clin.visit (hospital_id);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('clin.visit') AND name = 'ix_visit_visit_date'
)
    CREATE INDEX ix_visit_visit_date ON clin.visit (visit_date);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('clin.visit') AND name = 'ix_visit_analytics'
)
    CREATE NONCLUSTERED INDEX ix_visit_analytics
    ON clin.visit (visit_date, hospital_id, diagnosis_code);
GO

-- ============================================================
--  PRESCRIPTIONS
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('clin.prescription', 'U') IS NULL
BEGIN
    CREATE TABLE clin.prescription (
        prescription_id     VARCHAR(12)  NOT NULL,
        visit_id            VARCHAR(12)  NOT NULL,
        doctor_id           VARCHAR(7)   NOT NULL,
        prescription_date   DATE         NOT NULL,
        notes               VARCHAR(100) NULL,

        CONSTRAINT pk_prescription PRIMARY KEY CLUSTERED (prescription_id),
        CONSTRAINT fk_prescription_visit
            FOREIGN KEY (visit_id)  REFERENCES clin.visit  (visit_id),
        CONSTRAINT fk_prescription_doctor
            FOREIGN KEY (doctor_id) REFERENCES hosp.doctor (doctor_id)
    );
END;
GO

IF OBJECT_ID('clin.prescription_item', 'U') IS NULL
BEGIN
    CREATE TABLE clin.prescription_item (
        prescription_item_id VARCHAR(12) NOT NULL,
        prescription_id      VARCHAR(12) NOT NULL,
        drug_id              VARCHAR(5)  NOT NULL,
        dosage               VARCHAR(10) NOT NULL,
        frequency            VARCHAR(25) NOT NULL,
        duration_days        INT         NOT NULL,
        quantity             INT         NOT NULL,

        CONSTRAINT pk_prescription_item PRIMARY KEY CLUSTERED (prescription_item_id),
        CONSTRAINT fk_presc_item_prescription
            FOREIGN KEY (prescription_id) REFERENCES clin.prescription (prescription_id),
        CONSTRAINT fk_presc_item_drug
            FOREIGN KEY (drug_id)         REFERENCES ref.drug           (drug_id)
    );
END;
GO

-- ============================================================
--  CLAIMS
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('fin.claim', 'U') IS NULL
BEGIN
    CREATE TABLE fin.claim (
        claim_id        VARCHAR(12)   NOT NULL,
        patient_id      VARCHAR(12)   NOT NULL,
        visit_id        VARCHAR(12)   NOT NULL,
        hospital_id     VARCHAR(4)    NOT NULL,
        claim_date      DATE          NOT NULL,
        claim_amount    DECIMAL(10,2) NOT NULL,
        approved_amount DECIMAL(10,2) NULL,
        claim_status    VARCHAR(20)   NOT NULL,

        CONSTRAINT pk_claim          PRIMARY KEY CLUSTERED (claim_id),
        CONSTRAINT uq_claim_visit_id UNIQUE (visit_id),
        CONSTRAINT fk_claim_patient
            FOREIGN KEY (patient_id) REFERENCES pat.patient     (patient_id),
        CONSTRAINT fk_claim_visit
            FOREIGN KEY (visit_id)   REFERENCES clin.visit      (visit_id),
        CONSTRAINT fk_claim_hospital
            FOREIGN KEY (hospital_id) REFERENCES hosp.hospital  (hospital_id)
    );
END;
GO

-- ============================================================
--  FEEDBACK
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('svc.patient_feedback', 'U') IS NULL
BEGIN
    CREATE TABLE svc.patient_feedback (
        feedback_id     VARCHAR(12)  NOT NULL,
        patient_id      VARCHAR(12)  NOT NULL,
        hospital_id     VARCHAR(4)   NOT NULL,
        doctor_id       VARCHAR(7)   NOT NULL,
        -- TINYINT covers 0-255; add a CHECK if you want to enforce 1-5 stars.
        rating          TINYINT      NOT NULL
            CONSTRAINT chk_feedback_rating CHECK (rating BETWEEN 1 AND 5),
        comments        VARCHAR(200) NULL,
        feedback_date   DATE         NOT NULL,

        CONSTRAINT pk_patient_feedback PRIMARY KEY CLUSTERED (feedback_id),
        CONSTRAINT fk_feedback_patient
            FOREIGN KEY (patient_id)  REFERENCES pat.patient   (patient_id),
        CONSTRAINT fk_feedback_hospital
            FOREIGN KEY (hospital_id) REFERENCES hosp.hospital (hospital_id),
        CONSTRAINT fk_feedback_doctor
            FOREIGN KEY (doctor_id)   REFERENCES hosp.doctor   (doctor_id)
    );
END;
GO

-- ============================================================
--  VIEWS
--  SET options must be ON in the same batch as CREATE VIEW
--  so that the options are stored correctly in sys.sql_modules.
-- ============================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.vw_visit_detail', 'V') IS NOT NULL
    DROP VIEW dbo.vw_visit_detail;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE VIEW dbo.vw_visit_detail
AS
SELECT
    v.visit_id,
    v.visit_date,
    v.visit_type,
    v.visit_status,
    v.waiting_time,
    v.total_amount,
    p.patient_id,
    p.first_name + ' ' + p.last_name   AS patient_name,
    h.hospital_name,
    doc.first_name + ' ' + doc.last_name AS doctor_name,
    diag.diagnosis_name,
    diag.severity_level
FROM       clin.visit         v
INNER JOIN pat.patient         p    ON v.patient_id    = p.patient_id
INNER JOIN hosp.hospital       h    ON v.hospital_id   = h.hospital_id
INNER JOIN hosp.doctor         doc  ON v.doctor_id     = doc.doctor_id
INNER JOIN ref.diagnosis       diag ON v.diagnosis_code = diag.diagnosis_code;
GO

IF OBJECT_ID('dbo.vw_inventory_alert', 'V') IS NOT NULL
    DROP VIEW dbo.vw_inventory_alert;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE VIEW dbo.vw_inventory_alert
AS
SELECT
    i.inventory_id,
    h.hospital_name,
    d.drug_name,
    i.quantity_available,
    i.reorder_level,
    i.expiration_date,
    CASE
        WHEN i.quantity_available = 0                          THEN 'Stockout'
        WHEN i.quantity_available <= i.reorder_level           THEN 'Low Stock'
        ELSE                                                        'OK'
    END AS stock_status
FROM       inv.drug_inventory i
INNER JOIN hosp.hospital       h ON i.hospital_id = h.hospital_id
INNER JOIN ref.drug            d ON i.drug_id     = d.drug_id;
GO

-- ============================================================
--  AZURE BLOB STORAGE — BULK LOAD SUPPORT
--
--  Uncomment and replace the placeholder values before running.
--  Requires:  CONTROL DATABASE  permission.
--  SAS token must grant Read + List on the container.
-- ============================================================

/*
-- 1. Credential (created once per database)
IF NOT EXISTS (
    SELECT 1 FROM sys.database_scoped_credentials
    WHERE name = 'AzureBlobCredential'
)
BEGIN
    CREATE DATABASE SCOPED CREDENTIAL AzureBlobCredential
    WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
         SECRET   = '<YOUR_SAS_TOKEN_WITHOUT_LEADING_?>';
END;
GO

-- 2. External data source
IF NOT EXISTS (
    SELECT 1 FROM sys.external_data_sources
    WHERE name = 'UHIPBlobStorage'
)
BEGIN
    CREATE EXTERNAL DATA SOURCE UHIPBlobStorage
    WITH (
        TYPE       = BLOB_STORAGE,
        LOCATION   = 'https://<YOUR_STORAGE_ACCOUNT>.blob.core.windows.net/<YOUR_CONTAINER>',
        CREDENTIAL = AzureBlobCredential
    );
END;
GO

-- 3. Sample bulk loads  (adjust FIELDTERMINATOR / ROWTERMINATOR as needed)
BULK INSERT ref.diagnosis
FROM 'diagnosis.csv'
WITH (
    DATA_SOURCE      = 'UHIPBlobStorage',
    FORMAT           = 'CSV',
    FIRSTROW         = 2,
    FIELDTERMINATOR  = ',',
    ROWTERMINATOR    = '\n',
    TABLOCK
);
GO

BULK INSERT pat.patient
FROM 'patients.csv'
WITH (
    DATA_SOURCE      = 'UHIPBlobStorage',
    FORMAT           = 'CSV',
    FIRSTROW         = 2,
    FIELDTERMINATOR  = ',',
    ROWTERMINATOR    = '\n',
    TABLOCK
);
GO
*/

-- ============================================================
--  VERIFICATION
-- ============================================================

SELECT
    s.name  AS schema_name,
    t.name  AS table_name,
    SUM(p.rows) AS estimated_row_count
FROM sys.tables     t
JOIN sys.schemas    s ON t.schema_id  = s.schema_id
JOIN sys.partitions p ON t.object_id  = p.object_id
                      AND p.index_id IN (0, 1)   -- heap or clustered index
GROUP BY s.name, t.name
ORDER BY s.name, t.name;
GO

SELECT
    s.name  AS schema_name,
    v.name  AS view_name
FROM sys.views   v
JOIN sys.schemas s ON v.schema_id = s.schema_id
ORDER BY s.name, v.name;
GO

PRINT '============================================================';
PRINT 'UHIP Azure SQL deployment completed successfully.';
PRINT '============================================================';
GO
