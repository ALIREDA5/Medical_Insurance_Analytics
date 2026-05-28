-- Databricks notebook source
-- MAGIC %md
-- MAGIC ### checking the diagnosis table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT 
    diagnosis_code 
FROM medical_insurance.default.diagnosis
GROUP BY diagnosis_code
HAVING COUNT(*) > 1 OR diagnosis_code IS NULL;

-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT 
    diagnosis_name 
FROM medical_insurance.default.diagnosis
WHERE diagnosis_name != TRIM(diagnosis_name);

-- Data Standardization & Consistency
SELECT DISTINCT 
    severity_level 
FROM medical_insurance.default.diagnosis;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### checking the hospital table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
SELECT 
    hospital_id 
FROM medical_insurance.default.hospital
GROUP BY hospital_id
HAVING COUNT(*) > 1 OR hospital_id IS NULL;

-- Check for Unwanted Spaces
SELECT 
    hospital_name 
FROM medical_insurance.default.hospital
WHERE hospital_name != TRIM(hospital_name);

-- Data Standardization & Consistency
SELECT DISTINCT 
    hospital_type 
FROM medical_insurance.default.hospital;

SELECT DISTINCT 
    governorate 
FROM medical_insurance.default.hospital;

SELECT DISTINCT 
    district 
FROM medical_insurance.default.hospital;

-- Check for outliers
SELECT *
FROM (
    SELECT
        hospital_id,
        icu_capacity,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY icu_capacity) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY icu_capacity) OVER () AS Q3
    FROM medical_insurance.default.hospital
) t
WHERE icu_capacity < (Q1 - 1.5 * (Q3 - Q1))
   OR icu_capacity > (Q3 + 1.5 * (Q3 - Q1));

-- Check email
SELECT *
FROM medical_insurance.default.hospital
WHERE manager_email NOT LIKE '%_@%.%' OR manager_email IS NULL;

-- Check phone number
SELECT *
FROM medical_insurance.default.hospital
WHERE manager_phone NOT LIKE '+__-___-___-____'
OR manager_phone IS NULL;

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
    first_name 
FROM medical_insurance.default.doctor
WHERE first_name != TRIM(first_name);

SELECT 
    last_name 
FROM medical_insurance.default.doctor
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
-- MAGIC ### checking the claim table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
SELECT 
    claim_id 
FROM medical_insurance.default.claim
GROUP BY claim_id
HAVING COUNT(*) > 1 OR claim_id IS NULL;

-- Check for Unwanted Spaces
SELECT 
    claim_status 
FROM medical_insurance.default.claim
WHERE claim_status != TRIM(claim_status);

-- Data Standardization & Consistency
SELECT DISTINCT 
    claim_status 
FROM medical_insurance.default.claim;

-- Check for outliers
SELECT *
FROM (
    SELECT
        claim_amount,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY claim_amount) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY claim_amount) OVER () AS Q3
    FROM medical_insurance.default.claim
) t
WHERE claim_amount < (Q1 - 1.5 * (Q3 - Q1))
   OR claim_amount > (Q3 + 1.5 * (Q3 - Q1));

SELECT *
FROM (
    SELECT
        approved_amount,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY claim_amount) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY claim_amount) OVER () AS Q3
    FROM medical_insurance.default.claim
) t
WHERE approved_amount < (Q1 - 1.5 * (Q3 - Q1))
   OR approved_amount > (Q3 + 1.5 * (Q3 - Q1));

-- check for nulls in date 
SELECT *
FROM medical_insurance.default.claim
WHERE claim_date IS NULL

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### checking the claim_items table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
SELECT 
    claim_item_id 
FROM medical_insurance.default.claim_item
GROUP BY claim_item_id
HAVING COUNT(*) > 1 OR claim_item_id IS NULL;

-- Check for Unwanted Spaces
SELECT 
    drug_id 
FROM medical_insurance.default.claim_item
WHERE drug_id != TRIM(drug_id);

-- Check for outliers
SELECT *
FROM (
    SELECT
        item_amount,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY item_amount) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY item_amount) OVER () AS Q3
    FROM medical_insurance.default.claim_item
) t
WHERE item_amount < (Q1 - 1.5 * (Q3 - Q1))
   OR item_amount > (Q3 + 1.5 * (Q3 - Q1));

SELECT *
FROM (
    SELECT
        quantity,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY quantity) OVER () AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY quantity) OVER () AS Q3
    FROM medical_insurance.default.claim_item
) t
WHERE quantity < (Q1 - 1.5 * (Q3 - Q1))
   OR quantity > (Q3 + 1.5 * (Q3 - Q1));

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### checking the claim_approvals table

-- COMMAND ----------

-- Check for NULLs or Duplicates in Primary Key
SELECT 
    approval_id 
FROM medical_insurance.default.claim_approval
GROUP BY approval_id
HAVING COUNT(*) > 1 OR approval_id IS NULL;

-- Check for Unwanted Spaces
SELECT
    approval_id,
    approval_status 
FROM medical_insurance.default.claim_approval
WHERE  approval_status!= TRIM(approval_status);

SELECT
    approval_id,
    rejection_reason 
FROM medical_insurance.default.claim_approval
WHERE  rejection_reason != TRIM(rejection_reason);

-- check for nulls in date 
SELECT *
FROM medical_insurance.default.claim_approval
WHERE approval_date IS NULL