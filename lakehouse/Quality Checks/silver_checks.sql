-- Databricks notebook source
-- MAGIC %md
-- MAGIC
-- MAGIC =====================================================
-- MAGIC ## Quality Checks
-- MAGIC =====================================================
-- MAGIC
-- MAGIC **Script Purpose:**  
-- MAGIC This script performs various quality checks for data consistency, accuracy, and standardization across the 'silver' layer.
-- MAGIC
-- MAGIC **Checks Included:**
-- MAGIC - Null or duplicate primary keys
-- MAGIC - Unwanted spaces in string fields
-- MAGIC - Data standardization and consistency
-- MAGIC - Invalid date ranges and orders
-- MAGIC - Data consistency between related fields

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### checking the diagnosis table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT 
    diagnosis_code 
FROM medical_insurance.silver.diagnosis_silver
GROUP BY diagnosis_code
HAVING COUNT(*) > 1 OR diagnosis_code IS NULL;

-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT 
    diagnosis_name 
FROM medical_insurance.silver.diagnosis_silver
WHERE diagnosis_name != TRIM(diagnosis_name);

-- Data Standardization & Consistency
SELECT DISTINCT 
    severity_level 
FROM medical_insurance.silver.diagnosis_silver;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### checking the hospital table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT 
    hospital_id 
FROM medical_insurance.silver.hospital_silver
GROUP BY hospital_id
HAVING COUNT(*) > 1 OR hospital_id IS NULL;

-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT 
    hospital_name 
FROM medical_insurance.silver.hospital_silver
WHERE hospital_name != TRIM(hospital_name);

-- Data Standardization & Consistency
SELECT DISTINCT 
    hospital_type 
FROM medical_insurance.silver.hospital_silver;

SELECT DISTINCT 
    governorate 
FROM medical_insurance.silver.hospital_silver;

SELECT DISTINCT 
    district 
FROM medical_insurance.silver.hospital_silver;

-- Check for outliers
WITH Quartiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY icu_capacity) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY icu_capacity) OVER () AS Q3,
        icu_capacity,
        hospital_id
    FROM medical_insurance.silver.hospital_silver
),

IQR_Calc AS (
    SELECT *,
           (Q3 - Q1) AS IQR
    FROM Quartiles
)

SELECT *
FROM IQR_Calc
WHERE icu_capacity < (Q1 - 1.5 * IQR)
   OR icu_capacity > (Q3 + 1.5 * IQR);

-- Check phone number
SELECT *
FROM medical_insurance.silver.hospital_silver
WHERE hospital_phone NOT LIKE '+__-___-___-____'
OR hospital_phone IS NULL;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### checking the bed table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
SELECT 
    bed_id 
FROM medical_insurance.default.bed
GROUP BY bed_id
HAVING COUNT(*) > 1 OR bed_id IS NULL;

-- Check for Unwanted Spaces
SELECT 
    availability_status 
FROM medical_insurance.default.bed
WHERE availability_status != TRIM(availability_status);

-- Data Standardization & Consistency
SELECT DISTINCT 
    bed_type 
FROM medical_insurance.default.bed;

SELECT DISTINCT 
    availability_status 
FROM medical_insurance.default.bed;

-- Check  NULLs  in Foreign Key
SELECT 
    * 
FROM medical_insurance.default.bed
WHERE hospital_id IS NULL OR department_id IS NULL;

--

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Checking the doctor table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
SELECT 
    doctor_id 
FROM medical_insurance.default.doctor
GROUP BY doctor_id
HAVING COUNT(*) > 1 OR doctor_id IS NULL;

-- Check for Unwanted Spaces
SELECT 
    do 
FROM medical_insurance.silver.doctor_silver
WHERE last_name != TRIM(last_name);

-- Data Standardization & Consistency != TRIM(hospital_name);

-- Data Standardization & Consistency
SELECT DISTINCT 
    specialty 
FROM medical_insurance.default.doctor;

SELECT DISTINCT 
    employment_status 
FROM medical_insurance.default.doctor;

-- Check for outliers
SELECT *
FROM (
    SELECT
        doctor_id,
        years_experience,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY years_experience) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY years_experience) OVER () AS Q3
    FROM medical_insurance.default.doctor
) t
WHERE years_experience < (Q1 - 1.5 * (Q3 - Q1))
   OR years_experience > (Q3 + 1.5 * (Q3 - Q1));

-- Check phone number
SELECT *
FROM medical_insurance.default.doctor
WHERE phone NOT LIKE '+__-___-___-____'
OR phone IS NULL;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Checking the claim table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
SELECT 
    claim_id 
FROM medical_insurance.silver.claim_silver
GROUP BY claim_id
HAVING COUNT(*) > 1 OR claim_id IS NULL;

-- Check for Unwanted Spaces
SELECT 
    claim_status 
FROM medical_insurance.silver.claim_silver
WHERE claim_status != TRIM(claim_status);

-- Data Standardization & Consistency
SELECT DISTINCT 
    claim_status 
FROM medical_insurance.silver.claim_silver;

-- Check for outliers
SELECT *
FROM (
    SELECT
        claim_amount,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY claim_amount) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY claim_amount) OVER () AS Q3
    FROM medical_insurance.silver.claim_silver
) t
WHERE claim_amount < (Q1 - 1.5 * (Q3 - Q1))
   OR claim_amount > (Q3 + 1.5 * (Q3 - Q1));

SELECT *
FROM (
    SELECT
        approved_amount,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY claim_amount) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY claim_amount) OVER () AS Q3
    FROM medical_insurance.silver.claim_silver
) t
WHERE approved_amount < (Q1 - 1.5 * (Q3 - Q1))
   OR approved_amount > (Q3 + 1.5 * (Q3 - Q1));

-- check for nulls in date 
SELECT *
FROM medical_insurance.silver.claim_silver
WHERE claim_date IS NULL

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Checking the claim items table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
SELECT 
    claim_item_id 
FROM medical_insurance.silver.claim_items_silver
GROUP BY claim_item_id
HAVING COUNT(*) > 1 OR claim_item_id IS NULL;

-- Check for Unwanted Spaces
SELECT 
    drug_id 
FROM medical_insurance.silver.claim_items_silver
WHERE drug_id != TRIM(drug_id);

-- Check for outliers
SELECT *
FROM (
    SELECT
        item_amount,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY item_amount) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY item_amount) OVER () AS Q3
    FROM medical_insurance.silver.claim_items_silver
) t
WHERE item_amount < (Q1 - 1.5 * (Q3 - Q1))
   OR item_amount > (Q3 + 1.5 * (Q3 - Q1));

SELECT *
FROM (
    SELECT
        item_quantity,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY item_quantity) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY item_quantity) OVER () AS Q3
    FROM medical_insurance.silver.claim_items_silver
) t
WHERE item_quantity < (Q1 - 1.5 * (Q3 - Q1))
   OR item_quantity > (Q3 + 1.5 * (Q3 - Q1));

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Checking the claim approvals table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
SELECT 
    approval_id 
FROM medical_insurance.silver.claim_approval_silver
GROUP BY approval_id
HAVING COUNT(*) > 1 OR approval_id IS NULL;

-- Check for Unwanted Spaces
SELECT
    approval_id,
    approval_status 
FROM medical_insurance.silver.claim_approval_silver
WHERE  approval_status!= TRIM(approval_status);

SELECT
    approval_id,
    rejection_reason 
FROM medical_insurance.silver.claim_approval_silver
WHERE  rejection_reason != TRIM(rejection_reason);

-- check for nulls in date 
SELECT *
FROM medical_insurance.silver.claim_approval_silver
WHERE approval_date IS NULL