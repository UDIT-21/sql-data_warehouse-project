/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files. 
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `BULK INSERT` command to load data from csv Files to bronze tables.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.load_bronze;
===============================================================================
*/

-- Create or replace the stored procedure responsible for loading all bronze layer tables
CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
	-- Declare timing variables to track load duration for each table and the overall batch
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME; 

	-- Begin TRY block to handle any errors that occur during the load process
	BEGIN TRY
		-- Capture the start time of the entire bronze layer load batch
		SET @batch_start_time = GETDATE();

		PRINT '================================================';
		PRINT 'Loading Bronze Layer';
		PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------';

		-- -------------------------------------------------------
		-- Load bronze.crm_cust_info
		-- Source: CRM system customer master data
		-- Strategy: Truncate first to avoid duplicates, then bulk insert fresh data
		-- -------------------------------------------------------
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.crm_cust_info';
		-- Remove all existing rows so we load a clean, up-to-date snapshot from the source
		TRUNCATE TABLE bronze.crm_cust_info;
		PRINT '>> Inserting Data Into: bronze.crm_cust_info';
		-- Bulk insert raw customer data from CSV; skip row 1 (header), use comma as delimiter
		BULK INSERT bronze.crm_cust_info
		FROM 'C:\sql\dwh_project\datasets\source_crm\cust_info.csv'
		WITH (
			FIRSTROW = 2,          -- Skip the header row in the CSV file
			FIELDTERMINATOR = ',', -- Columns are separated by commas
			TABLOCK                -- Acquire a table-level lock for faster bulk load performance
		);
		-- Capture end time and print how long this table's load took
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- -------------------------------------------------------
		-- Load bronze.crm_prd_info
		-- Source: CRM system product master data
		-- Strategy: Truncate first to avoid duplicates, then bulk insert fresh data
		-- -------------------------------------------------------
        SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.crm_prd_info';
		-- Remove all existing rows so we load a clean, up-to-date snapshot from the source
		TRUNCATE TABLE bronze.crm_prd_info;
		PRINT '>> Inserting Data Into: bronze.crm_prd_info';
		-- Bulk insert raw product data from CSV; skip row 1 (header), use comma as delimiter
		BULK INSERT bronze.crm_prd_info
		FROM 'C:\sql\dwh_project\datasets\source_crm\prd_info.csv'
		WITH (
			FIRSTROW = 2,          -- Skip the header row in the CSV file
			FIELDTERMINATOR = ',', -- Columns are separated by commas
			TABLOCK                -- Acquire a table-level lock for faster bulk load performance
		);
		-- Capture end time and print how long this table's load took
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- -------------------------------------------------------
		-- Load bronze.crm_sales_details
		-- Source: CRM system transactional sales order data
		-- Strategy: Truncate first to avoid duplicates, then bulk insert fresh data
		-- -------------------------------------------------------
        SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.crm_sales_details';
		-- Remove all existing rows so we load a clean, up-to-date snapshot from the source
		TRUNCATE TABLE bronze.crm_sales_details;
		PRINT '>> Inserting Data Into: bronze.crm_sales_details';
		-- Bulk insert raw sales order data from CSV; skip row 1 (header), use comma as delimiter
		BULK INSERT bronze.crm_sales_details
		FROM 'C:\sql\dwh_project\datasets\source_crm\sales_details.csv'
		WITH (
			FIRSTROW = 2,          -- Skip the header row in the CSV file
			FIELDTERMINATOR = ',', -- Columns are separated by commas
			TABLOCK                -- Acquire a table-level lock for faster bulk load performance
		);
		-- Capture end time and print how long this table's load took
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading ERP Tables';
		PRINT '------------------------------------------------';

		-- -------------------------------------------------------
		-- Load bronze.erp_loc_a101
		-- Source: ERP system customer location/country mapping data
		-- Strategy: Truncate first to avoid duplicates, then bulk insert fresh data
		-- -------------------------------------------------------
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.erp_loc_a101';
		-- Remove all existing rows so we load a clean, up-to-date snapshot from the source
		TRUNCATE TABLE bronze.erp_loc_a101;
		PRINT '>> Inserting Data Into: bronze.erp_loc_a101';
		-- Bulk insert raw location data from CSV; skip row 1 (header), use comma as delimiter
		BULK INSERT bronze.erp_loc_a101
		FROM 'C:\sql\dwh_project\datasets\source_erp\loc_a101.csv'
		WITH (
			FIRSTROW = 2,          -- Skip the header row in the CSV file
			FIELDTERMINATOR = ',', -- Columns are separated by commas
			TABLOCK                -- Acquire a table-level lock for faster bulk load performance
		);
		-- Capture end time and print how long this table's load took
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- -------------------------------------------------------
		-- Load bronze.erp_cust_az12
		-- Source: ERP system customer demographics data (birthdate, gender)
		-- Strategy: Truncate first to avoid duplicates, then bulk insert fresh data
		-- -------------------------------------------------------
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.erp_cust_az12';
		-- Remove all existing rows so we load a clean, up-to-date snapshot from the source
		TRUNCATE TABLE bronze.erp_cust_az12;
		PRINT '>> Inserting Data Into: bronze.erp_cust_az12';
		-- Bulk insert raw customer demographics from CSV; skip row 1 (header), use comma as delimiter
		BULK INSERT bronze.erp_cust_az12
		FROM 'C:\sql\dwh_project\datasets\source_erp\cust_az12.csv'
		WITH (
			FIRSTROW = 2,          -- Skip the header row in the CSV file
			FIELDTERMINATOR = ',', -- Columns are separated by commas
			TABLOCK                -- Acquire a table-level lock for faster bulk load performance
		);
		-- Capture end time and print how long this table's load took
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- -------------------------------------------------------
		-- Load bronze.erp_px_cat_g1v2
		-- Source: ERP system product category and subcategory classification data
		-- Strategy: Truncate first to avoid duplicates, then bulk insert fresh data
		-- -------------------------------------------------------
		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.erp_px_cat_g1v2';
		-- Remove all existing rows so we load a clean, up-to-date snapshot from the source
		TRUNCATE TABLE bronze.erp_px_cat_g1v2;
		PRINT '>> Inserting Data Into: bronze.erp_px_cat_g1v2';
		-- Bulk insert raw product category data from CSV; skip row 1 (header), use comma as delimiter
		BULK INSERT bronze.erp_px_cat_g1v2
		FROM 'C:\sql\dwh_project\datasets\source_erp\px_cat_g1v2.csv'
		WITH (
			FIRSTROW = 2,          -- Skip the header row in the CSV file
			FIELDTERMINATOR = ',', -- Columns are separated by commas
			TABLOCK                -- Acquire a table-level lock for faster bulk load performance
		);
		-- Capture end time and print how long this table's load took
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		-- Capture the end time of the full batch and print total duration for all bronze tables
		SET @batch_end_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading Bronze Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '=========================================='

	END TRY

	-- CATCH block: if any error occurs during the load, capture and print diagnostic details
	-- instead of silently failing — helps pinpoint which table or step caused the issue
	BEGIN CATCH
		PRINT '=========================================='
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER'
		-- Print the human-readable error description
		PRINT 'Error Message: ' + ERROR_MESSAGE();
		-- Print the error number for cross-referencing SQL Server error codes
		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		-- Print the error state to help distinguish between similar errors
		PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================='
	END CATCH

END
