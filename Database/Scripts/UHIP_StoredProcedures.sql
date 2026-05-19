-- ============================================================
--  UHIP — Unified Healthcare Intelligence Platform
--  Stored Procedures — SQL Server
--  Port Said Governorate | Graduation Project 2025
-- ============================================================

USE uhip_db;
GO

-- ============================================================
--  CATEGORY 1 — PATIENT MANAGEMENT
-- ============================================================

-- ------------------------------------------------------------
-- 1.1  GetPatientByNationalID
--      البحث عن مريض بالـ National ID
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetPatientByNationalID
    @NationalID VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        patient_id,
        first_name + ' ' + last_name   AS full_name,
        gender,
        birth_date,
        DATEDIFF(YEAR, birth_date, GETDATE()) AS age,
        phone,
        city,
        street,
        blood_type,
        emergency_contact
    FROM pat.patient
    WHERE national_id = @NationalID;

    IF @@ROWCOUNT = 0
        RAISERROR('No patient found with this National ID.', 16, 1);
END;
GO

EXEC dbo.GetPatientByNationalID @NationalID = '283072011376328';
go
-- ------------------------------------------------------------
-- 1.2  GetPatientFullHistory
--      كل زيارات + تشخيصات + وصفات لمريض معين
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetPatientFullHistory
    @PatientID VARCHAR(12)
AS
BEGIN
    SET NOCOUNT ON;

    -- زيارات + تشخيصات
    SELECT
        v.visit_id,
        v.visit_date,
        v.visit_type,
        v.visit_status,
        h.hospital_name,
        dep.department_name,
        doc.first_name + ' ' + doc.last_name   AS doctor_name,
        d.diagnosis_name,
        d.diagnosis_category,
        d.severity_level,
        v.symptoms,
        v.waiting_time,
        v.total_amount
    FROM clin.visit v
    JOIN hosp.hospital    h   ON v.hospital_id    = h.hospital_id
    JOIN hosp.department  dep ON v.department_id  = dep.department_id
    JOIN hosp.doctor      doc ON v.doctor_id      = doc.doctor_id
    JOIN ref.diagnosis    d   ON v.diagnosis_code = d.diagnosis_code
    WHERE v.patient_id = @PatientID
    ORDER BY v.visit_date DESC;

    -- وصفات
    SELECT
        p.prescription_id,
        p.prescription_date,
        pi.drug_id,
        dr.drug_name,
        dr.generic_name,
        pi.dosage,
        pi.frequency,
        pi.duration_days,
        pi.quantity
    FROM clin.prescription p
    JOIN clin.prescription_item pi ON p.prescription_id = pi.prescription_id
    JOIN ref.drug              dr ON pi.drug_id         = dr.drug_id
    WHERE p.visit_id IN (
        SELECT visit_id FROM clin.visit WHERE patient_id = @PatientID
    )
    ORDER BY p.prescription_date DESC;
END;
GO
EXEC dbo.GetPatientFullHistory @PatientID = 'PAT000001';
go
-- ------------------------------------------------------------
-- 1.3  GetHighRiskPatients
--      مرضى بأكتر من N زيارة بتشخيصات Severe أو Critical
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetHighRiskPatients
    @MinVisits      INT  = 3,
    @SeverityFilter VARCHAR(10) = 'Severe'   -- 'Severe' أو 'Critical'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.patient_id,
        p.first_name + ' ' + p.last_name   AS full_name,
        p.gender,
        DATEDIFF(YEAR, p.birth_date, GETDATE()) AS age,
        p.phone,
        COUNT(v.visit_id)                  AS total_visits,
        MAX(v.visit_date)                  AS last_visit
    FROM pat.patient p
    JOIN clin.visit    v ON p.patient_id    = v.patient_id
    JOIN ref.diagnosis d ON v.diagnosis_code = d.diagnosis_code
    WHERE d.severity_level = @SeverityFilter
      AND v.visit_status   = 'Completed'
    GROUP BY
        p.patient_id, p.first_name, p.last_name,
        p.gender, p.birth_date, p.phone
    HAVING COUNT(v.visit_id) >= @MinVisits
    ORDER BY total_visits DESC;
