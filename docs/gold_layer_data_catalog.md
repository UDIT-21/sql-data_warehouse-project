Here is the enriched `DATA_CATALOG.md` file. As an experienced data engineer, I have upgraded this documentation by adding enterprise-grade metadata (SLAs, ownership), clarifying data modeling standards (handling unknowns/nulls), defining specific data quality constraints, removing duplicate fields, and providing starter queries to accelerate analyst onboarding.

---

# Data Catalog — Gold Layer

### Data Warehouse | Star Schema | Business-Ready Analytics

**Governance & Metadata**

* **Domain:** Enterprise Sales & Analytics
* **Data Stewards:** Enterprise Data Engineering Team
* **Refresh SLA:** Real-time computation (Gold views reflect the latest Silver state)
* **Environment:** Production (`prod_dw.gold`)
* **Version:** 2.1 (Last Updated: June 2026)

---

## Why a Data Catalog?

In any multi-layer data warehouse architecture, raw data passes through several stages of transformation before it becomes consumable. By the time data reaches the **Gold layer**, it has been:

* Ingested from source systems (Bronze)
* Cleaned, deduped, standardized, and validated (Silver)
* Joined, enriched, and modeled into a **Star Schema** (Gold)

Without a catalog, the Gold layer is a black box. Analysts, BI developers, and data consumers are left guessing: *What does `customer_key` mean? Where does `gender` actually come from? Why is `prd_end_dt` sometimes NULL?* These questions cost time, introduce errors, and erode trust in data.

**A data catalog answers those questions definitively** — it documents not just what columns exist, but what they mean, where they came from, and how they should be used.

---

## Why Document the Gold Layer Specifically?

The Gold layer is the **only layer** that business users, analysts, and BI tools directly query. Bronze is raw and unsafe to expose. Silver is clean but technical and normalized. Gold is the presentation layer — optimized for reporting and analytics via a Star Schema (fact + dimension tables).

Documenting Gold specifically matters because:

| Reason | Implication |
| --- | --- |
| **Consumer-Facing Layer** | Every dashboard, report, or ad-hoc query starts here. Misunderstood columns lead to wrong insights. |
| **Surrogate Keys Replace Natural Keys** | `customer_key` and `product_key` are system-generated integers. They mean nothing without documentation. |
| **Baked-in Business Logic** | Gender resolution, cost fallback to 0, and SCD Type 2 filtering are invisible without a catalog. |
| **Hidden Multi-Source Joins** | Gold views silently combine CRM and ERP data. Consumers need to trace lineage via this document. |
| **Database Engine Limitations** | Most BI tools and SQL IDEs show column names but not semantic meaning, origin, or transformation logic. |

> **Bottom Line:** The Gold layer is where SQL ends and storytelling begins. This catalog is that story.

---

## General Modeling Standards & Business Rules

To ensure consistency across reports, the Gold layer strictly adheres to the following data modeling standards:

* **Unknown/Missing Dimensions:** Any fact record lacking a valid dimension mapping is assigned a surrogate key of `-1`. The corresponding dimension tables contain a `-1` row with descriptive values like `Unknown` or `Not Applicable`.
* **Currency:** All monetary values (`sales_amount`, `cost`, `price`) are standardized to **USD**.
* **Dates:** All date fields follow the ISO-8601 standard (`YYYY-MM-DD`).
* **Active Records Only:** Dimension views in the Gold layer currently only expose the *active* version of a record (SCD Type 1 view over SCD Type 2 underlying Silver tables).

---

## Architecture Overview

```text
Source Systems (CSV, API)
       │
       ▼
┌─────────────┐
│   BRONZE    │  Raw ingestion — no transformation, full fidelity
│  (Tables)   │  Loaded via: bronze.load_bronze
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   SILVER    │  Cleaned, standardized, deduplicated, type-cast
│  (Tables)   │  Loaded via: silver.load_silver
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    GOLD     │  Star Schema — business-ready, analytical
│   (Views)   │  Queryable directly — no load procedure needed
└─────────────┘

```

**Gold layer objects are SQL Views** — they do not store data physically. They compute on-the-fly from Silver tables. This ensures Gold always reflects the latest Silver state without requiring a separate ETL orchestration run.

---

## Gold Layer Objects

