/*
================================================================================
                               ADVANCED ANALYTICS
================================================================================
  Project      : Data Warehouse Portfolio Project (Medallion Architecture)
  Layer        : Gold (Analytics & Reporting)
  Database     : DataWarehouse
  Schema       : gold

  ─────────────────────────────────────────────────────────────────────────────
  SECTIONS
  ─────────────────────────────────────────────────────────────────────────────
    1. Change Over Time Analysis     — trends, seasonality, date functions
    2. Cumulative Analysis           — running totals, moving averages
    3. Performance Analysis (YoY)    — LAG(), benchmarking vs avg & prior year
    4. Data Segmentation             — CASE-based product & customer bucketing
    5. Part-to-Whole Analysis        — category contribution & % of total
    6. Customer Report View          — gold.report_customers (full KPI view)
    7. Product Report View           — gold.report_products  (full KPI view)

  ─────────────────────────────────────────────────────────────────────────────
  SOURCE TABLES
  ─────────────────────────────────────────────────────────────────────────────
    gold.fact_sales        — transactional sales data (grain: order line)
    gold.dim_customers     — customer dimension (SCD Type 2 resolved to current)
    gold.dim_products      — product dimension

  VIEWS CREATED
  ─────────────────────────────────────────────────────────────────────────────
    gold.report_customers  — customer-level KPIs and segments
    gold.report_products   — product-level KPIs and segments

  ─────────────────────────────────────────────────────────────────────────────
*/


-- ==============================================================================
-- SECTION 1 │ CHANGE OVER TIME ANALYSIS
-- ==============================================================================
-- Purpose  : Track trends, growth, and changes in key metrics across time.
--            Useful for time-series analysis, seasonality detection, and
--            measuring growth or decline over specific periods.
--
-- Functions: YEAR(), MONTH(), DATETRUNC(), FORMAT()
--            Aggregate: SUM(), COUNT(), AVG()
--
-- Three equivalent approaches are shown below — each suits a different use case.
-- ==============================================================================


-- ------------------------------------------------------------------------------
-- 1A │ YEAR() + MONTH()   [Quick Exploration]
-- ------------------------------------------------------------------------------
-- Extract year and month as separate integer columns.
-- ✔  Simplest syntax; ORDER BY works cleanly on integer pairs.
-- ✘  Two columns instead of one date — harder to feed directly into BI tools.
-- ------------------------------------------------------------------------------
SELECT
    YEAR(order_date)             AS order_year,
    MONTH(order_date)            AS order_month,
    SUM(sales_amount)            AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,  -- unique buyers per period
    SUM(quantity)                AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL          -- exclude rows with no recorded order date
GROUP BY
    YEAR(order_date),
    MONTH(order_date)
ORDER BY
    YEAR(order_date),
    MONTH(order_date);


-- ------------------------------------------------------------------------------
-- 1B │ DATETRUNC()   [Best Practice for Time-Series]
-- ------------------------------------------------------------------------------
-- DATETRUNC(month, date) floors any date to the first day of its month.
-- Example: 2023-06-15  →  2023-06-01
-- ✔  Returns a proper DATE type — directly usable in charts and BI tools.
-- ✔  Single column; easier to JOIN, filter, or plot on a time axis.
-- ------------------------------------------------------------------------------
SELECT
    DATETRUNC(month, order_date) AS order_date,       -- e.g., 2023-06-01
    SUM(sales_amount)            AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity)                AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date);


-- ------------------------------------------------------------------------------
-- 1C │ FORMAT()   [Human-Readable Display]
-- ------------------------------------------------------------------------------
-- FORMAT(date, 'yyyy-MMM') produces a string like '2023-Jun'.
-- ✔  Great for reports and dashboards where readability matters.
-- ✘  Returns VARCHAR — ORDER BY will sort alphabetically, not chronologically.
--    Use FORMAT only for the display column; pair with DATETRUNC for ordering
--    in production views.
-- ------------------------------------------------------------------------------
SELECT
    FORMAT(order_date, 'yyyy-MMM') AS order_date,     -- e.g., '2023-Jun'
    SUM(sales_amount)              AS total_sales,
    COUNT(DISTINCT customer_key)   AS total_customers,
    SUM(quantity)                  AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM');