END;
GO
EXEC dbo.GetHighRiskPatients @MinVisits = 5, @SeverityFilter = 'Critical';
-- بالـ default values
EXEC dbo.GetHighRiskPatients;
go
-- ------------------------------------------------------------
-- 1.4  RegisterNewVisit
--      تسجيل زيارة جديدة مع validation
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.RegisterNewVisit
    @PatientID    VARCHAR(12),
    @HospitalID   VARCHAR(4),
    @DoctorID     VARCHAR(7),
    @DepartmentID VARCHAR(8),
    @DiagnosisCode VARCHAR(4),
    @VisitType    VARCHAR(15),
    @Symptoms     VARCHAR(100),
    @WaitingTime  INT          = NULL,
    @TotalCost    DECIMAL(10,2)= NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        -- validation: هل المريض موجود؟
        IF NOT EXISTS (SELECT 1 FROM pat.patient WHERE patient_id = @PatientID)
            RAISERROR('Patient not found.', 16, 1);

        -- validation: هل الدكتور Active؟
        IF NOT EXISTS (
            SELECT 1 FROM hosp.doctor
            WHERE doctor_id = @DoctorID AND employment_status = 'Active'
        )
            RAISERROR('Doctor is not active.', 16, 1);

        -- validation: هل الـ department تابع للـ hospital ده؟
        IF NOT EXISTS (
            SELECT 1 FROM hosp.department
            WHERE department_id = @DepartmentID AND hospital_id = @HospitalID
        )
            RAISERROR('Department does not belong to this hospital.', 16, 1);

        DECLARE @NewVisitID VARCHAR(12);
        SELECT @NewVisitID = 'VIS' + RIGHT('00000000' + CAST(
            ISNULL(MAX(CAST(SUBSTRING(visit_id,4,8) AS INT)),0) + 1
        AS VARCHAR), 8)
        FROM clin.visit;

        INSERT INTO clin.visit (
            visit_id, patient_id, hospital_id, doctor_id,
            department_id, visit_date, visit_type,
            diagnosis_code, symptoms, visit_status,
            waiting_time, total_amount
        )
        VALUES (
            @NewVisitID, @PatientID, @HospitalID, @DoctorID,
            @DepartmentID, CAST(GETDATE() AS DATE), @VisitType,
            @DiagnosisCode, @Symptoms, 'Completed',
            @WaitingTime, @TotalCost
        );

        SELECT @NewVisitID AS new_visit_id, 'Visit registered successfully.' AS message;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- ============================================================
--  CATEGORY 2 — HOSPITAL RESOURCES
-- ============================================================

-- ------------------------------------------------------------
-- 2.1  GetHospitalCapacityReport
--      نسبة إشغال الأسرة والـ ICU لكل مستشفى
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetHospitalCapacityReport
AS
BEGIN
    SET NOCOUNT ON;

    -- إشغال الأسرة العادية
    SELECT
        h.hospital_id,
        h.hospital_name,
        h.hospital_type,
        h.total_beds,
        COUNT(b.bed_id)                                          AS total_bed_records,
        SUM(CASE WHEN b.availability_status = 'Occupied'  THEN 1 ELSE 0 END) AS occupied_beds,
        SUM(CASE WHEN b.availability_status = 'Available' THEN 1 ELSE 0 END) AS available_beds,
        CAST(
            SUM(CASE WHEN b.availability_status = 'Occupied' THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(b.bed_id), 0)
        AS DECIMAL(5,1))                                         AS occupancy_pct,
        -- آخر snapshot للـ ICU
        i.occupied_beds  AS icu_occupied,
        i.available_beds AS icu_available,
        h.icu_capacity,
        CAST(i.occupied_beds * 100.0 / NULLIF(h.icu_capacity,0) AS DECIMAL(5,1)) AS icu_occupancy_pct
    FROM hosp.hospital h
    LEFT JOIN hosp.bed b ON h.hospital_id = b.hospital_id
    LEFT JOIN (
        SELECT hospital_id, occupied_beds, available_beds,
               ROW_NUMBER() OVER (PARTITION BY hospital_id ORDER BY update_time DESC) AS rn
        FROM hosp.icu_status
    ) i ON h.hospital_id = i.hospital_id AND i.rn = 1
    GROUP BY
        h.hospital_id, h.hospital_name, h.hospital_type,
        h.total_beds, h.icu_capacity,
        i.occupied_beds, i.available_beds
    ORDER BY occupancy_pct DESC;
END;
GO
EXEC dbo.GetHospitalCapacityReport;
go
-- ------------------------------------------------------------
-- 2.2  GetICUAlertHospitals
--      مستشفيات الـ ICU occupancy فيها فوق threshold
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetICUAlertHospitals
    @ThresholdPct DECIMAL(5,1) = 80.0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.hospital_id,
        h.hospital_name,
        h.district,
        h.icu_capacity,
        i.occupied_beds,
        i.available_beds,
        CAST(i.occupied_beds * 100.0 / NULLIF(h.icu_capacity,0) AS DECIMAL(5,1)) AS icu_occupancy_pct,
        i.update_time AS last_snapshot
    FROM hosp.hospital h
    JOIN (
        SELECT hospital_id, occupied_beds, available_beds, update_time,
               ROW_NUMBER() OVER (PARTITION BY hospital_id ORDER BY update_time DESC) AS rn
        FROM hosp.icu_status
    ) i ON h.hospital_id = i.hospital_id AND i.rn = 1
    WHERE CAST(i.occupied_beds * 100.0 / NULLIF(h.icu_capacity,0) AS DECIMAL(5,1)) >= @ThresholdPct
    ORDER BY icu_occupancy_pct DESC;