| Object | Type | Role in Star Schema | Row Grain |
| --- | --- | --- | --- |
| `gold.dim_customers` | View | Customer Dimension | One row per unique customer |
| `gold.dim_products` | View | Product Dimension | One row per currently active product version |
| `gold.fact_sales` | View | Central Fact Table | One row per sales order line |

---

## `gold.dim_customers`

### Purpose

The customer dimension consolidates identity, demographic, and location data from two source systems — the CRM (primary) and ERP (supplementary). It provides a single, clean, deduplicated record per customer.

### Source Tables (Silver Layer)

| Silver Table | Contribution |
| --- | --- |
| `silver.crm_cust_info` | Primary source: identity fields, marital status, gender, create date |
| `silver.erp_cust_az12` | Supplementary: birthdate, fallback gender |
| `silver.erp_loc_a101` | Supplementary: country of residence |

### Column Reference

| Column Name | Data Type | Description | Source |
| --- | --- | --- | --- |
| `customer_key` | INT | **Primary Surrogate Key.** System-generated integer. | Generated |
| `customer_id` | INT | **Natural key.** Original numeric ID from the CRM. | `crm_cust_info.cst_id` |
| `customer_number` | NVARCHAR(50) | **Business identifier.** Human-readable cross-reference code. | `crm_cust_info.cst_key` |
| `first_name` | NVARCHAR(50) | Customer's first name. | `crm_cust_info.cst_firstname` |
| `last_name` | NVARCHAR(50) | Customer's last name. | `crm_cust_info.cst_lastname` |
| `country` | NVARCHAR(50) | Country of residence (Standardized to ISO Alpha-3). | `erp_loc_a101.cntry` |
| `marital_status` | NVARCHAR(50) | Standardized to `Married`, `Single`, or `Unknown`. | `crm_cust_info.cst_marital_status` |
| `gender` | NVARCHAR(50) | Standardized to `M`, `F`, or `U`. | `crm_cust_info.cst_gndr` / `erp_cust_az12.gen` |
| `birthdate` | DATE | Customer's date of birth. | `erp_cust_az12.bdate` |
| `create_date` | DATE | Date the record was created in the CRM. | `crm_cust_info.cst_create_date` |

**Data Quality Constraints:**

* `customer_key` is unique and `NOT NULL`.
* `birthdate` must be >= `1900-01-01` and <= Current Date.

---

## `gold.dim_products`

### Purpose

Provides a clean, enriched view of active products, combining CRM product master data with ERP category hierarchies. Expired product versions are excluded.

### Source Tables (Silver Layer)

| Silver Table | Contribution |
| --- | --- |
| `silver.crm_prd_info` | Primary source: product attributes, cost, line, dates |
| `silver.erp_px_cat_g1v2` | Supplementary: category hierarchy (category, subcat, maintenance) |

### Column Reference

| Column Name | Data Type | Description | Source |
| --- | --- | --- | --- |
| `product_key` | INT | **Primary Surrogate Key.** System-generated integer. | Generated |
| `product_id` | INT | **Natural key.** Original numeric ID from CRM. | `crm_prd_info.prd_id` |
| `product_number` | NVARCHAR(50) | **Business identifier.** Human-readable code. | `crm_prd_info.prd_key` |
| `product_name` | NVARCHAR(50) | Descriptive name of the product. | `crm_prd_info.prd_nm` |
| `category_id` | NVARCHAR(50) | Derived category identifier extracted from CRM product key. | `crm_prd_info.cat_id` |
| `category` | NVARCHAR(50) | Top-level product category (e.g., `Bikes`). | `erp_px_cat_g1v2.cat` |
| `subcategory` | NVARCHAR(50) | Sub-category within the top-level (e.g., `Road Bikes`). | `erp_px_cat_g1v2.subcat` |
| `maintenance` | NVARCHAR(50) | Maintenance classification flag (`Yes`/`No`). | `erp_px_cat_g1v2.maintenance` |
| `cost` | DECIMAL(18,2) | Manufacturing/acquisition cost of the product. | `crm_prd_info.prd_cost` |
| `product_line` | NVARCHAR(50) | Standardized product line label. | `crm_prd_info.prd_line` |
| `start_date` | DATE | Date this version of the product became active. | `crm_prd_info.prd_start_dt` |

**Data Quality Constraints:**

* `product_key` is unique and `NOT NULL`.
* `cost` must be >= 0.

---

## `gold.fact_sales`

### Purpose

