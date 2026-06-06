/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)
    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.
Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================
-- This view builds the customer dimension by integrating customer data from
-- three silver tables: CRM customer info (primary), ERP demographics, and
-- ERP location. A surrogate key is generated for use in the fact table joins.
--
-- Source Tables:
--   - silver.crm_cust_info  : Primary source for customer attributes
--   - silver.erp_cust_az12  : Supplementary source for birthdate and gender
--   - silver.erp_loc_a101   : Supplementary source for country
--
-- Key Logic:
--   - Gender resolution: CRM is the trusted source; ERP gender is used only
--     as a fallback when CRM value is 'n/a' (unresolved)
--   - JOIN keys: cst_key (CRM) matched to cid (ERP) after both were cleaned
--     and standardized in the silver layer
-- =============================================================================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;  -- Drop existing view to allow clean re-creation
GO

CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key, -- Surrogate key: system-generated integer for joining to fact table
    ci.cst_id                           AS customer_id,  -- Natural key from CRM source system
    ci.cst_key                          AS customer_number, -- Business identifier used to link CRM and ERP records
    ci.cst_firstname                    AS first_name,
    ci.cst_lastname                     AS last_name,
    la.cntry                            AS country,       -- Sourced from ERP location table
    ci.cst_marital_status               AS marital_status,
    CASE 
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr  -- CRM is the primary trusted source for gender
        ELSE COALESCE(ca.gen, 'n/a')                 -- Fall back to ERP gender if CRM value is unresolved
    END                                 AS gender,
    ca.bdate                            AS birthdate,    -- Sourced from ERP demographics table
    ci.cst_create_date                  AS create_date   -- Original record creation date from CRM
FROM silver.crm_cust_info ci
-- Bring in ERP demographics (birthdate, gender) matched on cleaned customer key
LEFT JOIN silver.erp_cust_az12 ca
    ON ci.cst_key = ca.cid
-- Bring in ERP location (country) matched on cleaned customer key
LEFT JOIN silver.erp_loc_a101 la
    ON ci.cst_key = la.cid;
GO

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================
-- This view builds the product dimension by joining CRM product master data
-- with ERP product category reference data. A surrogate key is generated for
-- use in fact table joins.
--
-- Source Tables:
--   - silver.crm_prd_info      : Primary source for product attributes
--   - silver.erp_px_cat_g1v2   : Supplementary source for category and subcategory
--
-- Key Logic:
--   - Only currently active products are included (prd_end_dt IS NULL)
--     Historical/expired product versions are excluded to keep the dimension clean
--   - JOIN key: cat_id (CRM, derived during silver transformation) matched
--     to id (ERP category reference table)
--   - Surrogate key ordered by start date and product key for deterministic ordering
-- =============================================================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;  -- Drop existing view to allow clean re-creation
GO

CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key, -- Surrogate key: system-generated integer for joining to fact table
    pn.prd_id       AS product_id,      -- Natural key from CRM source system
    pn.prd_key      AS product_number,  -- Business identifier used to link sales records to products
    pn.prd_nm       AS product_name,
    pn.cat_id       AS category_id,     -- Derived key used to join with ERP product category table
    pc.cat          AS category,        -- Top-level category sourced from ERP reference data
    pc.subcat       AS subcategory,     -- Sub-category sourced from ERP reference data
    pc.maintenance  AS maintenance,     -- Maintenance classification sourced from ERP reference data
    pn.prd_cost     AS cost,
    pn.prd_line     AS product_line,    -- Standardized product line label (e.g. Mountain, Road, Touring)
    pn.prd_start_dt AS start_date       -- Date from which this version of the product became active
FROM silver.crm_prd_info pn
-- Bring in product category details matched on the derived category ID
LEFT JOIN silver.erp_px_cat_g1v2 pc
    ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL;  -- Include only currently active products; exclude historical/expired versions
GO

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================
-- This view builds the central fact table of the star schema by combining
-- transactional sales data from CRM with surrogate keys from both dimension
-- views. This is the primary table for sales analytics and reporting.
--
-- Source Tables:
--   - silver.crm_sales_details : Primary source for sales transactions
--   - gold.dim_products        : Provides product surrogate key
--   - gold.dim_customers       : Provides customer surrogate key
--
-- Key Logic:
--   - Fact table references dimension surrogate keys (not natural keys) to
--     support standard star schema query patterns
--   - JOIN to dim_products uses product_number (business key from CRM)
--   - JOIN to dim_customers uses customer_id (natural key from CRM)
--   - All date, sales, quantity, and price fields were already cleaned and
--     validated in the silver layer; no further transformation needed here
-- =============================================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;  -- Drop existing view to allow clean re-creation
GO

CREATE VIEW gold.fact_sales AS
SELECT
    sd.sls_ord_num  AS order_number,   -- Unique identifier for each sales order
    pr.product_key  AS product_key,    -- Surrogate key from gold.dim_products (replaces raw product key)
    cu.customer_key AS customer_key,   -- Surrogate key from gold.dim_customers (replaces raw customer ID)
    sd.sls_order_dt AS order_date,     -- Date the order was placed (cleaned DATE type from silver)
    sd.sls_ship_dt  AS shipping_date,  -- Date the order was shipped (cleaned DATE type from silver)
    sd.sls_due_dt   AS due_date,       -- Expected delivery date (cleaned DATE type from silver)
    sd.sls_sales    AS sales_amount,   -- Total sales value (recalculated and validated in silver)
    sd.sls_quantity AS quantity,       -- Number of units sold
    sd.sls_price    AS price           -- Unit price (derived or validated in silver)
FROM silver.crm_sales_details sd
-- Resolve product surrogate key by matching business product key
LEFT JOIN gold.dim_products pr
    ON sd.sls_prd_key = pr.product_number
-- Resolve customer surrogate key by matching CRM customer natural key
LEFT JOIN gold.dim_customers cu
    ON sd.sls_cust_id = cu.customer_id;
GO