END;
GO
EXEC dbo.GetICUAlertHospitals @ThresholdPct = 90.0;
go
-- ------------------------------------------------------------
-- 2.3  GetDoctorWorkload
--      عدد زيارات + نسبة double shifts لكل دكتور
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetDoctorWorkload
    @HospitalID VARCHAR(4) = NULL,
    @StartDate  DATE       = NULL,
    @EndDate    DATE       = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @StartDate = ISNULL(@StartDate, DATEADD(MONTH,-1,GETDATE()));
    SET @EndDate   = ISNULL(@EndDate,   GETDATE());

    SELECT
        doc.doctor_id,
        doc.first_name + ' ' + doc.last_name AS doctor_name,
        doc.specialty,
        h.hospital_name,
        COUNT(DISTINCT v.visit_id)           AS total_visits,
        COUNT(DISTINCT s.schedule_id)        AS total_shifts,
        SUM(CASE WHEN s.shift_start = '08:00' AND
                      EXISTS (SELECT 1 FROM hosp.doctor_schedule s2
                              WHERE s2.doctor_id  = s.doctor_id
                                AND s2.shift_date = s.shift_date
                                AND s2.shift_start = '20:00')
             THEN 1 ELSE 0 END)              AS double_shift_days,
        CAST(
            SUM(CASE WHEN s.shift_start = '08:00' AND
                          EXISTS (SELECT 1 FROM hosp.doctor_schedule s2
                                  WHERE s2.doctor_id  = s.doctor_id
                                    AND s2.shift_date = s.shift_date
                                    AND s2.shift_start = '20:00')
                 THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(DISTINCT s.shift_date),0)
        AS DECIMAL(5,1))                     AS double_shift_pct
    FROM hosp.doctor doc
    JOIN hosp.department  dep ON doc.department_id = dep.department_id
    JOIN hosp.hospital    h   ON dep.hospital_id   = h.hospital_id
    LEFT JOIN clin.visit  v   ON doc.doctor_id     = v.doctor_id
                          AND v.visit_date BETWEEN @StartDate AND @EndDate
    LEFT JOIN hosp.doctor_schedule s ON doc.doctor_id = s.doctor_id
                                 AND s.shift_date BETWEEN @StartDate AND @EndDate
    WHERE (@HospitalID IS NULL OR h.hospital_id = @HospitalID)
    GROUP BY doc.doctor_id, doc.first_name, doc.last_name, doc.specialty, h.hospital_name
    ORDER BY total_visits DESC;
END;
GO

-- ------------------------------------------------------------
-- 2.4  GetReferralSummary
--      ملخص الإحالات بين المستشفيات
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetReferralSummary
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @StartDate = ISNULL(@StartDate, DATEADD(MONTH,-3,GETDATE()));
    SET @EndDate   = ISNULL(@EndDate,   GETDATE());

    SELECT
        hf.hospital_name  AS from_hospital,
        ht.hospital_name  AS to_hospital,
        r.referral_reason,
        r.referral_status,
        COUNT(*)          AS total_referrals
    FROM hosp.referral r
    JOIN hosp.hospital hf ON r.from_hospital_id = hf.hospital_id
    JOIN hosp.hospital ht ON r.to_hospital_id   = ht.hospital_id
    WHERE r.referral_date BETWEEN @StartDate AND @EndDate
    GROUP BY hf.hospital_name, ht.hospital_name, r.referral_reason, r.referral_status
    ORDER BY total_referrals DESC;
END;
GO


-- ============================================================
--  CATEGORY 3 — PHARMACY & INVENTORY
-- ============================================================

-- ------------------------------------------------------------
-- 3.1  GetLowStockAlert
--      أدوية نزلت تحت الـ reorder_level
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetLowStockAlert
    @HospitalID VARCHAR(4) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.hospital_name,
        dr.drug_id,
        dr.drug_name,
        dr.drug_category,
        inv.quantity_available,
        inv.reorder_level,
        inv.reorder_level - inv.quantity_available AS shortage_units,
        inv.expiration_date,
        CASE
            WHEN inv.quantity_available = 0 THEN 'OUT OF STOCK'
            ELSE 'LOW STOCK'
        END AS alert_type
    FROM inv.drug_inventory inv
    JOIN hosp.hospital h  ON inv.hospital_id = h.hospital_id
    JOIN ref.drug     dr ON inv.drug_id     = dr.drug_id
    WHERE inv.quantity_available <= inv.reorder_level
      AND (@HospitalID IS NULL OR inv.hospital_id = @HospitalID)
    ORDER BY shortage_units DESC;
END;
GO

-- ------------------------------------------------------------
-- 3.2  GetExpiringSoonDrugs
--      أدوية هتنتهي صلاحيتها خلال N يوم
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetExpiringSoonDrugs
    @DaysAhead  INT        = 60,
    @HospitalID VARCHAR(4) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.hospital_name,
        dr.drug_name,
        dr.drug_category,
        inv.quantity_available,
        inv.expiration_date,
        DATEDIFF(DAY, GETDATE(), inv.expiration_date) AS days_to_expiry
    FROM inv.drug_inventory inv
    JOIN hosp.hospital h  ON inv.hospital_id = h.hospital_id
    JOIN ref.drug     dr ON inv.drug_id     = dr.drug_id
    WHERE inv.expiration_date <= DATEADD(DAY, @DaysAhead, GETDATE())
      AND inv.expiration_date >= GETDATE()
      AND inv.quantity_available > 0
      AND (@HospitalID IS NULL OR inv.hospital_id = @HospitalID)
    ORDER BY days_to_expiry ASC;
END;
GO

