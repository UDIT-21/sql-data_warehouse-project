/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'silver' schema, dropping existing tables 
    if they already exist.
	  Run this script to re-define the DDL structure of 'silver' Tables
===============================================================================
*/

-- Check if the silver CRM customer info table exists; drop it to allow a clean re-creation
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
GO

-- Create silver CRM customer info table
-- This is the cleaned and standardized version of bronze.crm_cust_info
-- Includes dwh_create_date to track when the record was loaded into the data warehouse
CREATE TABLE silver.crm_cust_info (
    cst_id             INT,                             -- Unique numeric identifier for each customer
    cst_key            NVARCHAR(50),                    -- Business/natural key from the CRM source system
    cst_firstname      NVARCHAR(50),                    -- Customer's first name (cleaned)
    cst_lastname       NVARCHAR(50),                    -- Customer's last name (cleaned)
    cst_marital_status NVARCHAR(50),                    -- Standardized marital status (e.g., 'Married', 'Single')
    cst_gndr           NVARCHAR(50),                    -- Standardized gender value (e.g., 'Male', 'Female')
    cst_create_date    DATE,                            -- Original record creation date from the CRM source
    dwh_create_date    DATETIME2 DEFAULT GETDATE()      -- Audit column: timestamp when the row was inserted into the silver layer
);
GO

-- Check if the silver CRM product info table exists; drop it to allow a clean re-creation
IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

-- Create silver CRM product info table
-- This is the cleaned and standardized version of bronze.crm_prd_info
-- cat_id is a new derived column extracted and mapped during silver transformation
-- Date columns are promoted from DATETIME (bronze) to DATE since time component is not needed
CREATE TABLE silver.crm_prd_info (
    prd_id          INT,                                -- Unique numeric identifier for each product
    cat_id          NVARCHAR(50),                       -- Category identifier derived from the product key during transformation
    prd_key         NVARCHAR(50),                       -- Business/natural key from the CRM source system
    prd_nm          NVARCHAR(50),                       -- Product name (cleaned)
    prd_cost        INT,                                -- Cost of the product
    prd_line        NVARCHAR(50),                       -- Standardized product line (e.g., 'Road', 'Mountain')
    prd_start_dt    DATE,                               -- Date from which the product record became active (cast from DATETIME in bronze)
    prd_end_dt      DATE,                               -- Date on which the product record expired (cast from DATETIME in bronze; NULL if still active)
    dwh_create_date DATETIME2 DEFAULT GETDATE()         -- Audit column: timestamp when the row was inserted into the silver layer
);
GO

-- Check if the silver CRM sales details table exists; drop it to allow a clean re-creation
IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
GO

-- Create silver CRM sales details table
-- This is the cleaned and standardized version of bronze.crm_sales_details
-- Date columns are promoted from INT (raw YYYYMMDD format in bronze) to proper DATE type
CREATE TABLE silver.crm_sales_details (
    sls_ord_num     NVARCHAR(50),                       -- Sales order number (unique identifier for each order)
    sls_prd_key     NVARCHAR(50),                       -- Product key referencing the product sold (links to crm_prd_info)
    sls_cust_id     INT,                                -- Customer ID referencing the buyer (links to crm_cust_info)
    sls_order_dt    DATE,                               -- Order date properly cast from raw INT (YYYYMMDD) in bronze
    sls_ship_dt     DATE,                               -- Shipment date properly cast from raw INT (YYYYMMDD) in bronze
    sls_due_dt      DATE,                               -- Due date properly cast from raw INT (YYYYMMDD) in bronze
    sls_sales       INT,                                -- Total sales amount for the order line
    sls_quantity    INT,                                -- Quantity of product units ordered
    sls_price       INT,                                -- Unit price of the product at the time of the order
    dwh_create_date DATETIME2 DEFAULT GETDATE()         -- Audit column: timestamp when the row was inserted into the silver layer
);
GO

-- Check if the silver ERP location table exists; drop it to allow a clean re-creation
IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO

-- Create silver ERP location table
-- This is the cleaned and standardized version of bronze.erp_loc_a101
-- Country values are normalized (e.g., trimmed, corrected inconsistent labels) during transformation
CREATE TABLE silver.erp_loc_a101 (
    cid             NVARCHAR(50),                       -- Customer identifier (links to customer records across tables)
    cntry           NVARCHAR(50),                       -- Standardized country name associated with the customer
    dwh_create_date DATETIME2 DEFAULT GETDATE()         -- Audit column: timestamp when the row was inserted into the silver layer
);
GO

-- Check if the silver ERP customer demographics table exists; drop it to allow a clean re-creation
IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO

-- Create silver ERP customer demographics table
-- This is the cleaned and standardized version of bronze.erp_cust_az12
-- Gender values are standardized to align with CRM gender conventions during transformation
CREATE TABLE silver.erp_cust_az12 (
    cid             NVARCHAR(50),                       -- Customer identifier (links to customer records across tables)
    bdate           DATE,                               -- Customer's date of birth (validated and cleaned)
    gen             NVARCHAR(50),                       -- Standardized gender value (harmonized with CRM during transformation)
    dwh_create_date DATETIME2 DEFAULT GETDATE()         -- Audit column: timestamp when the row was inserted into the silver layer
);
GO

-- Check if the silver ERP product category table exists; drop it to allow a clean re-creation
IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO

-- Create silver ERP product category table
-- This is the cleaned and standardized version of bronze.erp_px_cat_g1v2
-- Category and subcategory values are validated and trimmed during transformation
CREATE TABLE silver.erp_px_cat_g1v2 (
    id              NVARCHAR(50),                       -- Product identifier (links to product records across tables)
    cat             NVARCHAR(50),                       -- Standardized top-level product category (e.g., 'Bikes', 'Accessories')
    subcat          NVARCHAR(50),                       -- Standardized sub-category under the main category
    maintenance     NVARCHAR(50),                       -- Maintenance classification flag associated with the product
    dwh_create_date DATETIME2 DEFAULT GETDATE()         -- Audit column: timestamp when the row was inserted into the silver layer
);
GO