-- ==============================================================================
-- SECTION 2 │ CUMULATIVE ANALYSIS
-- ==============================================================================
-- Purpose  : Calculate running totals and moving averages for key metrics.
--            Tracks cumulative performance over time to reveal long-term trends.
--
-- Functions: Window Functions — SUM() OVER(), AVG() OVER()
--
-- KEY CONCEPT — Window Functions vs GROUP BY
-- ─────────────────────────────────────────────────────────────────────────────
--  GROUP BY collapses many rows into one summary row.
--  Window functions compute across rows while keeping EVERY row intact.
--
--  Syntax:  AGG_FUNCTION() OVER ( [PARTITION BY col] ORDER BY col )
--    • PARTITION BY  → resets the window for each group (e.g., per product)
--    • ORDER BY      → defines the running direction (e.g., chronological)
--    • No PARTITION BY → window spans the entire result set
--
--  Here: SUM() OVER (ORDER BY order_date) accumulates sales from the
--  earliest year up to (and including) the current row — a running total.
-- ==============================================================================

SELECT
    order_date,
    total_sales,

    -- Running total: cumulative sales from year 1 up to the current year
    SUM(total_sales) OVER (ORDER BY order_date)  AS running_total_sales,

    -- Moving average: average price from year 1 up to the current year
    -- Reveals whether the average price is trending up or down over time
    AVG(avg_price)   OVER (ORDER BY order_date)  AS moving_average_price

FROM
(
    -- ── Subquery: aggregate to one row per year BEFORE windowing ─────────────
    -- Window functions run on pre-aggregated rows; this inner aggregation is
    -- necessary to avoid summing individual transaction rows cumulatively.
    SELECT
        DATETRUNC(year, order_date)  AS order_date,   -- floor to year start
        SUM(sales_amount)            AS total_sales,
        AVG(price)                   AS avg_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(year, order_date)
) AS yearly_summary;        -- derived tables in SQL Server must have an alias


-- ==============================================================================
-- SECTION 3 │ PERFORMANCE ANALYSIS  (Year-over-Year)
-- ==============================================================================
-- Purpose  : Compare each product's annual sales against two benchmarks:
--              (a) its own historical average across all years
--              (b) its sales in the prior year (Year-over-Year)
--
-- Functions: LAG(), AVG() OVER(), CASE, CTE
--
-- KEY CONCEPTS
-- ─────────────────────────────────────────────────────────────────────────────
--  LAG(col) OVER (PARTITION BY x ORDER BY y)
--    → Returns the value from the PREVIOUS row within the partition.
--      Here: prior year's sales for the same product.
--      The first year for each product returns NULL (no prior row).
--
--  AVG(col) OVER (PARTITION BY product_name)
--    → Computes the average of [col] across ALL years for that product.
--      Same average is stamped on every row of that product — useful for
--      comparing each year to the product's lifetime baseline.
--
-- PATTERN: Aggregate first in a CTE, then apply window functions.
--   Separating the aggregation from the windowing keeps logic readable and
--   avoids nesting window functions inside GROUP BY queries (not allowed).
-- ==============================================================================

WITH yearly_product_sales AS (
-- ── CTE: one row per (year, product) ─────────────────────────────────────────
    SELECT
        YEAR(f.order_date)   AS order_year,
        p.product_name,
        SUM(f.sales_amount)  AS current_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY
        YEAR(f.order_date),
        p.product_name
)
SELECT
    order_year,
    product_name,
    current_sales,

    -- ── Benchmark A: average sales across ALL years for this product ──────────
    AVG(current_sales) OVER (PARTITION BY product_name)                                      AS avg_sales,

    -- Absolute gap vs the product's own historical average
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name)                      AS diff_avg,

    -- Label: is this year outperforming or underperforming the product average?
    CASE
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END AS avg_change,

    -- ── Benchmark B: Year-over-Year comparison ────────────────────────────────
    -- LAG() looks back one row (= prior year) within each product's partition
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year)                  AS py_sales,

    -- Absolute YoY change (NULL for first year — no prior year exists)
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year)  AS diff_py,

    -- Label: did sales rise, fall, or hold flat vs the prior year?
    CASE
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS py_change

