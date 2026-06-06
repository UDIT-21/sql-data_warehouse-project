Here is the complete, updated `Data Catalog.md` file. It incorporates the Mermaid.js diagrams for both the Architecture Overview and Data Lineage/Star Schema, and I have completely removed the "Transformation Notes" column from all the data dictionary tables as requested.

---

# Data Catalog — Gold Layer
### Data Warehouse | Star Schema | Business-Ready Analytics

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
|--------|-------------|
| **It's the consumer-facing layer** | Every dashboard, report, or ad-hoc query starts here. Misunderstood columns lead to wrong insights. |
| **Surrogate keys replace natural keys** | `customer_key` and `product_key` are system-generated integers — they mean nothing without documentation. |
| **Business logic is baked in** | Gender resolution, cost fallback to 0, SCD Type 2 filtering — these are invisible without a catalog. |
| **Multi-source joins are hidden** | Gold views silently combine CRM and ERP data. A consumer has no way to trace lineage without this document. |
| **Views have no column-level metadata in SQL Server** | SSMS and most BI tools show column names but not meaning or origin. |

---

## Architecture Overview

```mermaid
graph TD
    %% Define Nodes
    Source[<b>Source Systems</b> <br/> CSV Files]
    
    Bronze[<b>BRONZE Layer</b> <br/> Tables <br/> <i>Loaded via: bronze.load_bronze</i>]
    
    Silver[<b>SILVER Layer</b> <br/> Tables <br/> <i>Loaded via: silver.load_silver</i>]
    
    Gold[<b>GOLD Layer</b> <br/> Views <br/> <i>Queryable directly</i>]

    %% Define Flows & Transformations
    Source -->|Raw ingestion — no transformation, full fidelity| Bronze
    Bronze -->|Cleaned, standardized, deduplicated, type-cast| Silver
    Silver -->|Star Schema — business-ready, analytical| Gold\
```
---

**Gold layer objects are SQL Views** — they do not store data. They compute on-the-fly from Silver tables every time they are queried. This ensures Gold always reflects the latest Silver state without a separate ETL run.

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

The customer dimension consolidates identity, demographic, and location data from two source systems — the CRM (primary) and ERP (supplementary). It provides a single, clean, deduplicated record per customer for use in all sales analytics.

### Source Tables (Silver Layer)

| Silver Table | Contribution |
| --- | --- |
| `silver.crm_cust_info` | Primary source: identity fields, marital status, gender, create date |
| `silver.erp_cust_az12` | Supplementary: birthdate, fallback gender |
| `silver.erp_loc_a101` | Supplementary: country of residence |

### Column Reference

| Column Name | Data Type | Description | Source |
| --- | --- | --- | --- |
| `customer_key` | INT | **Surrogate key.** System-generated integer for joining to `fact_sales`. Has no meaning outside this warehouse. | Generated |
| `customer_id` | INT | **Natural key.** The original numeric ID from the CRM source system. | `crm_cust_info.cst_id` |
| `customer_number` | NVARCHAR(50) | **Business identifier.** A human-readable code used in both CRM and ERP to cross-reference a customer. | `crm_cust_info.cst_key` |
| `first_name` | NVARCHAR(50) | Customer's first name. | `crm_cust_info.cst_firstname` |
| `last_name` | NVARCHAR(50) | Customer's last name. | `crm_cust_info.cst_lastname` |
| `country` | NVARCHAR(50) | Country of residence. | `erp_loc_a101.cntry` |
| `marital_status` | NVARCHAR(50) | Marital status. | `crm_cust_info.cst_marital_status` |
| `gender` | NVARCHAR(50) | Customer's gender. | `crm_cust_info.cst_gndr` (primary), `erp_cust_az12.gen` (fallback) |
| `birthdate` | DATE | Customer's date of birth. | `erp_cust_az12.bdate` |
| `create_date` | DATE | Date the customer record was first created in the CRM source system. | `crm_cust_info.cst_create_date` |

---

## `gold.dim_products`

### Purpose

The product dimension provides a clean, enriched view of currently active products, combining CRM product master data with ERP category and subcategory classifications. Historical/expired product versions are excluded.

### Source Tables (Silver Layer)

| Silver Table | Contribution |
| --- | --- |
| `silver.crm_prd_info` | Primary source: product attributes, cost, line, dates |
| `silver.erp_px_cat_g1v2` | Supplementary: category hierarchy (category, subcategory, maintenance) |

### Column Reference

| Column Name | Data Type | Description | Source |
| --- | --- | --- | --- |
| `product_key` | INT | **Surrogate key.** System-generated integer for joining to `fact_sales`. Has no meaning outside this warehouse. | Generated |
| `product_id` | INT | **Natural key.** The original numeric ID from the CRM source system. | `crm_prd_info.prd_id` |
| `product_number` | NVARCHAR(50) | **Business identifier.** A human-readable code used in CRM to identify products. Used to join sales transactions to this dimension. | `crm_prd_info.prd_key` |
| `product_name` | NVARCHAR(50) | Descriptive name of the product. | `crm_prd_info.prd_nm` |
| `category_id` | NVARCHAR(50) | Derived category identifier extracted from the CRM product key. Used to join with ERP category reference data. | `crm_prd_info.cat_id` |
| `category` | NVARCHAR(50) | Top-level product category (e.g., `Bikes`, `Accessories`). | `erp_px_cat_g1v2.cat` |
| `subcategory` | NVARCHAR(50) | Sub-category within the top-level category (e.g., `Road Bikes`, `Helmets`). | `erp_px_cat_g1v2.subcat` |
| `maintenance` | NVARCHAR(50) | Maintenance classification flag from the ERP product reference. | `erp_px_cat_g1v2.maintenance` |
| `cost` | INT | Manufacturing or acquisition cost of the product. | `crm_prd_info.prd_cost` |
| `product_line` | NVARCHAR(50) | Standardized product line label. | `crm_prd_info.prd_line` |
| `start_date` | DATE | The date from which this version of the product became active. | `crm_prd_info.prd_start_dt` |

