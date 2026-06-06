# 🏭 Modern Data Warehouse & Analytics | SQL Server + Medallion Architecture

> An end-to-end **Data Engineering & Analytics** portfolio project — designing and implementing a production-style Data Warehouse on SQL Server using the Medallion Architecture (Bronze → Silver → Gold), from raw CSV ingestion through to analytical reporting.

Built by following the [Data With Baraa](http://bit.ly/3GiCVUE) tutorial series as part of my learning journey in data engineering — with hands-on implementation, documentation, and independent exploration at every step.

---

## 📌 Project At a Glance

| Attribute | Details |
|-----------|---------|
| **Architecture** | Medallion (Bronze → Silver → Gold) |
| **ETL Strategy** | Full Extract · Batch Processing · Full Load (Truncate & Reload) |
| **SCD Type** | Type 1 — Overwrite (no historization) |
| **Data Sources** | CRM system `.csv` · ERP system `.csv` |
| **Modeling** | Star Schema — Fact & Dimension tables |
| **Primary Stack** | SQL Server Express · SSMS · Git |

---

## 🎯 Problem Statement

Most organizations run multiple operational systems in parallel — CRM for customer relationships, ERP for supply and operations — each producing data in isolation. Without a centralized analytical layer, cross-system reporting is fragmented, unreliable, and slow.

This project addresses that by building a **Modern Data Warehouse** that:
- Consolidates raw data from CRM and ERP into a single SQL Server environment
- Applies structured transformation and quality checks layer by layer
- Delivers a clean, business-ready **Gold layer** optimized for EDA, analytics, and reporting

---

## 🏗️ Architecture Overview

This project follows the **Medallion Architecture** — a layered data design pattern widely adopted in modern data platforms (Azure Synapse, Databricks Lakehouse, dbt projects) and implemented here on SQL Server.

![Data Architecture](docs/data_architecture.png)

```
[CRM .csv] ──┐
              ├──► EXTRACT ──► [ BRONZE ] ──► [ SILVER ] ──► [ GOLD ] ──► Analytics / Reports
[ERP .csv] ──┘    (File         (Raw)          (Clean)       (Business
                   Parsing)     Tables         Tables         Views)
```

### Layer Breakdown

| Layer | Data State | Object Type | Load Strategy | Transformation Applied |
|-------|-----------|-------------|---------------|------------------------|
| 🥉 **Bronze** | Raw — ingested as-is from source | Tables | Full Load (Truncate & Insert) | None |
| 🥈 **Silver** | Cleaned, Normalized, Standardized | Tables | Full Load (Truncate & Insert) | Outlier detection, deduplication, filtering, missing value handling, validation, normalization |
| 🥇 **Gold** | Business-ready — analytics optimized | **Views** | None (computed from Silver) | Data integration, aggregation, business logic, Star Schema modeling |

> 💡 **Why Views in Gold?** SQL Views keep the Gold layer always in sync with Silver without redundant storage. They compute on-demand, enforce a clean contract for downstream consumers (BI tools, reports, ML), and make schema changes cheaper to propagate.

---

## ⚙️ ETL Pipeline Design

### The Three Phases

**Phase 1 — Extract**
Raw data is pulled from CRM and ERP source `.csv` files via **File Parsing**. This project uses a **Full Extract** strategy — the entire source dataset is re-ingested on each pipeline run. No change-data capture or incremental watermarking is applied, consistent with the SCD Type 1 overwrite approach.

**Phase 2 — Transform**
All transformation logic lives in the **Silver layer**. Data passes through:

| Transform Step | Purpose |
|----------------|---------|
| Outlier Detection | Flag or exclude statistically anomalous values |
| Deduplication | Remove duplicate records from source feeds |
| Data Filtering | Drop irrelevant or out-of-scope records |
| Missing Value Handling | Impute or null-coalesce incomplete fields |
| Data Validation | Enforce type checks, referential integrity, business rules |
| Normalization & Standardization | Consistent formats for dates, strings, categories |

**Phase 3 — Load**
Load strategy: **Batch Processing** with **Full Load (Truncate & Reload)**.
Each pipeline run truncates the target table before inserting fresh data — keeping the warehouse current without managing delta state.

### SCD Strategy

**SCD Type 1 — Overwrite**: The project scope covers the latest dataset snapshot only. No history is retained. When a record changes in the source, the warehouse record is simply overwritten. This is intentional — lightweight, appropriate for current-state reporting, and aligned with the project constraints.

---

## 📐 Data Modeling — Gold Layer

The Gold layer implements a **Star Schema** — the industry-standard model for analytical workloads, optimized for aggregation queries and BI tool compatibility.

```
           dim_customers
                │
dim_products ───┤
                ├──── fact_sales ──── report_sales_monthly
dim_date    ────┤
                │
           dim_[other]
```

### Object Types

| Category | Role | Examples |
|----------|------|---------|
| `dim_` | Dimension table — descriptive, slowly-changing attributes | `dim_customers`, `dim_product` |
| `fact_` | Fact table — measurable, transactional business events | `fact_sales` |
| `report_` | Pre-aggregated reporting object | `report_customers`, `report_sales_monthly` |

---

## 🏷️ Naming Conventions

All objects follow **snake_case** — lowercase letters with underscores. No camelCase, no reserved SQL words, English only.

### Tables

| Layer | Pattern | Example |
|-------|---------|---------|
| Bronze | `<sourcesystem>_<entity>` — exact source name, no renaming | `crm_customer_info`, `erp_customer_info` |
| Silver | `<sourcesystem>_<entity>` — exact source name, no renaming | `crm_customer_info`, `erp_customer_info` |
| Gold | `<category>_<entity>` — business-aligned, category-prefixed | `dim_customers`, `fact_sales`, `report_sales_monthly` |

### Columns

| Type | Pattern | Example | Notes |
|------|---------|---------|-------|
| Surrogate Key | `<tablename>_key` | `customer_key` | Warehouse-generated PK on all dim tables; independent of source natural keys |
| Technical / Metadata | `dwh_<column_name>` | `dwh_load_date` | System-generated audit columns; never sourced from upstream systems |

### Stored Procedures

```
load_<layer>
```
| Procedure | Responsibility |
|-----------|---------------|
| `load_bronze` | Truncate & bulk-load raw CSV data into Bronze tables |
| `load_silver` | Clean, transform, and reload Silver tables from Bronze |

Each stored procedure is scoped to exactly **one layer** — enforcing the Separation of Concerns principle. No procedure writes to more than one layer.

---

## 🗃️ Data Sources

| Source | Format | System | Content |
|--------|--------|--------|---------|
| CRM | `.csv` | Customer Relationship Management | Customer profiles, sales interactions |
| ERP | `.csv` | Enterprise Resource Planning | Orders, products, operational data |

---

## 🔧 Tech Stack

| Tool | Purpose | Link |
|------|---------|------|
| **SQL Server Express** | Host the SQL database (free tier) | [Download](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) |
| **SSMS** | GUI for querying, managing, and debugging the database | [Download](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms) |
| **Git + GitHub** | Version control and project repository | [github.com](https://github.com/) |
| **Draw.io** | Architecture, ETL flow, and data model diagrams | [drawio.com](https://www.drawio.com/) |
| **Notion** | Project documentation and task tracking | — |

---

## 📁 Repository Structure

```
data-warehouse-project/
│
├── datasets/                    # Raw source CSV files (CRM & ERP)
│
├── docs/                        # Project documentation & diagrams
│   ├── data_architecture.drawio
│   ├── data_flow.drawio
│   ├── data_models.drawio
│   ├── etl.drawio
│   ├── data_catalog.md
│   └── naming_conventions.md
│
├── scripts/                     # SQL scripts organized by layer
│   ├── bronze/                  # Ingestion — raw load from CSV
│   ├── silver/                  # Transformation — clean & standardize
│   └── gold/                    # Modeling — Star Schema views & reports
│
├── tests/                       # Data quality validation queries
├── README.md
├── LICENSE
└── .gitignore
```

---

## 📊 Analytics & Reporting

Once the Gold layer is built, the following analytical workflows run against it:

| Track | Questions Answered |
|-------|--------------------|
| **Customer Behavior** | Purchase patterns, frequency, RFM segmentation |
| **Product Performance** | Top/bottom performing products, category trends |
| **Sales Trends** | Revenue over time, seasonal patterns, growth rates |

Gold layer outputs are designed to plug directly into:
- **Excel** — ad-hoc business reporting and pivot analysis
- **BI Tools (e.g., Power BI)** — interactive dashboards
- **SQL-based EDA** — exploratory analysis directly in SSMS

See [`docs/data_catalog.md`](docs/data_catalog.md) for field-level definitions.

---

### Prerequisites

- [SQL Server Express](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) (free)
- [SSMS](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms) (free)
- Git

---

## 📋 Scope & Constraints

| In Scope | Out of Scope |
|----------|-------------|
| ✅ Latest dataset snapshot only | ❌ Historical tracking / SCD Type 2 |
| ✅ Full Extract + Full Load per run | ❌ Incremental / CDC pipelines |
| ✅ CRM + ERP CSV sources | ❌ Real-time / streaming ingestion |
| ✅ Data quality checks before analytics | ❌ Cloud deployment |
| ✅ Star Schema Gold modeling | ❌ OLTP / transactional workloads |

---

## 📚 Concepts Demonstrated

| Concept | Implementation |
|---------|---------------|
| Medallion Architecture | Three-schema design: Bronze → Silver → Gold |
| ETL Pipeline Design | Modular stored procedures per layer |
| Dimensional Modeling | Star Schema with fact, dim, and report objects |
| SCD Type 1 | Full truncate-and-reload with overwrite semantics |
| Data Quality Engineering | Outlier detection, dedup, validation in Silver |
| Naming Conventions | Consistent snake_case across all objects |
| Separation of Concerns | One stored procedure per layer, no cross-layer writes |

---

## 🙏 Credit

This project is built by following the free tutorial series by **Baraa Khatib Salkini**:

[![YouTube](https://img.shields.io/badge/YouTube-Data_With_Baraa-red?style=for-the-badge&logo=youtube&logoColor=white)](http://bit.ly/3GiCVUE)

All credit for the curriculum and project design goes to [Data With Baraa](https://www.datawithbaraa.com). This repo reflects my personal implementation, notes, and documentation built alongside the series.

---

## 🛡️ License

[MIT License](LICENSE)

---

*Learning data engineering — one layer at a time. 🥉🥈🥇*
