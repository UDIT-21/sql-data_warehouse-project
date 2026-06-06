/*
=============================================================
Database Creation: DataWarehouse (based on Medallion Architecture)
=============================================================
Script Purpose:
    This script creates a new SQL Server database named 'DataWarehouse'. 
    If the database already exists, it is dropped to ensure a clean setup. 
    The script then creates three schemas within the 'DataWarehouse' database: 'bronze', 'silver', and 'gold'.
    
WARNING:
    Running this script will drop the entire 'DataWarehouse' database if it exists, 
    permanently deleting all data within it. Proceed with caution and ensure you 
    have proper backups before executing this script.
*/

-- 1. Switch to the master database to perform database-level operations and create other databases
USE master; 
GO -- GO is like a separator it tells SSMS to execute all statements since the last GO as a single batch

-- Drop and recreate the 'DataWarehouse' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
  ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE DataWarehouse
END;
GO

-- 2. Create a new database named 'DataWarehouse'
CREATE DATABASE DataWarehouse; 
GO

-- 3. Switch to the newly created 'DataWarehouse' database to create tables and insert data */
USE DataWarehouse; 
GO

-- 4. Create schemas to establish logical containers that namespace database objects, enabling secure access control, organizational hierarchy, and conflict-free object naming across the data warehouse layers
CREATE SCHEMA bronze; 
GO  
CREATE SCHEMA silver;
GO 
CREATE SCHEMA gold;
GO
