/*
===============================================================================
Quality Check Script: Gold Layer
===============================================================================
Script Purpose:
    This script performs basic quality checks on the 'gold' schema views.
    It verifies:
    - Row counts to confirm views are returning data successfully
    - View structure to confirm correct column names and data types
    - Sample data preview to visually inspect business-ready records
    - Referential integrity checks between fact and dimension views
    - Business logic validation on key rules applied in the gold views

Usage Example:
    Run this script after creating gold views to validate the layer.
===============================================================================
*/

-- ============================================================
-- SECTION 1: ROW COUNT CHECKS
-- Purpose: Confirm that each gold view is returning data and
--          counts are consistent with expectations from silver
-- ============================================================

PRINT '================================================';
PRINT 'Gold Layer - Row Count Checks';
PRINT '================================================';

-- Check row counts across all gold views in one result set
-- Expected:
--   dim_customers : Should match silver.crm_cust_info (one row per unique customer)
--   dim_products  : Should be less than silver.crm_prd_info (active products only)
--   fact_sales    : Should match silver.crm_sales_details (one row per sales transaction)
SELECT 'gold.dim_customers' AS view_name, COUNT(*) AS row_count FROM gold.dim_customers
UNION ALL
SELECT 'gold.dim_products'  AS view_name, COUNT(*) AS row_count FROM gold.dim_products
UNION ALL
SELECT 'gold.fact_sales'    AS view_name, COUNT(*) AS row_count FROM gold.fact_sales;

-- ============================================================
-- SECTION 2: VIEW STRUCTURE CHECKS
-- Purpose: Confirm that all columns exist with the correct
--          names and data types as defined in the gold views
--          including surrogate keys in dimensions
-- ============================================================

PRINT '================================================';
PRINT 'Gold Layer - View Structure Checks';
PRINT '================================================';

-- Retrieve column metadata for all gold views from the system catalog
-- Expected: Each view should show all defined columns including
--           customer_key and product_key as surrogate key columns
SELECT 
    TABLE_NAME  AS view_name,
    COLUMN_NAME AS column_name,
    DATA_TYPE   AS data_type,
    IS_NULLABLE AS is_nullable
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold'
ORDER BY TABLE_NAME, ORDINAL_POSITION;  -- Order by view and column position for easy reading

-- ============================================================
-- SECTION 3: SAMPLE DATA PREVIEW
-- Purpose: Visually inspect a small sample of business-ready
--          records to confirm joins and transformations are
--          producing clean, enriched, and meaningful output
-- ============================================================

PRINT '================================================';
PRINT 'Gold Layer - Sample Data Preview';
PRINT '================================================';

-- Preview top 5 rows from each gold view
-- Expected: Fully enriched records with no raw codes or keys visible

-- Customer dimension: should show full names, readable country,
-- gender, marital status, birthdate — no raw single-char codes
SELECT TOP 5 * FROM gold.dim_customers;

-- Product dimension: should show product names with full category,
-- subcategory labels and only currently active products
SELECT TOP 5 * FROM gold.dim_products;

-- Fact table: should show surrogate keys (not raw IDs) linked to
-- dimensions alongside clean sales metrics and proper DATE values
SELECT TOP 5 * FROM gold.fact_sales;

-- ============================================================
-- SECTION 4: REFERENTIAL INTEGRITY CHECKS
-- Purpose: Validate that all foreign keys in the fact table
--          resolve to valid records in the dimension views
--          Any NULLs here indicate unmatched/orphaned records
-- ============================================================

PRINT '================================================';
PRINT 'Gold Layer - Referential Integrity Checks';
PRINT '================================================';

-- Check 1: fact_sales -> dim_customers
-- Verify every sales record successfully resolves to a customer
-- Expected: 0 rows (all customer keys in fact should exist in dim)
SELECT 
    fs.order_number,
    fs.customer_key
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers cu
    ON fs.customer_key = cu.customer_key
WHERE cu.customer_key IS NULL;  -- Any rows here mean orphaned sales with no matching customer

-- Check 2: fact_sales -> dim_products
-- Verify every sales record successfully resolves to a product
-- Expected: 0 rows (all product keys in fact should exist in dim)
SELECT 
    fs.order_number,
    fs.product_key
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products pr
    ON fs.product_key = pr.product_key
WHERE pr.product_key IS NULL;  -- Any rows here mean orphaned sales with no matching product

-- ============================================================
-- SECTION 5: BUSINESS LOGIC VALIDATION
-- Purpose: Validate that key business rules and transformations
--          defined in the gold views are working correctly
-- ============================================================

PRINT '================================================';
PRINT 'Gold Layer - Business Logic Validation';
PRINT '================================================';

-- Check 3: dim_customers
-- Verify surrogate keys are unique and not NULL
-- Expected: 0 rows (every customer must have a unique surrogate key)
SELECT 
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;  -- Any rows here indicate surrogate key generation failure

-- Check 4: dim_customers
-- Verify gender resolution logic worked correctly
-- CRM gender was preferred; ERP was used only as fallback
-- Expected: Only 'Male', 'Female', 'n/a' — no raw codes like 'M' or 'F'
SELECT DISTINCT gender AS gender_values FROM gold.dim_customers;

-- Check 5: dim_customers
-- Verify country values are fully standardized full names
-- Expected: No raw codes like 'DE', 'US', 'USA' — only full names or 'n/a'
SELECT DISTINCT country AS country_values FROM gold.dim_customers;

-- Check 6: dim_products
-- Verify surrogate keys are unique and not NULL
-- Expected: 0 rows (every product must have a unique surrogate key)
SELECT 
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;  -- Any rows here indicate surrogate key generation failure

-- Check 7: dim_products
-- Verify only currently active products are included in the dimension
-- Expected: 0 rows (historical records filtered by prd_end_dt IS NULL in the view)
SELECT 
    product_id,
    product_number,
    start_date
FROM gold.dim_products
WHERE start_date IS NULL;  -- Active products must always have a valid start date

-- Check 8: dim_products
-- Verify all products successfully joined to a category from ERP
-- Expected: 0 rows (every product should resolve to a category)
SELECT 
    product_id,
    product_number,
    category_id,
    category
FROM gold.dim_products
WHERE category IS NULL;  -- Any rows here mean unmatched category IDs between CRM and ERP

-- Check 9: fact_sales
-- Verify no NULL surrogate keys exist in the fact table
-- Expected: 0 rows (every fact row must link to both a customer and a product)
SELECT 
    order_number,
    customer_key,
    product_key
FROM gold.fact_sales
WHERE customer_key IS NULL 
   OR product_key  IS NULL;  -- NULLs here break star schema joins in reporting tools

-- Check 10: fact_sales
-- Verify sales metrics are valid (no zero, negative, or NULL values)
-- Expected: 0 rows (all values were cleaned and validated in the silver layer)
SELECT 
    order_number,
    sales_amount,
    quantity,
    price
FROM gold.fact_sales
WHERE sales_amount IS NULL OR sales_amount <= 0
   OR quantity     IS NULL OR quantity     <= 0
   OR price        IS NULL OR price        <= 0;

-- Check 11: fact_sales
-- Verify order date is always before or equal to shipping and due dates
-- Expected: 0 rows (logically an order cannot ship or be due before it was placed)
SELECT
    order_number,
    order_date,
    shipping_date,
    due_date
FROM gold.fact_sales
WHERE shipping_date < order_date  -- Shipping before order date is logically impossible
   OR due_date      < order_date; -- Due date before order date is logically impossible