FROM yearly_product_sales
ORDER BY product_name, order_year;


-- ==============================================================================
-- SECTION 4 │ DATA SEGMENTATION
-- ==============================================================================
-- Purpose  : Group data into meaningful categories for targeted insights.
--            Supports product pricing strategy and customer lifecycle analysis.
--
-- Functions: CASE, GROUP BY, DATEDIFF(), CTEs
--
-- Two segmentation examples are shown:
--   4A — Product cost tiers (static dimension attribute)
--   4B — Customer lifecycle segments (derived from behavioral metrics)
-- ==============================================================================


-- ------------------------------------------------------------------------------
-- 4A │ Product Cost Segmentation
-- ------------------------------------------------------------------------------
-- Bucket products into four cost tiers; count how many products fall in each.
-- Useful for: pricing audits, margin analysis, inventory strategy.
-- ------------------------------------------------------------------------------
WITH product_segments AS (
    SELECT
        product_key,
        product_name,
        cost,
        -- Assign each product a cost bucket using ordered CASE thresholds
        CASE
            WHEN cost < 100                THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500  THEN '100-500'
            WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
            ELSE                                'Above 1000'
        END AS cost_range
    FROM gold.dim_products
)
SELECT
    cost_range,
    COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;           -- most-populated tier first


-- ------------------------------------------------------------------------------
-- 4B │ Customer Lifecycle Segmentation
-- ------------------------------------------------------------------------------
-- Classify customers into three loyalty segments:
--
--   VIP      → lifespan ≥ 12 months  AND  total spending > €5,000
--   Regular  → lifespan ≥ 12 months  AND  total spending ≤ €5,000
--   New      → lifespan  < 12 months  (regardless of spend)
--
-- lifespan = DATEDIFF between first and last order in MONTHS.
-- A lifespan of 0 means the customer only purchased within a single month.
-- ------------------------------------------------------------------------------
WITH customer_spending AS (
-- ── CTE: one row per customer with behavioral metrics ─────────────────────────
    SELECT
        c.customer_key,
        SUM(f.sales_amount)                                   AS total_spending,
        MIN(f.order_date)                                     AS first_order,
        MAX(f.order_date)                                     AS last_order,
        -- Customer engagement window: months between first and last purchase
        DATEDIFF(month, MIN(f.order_date), MAX(f.order_date)) AS lifespan
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON f.customer_key = c.customer_key
    GROUP BY c.customer_key
)
SELECT
    customer_segment,
    COUNT(customer_key) AS total_customers
FROM (
    -- Inline subquery: apply segmentation BEFORE the outer GROUP BY
    SELECT
        customer_key,
        CASE
            WHEN lifespan >= 12 AND total_spending > 5000  THEN 'VIP'
            WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE                                                'New'
        END AS customer_segment
    FROM customer_spending
) AS segmented_customers
GROUP BY customer_segment
ORDER BY total_customers DESC;


-- ==============================================================================
-- SECTION 5 │ PART-TO-WHOLE ANALYSIS
-- ==============================================================================
-- Purpose  : Measure the relative contribution of each category to overall sales.
--            Identifies dominant revenue drivers at the category level.
--
-- Functions: SUM() OVER() [grand total], ROUND(), CAST()
--
-- KEY CONCEPT — Grand Total Window
-- ─────────────────────────────────────────────────────────────────────────────
--  SUM(total_sales) OVER ()  ← no PARTITION BY, no ORDER BY
--  This evaluates over the ENTIRE result set and returns the same grand total
--  on every row, allowing each row to divide its value by the grand total.
--
--  CAST to FLOAT is required to prevent integer division:
--    e.g., 3 / 10 = 0  (integer)   vs   3.0 / 10 = 0.3  (float)
-- ==============================================================================

