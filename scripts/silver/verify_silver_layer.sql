/*
===============================================================================
Quality Check Script: Silver Layer
===============================================================================
Script Purpose:
    This script performs basic quality checks on the 'silver' schema tables.
    It verifies:
    - Row counts to confirm transformation and load was successful
    - Table structure to confirm correct column names and data types
    - Sample data preview to visually inspect cleaned and transformed records
    - Basic data quality checks on key transformation rules applied in load_silver

Usage Example:
    Run this script after EXEC silver.load_silver to validate the load.
===============================================================================
*/

-- ============================================================
-- SECTION 1: ROW COUNT CHECKS
-- Purpose: Confirm that each silver table has been loaded with
--          data and counts are consistent with bronze source
-- ============================================================

PRINT '================================================';
PRINT 'Silver Layer - Row Count Checks';
PRINT '================================================';

-- Check row counts across all silver tables in one result set
-- Expected: Counts should be equal to or slightly less than bronze
--           (e.g. crm_cust_info will be lower due to deduplication)
SELECT 'silver.crm_cust_info'     AS table_name, COUNT(*) AS row_count FROM silver.crm_cust_info
UNION ALL
SELECT 'silver.crm_prd_info'      AS table_name, COUNT(*) AS row_count FROM silver.crm_prd_info
UNION ALL
SELECT 'silver.crm_sales_details' AS table_name, COUNT(*) AS row_count FROM silver.crm_sales_details
UNION ALL
SELECT 'silver.erp_loc_a101'      AS table_name, COUNT(*) AS row_count FROM silver.erp_loc_a101
UNION ALL
SELECT 'silver.erp_cust_az12'     AS table_name, COUNT(*) AS row_count FROM silver.erp_cust_az12
UNION ALL
SELECT 'silver.erp_px_cat_g1v2'   AS table_name, COUNT(*) AS row_count FROM silver.erp_px_cat_g1v2;

-- ============================================================
-- SECTION 2: TABLE STRUCTURE CHECKS
-- Purpose: Confirm that all columns exist with the correct
--          names and data types as defined in the DDL script
--          including the dwh_create_date audit column
-- ============================================================

PRINT '================================================';
PRINT 'Silver Layer - Table Structure Checks';
PRINT '================================================';

-- Retrieve column metadata for all silver tables from the system catalog
-- Expected: Each table should show all defined columns including dwh_create_date
SELECT 
    TABLE_NAME   AS table_name,
    COLUMN_NAME  AS column_name,
    DATA_TYPE    AS data_type,
    IS_NULLABLE  AS is_nullable
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'silver'
ORDER BY TABLE_NAME, ORDINAL_POSITION;  -- Order by table and column position for easy reading

-- ============================================================
-- SECTION 3: SAMPLE DATA PREVIEW
-- Purpose: Visually inspect a small sample of transformed records
--          to confirm cleaning and standardization was applied correctly
-- ============================================================

PRINT '================================================';
PRINT 'Silver Layer - Sample Data Preview';
PRINT '================================================';

-- Preview top 5 rows from each silver table
-- Expected: Data should reflect cleaned, standardized values (no raw codes)

-- CRM: Deduplicated customer master with readable gender and marital status
SELECT TOP 5 * FROM silver.crm_cust_info;

-- CRM: Product master with derived cat_id and decoded product line labels
SELECT TOP 5 * FROM silver.crm_prd_info;

-- CRM: Sales data with proper DATE types and recalculated sales/price values
SELECT TOP 5 * FROM silver.crm_sales_details;

-- ERP: Location data with standardized full country names
SELECT TOP 5 * FROM silver.erp_loc_a101;

-- ERP: Customer demographics with cleaned birthdates and normalized gender
SELECT TOP 5 * FROM silver.erp_cust_az12;

-- ERP: Product category reference data (direct copy from bronze)
SELECT TOP 5 * FROM silver.erp_px_cat_g1v2;

-- ============================================================
-- SECTION 4: TRANSFORMATION QUALITY CHECKS
-- Purpose: Validate that key transformation rules from load_silver
--          were applied correctly and no unexpected values remain
-- ============================================================

PRINT '================================================';
PRINT 'Silver Layer - Transformation Quality Checks';
PRINT '================================================';

-- Check 1: crm_cust_info
-- Verify no duplicate customer IDs exist after deduplication
-- Expected: Every cst_id should appear exactly once (max_count = 1)
SELECT 
    cst_id, 
    COUNT(*) AS duplicate_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1;  -- Any rows returned here indicate duplicate customer IDs

-- Check 2: crm_cust_info
-- Verify gender and marital status contain only standardized values
-- Expected: Only 'Male', 'Female', 'n/a' for gender
--           Only 'Married', 'Single', 'n/a' for marital status
SELECT DISTINCT cst_gndr           AS gender_values          FROM silver.crm_cust_info;
SELECT DISTINCT cst_marital_status AS marital_status_values  FROM silver.crm_cust_info;

-- Check 3: crm_prd_info
-- Verify product line contains only standardized descriptive labels
-- Expected: Only 'Mountain', 'Road', 'Other Sales', 'Touring', 'n/a'
SELECT DISTINCT prd_line AS product_line_values FROM silver.crm_prd_info;

-- Check 4: crm_prd_info
-- Verify no NULL or negative product costs remain after transformation
-- Expected: 0 rows (all NULLs were replaced with 0 in load_silver)
SELECT 
    prd_id, 
    prd_cost 
FROM silver.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost < 0;

-- Check 5: crm_sales_details
-- Verify no invalid sales, quantity, or price values remain
-- Expected: 0 rows (all were recalculated or derived in load_silver)
SELECT 
    sls_ord_num, 
    sls_sales, 
    sls_quantity, 
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales  IS NULL OR sls_sales  <= 0
   OR sls_quantity IS NULL OR sls_quantity <= 0
   OR sls_price  IS NULL OR sls_price  <= 0;

-- Check 6: erp_cust_az12
-- Verify no future birthdates remain after transformation
-- Expected: 0 rows (all future dates were set to NULL in load_silver)
SELECT 
    cid, 
    bdate
FROM silver.erp_cust_az12
WHERE bdate > GETDATE();

-- Check 7: erp_cust_az12
-- Verify gender contains only standardized values
-- Expected: Only 'Male', 'Female', 'n/a'
SELECT DISTINCT gen AS gender_values FROM silver.erp_cust_az12;

-- Check 8: erp_loc_a101
-- Verify country contains only full standardized names, no raw codes remain
-- Expected: No values like 'US', 'USA', 'DE' — only full country names or 'n/a'
SELECT DISTINCT cntry AS country_values FROM silver.erp_loc_a101;
