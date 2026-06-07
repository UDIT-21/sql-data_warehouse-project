/*
===============================================================================
Exploratory Data Analysis (EDA): Gold Layer
===============================================================================

What is EDA?
    Exploratory Data Analysis (EDA) is the first and most critical step after
    building a data warehouse. It is the process of systematically examining
    your dataset to understand its structure, content, distributions, and
    quality before building any reports, dashboards, or advanced analytics
    on top of it.

    EDA answers the fundamental question:
    "What does this data actually look like, and what story does it tell?"

Why do we perform EDA?
    - To verify the ETL pipeline produced correct, complete, and consistent
      data all the way from raw CSVs through Bronze and Silver to Gold.
    - To discover the real shape of the data: ranges, cardinalities, outliers,
      and patterns that were not visible at the schema design stage.
    - To understand the business story before writing reports — which countries
      have the most customers, which product categories drive the most revenue,
      what time span the sales data covers.
    - To build the foundation for Advanced Analytics, which includes trends,
      cumulative analysis, performance analysis, segmentation, and reporting.

-------------------------------------------------------------------------------
Understanding Dimensions vs. Measures
-------------------------------------------------------------------------------
    Before exploring any dataset, every column must be classified into one of
    two buckets. The key question to ask for each column is:

        "Is it numeric AND does aggregating it make business sense?"

    MEASURES (Numeric + Aggregatable)
        Columns whose aggregation (SUM, AVG, MIN, MAX) produces a meaningful
        business number. These are the VALUES we analyse.
        Examples in this dataset:
            - sls_sales    → total revenue
            - sls_quantity → units sold
            - sls_price    → unit price
            - Age          → average customer age

    DIMENSIONS (Categorical OR numeric but NOT meaningfully aggregatable)
        Columns used to GROUP, FILTER, or SLICE measures. These are the LENSES
        through which we look at the data.
        Examples in this dataset:
            - country, gender, marital_status → group customers by
            - category, subcategory, product_line → group products by
            - order_date, birthdate → date-based slicing
            - customer_id, product_id → identifiers (numeric but summing
              them has no business meaning)

-------------------------------------------------------------------------------
EDA Phases (in order)
-------------------------------------------------------------------------------
    This script follows six phases of Exploratory Data Analysis:

    Phase 1 — Database Exploration
        Understand the high-level inventory: what tables/views exist, how many
        columns each has, and what data types are present.

    Phase 2 — Dimensions Exploration
        Explore the categorical columns. Find distinct values, cardinalities,
        and distributions across dimensions like country, category, gender.

    Phase 3 — Date Exploration
        Understand the time span of the data. Find the earliest and latest
        order dates, customer birthdates, and identify any date gaps.

    Phase 4 — Measures Exploration (Big Numbers)
        Compute the high-level aggregates: total revenue, total quantity sold,
        average price, min/max values — the "big numbers" of the dataset.

    Phase 5 — Magnitude Analysis
        Compare the size of measures across dimensions. For example, total
        sales by country or total quantity by product category.

    Phase 6 — Ranking Analysis (Top N / Bottom N)
        Identify the best and worst performers across dimensions. For example,
        top 5 products by revenue or bottom 3 countries by order volume.

Usage:
    Run this script against the DataWarehouse database after gold views have
    been created and verified via scripts/gold/verify_gold_layer.sql.
===============================================================================
*/
USE DataWarehouse;
GO

--1. Explore all Objects in the Database. INFORMATION_SCHEMA is the standard, cross-database method for querying metadata about your database structure.
SELECT * FROM INFORMATION_SCHEMA.TABLES;

--2. Explore all Columns in the Database.
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA IN ('gold'); -- Focus on gold layer

-- 3.1 Dimensions Exploration: Explore categorical columns in dim_customers.
SELECT DISTINCT country FROM gold.dim_customers;

-- 3.2 Dimensions Exploration: Explore categorical columns in dim_products.
SELECT DISTINCT category,subcategory,product_name FROM gold.dim_products;

