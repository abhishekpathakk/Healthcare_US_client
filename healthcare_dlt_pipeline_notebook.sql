-- Create a bronze table for diagnosis mapping data
CREATE LIVE TABLE diagnostic_mapping
COMMENT "Bronze table for the diagnosis mapping file"
TBLPROPERTIES ("quality" = "bronze")
AS
SELECT *
FROM default1.raw_diagnosis_map;

-- Create or refresh a streaming bronze table for daily patient data
CREATE OR REFRESH STREAMING TABLE daily_patients
COMMENT "Bronze table for daily patient data"
TBLPROPERTIES ("quality" = "bronze")
AS
SELECT *
FROM STREAM(default1.raw_patients_daily);

-- Create or refresh a silver table that joins daily patient data with diagnosis data, applying data quality constraints
-- The constraints ensure certain fields (e.g., patient_id, name, age) are not null. Violating rows are dropped.
CREATE OR REFRESH STREAMING TABLE processed_patient_data(CONSTRAINT valid_data EXPECT (patient_id IS NOT NULL and `name` IS NOT NULL and age IS NOT NULL and gender IS NOT NULL and `address` IS NOT NULL and contact_number IS NOT NULL and admission_date IS NOT NULL) ON VIOLATION DROP ROW)
COMMENT "Silver table with newly joined data from bronze tables and data quality constraints"
TBLPROPERTIES ("quality" = "silver")
AS
SELECT
    p.patient_id,
    p.name,
    p.age,
    p.gender,
    p.address,
    p.contact_number,
    p.admission_date,
    m.diagnosis_description
FROM STREAM(live.daily_patients) p
LEFT JOIN live.diagnostic_mapping m
ON p.diagnosis_code = m.diagnosis_code;

-- Create a gold table that provides detailed patient statistics grouped by diagnosis description
CREATE LIVE TABLE patient_statistics_by_diagnosis
COMMENT "Gold table with detailed patient statistics by diagnosis description"
TBLPROPERTIES ("quality" = "gold")
AS
SELECT
    diagnosis_description,
    COUNT(patient_id) AS patient_count,
    AVG(age) AS avg_age,
    COUNT(DISTINCT gender) AS unique_gender_count,
    MIN(age) AS min_age,
    MAX(age) AS max_age
FROM live.processed_patient_data
GROUP BY diagnosis_description;

-- Create a gold table that provides detailed patient statistics grouped by gender
CREATE LIVE TABLE patient_statistics_by_gender
COMMENT "Gold table with detailed patient statistics by gender"
TBLPROPERTIES ("quality" = "gold")
AS
SELECT
    gender,
    COUNT(patient_id) AS patient_count,
    AVG(age) AS avg_age,
    COUNT(DISTINCT diagnosis_description) AS unique_diagnosis_count,
    MIN(age) AS min_age,
    MAX(age) AS max_age
FROM live.processed_patient_data
GROUP BY gender;