-- ------------------------------------------------------------
-- 3.3  DispenseDrug
--      صرف دواء — بيخصم من الـ inventory تلقائياً
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.DispenseDrug
    @HospitalID    VARCHAR(4),
    @DrugID        VARCHAR(5),
    @Quantity      INT,
    @PerformedBy   VARCHAR(60),
    @PrescriptionID VARCHAR(12) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @CurrentStock INT;

        SELECT @CurrentStock = quantity_available
        FROM inv.drug_inventory
        WHERE hospital_id = @HospitalID AND drug_id = @DrugID;

        IF @CurrentStock IS NULL
            RAISERROR('Drug not found in this hospital inventory.', 16, 1);

        IF @CurrentStock < @Quantity
            RAISERROR('Insufficient stock. Available: %d units.', 16, 1, @CurrentStock);

        -- خصم من الـ inventory
        UPDATE inv.drug_inventory
        SET quantity_available = quantity_available - @Quantity,
            last_updated       = GETDATE()
        WHERE hospital_id = @HospitalID AND drug_id = @DrugID;

        -- تسجيل الحركة
        DECLARE @NewTxID VARCHAR(9);
        SELECT @NewTxID = 'DT' + RIGHT('0000000' + CAST(
            ISNULL(MAX(CAST(SUBSTRING(transaction_id,3,7) AS INT)),0) + 1
        AS VARCHAR), 7)
        FROM inv.drug_transaction;

        INSERT INTO inv.drug_transaction
            (transaction_id, drug_id, hospital_id, transaction_type, quantity, transaction_date, performed_by)
        VALUES
            (@NewTxID, @DrugID, @HospitalID, 'Dispensing', @Quantity, CAST(GETDATE() AS DATE), @PerformedBy);

        SELECT
            @NewTxID              AS transaction_id,
            @CurrentStock - @Quantity AS remaining_stock,
            'Dispensed successfully.' AS message;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ------------------------------------------------------------
-- 3.4  GetDrugConsumptionReport
--      معدل صرف كل دواء شهرياً لكل مستشفى
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetDrugConsumptionReport
    @HospitalID VARCHAR(4) = NULL,
    @StartDate  DATE       = NULL,
    @EndDate    DATE       = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @StartDate = ISNULL(@StartDate, DATEADD(MONTH,-6,GETDATE()));
    SET @EndDate   = ISNULL(@EndDate,   GETDATE());

    SELECT
        h.hospital_name,
        dr.drug_name,
        dr.drug_category,
        FORMAT(dt.transaction_date,'yyyy-MM') AS month,
        SUM(dt.quantity)                      AS total_dispensed,
        COUNT(*)                              AS transaction_count
    FROM inv.drug_transaction dt
    JOIN hosp.hospital h  ON dt.hospital_id = h.hospital_id
    JOIN ref.drug     dr ON dt.drug_id     = dr.drug_id
    WHERE dt.transaction_type = 'Dispensing'
      AND dt.transaction_date BETWEEN @StartDate AND @EndDate
      AND (@HospitalID IS NULL OR dt.hospital_id = @HospitalID)
    GROUP BY h.hospital_name, dr.drug_name, dr.drug_category,
             FORMAT(dt.transaction_date,'yyyy-MM')
    ORDER BY h.hospital_name, month, total_dispensed DESC;
END;
GO


-- ============================================================
--  CATEGORY 4 — INSURANCE CLAIMS
-- ============================================================

-- ------------------------------------------------------------
-- 4.1  SubmitNewClaim
--      رفع claim جديدة لزيارة — بتضيف الـ items تلقائياً
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SubmitNewClaim
    @VisitID    VARCHAR(12),
    @PatientID  VARCHAR(12),
    @HospitalID VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        -- validation: الزيارة Completed؟
        IF NOT EXISTS (
            SELECT 1 FROM clin.visit
            WHERE visit_id = @VisitID AND visit_status = 'Completed'
        )
            RAISERROR('Visit is not completed or does not exist.', 16, 1);

        -- validation: مفيش claim موجودة للزيارة دي
        IF EXISTS (SELECT 1 FROM fin.claim WHERE visit_id = @VisitID)
            RAISERROR('A claim already exists for this visit.', 16, 1);

        -- حساب الـ claim amount من الـ visit
        DECLARE @VisitCost DECIMAL(10,2);
        SELECT @VisitCost = total_amount FROM clin.visit WHERE visit_id = @VisitID;

        DECLARE @NewClaimID VARCHAR(12);
        SELECT @NewClaimID = 'CLM' + RIGHT('00000000' + CAST(
            ISNULL(MAX(CAST(SUBSTRING(claim_id,4,8) AS INT)),0) + 1
        AS VARCHAR), 8)
        FROM fin.claim;

        INSERT INTO fin.claim
            (claim_id, patient_id, visit_id, hospital_id, claim_date, claim_amount, claim_status)
        VALUES
            (@NewClaimID, @PatientID, @VisitID, @HospitalID,
             CAST(GETDATE() AS DATE), @VisitCost, 'Pending Review');

        -- إضافة claim_items من visit_procedures تلقائياً
        DECLARE @ItemCounter INT = 1;

        INSERT INTO fin.claim_item (claim_item_id, claim_id, procedure_code, drug_id, item_amount, quantity)
        SELECT
            'CI' + RIGHT('000000000' + CAST(
                ISNULL((SELECT MAX(CAST(SUBSTRING(claim_item_id,3,9) AS INT)) FROM fin.claim_item),0)
                + ROW_NUMBER() OVER (ORDER BY vp.visit_procedure_id)
            AS VARCHAR), 9),
            @NewClaimID,
            vp.procedure_code,
            NULL,
            vp.procedure_amount,
            1
        FROM clin.visit_procedure vp
        WHERE vp.visit_id = @VisitID;

        SELECT @NewClaimID AS new_claim_id, 'Claim submitted successfully.' AS message;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ------------------------------------------------------------