-- 4.1 Date Exploration: Find the date of the earliest and latest order in fact_sales, How many years of sales data do we have?
SELECT 
MIN(order_date) AS first_order_date,
MAX(order_date) AS last_order_date ,
DATEDIFF(year, MIN(order_date), MAX(order_date)) AS years_of_sales_data
FROM gold.fact_sales;

--4.2 Date Exploration: Find the youngest and oldest customers based on birthdate in dim_customers. What is the age range of customers?
SELECT 
MIN(birthdate) AS oldest_birthdate,
DATEDIFF(YEAR, MIN(birthdate), GETDATE()) AS oldest_age,
MAX(birthdate) AS youngest_birthdate,
DATEDIFF(YEAR, MAX(birthdate), GETDATE()) AS youngest_age,
AVG(DATEDIFF(YEAR, birthdate, GETDATE())) AS  avg_age_of_customer  -- DATEDIFF calculates age for each customer, and AVG gives the average age of customers
FROM gold.dim_customers;

-- 4.3 Date Exploration: Find the youngest and oldest customers based on birthdate in dim_customers. What is the age range of customers? Also, return their names.
WITH AgeCalculations AS (
    SELECT 
        CONCAT(first_name, ' ', last_name) AS customer_name,
        birthdate,
        DATEDIFF(YEAR, birthdate, GETDATE()) AS age,
        ROW_NUMBER() OVER (ORDER BY birthdate ASC) AS oldest_rank,
        ROW_NUMBER() OVER (ORDER BY birthdate DESC) AS youngest_rank
    FROM gold.dim_customers
    WHERE birthdate IS NOT NULL
)
SELECT 
    MAX(CASE WHEN oldest_rank = 1 THEN customer_name END) AS oldest_customer_name,
    MIN(birthdate) AS oldest_birthdate,
    MAX(CASE WHEN oldest_rank = 1 THEN age END) AS oldest_age,
    MAX(CASE WHEN youngest_rank = 1 THEN customer_name END) AS youngest_customer_name,
    MAX(CASE WHEN youngest_rank = 1 THEN birthdate END) AS youngest_birthdate,
    MAX(CASE WHEN youngest_rank = 1 THEN age END) AS youngest_age,
    AVG(age) AS avg_age_of_customer
FROM AgeCalculations;

-- 5.1 Measures Exploration: Calculate the key metric of the business. Find the Total Sales & how many items are sold
SELECT 
SUM(quantity) AS total_quantity,
SUM(sales_amount) AS total_sales
FROM gold.fact_sales;

-- 5.2 Measures Exploration: Find the Average Selling Price
SELECT AVG(price) AS avg_price FROM gold.fact_sales;

-- 5.3 Measures Exploration: Find the Total number of Oders
SELECT 
COUNT((order_number)) AS total_entries,
COUNT(DISTINCT(order_number)) AS total_distinct_oders 
FROM gold.fact_sales;

-- 5.4 Measures Exploration: Find the Total number of registered Products
SELECT 
COUNT(DISTINCT(product_key)) AS total_products
FROM gold.dim_products;

-- 5.5 Measures Exploration: Find the Total number of registered Customer
SELECT 
COUNT(DISTINCT(customer_key)) AS total_customers
FROM gold.dim_customers;

-- 5.6 Measures Exploration: Find the Total number of Customer who have made a purchase
SELECT 
COUNT(DISTINCT(customer_key)) AS total_customers
FROM gold.fact_sales;

-- 5.7 Basket Analysis: Find the average items a customer purchase and revenue per unique order
SELECT
SUM(quantity) / COUNT(DISTINCT order_number) AS avg_items_per_order,
SUM(sales_amount) / COUNT(DISTINCT order_number) AS avg_order_value
FROM gold.fact_sales;

--6. Generate a Report of all key metrices

