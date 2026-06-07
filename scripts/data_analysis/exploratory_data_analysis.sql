/*
===============================================================================
Exploratory Data Analysis (EDA): Gold Layer
===============================================================================

Purpose:
    This script performs a systematic, six-phase exploration of the Gold Layer
    in the DataWarehouse. It is designed to run immediately after the Gold Layer
    views are verified, and before any BI reports, dashboards, or advanced
    analytics are built on top of them.

    Think of this as the analyst's "first conversation" with the data — the
    goal is to understand what is actually in the warehouse, not just what the
    schema says should be there.

Why EDA Before Reporting?
    Every pipeline can introduce silent errors: wrong grain joins that
    double-count revenue, date columns loaded as strings, NULL customer keys,
    or a category that maps to nothing. EDA surfaces these before they
    propagate into executive dashboards.

KPI: Key Performance Indicators
    A metric is just any number you can measure — page views, number of products, average age of customers. 
    A KPI is a metric that's been chosen because it directly reflects whether a business goal is being met. 
    Every KPI is a metric, but not every metric is a KPI.
        1. A KPI only exists in relation to a goal.
        2. Take any metric and ask "so what?" until you hit a business decision.
        3. A KPI without an owner is just a number. If nobody is accountable for moving it, it won't be acted on.
        4. Check if it influences decisions.

-------------------------------------------------------------------------------
Dimensions vs. Measures — The Analyst's Compass
-------------------------------------------------------------------------------

    Before writing a single GROUP BY, classify every column by asking:

        "Is it numeric AND does aggregating it produce a meaningful business
         number?"

    MEASURES  → Numeric + Aggregatable = the VALUES we analyse
        sls_sales_amount  → total revenue
        sls_quantity      → units sold
        sls_price         → unit selling price
        customer age      → average demographic indicator

    DIMENSIONS → Categorical OR non-aggregatable numeric = the LENSES we
                 use to slice measures
        country, gender, marital_status → customer segmentation lenses
        category, subcategory, product_line → product taxonomy lenses
        order_date, birthdate → time-based slicing axes
        customer_key, product_key → surrogate identifiers; numerically
            meaningless to SUM, used only for COUNT DISTINCT cardinality

-------------------------------------------------------------------------------
EDA Phases
-------------------------------------------------------------------------------

    Phase 1 — Database Exploration
        Asset inventory: what objects exist, their schemas, and their columns.

    Phase 2 — Dimensions Exploration
        Categorical profiling: distinct values, cardinalities, and any
        unexpected entries (typos, NULLs, legacy codes).

    Phase 3 — Date Exploration
        Temporal coverage: earliest/latest dates, age ranges, data freshness.

    Phase 4 — Measures Exploration
        High-level aggregates: the "big numbers" — total revenue, units,
        average price, order counts.

    Phase 5 — Magnitude Analysis
        Cross-dimensional aggregation: measures broken down by each dimension
        to reveal where the business is concentrated.

    Phase 6 — Ranking Analysis
        Top-N / Bottom-N: best and worst performers to guide prioritisation.

Prerequisite:
    Run scripts/gold/verify_gold_layer.sql and confirm zero failures before
    executing this script.

Target Database: DataWarehouse
Target Schema:   gold
===============================================================================
*/

USE DataWarehouse;
GO


/* ============================================================================
   PHASE 1 — DATABASE EXPLORATION
   "What does our data warehouse actually expose to downstream consumers?"
   ============================================================================
   Before touching any data, map the full inventory of objects in the warehouse.
   This confirms that all expected tables and views were created successfully
   and gives every analyst an accurate mental model of what is available.
   Skipping this step risks querying stale or wrong objects silently.
   ============================================================================ */

-- ─────────────────────────────────────────────────────────────────────────────
-- 1.1  What schemas and tables/views are registered in the warehouse?
--
--      Implication: A complete object inventory. If any Gold view is missing
--      from this list, the upstream stored procedure failed silently and all
--      downstream queries will return errors or stale data.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT * 
FROM INFORMATION_SCHEMA.TABLES;


-- ─────────────────────────────────────────────────────────────────────────────
-- 1.2  What columns are available in the Gold Layer, and what are their types?
--
--      Implication: Column-level inventory for the gold schema. Catches schema
--      drift early — a column renamed during a Silver rebuild will appear
--      missing here before any report notices it. Also useful when onboarding
--      new analysts who need to understand the full data model quickly.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT * 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold';