---

## `gold.fact_sales`

### Purpose

The central fact table of the Star Schema. It records every sales order line transaction and links each to a product and a customer via surrogate keys. This is the primary table for sales volume, revenue, and pricing analytics.

### Source Tables

| Source | Contribution |
| --- | --- |
| `silver.crm_sales_details` | All transactional fields: order number, dates, sales amount, quantity, price |
| `gold.dim_products` | Resolves `sls_prd_key` (business key) → `product_key` (surrogate) |
| `gold.dim_customers` | Resolves `sls_cust_id` (natural key) → `customer_key` (surrogate) |

### Column Reference

| Column Name | Data Type | Description | Source |
| --- | --- | --- | --- |
| `order_number` | NVARCHAR(50) | **Degenerate dimension key.** The unique sales order identifier from the CRM source system. Not a surrogate — it carries meaningful information (order ID). | `crm_sales_details.sls_ord_num` |
| `product_key` | INT | Foreign key to `gold.dim_products`. Identifies the product sold. | Resolved via `dim_products.product_key` |
| `customer_key` | INT | Foreign key to `gold.dim_customers`. Identifies the purchasing customer. | Resolved via `dim_customers.customer_key` |
| `order_date` | DATE | The date the sales order was placed. | `crm_sales_details.sls_order_dt` |
| `shipping_date` | DATE | The date the order was shipped from the warehouse. | `crm_sales_details.sls_ship_dt` |
| `due_date` | DATE | The expected delivery date for the order. | `crm_sales_details.sls_due_dt` |
| `sales_amount` | INT | Total monetary value of the order line. | `crm_sales_details.sls_sales` |
| `quantity` | INT | Number of product units in the order line. | `crm_sales_details.sls_quantity` |
| `price` | INT | Unit price of the product at the time of the order. | `crm_sales_details.sls_price` |

---

## Data Lineage

The data warehouse follows a batch-processed Medallion Architecture. Data flows from external CSV files through a series of SQL stored procedures and dynamic views.

```mermaid
graph TD
    %% Source Layer
    subgraph Sources [External Source Systems]
        CRM_Files[CRM CSVs]
        ERP_Files[ERP CSVs]
    end

    %% Bronze Layer
    subgraph Bronze [Bronze Layer: Raw Data]
        B_CRM[bronze.crm_*]
        B_ERP[bronze.erp_*]
    end

    %% Silver Layer
    subgraph Silver [Silver Layer: Cleansed & Conformed]
        S_CRM[silver.crm_*]
        S_ERP[silver.erp_*]
    end

    %% Gold Layer
    subgraph Gold [Gold Layer: Star Schema Views]
        G_DimCust[gold.dim_customers]
        G_DimProd[gold.dim_products <br/> active only]
        G_Fact[gold.fact_sales]
    end

    %% Data Flow
    CRM_Files -->|BULK INSERT <br/> exec bronze.load_bronze| B_CRM
    ERP_Files -->|BULK INSERT <br/> exec bronze.load_bronze| B_ERP

    B_CRM -->|Standardize & Dedupe <br/> exec silver.load_silver| S_CRM
    B_ERP -->|Standardize & Dedupe <br/> exec silver.load_silver| S_ERP

    S_CRM -.->|Dynamic View Join| G_DimCust
    S_ERP -.->|Dynamic View Join| G_DimCust
    
    S_CRM -.->|Dynamic View Join| G_DimProd
    S_ERP -.->|Dynamic View Join| G_DimProd
    
    S_CRM -.->|Dynamic View Join| G_Fact
    G_DimProd -.->|Surrogate Key Match| G_Fact
    G_DimCust -.->|Surrogate Key Match| G_Fact

```

---

## Star Schema Entity-Relationship Diagram (ERD)

**Fact Table Grain:** One row per individual sales order line item.

```mermaid
erDiagram
    %% Dimension: Customers
    gold_dim_customers {
        INT customer_key PK "Surrogate Key"
        INT customer_id "Natural Key"
        NVARCHAR customer_number "Business Key"
        NVARCHAR first_name 
        NVARCHAR last_name 
        NVARCHAR country 
        NVARCHAR marital_status 
        NVARCHAR gender 
        DATE birthdate 
        DATE create_date 
    }

    %% Dimension: Products
    gold_dim_products {
        INT product_key PK "Surrogate Key (SCD2 Active)"
        INT product_id "Natural Key"
        NVARCHAR product_number "Business Key"
        NVARCHAR product_name 
        NVARCHAR category_id 
        NVARCHAR category 
        NVARCHAR subcategory 
        NVARCHAR maintenance 
        INT cost 
        NVARCHAR product_line 
        DATE start_date 
    }

    %% Fact: Sales
    gold_fact_sales {
        NVARCHAR order_number "Degenerate Dimension"
        INT product_key FK 
        INT customer_key FK 
        DATE order_date 
        DATE shipping_date 
        DATE due_date 
        INT sales_amount 
        INT quantity 
        INT price 
    }

    %% Relationships
    gold_dim_customers ||--o{ gold_fact_sales : "places"
    gold_dim_products ||--o{ gold_fact_sales : "contains"

```

```

```