SELECT 'Total Revenue' AS Metric, CAST(SUM(sales_amount) AS VARCHAR(20)) AS Value FROM gold.fact_sales
UNION ALL
SELECT 'Total Units Sold', CAST(SUM(quantity) AS VARCHAR(20)) FROM gold.fact_sales
UNION ALL
SELECT 'Average Unit Price', CAST(CAST(AVG(price) AS DECIMAL(10, 2)) AS VARCHAR(20)) FROM gold.fact_sales
UNION ALL
SELECT 'Min Price', CAST(MIN(price) AS VARCHAR(20)) FROM gold.fact_sales
UNION ALL
SELECT 'Max Price', CAST(MAX(price) AS VARCHAR(20)) FROM gold.fact_sales
UNION ALL
SELECT 'Total Orders', CAST(COUNT(DISTINCT order_number) AS VARCHAR(20)) FROM gold.fact_sales
UNION ALL
SELECT 'Total Products', CAST(COUNT(DISTINCT product_key) AS VARCHAR(20)) FROM gold.dim_products
UNION ALL
SELECT 'Total Customers', CAST(COUNT(DISTINCT customer_key) AS VARCHAR(20)) FROM gold.dim_customers
UNION ALL
SELECT 'Customers Who Bought', CAST(COUNT(DISTINCT customer_key) AS VARCHAR(20)) FROM gold.fact_sales;

-- 7. Magnitude Analysis: Aggregate measures by dimensions. Find total customer by country.
SELECT 
country, 
COUNT(DISTINCT customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;

-- 7.2 Magnitude Analysis: Find total customer by gender.
SELECT  
gender,
COUNT(DISTINCT customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY gender 
ORDER BY total_customers DESC;

-- 7.3 Magnitude Analysis: Find total products by cateogy
SELECT  
category,
COUNT(DISTINCT product_key) AS total_products
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC;

-- 7.4 Magnitude Analysis: Find average cost by each category.
SELECT  
category,
AVG(cost) AS avg_cost
FROM gold.dim_products
GROUP BY category
ORDER BY avg_cost DESC;

-- 7.5 Magnitude Analysis: Find total revenue by each category.
SELECT  
p.category,
SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p 
ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;

-- 7.6 Magnitude Analysis: Find total revenue by each customer.
SELECT  
c.customer_key,
CONCAT(c.first_name,' ', c.last_name) AS customer_name,
SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC;

-- 7.7 Magnitude Analysis: Find the distribution of sold items across different countries.
SELECT  
c.country,
SUM(f.quantity) AS sold_items
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY country ASC;

-- 8.1 Ranking Analysis: Rank Dimensions by aggregated Measures. Find top 5 products by revenue.
SELECT TOP 5
p.product_name, p.category, p.subcategory,
SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p 
ON f.product_key = p.product_key
GROUP BY p.product_name, p.category, p.subcategory
ORDER BY total_revenue DESC;

-- By Window Function (Top 5 products by revenue)
SELECT *
FROM (
    SELECT
    p.product_name,
    SUM(f.sales_amount) AS total_revenue,
    ROW_NUMBER() OVER (ORDER BY SUM(f.sales_amount) DESC) AS rank_products
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p 
    ON f.product_key = p.product_key
    GROUP BY p.product_name
    )t
WHERE rank_products <= 5;

-- 8.2 Ranking Analysis: Rank Dimensions by aggregated Measures. Find top 5 products by revenue.
SELECT TOP 5
p.subcategory,
SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p 
ON f.product_key = p.product_key
GROUP BY p.subcategory
ORDER BY total_revenue DESC;

-- 8.3 Ranking Analysis: Find top 10 customers by revenue.
SELECT TOP 10
c.customer_key,
CONCAT(c.first_name,' ', c.last_name) AS customer_name,
SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC;

-- By Window Function (Last 3 customers by order placed)
SELECT *
FROM (
    SELECT
    c.customer_key,
    CONCAT(c.first_name,' ', c.last_name) AS customer_name,
    COUNT(DISTINCT f.order_number) AS total_oders,
    ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT f.order_number) ASC) AS rank_customers
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
    GROUP BY c.customer_key, c.first_name, c.last_name 
    )t
WHERE rank_customers <= 3;
 


-- 8.4 Ranking Analysis: Find 5 worst performing products by sales revenue.
SELECT TOP 5
p.product_name, p.subcategory,
SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p 
ON f.product_key = p.product_key
GROUP BY p.product_name, p.subcategory
ORDER BY total_revenue ASC;