/* ============================================================================
   PHASE 2 — DIMENSIONS EXPLORATION
   "What are the distinct categorical values in each dimension, and are there
    any unexpected entries — misspellings, NULLs, or legacy codes — that
    would corrupt downstream groupings?"
   ============================================================================ */

-- ─────────────────────────────────────────────────────────────────────────────
-- 2.1  What geographic markets does the business currently operate in?
--
--      Implication: Validates the customer dimension's country column.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT DISTINCT country 
FROM gold.dim_customers
ORDER BY country;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2.2  What does our complete product taxonomy look like — from category
--      down to individual product name?
--
--      Implication: Validates the three-level hierarchy (Category →
--      Sub-category → Product Name) in dim_products. 
-- ─────────────────────────────────────────────────────────────────────────────
SELECT DISTINCT 
    category, 
    subcategory, 
    product_name 
FROM gold.dim_products
ORDER BY category, subcategory, product_name;


/* ============================================================================
   PHASE 3 — DATE EXPLORATION
   "What is the temporal coverage of our data, and do we have enough history
    to support trend analysis, year-over-year comparisons, and cohort studies?"
   ============================================================================ */

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.1  How many years of transactional history do we hold, and when exactly
--      does it begin and end?
--
--      Implication: Determines the maximum lookback window for trend reports.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 
    MIN(order_date)                                    AS first_order_date,
    MAX(order_date)                                    AS last_order_date,
    DATEDIFF(YEAR, MIN(order_date), MAX(order_date))   AS years_of_sales_data
FROM gold.fact_sales;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3.2  What is the age range of our customer base at a population level?
--
--      Implication: Surfaces the overall demographic spread.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 
    MIN(birthdate)                                      AS oldest_birthdate,
    DATEDIFF(YEAR, MIN(birthdate), GETDATE())           AS oldest_age,
    MAX(birthdate)                                      AS youngest_birthdate,
    DATEDIFF(YEAR, MAX(birthdate), GETDATE())           AS youngest_age,
    AVG(DATEDIFF(YEAR, birthdate, GETDATE()))           AS avg_age_of_customer
    -- DATEDIFF calculates each customer's current age; AVG then gives
    -- the mean age across the entire registered customer population.
FROM gold.dim_customers;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3.3  Who are the single oldest and youngest customers by name, and what
--      is the average age of the full customer base? Using Window Function.
--
--      Implication: Personalises the age-range story for stakeholder
--      presentations.
-- ─────────────────────────────────────────────────────────────────────────────
WITH AgeCalculations AS (
    SELECT 
        CONCAT(first_name, ' ', last_name)         AS customer_name,
        birthdate,
        DATEDIFF(YEAR, birthdate, GETDATE())        AS age,
        ROW_NUMBER() OVER (ORDER BY birthdate ASC)  AS oldest_rank,
        ROW_NUMBER() OVER (ORDER BY birthdate DESC) AS youngest_rank
    FROM gold.dim_customers
    WHERE birthdate IS NOT NULL
)
SELECT 
    MAX(CASE WHEN oldest_rank  = 1 THEN customer_name END) AS oldest_customer_name,
    MIN(birthdate)                                          AS oldest_birthdate,
    MAX(CASE WHEN oldest_rank  = 1 THEN age END)           AS oldest_age,
    MAX(CASE WHEN youngest_rank = 1 THEN customer_name END) AS youngest_customer_name,
    MAX(CASE WHEN youngest_rank = 1 THEN birthdate END)    AS youngest_birthdate,
    MAX(CASE WHEN youngest_rank = 1 THEN age END)          AS youngest_age,
    AVG(age)                                               AS avg_age_of_customer
FROM AgeCalculations;


/* ============================================================================
   PHASE 4 — MEASURES EXPLORATION  (The "Big Numbers")
   "At the highest level of aggregation, what does the business look like?
    What are the headline figures that would appear on an executive summary?"
   ============================================================================ */

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.1  What is the total gross revenue, and how many units has the business
--      sold in aggregate across all time?
--
--      Implication: The two most fundamental business metrics. Total revenue
--      is the north-star KPI for most organisations; total quantity confirms
--      whether revenue is being driven by volume or by price.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 
    SUM(quantity)     AS total_quantity,
    SUM(sales_amount) AS total_sales
FROM gold.fact_sales;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4.2  What is the average unit selling price across all transactions?
--
--      Implication: Establishes the baseline average selling price (ASP).
--      When compared with dim_products.cost, this forms the basis for gross
--      margin analysis.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 
    AVG(price) AS avg_price 
