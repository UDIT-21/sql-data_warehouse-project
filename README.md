# 🏭 Modern Data Warehouse: SQL Server + Medallion Architecture

> An end-to-end **Data Engineering** portfolio project implementing a production-grade Data Warehouse using the **Medallion Architecture** (Bronze ➔ Silver ➔ Gold). Built entirely on SQL Server, transforming raw CSVs into a business-ready Star Schema.

Built alongside the [Data With Baraa](http://bit.ly/3GiCVUE) series, featuring hands-on implementation, custom data catalogs, and interactive documentation.

---

## 📌 Project Snapshot

| Feature | Specification |
| :--- | :--- |
| **Architecture** | Medallion (Bronze, Silver, Gold) |
| **Data Modeling** | Star Schema (Fact & Dimension views) |
| **ETL Strategy** | Full Extract · Batch Processing · Truncate & Reload |
| **SCD Strategy** | Type 1 (Overwrite / No historization) |
| **Sources** | CRM (`.csv`) & ERP (`.csv`) |
| **Core Stack** | SQL Server Express, SSMS, Git |

---

```markdown
## 🏗️ Architecture & Data Flow

Data progresses through three distinct layers, increasing in structure, quality, and business value.

```text
[Raw CSVs] ➔ [ 🥉 BRONZE ] ➔ [ 🥈 SILVER ] ➔ [ 🥇 GOLD ] ➔ [ BI / Analytics ]

```

| Layer | Purpose | Object Type | Transformations |
| --- | --- | --- | --- |
| **Bronze** | Raw ingestion target. | Tables | None. Full fidelity to source. |
| **Silver** | Cleansed & conformed data. | Tables | Deduplication, type-casting, null handling, standardization. |
| **Gold** | Business-ready analytics. | Views | Star Schema joins, aggregations, surrogate keys. |

> **Architectural Note:** The Gold layer utilizes **SQL Views** rather than physical tables to ensure it remains perfectly synchronized with the Silver layer while reducing redundant storage.

---

## ⚙️ Technical Implementation

* **Extraction:** Full batch load via `BULK INSERT` from local `.csv` files.
* **Transformation:** Modular Stored Procedures (`load_bronze`, `load_silver`) enforce strict Separation of Concerns.
* **Modeling:** Dimensions (`dim_customers`, `dim_products`) and Facts (`fact_sales`) joined via dynamically generated surrogate keys.
* **Governance:** Strict `snake_case` naming conventions applied across all schemas, tables, and metadata columns (e.g., `dwh_create_date`).

---

## 📁 Repository Structure

```text
data-warehouse-project/
├── datasets/        # Raw source CRM & ERP data (.csv)
├── docs/            # Data dictionaries, ERDs, and naming conventions
├── scripts/
│   ├── bronze/      # DDL & DML for raw ingestion
│   ├── silver/      # Data cleansing & standardization procedures
│   └── gold/        # Star schema view definitions

```

```

```

---

## 🚀 Getting Started

**Prerequisites:**

* [SQL Server Express](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) (Free)
* [SQL Server Management Studio (SSMS)](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms)
* Git

**Execution Order:**

1. Run `Create Database_Schemas.sql` to establish the environment.
2. Execute the **Bronze** DDL & Load procedures.
3. Execute the **Silver** DDL & Load procedures.
4. Execute the **Gold** DDL to generate reporting views.

---

## 🙏 Acknowledgments & License

* **Curriculum:** Inspired by and built following [Data With Baraa](http://bit.ly/3GiCVUE).
* **License:** [MIT License](https://www.google.com/search?q=LICENSE)

```

```
