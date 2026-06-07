# Data Warehouse Patterns — Complete Reference Guide

> **Purpose:** Self-documentation for the DataWarehouse project built using Medallion Architecture (Bronze → Silver → Gold) on SQL Server.  
> **Author:** Udit  
> **Source:** Self-taught project from YouTube  
> **Stack:** SQL Server · T-SQL · SSMS · CSV flat files  

---

## Table of Contents

1. [The Big Picture](#1-the-big-picture)
2. [Database & Schema Setup](#2-database--schema-setup)
3. [DDL Patterns — Creating Tables](#3-ddl-patterns--creating-tables)
   - [Bronze Table Pattern](#31-bronze-table-pattern)
   - [Silver Table Pattern](#32-silver-table-pattern)
4. [Data Load Patterns — Bronze Layer](#4-data-load-patterns--bronze-layer)
   - [Stored Procedure Shell](#41-stored-procedure-shell)
   - [Per-Table BULK INSERT Block](#42-per-table-bulk-insert-block)
5. [Transformation Patterns — Silver Layer](#5-transformation-patterns--silver-layer)
   - [Pattern 1 — TRIM](#51-pattern-1--trim-remove-whitespace)
   - [Pattern 2 — CASE WHEN Decode](#52-pattern-2--case-when-decode-codes-to-labels)
   - [Pattern 3 — ROW_NUMBER Deduplication](#53-pattern-3--row_number-deduplication)
   - [Pattern 4 — Integer Date Conversion](#54-pattern-4--integer-date-conversion)
   - [Pattern 5 — Business Rule Recalculation](#55-pattern-5--business-rule-recalculation)
   - [Bonus — SCD Type 2 with LEAD()](#56-bonus-pattern--scd-type-2-with-lead)
6. [Gold Layer — Views Pattern](#6-gold-layer--views-pattern)
   - [Why Views Not Tables](#61-why-views-not-tables)
   - [Surrogate Keys](#62-surrogate-keys)
   - [dim_customers](#63-gold-view-dim_customers)
   - [dim_products](#64-gold-view-dim_products)
   - [fact_sales](#65-gold-view-fact_sales)
7. [Master Cheat Sheet](#10-master-cheat-sheet)

---

## 1. The Big Picture

```
CSV Files (Raw Data)
      ↓
  BRONZE Layer   ←  "Land it as-is. No transformation."
      ↓
  SILVER Layer   ←  "Clean it. Standardize it. Fix it."
      ↓
  GOLD Layer     ←  "Shape it for business. Views only."
```

| Layer | Storage | Purpose | Refresh Method |
|-------|---------|---------|----------------|
| Bronze | Physical Tables | Raw copy of source | TRUNCATE + BULK INSERT |
| Silver | Physical Tables | Cleaned & standardized | TRUNCATE + INSERT SELECT |
| Gold | Views (no data) | Business-ready star schema | Automatic (reads from silver) |

> **Key insight:** The tables change across projects. The logic changes. The **pattern never changes.**

---

## 2. Database & Schema Setup

> Run this **once per project.** Always start from `master`.

```sql
/*
============================================================
TEMPLATE: Create any database from scratch
============================================================
*/

-- Step 1: Always work from master
USE master;
GO

-- Step 2: Drop and recreate — the "clean slate" pattern
-- Always check before dropping. Never blindly drop.
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    -- SINGLE_USER  = only one connection allowed (you)
    -- ROLLBACK IMMEDIATE = cancel all running transactions instantly
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO

-- Step 3: Create the database
CREATE DATABASE DataWarehouse;
GO

-- Step 4: Switch into it
USE DataWarehouse;
GO

-- Step 5: Create schemas (one per layer)
-- Schemas = logical folders inside a database
CREATE SCHEMA bronze; GO
CREATE SCHEMA silver; GO
CREATE SCHEMA gold;   GO
```

### What is `GO`?

`GO` is a **batch separator** in SSMS. It tells SQL Server:
> *"Execute everything above this line as one batch before moving on."*

Think of it like pressing **Enter** to confirm a command in a terminal.

---

## 3. DDL Patterns — Creating Tables

### The Universal Pattern

```
Check if table exists → Drop it → Create it fresh
```

This is used for **every single table** in Bronze and Silver. Only the table name and columns change.

---

### 3.1 Bronze Table Pattern

Bronze tables are **exact mirrors of your CSV files.**  
- No logic  
- No cleaning  
- Raw data types only  

```sql
/*
============================================================
BRONZE TABLE TEMPLATE
============================================================
Copy this. Change schema, table name, and columns. Done.
============================================================
*/

-- Step 1: Check and drop
IF OBJECT_ID('bronze.your_table_name', 'U') IS NOT NULL
    DROP TABLE bronze.your_table_name;
GO
-- 'U' = User table (vs views, procedures, etc.)
-- OBJECT_ID returns NULL if table doesn't exist → safe skip

-- Step 2: Create with raw data types
CREATE TABLE bronze.your_table_name (
    id_column       INT,             -- numeric IDs from source
    key_column      NVARCHAR(50),    -- text keys (N = supports unicode/special chars)
    name_column     NVARCHAR(50),    -- any text field
    status_column   NVARCHAR(50),    -- raw codes like 'S', 'M', 'F' (NOT cleaned yet)
    date_column     DATE,            -- date only
    datetime_column DATETIME,        -- date + time
    int_date_column INT              -- dates stored as integers e.g. 20230415
);
GO
```

**Real example from this project:**

```sql
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_cust_info;
GO

CREATE TABLE bronze.crm_cust_info (
    cst_id              INT,          -- raw numeric ID
    cst_key             NVARCHAR(50), -- business key
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_marital_status  NVARCHAR(50), -- raw: 'S' or 'M'
    cst_gndr            NVARCHAR(50), -- raw: 'F' or 'M'
    cst_create_date     DATE
);
GO
```

---

### 3.2 Silver Table Pattern

Silver tables look nearly identical to bronze with **two key differences:**

1. **Better data types** — INT dates become proper `DATE`, `DATETIME` becomes `DATE`
2. **One extra audit column** — `dwh_create_date DATETIME2 DEFAULT GETDATE()`

```sql
/*
============================================================
SILVER TABLE TEMPLATE
============================================================
Same as bronze + better types + audit column at the end.
============================================================
*/

IF OBJECT_ID('silver.your_table_name', 'U') IS NOT NULL
    DROP TABLE silver.your_table_name;
GO

CREATE TABLE silver.your_table_name (
    id_column       INT,
    key_column      NVARCHAR(50),
    name_column     NVARCHAR(50),
    status_column   NVARCHAR(50),    -- will store 'Single', 'Married' (decoded)
    date_column     DATE,            -- promoted from INT in bronze
    
    -- THE KEY DIFFERENCE FROM BRONZE ↓
    dwh_create_date DATETIME2 DEFAULT GETDATE()
    -- DATETIME2  = more precise than DATETIME
    -- DEFAULT GETDATE() = auto-fills with current timestamp on INSERT
    -- This is your audit trail: "when did this row land in silver?"
);
GO
```

**Bronze vs Silver — side by side:**

```sql
-- BRONZE: raw codes, no audit column
CREATE TABLE bronze.crm_cust_info (
    cst_id              INT,
    cst_marital_status  NVARCHAR(50), -- stores 'S', 'M'
    cst_gndr            NVARCHAR(50), -- stores 'F', 'M'
    cst_create_date     DATE
    -- no dwh_create_date
);

-- SILVER: decoded labels, with audit column
CREATE TABLE silver.crm_cust_info (
    cst_id              INT,
    cst_marital_status  NVARCHAR(50), -- stores 'Single', 'Married'
    cst_gndr            NVARCHAR(50), -- stores 'Female', 'Male'
    cst_create_date     DATE,
    dwh_create_date     DATETIME2 DEFAULT GETDATE()  -- ← NEW in silver
);
```

---

## 4. Data Load Patterns — Bronze Layer

### The Pattern

```
Stored Procedure
    └── BEGIN TRY
            ├── Table 1: TRUNCATE → BULK INSERT → Log duration
            ├── Table 2: TRUNCATE → BULK INSERT → Log duration
            └── Table N: TRUNCATE → BULK INSERT → Log duration
    └── BEGIN CATCH
            └── Print error details
```

---

### 4.1 Stored Procedure Shell

```sql
/*
============================================================
STORED PROCEDURE TEMPLATE — any layer load
============================================================
The shell never changes. Only the load blocks inside change.
============================================================
*/

CREATE OR ALTER PROCEDURE schema_name.procedure_name AS
BEGIN
    -- Timing variables — declare once, reuse for every table
    DECLARE @start_time       DATETIME,
            @end_time         DATETIME,
            @batch_start_time DATETIME,
            @batch_end_time   DATETIME;

    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Starting Load...';
        PRINT '================================================';

        -- ← INSERT YOUR TABLE LOAD BLOCKS HERE

        SET @batch_end_time = GETDATE();
        PRINT 'Load Complete. Total Duration: '
            + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time)
              AS NVARCHAR) + ' seconds';
    END TRY

    -- Fires if ANYTHING in the TRY block fails
    BEGIN CATCH
        PRINT '========================================';
        PRINT 'ERROR OCCURRED';
        PRINT 'Message: ' + ERROR_MESSAGE();
        PRINT 'Number:  ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'State:   ' + CAST(ERROR_STATE()  AS NVARCHAR);
        PRINT '========================================';
    END CATCH
END
```

---

### 4.2 Per-Table BULK INSERT Block

```sql
/*
============================================================
ONE TABLE LOAD BLOCK
============================================================
Copy this block for every table. Change only:
  1. The table name
  2. The file path
Everything else stays identical.
============================================================
*/

SET @start_time = GETDATE();
PRINT '>> Truncating: schema.table_name';

-- TRUNCATE vs DELETE:
-- TRUNCATE = wipes all rows instantly, no row-level logging → FAST
-- DELETE   = logs each row deletion → SLOW, use only when WHERE needed
-- Always use TRUNCATE in ETL full loads
TRUNCATE TABLE schema.table_name;

PRINT '>> Loading: schema.table_name';
BULK INSERT schema.table_name
FROM 'C:\path\to\your\file.csv'
WITH (
    FIRSTROW = 2,           -- Skip row 1 (the header row in the CSV)
    FIELDTERMINATOR = ',',  -- Columns are comma-separated
    TABLOCK                 -- Lock entire table during load = faster
);

SET @end_time = GETDATE();
PRINT '>> Duration: '
    + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
    + ' seconds';
PRINT '>> -------------';
```

> **Remember:** Only two things change per table block — the **table name** and the **file path**. The timing, truncate, and BULK INSERT structure is always the same.

---

## 5. Transformation Patterns — Silver Layer

Silver is where the real engineering happens. Every transformation you will ever write in silver falls into one of these five patterns.

---

### 5.1 Pattern 1 — TRIM (Remove Whitespace)

**Problem:** Source data has accidental spaces — `'  John  '` instead of `'John'`  
**Solution:** `TRIM()`

```sql
-- Apply to any text column from an external/human-entered source
TRIM(cst_firstname) AS cst_firstname,
TRIM(cst_lastname)  AS cst_lastname

-- Defensive version (also upper-cases before comparison):
UPPER(TRIM(column_name))
-- Handles: 'john', 'JOHN', ' John ', ' john ' → all become 'JOHN'
```

---

### 5.2 Pattern 2 — CASE WHEN (Decode Codes to Labels)

**Problem:** Source stores `'M'`, `'S'` — needs to be `'Married'`, `'Single'`  
**Solution:** `CASE WHEN`

```sql
-- Always combine with UPPER(TRIM()) for defensive matching
CASE
    WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
    WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
    ELSE 'n/a'   -- ALWAYS have ELSE — never leave unknowns as NULL
END AS cst_marital_status

-- Same pattern for gender:
CASE
    WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
    WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
    ELSE 'n/a'
END AS cst_gndr

-- Same pattern for product lines:
CASE
    WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
    WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
    WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
    WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
    ELSE 'n/a'
END AS prd_line
```

> **Rule:** Use on any coded/abbreviated column — status, gender, type, flag, category code.

---

### 5.3 Pattern 3 — ROW_NUMBER() Deduplication

**Problem:** Same customer appears 3 times in source. Keep only the most recent record.  
**Solution:** `ROW_NUMBER()` window function + subquery filter

```sql
-- The full deduplication pattern:
SELECT * FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY cst_id           -- group by the unique key
            ORDER BY cst_create_date DESC -- most recent gets rank 1
        ) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL  -- always filter NULLs before deduplication
) t
WHERE flag_last = 1           -- keep only rank 1 = most recent per key

-- How to adapt this for any table:
--   Change PARTITION BY → your unique key column
--   Change ORDER BY     → your "freshness" column (date, version, timestamp)
--   Change the source   → your bronze table
```

---

### 5.4 Pattern 4 — Integer Date Conversion

**Problem:** Source stores dates as integers like `20230415`. SQL Server cannot filter, sort, or calculate with these as real dates.  
**Solution:** Validate → Cast to VARCHAR → Cast to DATE

```sql
CASE
    WHEN sls_order_dt = 0                -- zero is not a valid date
      OR LEN(sls_order_dt) != 8         -- must be exactly 8 digits (YYYYMMDD)
    THEN NULL                            -- reject bad values gracefully
    ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
    --        ↑ Step 1: INT 20230415 → VARCHAR '20230415'
    --                   Step 2: VARCHAR '20230415' → DATE 2023-04-15
END AS sls_order_dt

-- Apply the same pattern to all three date fields:
-- sls_order_dt, sls_ship_dt, sls_due_dt
```

> **Use whenever:** a source system stores dates as `YYYYMMDD` integer format.  
> **Always validate:** length = 8 AND value != 0 before converting.

---

### 5.5 Pattern 5 — Business Rule Recalculation

**Problem:** Source has `sales`, `quantity`, `price` but they are mathematically inconsistent across rows. `sales != quantity * price` in some records.  
**Solution:** Recalculate from the most reliable fields.

```sql
-- Recalculate sales if missing, zero, or inconsistent:
CASE
    WHEN sls_sales IS NULL
      OR sls_sales <= 0
      OR sls_sales != sls_quantity * ABS(sls_price)  -- math consistency check
    THEN sls_quantity * ABS(sls_price)    -- recalculate from trusted fields
    ELSE sls_sales                        -- original was fine, keep it
END AS sls_sales,

-- Derive price if missing or invalid:
CASE
    WHEN sls_price IS NULL OR sls_price <= 0
    THEN CAST(sls_sales / NULLIF(sls_quantity, 0) AS INT)
    --                     ↑ NULLIF(x, 0) returns NULL instead of dividing by zero
    --                       prevents "division by zero" runtime error
    ELSE sls_price
END AS sls_price
```

---

### 5.6 Bonus Pattern — SCD Type 2 with LEAD()

**Problem:** Product prices change over time. We need to track history — each version needs a `start_date` and `end_date`.  
**Solution:** `LEAD()` window function to derive end date from next version's start date.

```sql
CAST(prd_start_dt AS DATE) AS prd_start_dt,

CAST(
    LEAD(prd_start_dt)              -- peek at the NEXT row's start date
    OVER (
        PARTITION BY prd_key        -- within the same product
        ORDER BY prd_start_dt ASC   -- ordered chronologically
    ) - 1                           -- subtract 1 day → end date
    AS DATE
) AS prd_end_dt

-- Result:
--  prd_key  | prd_start_dt | prd_end_dt
-- ──────────┼──────────────┼────────────
--  BK-R68R  | 2020-01-01   | 2021-05-31   ← old version, now expired
--  BK-R68R  | 2021-06-01   | NULL         ← current version (NULL = still active)

-- Gold layer filters: WHERE prd_end_dt IS NULL → only current products
```

> **SCD Type 2** = Slowly Changing Dimension. Used when you need full history of how a record changed over time, not just its current state.

---

## 6. Gold Layer — Views Pattern

### 6.1 Why Views, Not Tables?

| | Bronze/Silver Tables | Gold Views |
|---|---|---|
| Stores data physically? | ✅ Yes | ❌ No |
| Needs manual refresh? | ✅ TRUNCATE + INSERT | ❌ Always live |
| When silver updates... | Bronze/Silver must reload | Gold is instantly fresh |
| Purpose | Store and clean data | Shape data for business use |

```
Update silver → run silver.load_silver
             → gold views automatically reflect the new data
             → no extra step needed for gold
```

---

### 6.2 Surrogate Keys

```sql
-- NATURAL KEY:   the ID from the source system (e.g. cst_id = 1234)
--                can change, can have gaps, not guaranteed unique across systems

-- SURROGATE KEY: a new clean integer we generate ourselves (1, 2, 3, 4...)
--                stable, predictable, perfect for star schema joins

-- How to generate a surrogate key:
ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key
-- Produces: 1, 2, 3, 4... ordered by cst_id

-- Rule: Always use surrogate keys in the fact table joins.
--       Never expose raw natural keys in the gold layer.
```

---

### 6.3 Gold View: dim_customers

```sql
/*
============================================================
DIMENSION: gold.dim_customers
Sources   : silver.crm_cust_info (primary)
            silver.erp_cust_az12 (birthdate + gender)
            silver.erp_loc_a101  (country)
Key Logic : CRM gender is trusted source; ERP gender is fallback only
============================================================
*/

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key,  -- surrogate key
    ci.cst_id           AS customer_id,       -- natural key
    ci.cst_key          AS customer_number,   -- business key
    ci.cst_firstname    AS first_name,
    ci.cst_lastname     AS last_name,
    la.cntry            AS country,           -- from ERP location
    ci.cst_marital_status AS marital_status,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr   -- CRM wins (trusted)
        ELSE COALESCE(ca.gen, 'n/a')                  -- ERP as fallback
    END                 AS gender,
    ca.bdate            AS birthdate,         -- from ERP demographics
    ci.cst_create_date  AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101  la ON ci.cst_key = la.cid;
GO
```

---

### 6.4 Gold View: dim_products

```sql
/*
============================================================
DIMENSION: gold.dim_products
Sources   : silver.crm_prd_info      (primary)
            silver.erp_px_cat_g1v2   (category + subcategory)
Key Logic : Only active products (prd_end_dt IS NULL)
            Historical versions are excluded
============================================================
*/

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,
    pn.prd_id       AS product_id,
    pn.prd_key      AS product_number,
    pn.prd_nm       AS product_name,
    pn.cat_id       AS category_id,
    pc.cat          AS category,       -- from ERP reference data
    pc.subcat       AS subcategory,
    pc.maintenance  AS maintenance,
    pn.prd_cost     AS cost,
    pn.prd_line     AS product_line,
    pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL;  -- current products only (SCD Type 2 filter)
GO
```

---

### 6.5 Gold View: fact_sales

```sql
/*
============================================================
FACT TABLE: gold.fact_sales
Sources   : silver.crm_sales_details (transactions)
            gold.dim_products        (product surrogate key)
            gold.dim_customers       (customer surrogate key)
Key Logic : Fact table stores SURROGATE KEYS + MEASURES only
            No descriptive columns (those live in dimensions)
============================================================
*/

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT
    sd.sls_ord_num  AS order_number,
    pr.product_key  AS product_key,    -- surrogate from dim_products
    cu.customer_key AS customer_key,   -- surrogate from dim_customers
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt  AS shipping_date,
    sd.sls_due_dt   AS due_date,
    sd.sls_sales    AS sales_amount,   -- measure
    sd.sls_quantity AS quantity,       -- measure
    sd.sls_price    AS price           -- measure
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products  pr ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu ON sd.sls_cust_id = cu.customer_id;
GO
```
---

## Project File Structure

```
DataWarehouse/
├── scripts/
│   ├── create_database.sql              ← Run first (once)
│   ├── bronze/
│   │   ├── create_bronze_layer.sql      ← DDL: create bronze tables
│   │   ├── loaddata_bronze_layer.sql    ← ETL: BULK INSERT from CSVs
│   │   └── verify_bronze_layer.sql      ← QC: row counts + samples
│   ├── silver/
│   │   ├── create_silver_layer.sql      ← DDL: create silver tables
│   │   ├── loaddata_silver_layer.sql    ← ETL: transform + load from bronze
│   │   └── verify_silver_layer.sql      ← QC: data quality checks
│   └── gold/
│       ├── create_gold_layer.sql        ← DDL: create gold views
│       └── verify_gold_layer.sql        ← QC: referential integrity checks
├── Dataset/
│   ├── source_crm/
│   │   ├── cust_info.csv
│   │   ├── prd_info.csv
│   │   └── sales_details.csv
│   └── source_erp/
│       ├── CUST_AZ12.csv
│       ├── LOC_A101.csv
│       └── PX_CAT_G1V2.csv
└── docs/
    └── data_warehouse_patterns.md       ← This file
```

---

## Execution Order

Always run scripts in this exact order:

```
1. create_database.sql          → creates DB + schemas
2. bronze/create_bronze_layer.sql   → creates bronze tables
3. bronze/loaddata_bronze_layer.sql → loads CSV data into bronze
4. bronze/verify_bronze_layer.sql   → confirm bronze loaded correctly
5. silver/create_silver_layer.sql   → creates silver tables
6. silver/loaddata_silver_layer.sql → transforms + loads silver
7. silver/verify_silver_layer.sql   → confirm silver quality
8. gold/create_gold_layer.sql       → creates gold views
9. gold/verify_gold_layer.sql       → confirm gold integrity
```

---

*Last updated: June 2026 · DataWarehouse v1.0 · SQL Server · Medallion Architecture*
