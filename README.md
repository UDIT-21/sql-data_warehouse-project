# 🏭 Modern Data Warehouse: SQL Server + Medallion Architecture

> An end-to-end **Data Engineering** portfolio project implementing a production-grade Data Warehouse using the **Medallion Architecture** (Bronze → Silver → Gold). Built entirely on SQL Server, transforming raw CSV files into a business-ready Star Schema.

Built alongside the Data With Baraa series, featuring hands-on implementation, custom data catalogs, and interactive documentation.

---

## 📌 Project Snapshot

| Feature           | Specification                                       |
| ----------------- | --------------------------------------------------- |
| **Architecture**  | Medallion (Bronze, Silver, Gold)                    |
| **Data Modeling** | Star Schema (Fact & Dimension Views)                |
| **ETL Strategy**  | Full Extract · Batch Processing · Truncate & Reload |
| **SCD Strategy**  | Type 1 (Overwrite / No Historization)               |
| **Data Sources**  | CRM CSV Files & ERP CSV Files                       |
| **Core Stack**    | SQL Server Express, SSMS, Git                       |

---

## 🏗️ Architecture & Data Flow

Data progresses through three distinct layers, increasing in structure, quality, and business value.

```text
[Raw CSV Files]
        │
        ▼
 [🥉 BRONZE]
        │
        ▼
 [🥈 SILVER]
        │
        ▼
 [🥇 GOLD]
        │
        ▼
 [BI / Analytics]
```

### Layer Overview

| Layer      | Purpose                         | Object Type | Key Transformations                                               |
| ---------- | ------------------------------- | ----------- | ----------------------------------------------------------------- |
| **Bronze** | Raw data ingestion layer        | Tables      | No transformations; preserves source fidelity                     |
| **Silver** | Cleansed and standardized layer | Tables      | Deduplication, type casting, null handling, data standardization  |
| **Gold**   | Business-ready analytics layer  | Views       | Star Schema modeling, business calculations, reporting structures |

> **Architectural Note:** The Gold layer uses SQL Views rather than physical tables, ensuring real-time synchronization with the Silver layer while minimizing redundant storage.

---

## ⚙️ Technical Implementation

### Data Extraction

* Full batch ingestion using `BULK INSERT`
* Source files loaded from local CSV datasets
* Truncate-and-reload strategy for consistent refreshes

### Data Transformation

* Modular Stored Procedures:

  * `load_bronze`
  * `load_silver`
* Clear separation of extraction, cleansing, and transformation logic

### Data Modeling

* Star Schema design
* Dimension Views:

  * `dim_customers`
  * `dim_products`
* Fact Views:

  * `fact_sales`
* Surrogate keys generated for optimized analytical joins

### Data Governance

* Consistent `snake_case` naming convention
* Metadata tracking columns included throughout the warehouse
* Example: `dwh_create_date`

---

## 📁 Repository Structure

```text
data-warehouse-project/
│
├── datasets/
│   ├── crm/
│   └── erp/
│
├── docs/
│   ├── data_dictionary.md
│   ├── naming_conventions.md
│   └── erd/
│
├── scripts/
│   ├── bronze/
│   │   ├── ddl_bronze.sql
│   │   └── load_bronze.sql
│   │
│   ├── silver/
│   │   ├── ddl_silver.sql
│   │   └── load_silver.sql
│   │
│   └── gold/
│       └── create_gold_views.sql
│
├── README.md
└── LICENSE
```

---

## 🚀 Getting Started

### Prerequisites

* SQL Server Express
* SQL Server Management Studio (SSMS)
* Git

### Setup & Execution

1. Execute `Create_Database_Schemas.sql`
2. Run Bronze Layer scripts
3. Run Silver Layer scripts
4. Run Gold Layer scripts
5. Query Gold Views for analytics and reporting

---

## 📊 Data Warehouse Layers

### 🥉 Bronze Layer

* Raw source ingestion
* No transformations applied
* Maintains complete source fidelity

### 🥈 Silver Layer

* Data cleansing and validation
* Standardization and normalization
* Business-rule enforcement

### 🥇 Gold Layer

* Star Schema presentation layer
* Fact and Dimension Views
* Optimized for BI and reporting tools

---

## 🎯 Project Objectives

* Build a scalable SQL Server Data Warehouse
* Implement Medallion Architecture principles
* Apply ETL best practices
* Design analytical Star Schemas
* Create a business-ready reporting layer
* Demonstrate real-world Data Engineering workflows

---

## 🙏 Acknowledgments

* **Curriculum:** Inspired by and developed alongside the Data With Baraa Data Engineering Series.
* **Community:** Thanks to the Data Engineering learning community for insights and best practices.

---

## 📄 License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.