FROM gold.fact_sales;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4.3  How many discrete sales transactions (orders) has the business
--      processed, and how does raw row count compare with distinct order count?
--
--      Implication: The gap between total_entries and total_distinct_orders
--      reveals the average number of line items per order.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 
    COUNT(order_number)          AS total_entries,
    COUNT(DISTINCT order_number) AS total_distinct_orders
FROM gold.fact_sales;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4.4  How wide is our product catalogue — how many unique products are
--      we able to sell?
--
--      Implication: Baseline catalogue size. 
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 
    COUNT(DISTINCT product_key) AS total_products
FROM gold.dim_products;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4.5  How large is our total registered customer base?
--
--      Implication: The size of the CRM universe. This is the denominator for
--      any customer activation or retention rate calculation.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 
    COUNT(DISTINCT customer_key) AS total_registered_customers
FROM gold.dim_customers;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4.6  Of all registered customers, how many have actually placed an order?
--      What is our customer activation rate?
--
--      Implication: Comparing this number with total_registered_customers
--      (above) gives the activation rate = active buyers / registered base.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 
    COUNT(DISTINCT customer_key) AS total_active_customers
FROM gold.fact_sales;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4.7  What does a typical order look like in terms of item count and
--      monetary value? (Basket Analysis)
--
--      Implication: Average items per order is the basket depth metric used
--      in upsell and cross-sell strategy. Average order value (AOV) is the
--      primary lever for revenue growth without acquiring new customers.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    SUM(quantity)     / COUNT(DISTINCT order_number) AS avg_items_per_order,
    SUM(sales_amount) / COUNT(DISTINCT order_number) AS avg_order_value
FROM gold.fact_sales;


/* ============================================================================
   PHASE 5 — KEY METRICS SUMMARY REPORT
   "Can we produce a single-screen executive summary of every headline KPI
    in the warehouse, formatted so it can be dropped directly into a briefing?"
   ============================================================================ */

SELECT 'Total Revenue'          AS metric, CAST(SUM(sales_amount) AS VARCHAR(20))                         AS value FROM gold.fact_sales
UNION ALL
SELECT 'Total Units Sold',               CAST(SUM(quantity) AS VARCHAR(20))                               FROM gold.fact_sales
UNION ALL
SELECT 'Average Unit Price',             CAST(CAST(AVG(price) AS DECIMAL(10, 2)) AS VARCHAR(20))          FROM gold.fact_sales
UNION ALL
SELECT 'Min Unit Price',                 CAST(MIN(price) AS VARCHAR(20))                                  FROM gold.fact_sales
UNION ALL
SELECT 'Max Unit Price',                 CAST(MAX(price) AS VARCHAR(20))                                  FROM gold.fact_sales
UNION ALL
SELECT 'Total Distinct Orders',          CAST(COUNT(DISTINCT order_number) AS VARCHAR(20))                FROM gold.fact_sales
UNION ALL
SELECT 'Total Products in Catalogue',    CAST(COUNT(DISTINCT product_key)  AS VARCHAR(20))                FROM gold.dim_products
UNION ALL
SELECT 'Total Registered Customers',     CAST(COUNT(DISTINCT customer_key) AS VARCHAR(20))                FROM gold.dim_customers
UNION ALL
SELECT 'Customers Who Placed an Order',  CAST(COUNT(DISTINCT customer_key) AS VARCHAR(20))                FROM gold.fact_sales;


