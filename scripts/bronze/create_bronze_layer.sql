/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'bronze' schema, dropping existing tables 
    if they already exist.
	  Run this script to re-define the DDL structure of 'bronze' Tables
===============================================================================
*/

-- Check if the CRM customer info table exists; drop it to allow a clean re-creation
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_cust_info;
GO

-- 1. Create CRM customer info table to store core customer attributes from the CRM source system
CREATE TABLE bronze.crm_cust_info (
    cst_id              INT,            -- Unique numeric identifier for each customer
    cst_key             NVARCHAR(50),   -- Business/natural key used to identify the customer in the source system
    cst_firstname       NVARCHAR(50),   -- Customer's first name
    cst_lastname        NVARCHAR(50),   -- Customer's last name
    cst_marital_status  NVARCHAR(50),   -- Marital status (e.g., Single, Married)
    cst_gndr            NVARCHAR(50),   -- Gender of the customer
    cst_create_date     DATE            -- Date when the customer record was created in the source system
);
GO

-- Check if the CRM product info table exists; drop it to allow a clean re-creation
IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_prd_info;
GO

-- 2. Create CRM product info table to store product master data from the CRM source system
CREATE TABLE bronze.crm_prd_info (
    prd_id       INT,            -- Unique numeric identifier for each product
    prd_key      NVARCHAR(50),   -- Business/natural key used to identify the product in the source system
    prd_nm       NVARCHAR(50),   -- Name/description of the product
    prd_cost     INT,            -- Cost associated with the product
    prd_line     NVARCHAR(50),   -- Product line or category grouping (e.g., Road, Mountain)
    prd_start_dt DATETIME,       -- Date from which the product record became active/valid
    prd_end_dt   DATETIME        -- Date on which the product record expired or was replaced (NULL if still active)
);
GO

-- Check if the CRM sales details table exists; drop it to allow a clean re-creation
IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE bronze.crm_sales_details;
GO

-- 3. Create CRM sales details table to store transactional sales order data from the CRM source system
CREATE TABLE bronze.crm_sales_details (
    sls_ord_num  NVARCHAR(50),   -- Sales order number (unique identifier for each order)
    sls_prd_key  NVARCHAR(50),   -- Product key referencing the product sold (links to crm_prd_info)
    sls_cust_id  INT,            -- Customer ID referencing the buyer (links to crm_cust_info)
    sls_order_dt INT,            -- Order date stored as integer (raw format from source, e.g. YYYYMMDD)
    sls_ship_dt  INT,            -- Shipment date stored as integer (raw format from source)
    sls_due_dt   INT,            -- Due/expected delivery date stored as integer (raw format from source)
    sls_sales    INT,            -- Total sales amount for the order line
    sls_quantity INT,            -- Quantity of product units ordered
    sls_price    INT             -- Unit price of the product at the time of the order
);
GO

-- Check if the ERP location table exists; drop it to allow a clean re-creation
IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE bronze.erp_loc_a101;
GO

-- 4. Create ERP location table to store customer-to-country mapping from the ERP source system
CREATE TABLE bronze.erp_loc_a101 (
    cid    NVARCHAR(50),   -- Customer identifier (links to customer records in other tables)
    cntry  NVARCHAR(50)    -- Country associated with the customer's location
);
GO

-- Check if the ERP customer demographics table exists; drop it to allow a clean re-creation
IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE bronze.erp_cust_az12;
GO

-- 5. Create ERP customer demographics table to store additional customer attributes from the ERP source system
CREATE TABLE bronze.erp_cust_az12 (
    cid    NVARCHAR(50),   -- Customer identifier (links to customer records in other tables)
    bdate  DATE,           -- Customer's date of birth
    gen    NVARCHAR(50)    -- Gender of the customer (raw value from ERP, may differ from CRM)
);
GO

-- Check if the ERP product category table exists; drop it to allow a clean re-creation
IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE bronze.erp_px_cat_g1v2;
GO

-- 6. Create ERP product category table to store product classification hierarchy from the ERP source system
CREATE TABLE bronze.erp_px_cat_g1v2 (
    id           NVARCHAR(50),   -- Product identifier (links to product records in other tables)
    cat          NVARCHAR(50),   -- Top-level product category (e.g., Bikes, Accessories)
    subcat       NVARCHAR(50),   -- Sub-category under the main category (e.g., Road Bikes, Helmets)
    maintenance  NVARCHAR(50)    -- Maintenance classification or flag associated with the product
);
GO