-- 4.2  ReviewClaim
--      مراجعة وتحديث حالة الـ claim (approve / reject / partial)
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.ReviewClaim
    @ClaimID         VARCHAR(12),
    @ReviewedBy      VARCHAR(50),
    @NewStatus       VARCHAR(20),      -- Approved / Partially Approved / Rejected
    @ApprovedAmount  DECIMAL(10,2) = NULL,
    @RejectionReason VARCHAR(80)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM fin.claim WHERE claim_id = @ClaimID)
            RAISERROR('Claim not found.', 16, 1);

        IF @NewStatus NOT IN ('Approved','Partially Approved','Rejected')
            RAISERROR('Invalid status. Use: Approved / Partially Approved / Rejected', 16, 1);

        IF @NewStatus = 'Rejected' AND @RejectionReason IS NULL
            RAISERROR('Rejection reason is required when rejecting a claim.', 16, 1);

        -- تحديث الـ claim
        UPDATE fin.claim
        SET claim_status    = @NewStatus,
            approved_amount = CASE
                                WHEN @NewStatus = 'Approved'          THEN claim_amount
                                WHEN @NewStatus = 'Partially Approved' THEN @ApprovedAmount
                                ELSE 0
                              END
        WHERE claim_id = @ClaimID;

        -- إضافة approval record
        DECLARE @NewApprovalID VARCHAR(12);
        SELECT @NewApprovalID = 'APR' + RIGHT('00000000' + CAST(
            ISNULL(MAX(CAST(SUBSTRING(approval_id,4,8) AS INT)),0) + 1
        AS VARCHAR), 8)
        FROM fin.claim_approval;

        INSERT INTO fin.claim_approval
            (approval_id, claim_id, reviewed_by, approval_status, approval_date, rejection_reason)
        VALUES
            (@NewApprovalID, @ClaimID, @ReviewedBy, @NewStatus,
             CAST(GETDATE() AS DATE), @RejectionReason);

        SELECT @NewApprovalID AS approval_id, 'Claim reviewed successfully.' AS message;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ------------------------------------------------------------
-- 4.3  GetClaimsByStatus
--      فلترة المطالبات حسب الـ status وتاريخ
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetClaimsByStatus
    @Status     VARCHAR(20) = NULL,
    @HospitalID VARCHAR(4)  = NULL,
    @StartDate  DATE        = NULL,
    @EndDate    DATE        = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @StartDate = ISNULL(@StartDate, DATEADD(MONTH,-1,GETDATE()));
    SET @EndDate   = ISNULL(@EndDate,   GETDATE());

    SELECT
        c.claim_id,
        p.first_name + ' ' + p.last_name AS patient_name,
        h.hospital_name,
        c.claim_date,
        c.claim_amount,
        c.approved_amount,
        c.claim_status,
        ca.reviewed_by,
        ca.approval_date,
        ca.rejection_reason
    FROM fin.claim c
    JOIN pat.patient        p  ON c.patient_id  = p.patient_id
    JOIN hosp.hospital       h  ON c.hospital_id = h.hospital_id
    LEFT JOIN fin.claim_approval ca ON c.claim_id = ca.claim_id
    WHERE (@Status     IS NULL OR c.claim_status  = @Status)
      AND (@HospitalID IS NULL OR c.hospital_id   = @HospitalID)
      AND c.claim_date BETWEEN @StartDate AND @EndDate
    ORDER BY c.claim_date DESC;
END;
GO

-- ------------------------------------------------------------
-- 4.4  GetRejectionReasonsAnalysis
--      أكتر أسباب الرفض تكراراً
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetRejectionReasonsAnalysis
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @StartDate = ISNULL(@StartDate, DATEADD(MONTH,-6,GETDATE()));
    SET @EndDate   = ISNULL(@EndDate,   GETDATE());

    SELECT
        ca.rejection_reason,
        COUNT(*)                        AS total_rejections,
        CAST(COUNT(*) * 100.0 /
            NULLIF(SUM(COUNT(*)) OVER(),0)
        AS DECIMAL(5,1))                AS pct_of_all_rejections
    FROM fin.claim_approval ca
    WHERE ca.approval_status = 'Rejected'
      AND ca.approval_date BETWEEN @StartDate AND @EndDate
      AND ca.rejection_reason IS NOT NULL
    GROUP BY ca.rejection_reason
    ORDER BY total_rejections DESC;
END;
GO


-- ============================================================
--  CATEGORY 5 — FRAUD DETECTION  ⚠️
-- ============================================================