The central fact table of the Star Schema. It records every sales order line transaction. This is the primary table for sales volume, revenue, and pricing analytics.

### Source Tables

| Source | Contribution |
| --- | --- |
| `silver.crm_sales_details` | Transactional fields: order number, dates, sales amount, quantity, price |
| `gold.dim_products` | Resolves `sls_prd_key` (business key) → `product_key` (surrogate) |
| `gold.dim_customers` | Resolves `sls_cust_id` (natural key) → `customer_key` (surrogate) |

### Column Reference

| Column Name | Data Type | Description | Source |
| --- | --- | --- | --- |
| `order_number` | NVARCHAR(50) | **Degenerate dimension key.** Unique sales order identifier. | `crm_sales_details.sls_ord_num` |
| `product_key` | INT | **Foreign key.** Identifies the product sold. | `dim_products.product_key` |
| `customer_key` | INT | **Foreign key.** Identifies the purchasing customer. | `dim_customers.customer_key` |
| `order_date` | DATE | The date the sales order was placed. | `crm_sales_details.sls_order_dt` |
| `shipping_date` | DATE | The date the order was shipped from the warehouse. | `crm_sales_details.sls_ship_dt` |
| `due_date` | DATE | The expected delivery date for the order. | `crm_sales_details.sls_due_dt` |
| `sales_amount` | DECIMAL(18,2) | Total monetary value (`quantity` * `price`). | `crm_sales_details.sls_sales` |
| `quantity` | INT | Number of product units in the order line. | `crm_sales_details.sls_quantity` |
| `price` | DECIMAL(18,2) | Unit price of the product at the time of the order. | `crm_sales_details.sls_price` |

**Data Quality Constraints:**

* `order_number`, `product_key`, and `customer_key` combined form a unique composite grain.
* Missing dimensional links default to `-1` (Never `NULL`).
* `sales_amount` must precisely equal `quantity * price`.

---

## Data Lineage (Data Flow)

The data warehouse follows a Medallion Architecture. The diagram below illustrates the flow from external source files through the Bronze and Silver tables, ultimately combining into Gold layer views.

```text
=============================================================================================
 SOURCES                  BRONZE LAYER               SILVER LAYER               GOLD LAYER
=============================================================================================

📁 CRM
 └── sales_details ────> crm_sales_details ───────> crm_sales_details ───────> fact_sales

📁 CRM
 └── cust_info ────────> crm_cust_info ───────────> crm_cust_info ─────────┐
                                                                           ├─> dim_customers
📁 ERP                                                                     │
 ├── erp_cust_az12 ────> erp_cust_az12 ───────────> erp_cust_az12 ─────────┤
 └── erp_loc_a101  ────> erp_loc_a101  ───────────> erp_loc_a101  ─────────┘

📁 CRM
 └── prd_info  ────────> crm_prd_info  ───────────> crm_prd_info  ─────────┐
                                                                           ├─> dim_products
📁 ERP                                                                     │
 └── erp_px_cat_g1v2 ──> erp_px_cat_g1v2 ─────────> erp_px_cat_g1v2 ───────┘

=============================================================================================

```

---

## Sales Data Mart (Entity Relationship)

Below is the conceptual Star Schema structure connecting our dimensions to the central fact table.

```text
┌──────────────────────┐              ┌──────────────────────┐              ┌──────────────────────┐
│  gold.dim_customers  │              │   gold.fact_sales    │              │  gold.dim_products   │
├──────────────────────┤              ├──────────────────────┤              ├──────────────────────┤
│ PK customer_key      │ 1          * │ order_number         │ * 1 │ PK product_key       │
├──────────────────────┤──────────────┤ FK1 product_key      ├──────────────├──────────────────────┤
│    customer_id       │              │ FK2 customer_key     │              │    product_id        │
│    customer_number   │              │ order_date           │              │    product_number    │
│    first_name        │              │ shipping_date        │              │    product_name      │
│    last_name         │              │ due_date             │              │    category_id       │
│    country           │              │ sales_amount         │              │    category          │
│    marital_status    │              │ quantity             │              │    subcategory       │
│    gender            │              │ price                │              │    maintenance       │
│    birthdate         │              └───────────┬──────────┘              │    cost              │
└──────────────────────┘                          │                         │    product_line      │
                                                  │                         │    start_date        │
                                         [ Sales Calculation ]              └──────────────────────┘
                                        Sales = Quantity * Price                                    

```

---


