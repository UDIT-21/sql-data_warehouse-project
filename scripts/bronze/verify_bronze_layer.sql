/*
===============================================================================
Quality Check Script: Bronze Layer
===============================================================================
Script Purpose:
    This script performs basic quality checks on the 'bronze' schema tables.
    It verifies:
    - Row counts to confirm data was loaded successfully
    - Table structure to confirm correct column names and data types
    - Sample data preview to visually inspect raw loaded records

Usage Example:
    Run this script after EXEC bronze.load_bronze to validate the load.
===============================================================================
*/

-- ============================================================
-- SECTION 1: ROW COUNT CHECKS
-- Purpose: Confirm that each bronze table has been loaded with
--          data and no table was accidentally left empty
-- ============================================================

PRINT '================================================';
PRINT 'Bronze Layer - Row Count Checks';
PRINT '================================================';

-- Check row counts across all bronze tables in one result set
-- Expected: All tables should have row counts greater than 0
SELECT 'bronze.crm_cust_info'     AS table_name, COUNT(*) AS row_count FROM bronze.crm_cust_info
UNION ALL
SELECT 'bronze.crm_prd_info'      AS table_name, COUNT(*) AS row_count FROM bronze.crm_prd_info
UNION ALL
SELECT 'bronze.crm_sales_details' AS table_name, COUNT(*) AS row_count FROM bronze.crm_sales_details
UNION ALL
SELECT 'bronze.erp_loc_a101'      AS table_name, COUNT(*) AS row_count FROM bronze.erp_loc_a101
UNION ALL
SELECT 'bronze.erp_cust_az12'     AS table_name, COUNT(*) AS row_count FROM bronze.erp_cust_az12
UNION ALL
SELECT 'bronze.erp_px_cat_g1v2'   AS table_name, COUNT(*) AS row_count FROM bronze.erp_px_cat_g1v2;

-- ============================================================
-- SECTION 2: TABLE STRUCTURE CHECKS
-- Purpose: Confirm that all columns exist with the correct
--          names and data types as defined in the DDL script
-- ============================================================

PRINT '================================================';
PRINT 'Bronze Layer - Table Structure Checks';
PRINT '================================================';

-- Retrieve column metadata for all bronze tables from the system catalog
-- Expected: Each table should show all its defined columns with correct data types
SELECT 
    TABLE_NAME   AS table_name,
    COLUMN_NAME  AS column_name,
    DATA_TYPE    AS data_type,
    IS_NULLABLE  AS is_nullable
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bronze'
ORDER BY TABLE_NAME, ORDINAL_POSITION;  -- Order by table and column position for easy reading

-- ============================================================
-- SECTION 3: SAMPLE DATA PREVIEW
-- Purpose: Visually inspect a small sample of raw records
--          to confirm data was loaded correctly from CSV files
-- ============================================================

PRINT '================================================';
PRINT 'Bronze Layer - Sample Data Preview';
PRINT '================================================';

-- Preview top 5 rows from each bronze table
-- Expected: Rows should reflect raw, unmodified source data from the CSV files

-- CRM: Customer master data
SELECT TOP 5 * FROM bronze.crm_cust_info;

-- CRM: Product master data
SELECT TOP 5 * FROM bronze.crm_prd_info;

-- CRM: Sales transactional data
SELECT TOP 5 * FROM bronze.crm_sales_details;

-- ERP: Customer location/country mapping
SELECT TOP 5 * FROM bronze.erp_loc_a101;

-- ERP: Customer demographics (birthdate, gender)
SELECT TOP 5 * FROM bronze.erp_cust_az12;

-- ERP: Product category and subcategory reference data
SELECT TOP 5 * FROM bronze.erp_px_cat_g1v2;