-- ------------------------------------------------------------
-- 5.1  DetectInflatedProcedureCosts
--      إجراءات تكلفتها أعلى من الـ expected بنسبة معينة
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.DetectInflatedProcedureCosts
    @InflationThresholdPct DECIMAL(5,1) = 20.0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        vp.visit_procedure_id,
        vp.visit_id,
        v.visit_date,
        h.hospital_name,
        doc.first_name + ' ' + doc.last_name  AS doctor_name,
        pr.procedure_name,
        pr.expected_amount,
        vp.procedure_amount                     AS actual_cost,
        CAST((vp.procedure_amount - pr.expected_amount) * 100.0
             / NULLIF(pr.expected_cost,0) AS DECIMAL(5,1)) AS inflation_pct,
        p.first_name + ' ' + p.last_name      AS patient_name,
        'Inflated Procedure Cost'             AS fraud_signal
    FROM clin.visit_procedure vp
    JOIN clin.visit     v   ON vp.visit_id       = v.visit_id
    JOIN ref.medical_procedure pr  ON vp.procedure_code = pr.procedure_code
    JOIN hosp.hospital  h   ON v.hospital_id     = h.hospital_id
    JOIN hosp.doctor    doc ON v.doctor_id       = doc.doctor_id
    JOIN pat.patient   p   ON v.patient_id      = p.patient_id
    WHERE (vp.procedure_amount - pr.expected_amount) * 100.0
          / NULLIF(pr.expected_cost,0) >= @InflationThresholdPct
    ORDER BY inflation_pct DESC;
END;
GO

-- ------------------------------------------------------------
-- 5.2  DetectDrugsDispensedWithoutPrescription
--      صرف دواء من غير وصفة طبية مقابلة — drug theft signal
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.DetectDrugsDispensedWithoutPrescription
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @StartDate = ISNULL(@StartDate, DATEADD(MONTH,-3,GETDATE()));
    SET @EndDate   = ISNULL(@EndDate,   GETDATE());

    SELECT
        dt.transaction_id,
        dt.transaction_date,
        h.hospital_name,
        dr.drug_name,
        dr.drug_category,
        dt.quantity,
        dt.performed_by,
        'Dispensing Without Prescription' AS fraud_signal
    FROM inv.drug_transaction dt
    JOIN hosp.hospital h  ON dt.hospital_id = h.hospital_id
    JOIN ref.drug     dr ON dt.drug_id     = dr.drug_id
    WHERE dt.transaction_type = 'Dispensing'
      AND dt.transaction_date BETWEEN @StartDate AND @EndDate
      AND NOT EXISTS (
            SELECT 1
            FROM clin.prescription_item pi
            JOIN clin.prescription      px  ON pi.prescription_id = px.prescription_id
            JOIN clin.visit             v   ON px.visit_id        = v.visit_id
            WHERE pi.drug_id      = dt.drug_id
              AND v.hospital_id   = dt.hospital_id
              AND CAST(px.prescription_date AS DATE) = dt.transaction_date
      )
    ORDER BY dt.transaction_date DESC;
END;
GO

-- ------------------------------------------------------------
-- 5.3  DetectDuplicateClaims
--      نفس المريض + نفس الزيارة بأكتر من claim
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.DetectDuplicateClaims
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.patient_id,
        p.first_name + ' ' + p.last_name AS patient_name,
        c.visit_id,
        COUNT(c.claim_id)                AS claim_count,
        SUM(c.claim_amount)              AS total_claimed,
        STRING_AGG(c.claim_id, ', ')     AS claim_ids,
        'Duplicate Claim'                AS fraud_signal
    FROM fin.claim c
    JOIN pat.patient p ON c.patient_id = p.patient_id
    GROUP BY c.patient_id, p.first_name, p.last_name, c.visit_id
    HAVING COUNT(c.claim_id) > 1
    ORDER BY claim_count DESC;
END;
GO

