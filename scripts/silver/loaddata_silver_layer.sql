/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silver.load_silver;
===============================================================================
*/

-- Create or replace the stored procedure responsible for transforming and loading all silver layer tables
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    -- Declare timing variables to track load duration for each table and the overall batch
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME; 

    -- Begin TRY block to handle any errors that occur during the transformation and load process
    BEGIN TRY
        -- Capture the start time of the entire silver layer load batch
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------';

		-- -------------------------------------------------------
		-- Load silver.crm_cust_info
		-- Source: bronze.crm_cust_info
		-- Transformations:
		--   - Remove leading/trailing spaces from first and last name fields
		--   - Decode marital status codes to readable labels (S -> Single, M -> Married)
		--   - Decode gender codes to readable labels (F -> Female, M -> Male)
		--   - Deduplicate by cst_id keeping only the most recent record via ROW_NUMBER()
		--   - Exclude rows where cst_id is NULL (cannot be linked to other tables)
		-- -------------------------------------------------------
        SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_cust_info';
		-- Remove all existing rows before loading fresh transformed data
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Inserting Data Into: silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info (
			cst_id, 
			cst_key, 
			cst_firstname, 
			cst_lastname, 
			cst_marital_status, 
			cst_gndr,
			cst_create_date
		)
		SELECT
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,  -- Remove accidental leading/trailing whitespace
			TRIM(cst_lastname)  AS cst_lastname,   -- Remove accidental leading/trailing whitespace
			CASE 
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				ELSE 'n/a'                         -- Default for unknown or missing values
			END AS cst_marital_status,             -- Decode single-char codes to readable labels
			CASE 
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				ELSE 'n/a'                         -- Default for unknown or missing values
			END AS cst_gndr,                       -- Decode single-char codes to readable labels
			cst_create_date
		FROM (
			-- Rank records per customer by most recent creation date
			-- so we can filter down to just the latest version of each customer
			SELECT
				*,
				ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL  -- Exclude records with no customer ID; they are unlinkable
		) t
		WHERE flag_last = 1;          -- Keep only the most recent record per customer
		-- Capture end time and print how long this table's load took
		SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		-- -------------------------------------------------------
		-- Load silver.crm_prd_info
		-- Source: bronze.crm_prd_info
		-- Transformations:
		--   - Extract category ID from first 5 chars of prd_key (replace '-' with '_')
		--   - Extract clean product key from character 7 onward of prd_key
		--   - Replace NULL product costs with 0 to avoid downstream calculation issues
		--   - Decode product line codes to readable labels (M -> Mountain, R -> Road, etc.)
		--   - Cast prd_start_dt from DATETIME to DATE (time component not needed)
		--   - Derive prd_end_dt as one day before the next product version's start date (SCD Type 2)
		-- -------------------------------------------------------
        SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_prd_info';
		-- Remove all existing rows before loading fresh transformed data
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Inserting Data Into: silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info (
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
		)
		SELECT
			prd_id,
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,  -- Extract category portion from composite key; normalize separator
			SUBSTRING(prd_key, 7, LEN(prd_key))          AS prd_key, -- Strip category prefix to get the true product key
			prd_nm,
			ISNULL(prd_cost, 0) AS prd_cost,                         -- Replace NULL cost with 0 to prevent NULL propagation in calculations
			CASE 
				WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
				WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
				WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
				WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
				ELSE 'n/a'                                            -- Default for unknown or missing product line codes
			END AS prd_line,                                          -- Decode single-char product line codes to descriptive labels
			CAST(prd_start_dt AS DATE) AS prd_start_dt,              -- Strip time component; only the date portion is meaningful
			CAST(
				LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1
				AS DATE
			) AS prd_end_dt  -- Derive end date as one day before the next version's start (SCD Type 2 pattern)
		FROM bronze.crm_prd_info;
		-- Capture end time and print how long this table's load took
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		-- -------------------------------------------------------
		-- Load silver.crm_sales_details
		-- Source: bronze.crm_sales_details
		-- Transformations:
		--   - Convert integer date fields (YYYYMMDD) to proper DATE type
		--   - Set date to NULL if value is 0 or not exactly 8 digits (invalid raw data)
		--   - Recalculate sls_sales if NULL, zero, negative, or inconsistent with quantity * price
		--   - Derive sls_price from sales / quantity if original price is NULL or invalid
		--   - NULLIF on quantity prevents division by zero when deriving price
		-- -------------------------------------------------------
        SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_sales_details';
		-- Remove all existing rows before loading fresh transformed data
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Inserting Data Into: silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details (
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
		SELECT 
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE 
				WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL  -- Reject invalid date integers
				ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)            -- Convert valid YYYYMMDD integer to DATE
			END AS sls_order_dt,
			CASE 
				WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL    -- Reject invalid date integers
				ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)             -- Convert valid YYYYMMDD integer to DATE
			END AS sls_ship_dt,
			CASE 
				WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL      -- Reject invalid date integers
				ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)              -- Convert valid YYYYMMDD integer to DATE
			END AS sls_due_dt,
			CASE 
				WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
					THEN sls_quantity * ABS(sls_price)  -- Recalculate when original is missing, zero, or mathematically inconsistent
				ELSE sls_sales
			END AS sls_sales,
			sls_quantity,
			CASE 
				WHEN sls_price IS NULL OR sls_price <= 0 
					THEN CAST(sls_sales / NULLIF(sls_quantity, 0) AS INT)  -- Derive price from sales/quantity; NULLIF prevents division by zero
				ELSE sls_price
			END AS sls_price
		FROM bronze.crm_sales_details;
		-- Capture end time and print how long this table's load took
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading ERP Tables';
		PRINT '------------------------------------------------';

		-- -------------------------------------------------------
		-- Load silver.erp_cust_az12
		-- Source: bronze.erp_cust_az12
		-- Transformations:
		--   - Strip 'NAS' prefix from cid where present to align with CRM customer key format
		--   - Nullify future birthdates (data quality issue; birthdate cannot be in the future)
		--   - Normalize gender values from multiple raw formats to Female / Male / n/a
		-- -------------------------------------------------------
        SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.erp_cust_az12';
		-- Remove all existing rows before loading fresh transformed data
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> Inserting Data Into: silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12 (
			cid,
			bdate,
			gen
		)
		SELECT
			CASE
				WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))  -- Remove 'NAS' prefix to match CRM customer ID format
				ELSE cid
			END AS cid, 
			CASE
				WHEN bdate > GETDATE() THEN NULL  -- Future birthdates are invalid; nullify to prevent wrong age calculations
				ELSE bdate
			END AS bdate,
			CASE
				WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
				WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
				ELSE 'n/a'                                -- Default for blank, NULL, or unrecognized codes
			END AS gen  -- Normalize multiple raw gender representations into a consistent standard
		FROM bronze.erp_cust_az12;
		-- Capture end time and print how long this table's load took
	    SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		-- -------------------------------------------------------
		-- Load silver.erp_loc_a101
		-- Source: bronze.erp_loc_a101
		-- Transformations:
		--   - Remove hyphens from cid to align with CRM customer ID format
		--   - Expand country abbreviations/codes to full country names (DE -> Germany, US/USA -> United States)
		--   - Replace blank or NULL country values with 'n/a'
		--   - Trim whitespace from all other country values
		-- -------------------------------------------------------
        SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.erp_loc_a101';
		-- Remove all existing rows before loading fresh transformed data
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> Inserting Data Into: silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101 (
			cid,
			cntry
		)
		SELECT
			REPLACE(cid, '-', '') AS cid,  -- Strip hyphens to align customer ID format with CRM tables
			CASE
				WHEN TRIM(cntry) = 'DE'              THEN 'Germany'
				WHEN TRIM(cntry) IN ('US', 'USA')    THEN 'United States'
				WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'  -- Treat blank strings and NULLs as unknown country
				ELSE TRIM(cntry)                                    -- Keep other values as-is, just trimmed
			END AS cntry  -- Normalize country codes and abbreviations to full standardized names
		FROM bronze.erp_loc_a101;
		-- Capture end time and print how long this table's load took
	    SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		-- -------------------------------------------------------
		-- Load silver.erp_px_cat_g1v2
		-- Source: bronze.erp_px_cat_g1v2
		-- Transformations:
		--   - No transformations applied; data is loaded as-is from bronze
		--   - Included in silver for layer consistency and as a single source of truth
		-- -------------------------------------------------------
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
		-- Remove all existing rows before loading fresh transformed data
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2 (
			id,
			cat,
			subcat,
			maintenance	
		)
		SELECT
			id,
			cat,
			subcat,
			maintenance
		FROM bronze.erp_px_cat_g1v2;  -- Direct copy; no transformation needed for product category reference data
		-- Capture end time and print how long this table's load took
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		-- Capture the end time of the full batch and print total duration across all silver tables
		SET @batch_end_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading Silver Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '=========================================='
		
	END TRY

	-- CATCH block: if any error occurs during transformation or load, capture and print diagnostic details
	-- This prevents silent failures and helps pinpoint exactly which table or step caused the issue
	BEGIN CATCH
		PRINT '=========================================='
		PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER'
		-- Print the human-readable error description
		PRINT 'Error Message: ' + ERROR_MESSAGE();
		-- Print the error number for cross-referencing SQL Server error codes
		PRINT 'Error Number: '  + CAST(ERROR_NUMBER() AS NVARCHAR);
		-- Print the error state to help distinguish between similar errors
		PRINT 'Error State: '   + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================='
	END CATCH
END
