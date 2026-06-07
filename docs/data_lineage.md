---
# Introduction to Data Lineage

> **Data lineage** is the comprehensive map of your data’s journey. It tracks the complete lifecycle of data: its origin, every transformation it undergoes, and its final destination.
---

## Why is Data Lineage Critical?

As data ecosystems grow from a few tables to thousands of interdependent models, tracking dependencies manually becomes impossible. Implementing clear data lineage serves four primary functions:

* **Root Cause Analysis (Debugging):** When a metric drops or a dashboard breaks, lineage prevents blind guessing. Engineers can trace a broken Gold-layer metric upstream through the Silver layer to find the exact source ingestion that failed.
* **Impact Analysis (Preventing Disasters):** Before altering or dropping a source column (e.g., changing `cust_id` to `customer_identifier`), lineage allows teams to look downstream. This reveals exactly which models and dashboards will be affected, enabling proactive updates before systems crash.
* **Trust and Data Quality:** Stakeholders rarely trust a number they don't understand. Lineage provides transparency, proving exactly which source systems, filters, and business logic fed into a final dashboard metric.
* **Regulatory Compliance and Auditing:** Under data privacy laws (like GDPR or HIPAA), organizations must track Personally Identifiable Information (PII). Lineage allows compliance teams to find exactly where a user's data has propagated throughout the warehouse so it can be properly audited or deleted.

---

```mermaid
graph LR
    %% Subgraphs for Layers
    subgraph Sources
        CRM[CRM]
        ERP[ERP]
    end

    subgraph Bronze Layer
        B_crm_sales[crm_sales_details]
        B_crm_cust[crm_cust_info]
        B_crm_prd[crm_prd_info]
        B_erp_cust[erp_cust_az12]
        B_erp_loc[erp_loc_a101]
        B_erp_cat[erp_px_cat_g1v2]
    end

    subgraph Silver Layer
        S_crm_sales[crm_sales_details]
        S_crm_cust[crm_cust_info]
        S_crm_prd[crm_prd_info]
        S_erp_cust[erp_cust_az12]
        S_erp_loc[erp_loc_a101]
        S_erp_cat[erp_px_cat_g1v2]
    end

    subgraph Gold Layer
        G_fact_sales[fact_sales]
        G_dim_cust[dim_customers]
        G_dim_prd[dim_products]
    end

    %% Routing: Sources to Bronze Layer
    CRM --> B_crm_sales
    CRM --> B_crm_cust
    CRM --> B_crm_prd
    
    ERP --> B_erp_cust
    ERP --> B_erp_loc
    ERP --> B_erp_cat

    %% Routing: Bronze Layer to Silver Layer
    B_crm_sales --> S_crm_sales
    B_crm_cust --> S_crm_cust
    B_crm_prd --> S_crm_prd
    
    B_erp_cust --> S_erp_cust
    B_erp_loc --> S_erp_loc
    B_erp_cat --> S_erp_cat

    %% Routing: Silver Layer to Gold Layer
    S_crm_sales --> G_fact_sales
    
    S_crm_cust --> G_dim_cust
    S_erp_cust --> G_dim_cust
    S_erp_loc --> G_dim_cust
    
    S_crm_prd --> G_dim_prd
    S_erp_cat --> G_dim_prd

```
