/*
===============================================================================
Quality Check Script: Silver Layer
===============================================================================
Script Purpose:
    This script performs quality checks to validate the integrity, consistency,
    and accuracy of the Silver Layer. These checks ensure:
    - Row counts to confirm transformation and load was successful
    - Table structure to confirm correct column names and data types
    - Sample data preview to visually inspect cleaned and transformed records
    - NULL or duplicate primary keys are identified
    - Unwanted spaces in string fields are detected
    - Data standardization and consistency is validated
    - Invalid date ranges and orders are caught
    - Data consistency between related fields is verified

Usage Notes:
    - Run these checks after EXEC silver.load_silver
    - Investigate and resolve any discrepancies found during the checks
    - Expected result is noted above each check
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
--           crm_cust_info will be lower due to deduplication logic
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
-- Expected: Cleaned and standardized values with no raw single-char codes

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
-- SECTION 4: silver.crm_cust_info CHECKS
-- ============================================================

PRINT '================================================';
PRINT 'Silver Layer - silver.crm_cust_info Checks';
PRINT '================================================';

-- Check 1: NULL or Duplicate Primary Keys
-- Verifies deduplication logic in load_silver worked correctly
-- Expected: No results
SELECT 
    cst_id,
    COUNT(*) AS duplicate_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check 2: Unwanted Spaces in Customer Key
-- Verifies no leading or trailing whitespace remains in key fields
-- Expected: No results
SELECT 
    cst_key
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key);

-- Check 3: Unwanted Spaces in Name Fields
-- Verifies TRIM() was correctly applied to first and last name during load
-- Expected: No results
SELECT 
    cst_firstname,
    cst_lastname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)
   OR cst_lastname  != TRIM(cst_lastname);

-- Check 4: Gender Standardization
-- Verifies gender codes were decoded to readable labels
-- Expected: Only 'Male', 'Female', 'n/a'
SELECT DISTINCT 
    cst_gndr AS gender_values
FROM silver.crm_cust_info;

-- Check 5: Marital Status Standardization
-- Verifies marital status codes were decoded to readable labels
-- Expected: Only 'Married', 'Single', 'n/a'
SELECT DISTINCT 
    cst_marital_status AS marital_status_values
FROM silver.crm_cust_info;

-- ============================================================
-- SECTION 5: silver.crm_prd_info CHECKS
-- ============================================================

PRINT '================================================';
PRINT 'Silver Layer - silver.crm_prd_info Checks';
PRINT '================================================';

-- Check 6: NULL or Duplicate Primary Keys
-- Expected: No results
SELECT 
    prd_id,
    COUNT(*) AS duplicate_count
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Check 7: Unwanted Spaces in Product Name
-- Verifies no leading or trailing whitespace remains in product name
-- Expected: No results
SELECT 
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- Check 8: NULL or Negative Product Cost
-- Verifies ISNULL(prd_cost, 0) was applied correctly during load
-- Expected: No results
SELECT 
    prd_id,
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Check 9: Product Line Standardization
-- Verifies product line codes were decoded to readable labels
-- Expected: Only 'Mountain', 'Road', 'Other Sales', 'Touring', 'n/a'
SELECT DISTINCT 
    prd_line AS product_line_values
FROM silver.crm_prd_info;

-- Check 10: Invalid Date Order (Start Date > End Date)
-- Verifies no product has an end date that precedes its start date
-- Expected: No results
SELECT 
    prd_id,
    prd_key,
    prd_start_dt,
    prd_end_dt
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- ============================================================
-- SECTION 6: silver.crm_sales_details CHECKS
-- ============================================================

PRINT '================================================';
PRINT 'Silver Layer - silver.crm_sales_details Checks';
PRINT '================================================';

-- Check 11: Invalid Raw Date Integers in Bronze Source
-- Validates the raw integer date fields before they were converted
-- Catches values that are 0, wrong digit length, or out of realistic range
-- Expected: No results (all should have been handled during silver load)
SELECT 
    NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
   OR LEN(sls_due_dt) != 8
   OR sls_due_dt > 20500101   -- Dates beyond year 2050 are unrealistic
   OR sls_due_dt < 19000101;  -- Dates before year 1900 are unrealistic

-- Check 12: Invalid Date Order (Order Date > Shipping or Due Date)
-- Verifies that an order was not recorded as shipping or due before it was placed
-- Expected: No results
SELECT 
    sls_ord_num,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt   -- Order cannot ship before it was placed
   OR sls_order_dt > sls_due_dt;   -- Order cannot be due before it was placed

-- Check 13: Sales Consistency (Sales = Quantity * Price)
-- Verifies the core business rule: sales amount must equal quantity multiplied by price
-- Also checks for any NULL or non-positive values in key metrics
-- Expected: No results
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales    != sls_quantity * sls_price  -- Catches mathematically inconsistent rows
   OR sls_sales    IS NULL OR sls_sales    <= 0
   OR sls_quantity IS NULL OR sls_quantity <= 0
   OR sls_price    IS NULL OR sls_price    <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- ============================================================
-- SECTION 7: silver.erp_cust_az12 CHECKS
-- ============================================================

PRINT '================================================';
PRINT 'Silver Layer - silver.erp_cust_az12 Checks';
PRINT '================================================';

-- Check 14: Out-of-Range Birthdates
-- Verifies birthdates fall within a realistic human lifespan range
-- Future dates should have been nullified during silver load
-- Expected: No results
SELECT DISTINCT
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'  -- Older than 100 years is unrealistic
   OR bdate > GETDATE();    -- Future birthdates are invalid

-- Check 15: Gender Standardization
-- Verifies multiple raw gender formats were normalized correctly
-- Expected: Only 'Male', 'Female', 'n/a'
SELECT DISTINCT 
    gen AS gender_values
FROM silver.erp_cust_az12;

-- ============================================================
-- SECTION 8: silver.erp_loc_a101 CHECKS
-- ============================================================

PRINT '================================================';
PRINT 'Silver Layer - silver.erp_loc_a101 Checks';
PRINT '================================================';

-- Check 16: Country Standardization
-- Verifies country codes and abbreviations were expanded to full names
-- Expected: No raw codes like 'DE', 'US', 'USA' — only full names or 'n/a'
SELECT DISTINCT 
    cntry AS country_values
FROM silver.erp_loc_a101
ORDER BY cntry;

-- ============================================================
-- SECTION 9: silver.erp_px_cat_g1v2 CHECKS
-- ============================================================

PRINT '================================================';
PRINT 'Silver Layer - silver.erp_px_cat_g1v2 Checks';
PRINT '================================================';

-- Check 17: Unwanted Spaces in Category Fields
-- Verifies no leading or trailing whitespace in category reference data
-- Expected: No results
SELECT 
    id,
    cat,
    subcat,
    maintenance
FROM silver.erp_px_cat_g1v2
WHERE cat         != TRIM(cat)
   OR subcat      != TRIM(subcat)
   OR maintenance != TRIM(maintenance);

-- Check 18: Maintenance Value Standardization
-- Verifies maintenance field contains only expected classification values
-- Expected: A small distinct list of known maintenance labels
SELECT DISTINCT 
    maintenance AS maintenance_values
FROM silver.erp_px_cat_g1v2;
