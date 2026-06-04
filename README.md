# 🏭 Data Warehouse & Analytics Project

A portfolio project where I build an end-to-end data warehouse using SQL Server —
covering data ingestion, transformation, modeling, and SQL-based analytics.

Built by following the [Data With Baraa](http://bit.ly/3GiCVUE) YouTube tutorial series
as part of my learning journey in data engineering and analytics.

---

## 🏗️ Architecture Overview

This project follows the **Medallion Architecture** — a three-layer approach to organizing
data from raw to business-ready.

![Data Architecture](docs/data_architecture.png)

| Layer | What happens here |
|-------|-------------------|
| 🥉 **Bronze** | Raw CSV data loaded as-is into SQL Server — no changes |
| 🥈 **Silver** | Data is cleaned, standardized, and normalized |
| 🥇 **Gold** | Business-ready star schema (fact + dimension tables) for reporting |

---

## 📖 What This Project Covers

| Area | Description |
|------|-------------|
| Data Architecture | Medallion Architecture design (Bronze → Silver → Gold) |
| ETL Pipelines | Extract, Transform, Load from ERP and CRM CSV sources |
| Data Modeling | Star schema with fact and dimension tables |
| SQL Analytics | Customer behavior, product performance, and sales trend analysis |

---

## 🛠️ Tools Used

All free!

| Tool | Purpose | Link |
|------|---------|------|
| SQL Server Express | Host the SQL database | [Download](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) |
| SSMS | GUI to manage and query the database | [Download](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms) |
| DrawIO | Architecture and data flow diagrams | [drawio.com](https://www.drawio.com/) |
| Git + GitHub | Version control | [github.com](https://github.com/) |

---

## 📁 Repository Structure

```
data-warehouse-project/
│
├── datasets/          # Source CSV files (ERP and CRM raw data)
│
├── docs/              # Architecture diagrams and documentation
│   ├── data_architecture.drawio
│   ├── data_flow.drawio
│   ├── data_models.drawio
│   ├── etl.drawio
│   ├── data_catalog.md
│   └── naming-conventions.md
│
├── scripts/           # SQL scripts organized by layer
│   ├── bronze/        # Raw data ingestion
│   ├── silver/        # Cleaning and transformation
│   └── gold/          # Analytical models
│
├── tests/             # Data quality checks
├── README.md
├── LICENSE
└── .gitignore
```

---

## 📊 Analytics Goals

SQL queries built to answer:

- **Customer Behavior** — purchase patterns, frequency, segmentation
- **Product Performance** — top/bottom performing products
- **Sales Trends** — revenue over time, seasonal patterns

See [`docs/requirements.md`](docs/requirements.md) for detailed specs.

---

## 🙏 Credit

This project is built by following the free tutorial by **Baraa Khatib Salkini**:

[![YouTube](https://img.shields.io/badge/YouTube-Tutorial-red?style=for-the-badge&logo=youtube&logoColor=white)](http://bit.ly/3GiCVUE)

All credit for the curriculum and project design goes to [Data With Baraa](https://www.datawithbaraa.com).

---

## 🛡️ License

[MIT License](LICENSE)