WITH category_sales AS (
-- ── CTE: aggregate total sales per product category ────────────────────────
    SELECT
        p.category,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.category
)
SELECT
    category,
    total_sales,

    -- Grand total across ALL categories — same value stamped on every row
    SUM(total_sales) OVER ()                                                  AS overall_sales,

    -- Percentage share: this category's sales ÷ grand total × 100
    ROUND(
        (CAST(total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100, 2
    )                                                                          AS percentage_of_total

FROM category_sales
ORDER BY total_sales DESC;              -- highest-contributing category first


-- ==============================================================================
-- SECTION 6 │ CUSTOMER REPORT VIEW  —  gold.report_customers
-- ==============================================================================
-- Purpose  : Consolidate all key customer metrics into a single reusable
--            Gold view. This becomes the primary source for customer-facing
--            dashboards, CRM feeds, and executive reports.
--
-- Metrics produced
-- ─────────────────────────────────────────────────────────────────────────────
--   Demographic  : age, age_group
--   Behavioral   : customer_segment (VIP / Regular / New)
--   Activity     : total_orders, total_sales, total_quantity, total_products
--   Temporal     : last_order_date, lifespan (months), recency (months)
--   KPIs         : avg_order_value, avg_monthly_spend
--
-- Design pattern — 3-layer CTE stack
-- ─────────────────────────────────────────────────────────────────────────────
--   Layer 1  base_query           → flat join; one row per order line
--   Layer 2  customer_aggregation → roll-up to one row per customer
--   Layer 3  final SELECT         → apply segmentation labels & compute KPIs
--
-- BUG FIX: original script was missing a comma between [total_products]
--          and [lifespan] in the final SELECT list — corrected below.
-- ==============================================================================

IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;    -- drop stale version before recreating
GO

CREATE VIEW gold.report_customers AS

WITH base_query AS (
/*──────────────────────────────────────────────────────────────────────────────
  LAYER 1 — Base Query
  Joins fact_sales ↔ dim_customers to produce one flat row per order line.
  • CONCAT builds a display-ready full name.
  • DATEDIFF(year, birthdate, GETDATE()) computes current age in full years.
──────────────────────────────────────────────────────────────────────────────*/
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name)      AS customer_name,
        DATEDIFF(year, c.birthdate, GETDATE())       AS age   -- full years today
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL      -- exclude records with no valid order date
),

customer_aggregation AS (
/*──────────────────────────────────────────────────────────────────────────────
  LAYER 2 — Customer Aggregations
  Rolls up order-line data to exactly one row per customer.
  • COUNT(DISTINCT order_number)  → total number of distinct orders placed
  • COUNT(DISTINCT product_key)   → breadth of product purchases
  • DATEDIFF(month, MIN, MAX)     → lifespan = customer engagement window
──────────────────────────────────────────────────────────────────────────────*/
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number)                                  AS total_orders,
        SUM(sales_amount)                                             AS total_sales,
        SUM(quantity)                                                 AS total_quantity,
        COUNT(DISTINCT product_key)                                   AS total_products,
        MAX(order_date)                                               AS last_order_date,
        DATEDIFF(month, MIN(order_date), MAX(order_date))             AS lifespan
    FROM base_query
    GROUP BY
        customer_key,
        customer_number,
        customer_name,
        age
)

