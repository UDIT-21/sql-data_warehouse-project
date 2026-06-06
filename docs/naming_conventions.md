# 📖 Naming Conventions

This document defines the naming standards used across the Data Warehouse to ensure consistency, readability, maintainability, and traceability.

These conventions apply to:

* Schemas
* Tables
* Views
* Columns
* Stored Procedures
* ETL Metadata Objects

---

# Table of Contents

* [General Principles](#general-principles)
* [Schema Conventions](#schema-conventions)
* [Table & View Naming Conventions](#table--view-naming-conventions)

  * [Bronze Layer](#bronze-layer)
  * [Silver Layer](#silver-layer)
  * [Gold Layer](#gold-layer)
* [Column Naming Conventions](#column-naming-conventions)

  * [Surrogate Keys](#surrogate-keys)
  * [Natural Keys](#natural-keys)
  * [Technical Columns](#technical-columns)
* [Stored Procedure Conventions](#stored-procedure-conventions)
* [Examples](#examples)

---

# General Principles

The following standards apply across the entire Data Warehouse.

### Naming Style

* Use **snake_case**
* Use lowercase letters only
* Separate words using underscores (`_`)
* Avoid spaces and special characters

### Language

* Use English for all database objects.
* Use business-friendly and descriptive names.

### Reserved Keywords

Avoid SQL reserved keywords such as:

```text
SELECT
TABLE
GROUP
ORDER
DATE
USER
```

If a business term conflicts with a reserved keyword, use an alternative descriptive name.

### Consistency

Similar objects should follow identical naming patterns throughout all layers.

### Schema Organization

Every object must belong to its corresponding schema:

| Layer  | Schema   |
| ------ | -------- |
| Bronze | `bronze` |
| Silver | `silver` |
| Gold   | `gold`   |

---

# Schema Conventions

The Data Warehouse follows the Medallion Architecture.

| Schema   | Purpose                           |
| -------- | --------------------------------- |
| `bronze` | Raw ingestion layer               |
| `silver` | Cleansed and standardized layer   |
| `gold`   | Business-ready presentation layer |

---

# Table & View Naming Conventions

## Bronze Layer

Bronze tables preserve source-system naming to maintain complete lineage and traceability.

### Pattern

```text
<source_system>_<entity>
```

### Components

| Component       | Description                         |
| --------------- | ----------------------------------- |
| `source_system` | Originating system (CRM, ERP, etc.) |
| `entity`        | Original table or file name         |

### Examples

| Object Name     | Description                   |
| --------------- | ----------------------------- |
| `crm_cust_info` | Customer information from CRM |
| `crm_prd_info`  | Product information from CRM  |
| `erp_loc_a101`  | Location data from ERP        |
| `erp_cust_az12` | Customer attributes from ERP  |

### Rules

* Preserve source naming whenever possible.
* Do not rename business entities.
* Do not introduce transformations into object names.

---

## Silver Layer

Silver tables retain source lineage while storing cleansed and standardized data.

### Pattern

```text
<source_system>_<entity>
```

### Examples

| Object Name         | Description                         |
| ------------------- | ----------------------------------- |
| `crm_cust_info`     | Cleansed CRM customer data          |
| `crm_sales_details` | Standardized sales transactions     |
| `erp_px_cat_g1v2`   | Standardized ERP category hierarchy |

### Rules

* Maintain naming consistency with Bronze.
* Preserve lineage between layers.
* Avoid introducing business-oriented naming at this stage.

---

## Gold Layer

Gold objects use business-friendly names aligned with analytical and reporting requirements.

### Pattern

```text
<category>_<entity>
```

### Components

| Component  | Description                        |
| ---------- | ---------------------------------- |
| `category` | Object role within the Star Schema |
| `entity`   | Business entity name               |

### Examples

| Object Name            | Description             |
| ---------------------- | ----------------------- |
| `dim_customers`        | Customer dimension      |
| `dim_products`         | Product dimension       |
| `fact_sales`           | Sales fact table        |
| `report_sales_monthly` | Reporting table or view |

### Rules

* Use descriptive business terminology.
* Avoid source-system abbreviations.
* Prefer pluralized entity names.
* Align names with reporting and analytics use cases.

---

## Gold Layer Prefix Glossary

| Prefix    | Meaning                 | Example                |
| --------- | ----------------------- | ---------------------- |
| `dim_`    | Dimension table or view | `dim_customers`        |
| `fact_`   | Fact table or view      | `fact_sales`           |
| `report_` | Reporting object        | `report_sales_monthly` |

---

# Column Naming Conventions

## Surrogate Keys

Surrogate keys are system-generated identifiers used within the Data Warehouse.

### Pattern

```text
<entity>_key
```

### Examples

| Column Name    |
| -------------- |
| `customer_key` |
| `product_key`  |
| `date_key`     |
| `store_key`    |

### Rules

* Must be unique.
* Must be integer-based whenever possible.
* Used for dimensional relationships.

---

## Natural Keys

Natural keys originate from source systems.

### Pattern

```text
<entity>_id
```

### Examples

| Column Name   |
| ------------- |
| `customer_id` |
| `product_id`  |
| `order_id`    |

### Rules

* Preserve source-system identifiers.
* Never use natural keys as dimension primary keys.

---

## Technical Columns

Technical metadata columns generated by ETL processes must use the `dwh_` prefix.

### Pattern

```text
dwh_<column_name>
```

### Examples

| Column Name         | Description               |
| ------------------- | ------------------------- |
| `dwh_create_date`   | Record creation timestamp |
| `dwh_update_date`   | Record update timestamp   |
| `dwh_load_date`     | ETL load timestamp        |
| `dwh_source_system` | Source system identifier  |

### Rules

* Reserved exclusively for warehouse metadata.
* Must not contain business attributes.
* Should support auditing and lineage requirements.

---

# Stored Procedure Conventions

Stored procedures should clearly indicate their purpose and target layer.

### Pattern

```text
load_<layer>
```

### Examples

| Procedure Name | Purpose                             |
| -------------- | ----------------------------------- |
| `load_bronze`  | Load raw source data                |
| `load_silver`  | Cleanse and standardize data        |
| `load_gold`    | Optional Gold layer materialization |

---

## Extended Patterns

For larger projects, additional patterns may be used:

| Pattern             | Purpose                 |
| ------------------- | ----------------------- |
| `load_<layer>`      | Data loading            |
| `validate_<entity>` | Data quality validation |
| `audit_<entity>`    | Audit processing        |
| `rebuild_<entity>`  | Object recreation       |
| `refresh_<entity>`  | Data refresh            |

### Examples

```text
validate_customers
audit_sales
refresh_dim_products
```

---
# Summary

The naming standards defined in this document ensure:

* Consistent object naming
* Improved readability
* Easier maintenance
* Better data lineage tracking
* Stronger governance and auditability
* Alignment with Data Warehouse and Medallion Architecture best practices

Adhering to these conventions helps maintain a scalable, understandable, and enterprise-ready Data Warehouse environment.