/* ============================================================================
   PHASE 6 — MAGNITUDE ANALYSIS
   "Where is the business concentrated? Which dimensions account for the
    majority of customers, products, and revenue — and which are marginal?"
   ============================================================================ */

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.1  How is our customer base distributed across geographic markets?
--
--      Implication: Identifies which countries are the primary customer
--      acquisition markets vs. which are negligible.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 
    country, 
    COUNT(DISTINCT customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.2  What is the gender split of our registered customer base?
--
--      Implication: Informs marketing and creative strategy.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT  
    gender,
    COUNT(DISTINCT customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY gender 
ORDER BY total_customers DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.3  How many distinct products does each category contain?
--
--      Implication: Reveals catalogue concentration.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT  
    category,
    COUNT(DISTINCT product_key) AS total_products
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.4  What is the average product cost per category?
--
--      Implication: Establishes the cost baseline by category, which feeds
--      directly into gross margin calculations when paired with average
--      selling price by category.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT  
    category,
    AVG(cost) AS avg_cost
FROM gold.dim_products
GROUP BY category
ORDER BY avg_cost DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.5  Which product categories are driving the most revenue for the business?
--
--      Implication: The single most important category-level question for
--      merchandising and supply chain teams. Confirms which categories to
--      prioritise in inventory planning and promotional spend.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT  
    p.category,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p 
    ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.6  What is the total lifetime revenue attributed to each individual
--      customer?
--
--      Implication: This is the Customer Lifetime Value (CLV) proxy —
--      arguably the most important customer-level metric for CRM strategy.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT  
    c.customer_key,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    SUM(f.sales_amount)                    AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.7  How is total product volume (units sold) distributed across
--      geographic markets?
--
--      Implication: Volume distribution by country reveals which markets
--      absorb the most physical product — critical for logistics, warehouse
--      positioning, and fulfilment SLA planning.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT  
    c.country,
    SUM(f.quantity) AS total_units_sold
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_units_sold DESC;


/* ============================================================================
   PHASE 7 — RANKING ANALYSIS  (Top N / Bottom N)
   "Who and what are the outliers — the clear over-performers we should
    double down on, and the clear under-performers we should investigate
    or deprioritise?"
   ============================================================================ */

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.1a  Which five individual products generate the most revenue?
--      (Approach A: TOP with ORDER BY)
--
--      Implication: The top-5 revenue products are typically responsible for
--      a disproportionate share of total revenue (Pareto principle). These are
--      the products that demand the highest stock availability, the most
--      prominent placement in digital and physical channels, and the first
--      consideration in any promotional strategy.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT TOP 5
    p.product_name,
    p.category,
    p.subcategory,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p 
    ON f.product_key = p.product_key
GROUP BY p.product_name, p.category, p.subcategory
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.1b Which five individual products generate the most revenue? Using Window Function. 
--
--      Implication: Identical business question as 7.1 but implemented with
--      ROW_NUMBER() so the rank value is available as a column. 
-- ─────────────────────────────────────────────────────────────────────────────
SELECT *
FROM (
    SELECT
        p.product_name,
        SUM(f.sales_amount)                                    AS total_revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(f.sales_amount) DESC) AS revenue_rank
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p 
        ON f.product_key = p.product_key
    GROUP BY p.product_name
) ranked_products
WHERE revenue_rank <= 5;


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.2  Which five product sub-categories are the strongest revenue contributors?
--
--      Implication: One level above individual products, sub-category ranking
--      reveals which product families — not just individual SKUs — are winning
--      commercially. 
-- ─────────────────────────────────────────────────────────────────────────────
SELECT TOP 5
    p.subcategory,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p 
    ON f.product_key = p.product_key
GROUP BY p.subcategory
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.3  Who are our top 10 highest-spending customers by lifetime revenue?
--
--      Implication: These are the VIP accounts. Losing even one of these
--      customers has a measurable P&L impact. This list feeds directly into
--      account management prioritisation, dedicated customer success outreach,
--      and early access to new product launches.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT TOP 10
    c.customer_key,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    SUM(f.sales_amount)                    AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.4  Which three customers have placed the fewest orders — our most
--      infrequent buyers?
--      (Window Function approach)
--
--      Implication: Customers who have transacted only once or twice are the
--      highest-risk segment for permanent churn. This list is the seed for a
--      win-back campaign.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT *
FROM (
    SELECT
        c.customer_key,
        CONCAT(c.first_name, ' ', c.last_name)                      AS customer_name,
        COUNT(DISTINCT f.order_number)                               AS total_orders,
        ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT f.order_number) ASC) AS order_frequency_rank
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON f.customer_key = c.customer_key
    GROUP BY c.customer_key, c.first_name, c.last_name 
) ranked_customers
WHERE order_frequency_rank <= 3;


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.5  Which five products are the weakest performers by total revenue?
--
--      Implication: The bottom-5 revenue products are candidates for range
--      rationalisation. Before acting on this, compare with quantity sold
--      (a low-revenue product may have high volume and serve as a loss-leader)
--      and with days-in-range (a new product naturally has less accumulated
--      revenue).
-- ─────────────────────────────────────────────────────────────────────────────
SELECT TOP 5
    p.product_name,
    p.subcategory,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p 
    ON f.product_key = p.product_key
GROUP BY p.product_name, p.subcategory
ORDER BY total_revenue ASC;