-- ------------------------------------------------------------
-- 5.4  DetectAbnormalPrescriptionQuantity
--      وصفات فيها quantity ضعف الـ normal (duration × frequency)
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.DetectAbnormalPrescriptionQuantity
    @MultiplierThreshold DECIMAL(4,1) = 1.8
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pi.prescription_item_id,
        px.prescription_id,
        px.prescription_date,
        v.hospital_id,
        h.hospital_name,
        doc.first_name + ' ' + doc.last_name  AS doctor_name,
        pat.first_name + ' ' + pat.last_name  AS patient_name,
        dr.drug_name,
        pi.frequency,
        pi.duration_days,
        pi.quantity                           AS actual_quantity,
        CASE pi.frequency
            WHEN 'Once daily'      THEN pi.duration_days * 1
            WHEN 'Twice daily'     THEN pi.duration_days * 2
            WHEN 'Three times daily' THEN pi.duration_days * 3
            WHEN 'Every 12 hours'  THEN pi.duration_days * 2
            WHEN 'Every 8 hours'   THEN pi.duration_days * 3
            WHEN 'Every 6 hours'   THEN pi.duration_days * 4
            ELSE pi.duration_days
        END                                   AS expected_quantity,
        CAST(pi.quantity * 1.0 /
            NULLIF(CASE pi.frequency
                WHEN 'Once daily'        THEN pi.duration_days * 1
                WHEN 'Twice daily'       THEN pi.duration_days * 2
                WHEN 'Three times daily' THEN pi.duration_days * 3
                WHEN 'Every 12 hours'    THEN pi.duration_days * 2
                WHEN 'Every 8 hours'     THEN pi.duration_days * 3
                WHEN 'Every 6 hours'     THEN pi.duration_days * 4
                ELSE pi.duration_days
            END, 0)
        AS DECIMAL(4,1))                      AS quantity_multiplier,
        'Abnormal Prescription Quantity'      AS fraud_signal
    FROM clin.prescription_item pi
    JOIN clin.prescription  px  ON pi.prescription_id = px.prescription_id
    JOIN clin.visit        v   ON px.visit_id         = v.visit_id
    JOIN hosp.hospital     h   ON v.hospital_id        = h.hospital_id
    JOIN hosp.doctor       doc ON px.doctor_id         = doc.doctor_id
    JOIN pat.patient      pat ON v.patient_id         = pat.patient_id
    JOIN ref.drug         dr  ON pi.drug_id           = dr.drug_id
    WHERE pi.quantity * 1.0 / NULLIF(
        CASE pi.frequency
            WHEN 'Once daily'        THEN pi.duration_days * 1
            WHEN 'Twice daily'       THEN pi.duration_days * 2
            WHEN 'Three times daily' THEN pi.duration_days * 3
            WHEN 'Every 12 hours'    THEN pi.duration_days * 2
            WHEN 'Every 8 hours'     THEN pi.duration_days * 3
            WHEN 'Every 6 hours'     THEN pi.duration_days * 4
            ELSE pi.duration_days
        END, 0) >= @MultiplierThreshold
    ORDER BY quantity_multiplier DESC;
END;
GO

-- ------------------------------------------------------------
-- 5.5  GetFraudSummaryByDoctor
--      تقرير بأكتر الدكاترة اللي ليهم fraud signals
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetFraudSummaryByDoctor
AS
BEGIN
    SET NOCOUNT ON;

    WITH InflatedCosts AS (
        SELECT v.doctor_id, COUNT(*) AS inflated_count
        FROM clin.visit_procedure vp
        JOIN clin.visit v     ON vp.visit_id       = v.visit_id
        JOIN ref.medical_procedure p ON vp.procedure_code = p.procedure_code
        WHERE (vp.procedure_amount - p.expected_amount) * 100.0
              / NULLIF(p.expected_cost,0) >= 20
        GROUP BY v.doctor_id
    ),
    AbnormalRx AS (
        SELECT px.doctor_id, COUNT(*) AS abnormal_rx_count
        FROM clin.prescription_item pi
        JOIN clin.prescription  px ON pi.prescription_id = px.prescription_id
        WHERE pi.quantity * 1.0 / NULLIF(
            CASE pi.frequency
                WHEN 'Once daily'        THEN pi.duration_days * 1
                WHEN 'Twice daily'       THEN pi.duration_days * 2
                WHEN 'Three times daily' THEN pi.duration_days * 3
                WHEN 'Every 12 hours'    THEN pi.duration_days * 2
                WHEN 'Every 8 hours'     THEN pi.duration_days * 3
                WHEN 'Every 6 hours'     THEN pi.duration_days * 4
                ELSE pi.duration_days
            END, 0) >= 1.8
        GROUP BY px.doctor_id
    ),
    RejectedClaims AS (
        SELECT v.doctor_id, COUNT(*) AS rejected_claims
        FROM fin.claim c
        JOIN fin.claim_approval ca ON c.claim_id  = ca.claim_id
        JOIN clin.visit          v  ON c.visit_id  = v.visit_id
        WHERE ca.approval_status = 'Rejected'
        GROUP BY v.doctor_id
    )
    SELECT
        doc.doctor_id,
        doc.first_name + ' ' + doc.last_name  AS doctor_name,
        doc.specialty,
        h.hospital_name,
        ISNULL(ic.inflated_count,    0)        AS inflated_procedure_count,
        ISNULL(ar.abnormal_rx_count, 0)        AS abnormal_prescription_count,
        ISNULL(rc.rejected_claims,   0)        AS rejected_claims_count,
        ISNULL(ic.inflated_count,0)
            + ISNULL(ar.abnormal_rx_count,0)
            + ISNULL(rc.rejected_claims,0)     AS total_fraud_signals
    FROM hosp.doctor doc
    JOIN hosp.department dep ON doc.department_id = dep.department_id
    JOIN hosp.hospital   h   ON dep.hospital_id   = h.hospital_id
    LEFT JOIN InflatedCosts  ic ON doc.doctor_id = ic.doctor_id
    LEFT JOIN AbnormalRx     ar ON doc.doctor_id = ar.doctor_id
    LEFT JOIN RejectedClaims rc ON doc.doctor_id = rc.doctor_id
    WHERE ISNULL(ic.inflated_count,0)
        + ISNULL(ar.abnormal_rx_count,0)
        + ISNULL(rc.rejected_claims,0) > 0
    ORDER BY total_fraud_signals DESC;
END;
GO


-- ============================================================
--  CATEGORY 6 — ANALYTICS & REPORTING
-- ============================================================