/*──────────────────────────────────────────────────────────────────────────────
  LAYER 3 — Final Output
  Derives segmentation labels and KPIs from the aggregated customer data.
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,

    -- Age group bucket — useful for demographic analysis and cohort reporting
    CASE
        WHEN age < 20                  THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29     THEN '20-29'
        WHEN age BETWEEN 30 AND 39     THEN '30-39'
        WHEN age BETWEEN 40 AND 49     THEN '40-49'
        ELSE                                '50 and above'
    END AS age_group,

    -- Customer loyalty segment (mirrors the segmentation in Section 4B)
    -- VIP → long-tenure, high-spend | Regular → long-tenure, lower-spend
    -- New → short tenure regardless of spend
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000  THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE                                             'New'
    END AS customer_segment,

    last_order_date,

    -- Recency: months elapsed since the customer's last purchase.
    -- Lower recency = more recently active customer.
    -- Key input for RFM (Recency–Frequency–Monetary) analysis.
    DATEDIFF(month, last_order_date, GETDATE())     AS recency,

    total_orders,
    total_sales,
    total_quantity,
    total_products,     -- ← comma was missing here in the original script (BUG FIX)
    lifespan,

    -- Average Order Value (AOV): how much revenue per order on average?
    -- CASE guard prevents division-by-zero if total_orders = 0.
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_value,

    -- Average Monthly Spend: revenue generated per month of customer lifespan.
    -- If lifespan = 0 (single-month customer), use total_sales as-is to avoid /0.
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_spend

FROM customer_aggregation;
GO


-- ==============================================================================
-- SECTION 7 │ PRODUCT REPORT VIEW  —  gold.report_products
-- ==============================================================================
-- Purpose  : Consolidate all key product metrics into a single reusable
--            Gold view. This becomes the primary source for product-facing
--            dashboards, inventory management, and executive reports.
--
-- Metrics produced
-- ─────────────────────────────────────────────────────────────────────────────
--   Descriptive : product_name, category, subcategory, cost
--   Behavioral  : product_segment (High-Performer / Mid-Range / Low-Performer)
--   Activity    : total_orders, total_sales, total_quantity, total_customers
--   Temporal    : last_sale_date, lifespan (months), recency_in_months
--   KPIs        : avg_selling_price, avg_order_revenue, avg_monthly_revenue
--
-- Design pattern — same 3-layer CTE stack as the Customer Report (Section 6)
-- ─────────────────────────────────────────────────────────────────────────────
--   Layer 1  base_query             → flat join; one row per order line
--   Layer 2  product_aggregations   → roll-up to one row per product
--   Layer 3  final SELECT           → apply segment labels & compute KPIs
-- ==============================================================================

IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;     -- drop stale version before recreating
GO

CREATE VIEW gold.report_products AS

WITH base_query AS (
/*──────────────────────────────────────────────────────────────────────────────
  LAYER 1 — Base Query
  Joins fact_sales ↔ dim_products to produce one flat row per order line.
  Brings in all product attributes (category, subcategory, cost) alongside
  the transactional columns needed for aggregation in Layer 2.
──────────────────────────────────────────────────────────────────────────────*/
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL      -- only consider rows with valid sale dates
),

product_aggregations AS (
/*──────────────────────────────────────────────────────────────────────────────
  LAYER 2 — Product Aggregations
  Rolls up order-line data to exactly one row per product.
  • COUNT(DISTINCT customer_key) → number of unique customers who bought it
  • DATEDIFF(MONTH, MIN, MAX)    → lifespan = months product has been actively sold
  • NULLIF(quantity, 0) in avg_selling_price prevents division-by-zero when
    a line item has zero quantity (data quality guard).
──────────────────────────────────────────────────────────────────────────────*/
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date))               AS lifespan,
        MAX(order_date)                                                  AS last_sale_date,
        COUNT(DISTINCT order_number)                                     AS total_orders,
        COUNT(DISTINCT customer_key)                                     AS total_customers,
        SUM(sales_amount)                                                AS total_sales,
        SUM(quantity)                                                    AS total_quantity,
        -- Average revenue per unit sold across all transactions
        -- CAST to FLOAT avoids integer truncation; NULLIF guards against /0
        ROUND(
            AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)), 1
        )                                                                AS avg_selling_price
    FROM base_query
    GROUP BY
        product_key,
        product_name,
        category,
        subcategory,
        cost
)

/*──────────────────────────────────────────────────────────────────────────────
  LAYER 3 — Final Output
  Derives performance segment labels and KPIs from the aggregated product data.
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_sale_date,

    -- Recency: months elapsed since this product's last recorded sale.
    -- High recency = product may be stagnant or discontinued.
    DATEDIFF(MONTH, last_sale_date, GETDATE())      AS recency_in_months,

    -- Revenue-based performance tier for product portfolio analysis
    -- Thresholds should be reviewed periodically against business targets.
    CASE
        WHEN total_sales > 50000  THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE                           'Low-Performer'
    END AS product_segment,

    lifespan,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,

    -- Average Order Revenue (AOR): avg revenue generated per order for this product.
    -- CASE guard prevents division-by-zero if total_orders = 0.
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_revenue,

    -- Average Monthly Revenue: revenue per month across the product's active lifespan.
    -- If lifespan = 0 (sold only within one calendar month), use total_sales directly.
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_revenue

FROM product_aggregations;
GO