-- ------------------------------------------------------------
-- 6.1  GetMonthlyVisitsTrend
--      عدد الزيارات شهرياً + مقارنة بالشهر السابق
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetMonthlyVisitsTrend
    @HospitalID VARCHAR(4) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    WITH monthly AS (
        SELECT
            FORMAT(visit_date,'yyyy-MM')  AS month,
            COUNT(*)                      AS total_visits,
            SUM(CASE WHEN visit_type = 'Emergency'   THEN 1 ELSE 0 END) AS emergency_visits,
            SUM(CASE WHEN visit_type = 'Inpatient'   THEN 1 ELSE 0 END) AS inpatient_visits,
            SUM(CASE WHEN visit_type = 'Outpatient'  THEN 1 ELSE 0 END) AS outpatient_visits,
            AVG(CAST(waiting_time AS FLOAT))          AS avg_waiting_time,
            AVG(CAST(total_amount   AS FLOAT))          AS avg_visit_cost
        FROM clin.visit
        WHERE (@HospitalID IS NULL OR hospital_id = @HospitalID)
          AND visit_status = 'Completed'
        GROUP BY FORMAT(visit_date,'yyyy-MM')
    )
    SELECT
        month,
        total_visits,
        emergency_visits,
        inpatient_visits,
        outpatient_visits,
        CAST(avg_waiting_time AS DECIMAL(6,1)) AS avg_waiting_time_min,
        CAST(avg_visit_cost   AS DECIMAL(10,2)) AS avg_visit_cost_egp,
        LAG(total_visits) OVER (ORDER BY month)  AS prev_month_visits,
        CAST(
            (total_visits - LAG(total_visits) OVER (ORDER BY month)) * 100.0
            / NULLIF(LAG(total_visits) OVER (ORDER BY month),0)
        AS DECIMAL(5,1))                         AS mom_change_pct
    FROM monthly
    ORDER BY month;
END;
GO

-- ------------------------------------------------------------
-- 6.2  GetHospitalPerformanceScore
--      تجميع rating + waiting_time + rejection rate لكل مستشفى
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetHospitalPerformanceScore
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.hospital_id,
        h.hospital_name,
        h.hospital_type,
        h.district,
        -- Patient satisfaction
        CAST(AVG(CAST(pf.rating AS FLOAT)) AS DECIMAL(3,1))    AS avg_rating,
        COUNT(DISTINCT pf.feedback_id)                          AS total_feedback,
        -- Waiting time
        CAST(AVG(CAST(v.waiting_time AS FLOAT)) AS DECIMAL(6,1)) AS avg_waiting_min,
        -- Claim rejection rate
        COUNT(DISTINCT CASE WHEN ca.approval_status = 'Rejected' THEN c.claim_id END) AS rejected_claims,
        COUNT(DISTINCT c.claim_id)                              AS total_claims,
        CAST(
            COUNT(DISTINCT CASE WHEN ca.approval_status = 'Rejected' THEN c.claim_id END) * 100.0
            / NULLIF(COUNT(DISTINCT c.claim_id),0)
        AS DECIMAL(5,1))                                        AS rejection_rate_pct,
        -- Referral overflow rate
        COUNT(DISTINCT r.referral_id)                           AS total_referrals_out
    FROM hosp.hospital h
    LEFT JOIN svc.patient_feedback pf ON h.hospital_id = pf.hospital_id
    LEFT JOIN clin.visit           v  ON h.hospital_id = v.hospital_id  AND v.visit_status = 'Completed'
    LEFT JOIN fin.claim           c  ON h.hospital_id = c.hospital_id
    LEFT JOIN fin.claim_approval  ca ON c.claim_id    = ca.claim_id
    LEFT JOIN hosp.referral        r  ON h.hospital_id = r.from_hospital_id
    GROUP BY h.hospital_id, h.hospital_name, h.hospital_type, h.district
    ORDER BY avg_rating DESC;
END;
GO

-- ------------------------------------------------------------
-- 6.3  GetTopDiagnosesByHospital
--      أكتر N تشخيصات في كل مستشفى
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.GetTopDiagnosesByHospital
    @TopN       INT        = 5,
    @HospitalID VARCHAR(4) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    WITH ranked AS (
        SELECT
            h.hospital_name,
            d.diagnosis_name,
            d.diagnosis_category,
            d.severity_level,
            COUNT(*) AS visit_count,
            ROW_NUMBER() OVER (
                PARTITION BY h.hospital_id
                ORDER BY COUNT(*) DESC
            ) AS rnk
        FROM clin.visit v
        JOIN hosp.hospital h  ON v.hospital_id    = h.hospital_id
        JOIN ref.diagnosis d  ON v.diagnosis_code = d.diagnosis_code
        WHERE v.visit_status = 'Completed'
          AND (@HospitalID IS NULL OR v.hospital_id = @HospitalID)
        GROUP BY h.hospital_id, h.hospital_name,
                 d.diagnosis_name, d.diagnosis_category, d.severity_level
    )
    SELECT hospital_name, diagnosis_name, diagnosis_category,
           severity_level, visit_count, rnk AS rank
    FROM ranked
    WHERE rnk <= @TopN
    ORDER BY hospital_name, rnk;
END;
GO

-- ============================================================
--  END OF SCRIPT
--  Total: 18 Stored Procedures across 6 categories
-- ============================================================
