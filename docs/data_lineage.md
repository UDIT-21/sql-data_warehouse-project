Here is the data flow and data lineage represented in Markdown.

### 1. Hierarchical Text Representation

**Sources**

* **CRM**
* ➔ `crm_sales_details` (Bronze)
* ➔ `crm_cust_info` (Bronze)
* ➔ `crm_prd_info` (Bronze)


* **ERP**
* ➔ `erp_cust_az12` (Bronze)
* ➔ `erp_loc_a101` (Bronze)
* ➔ `erp_px_cat_g1v2` (Bronze)



---

**Medallion Architecture Lineage**

* **Fact: Sales** (`fact_sales` - Gold)
* *Sourced from:* `crm_sales_details` (Silver) ➔ `crm_sales_details` (Bronze) ➔ CRM


* **Dimension: Customers** (`dim_customers` - Gold)
* *Sourced from:* `crm_cust_info` (Silver) ➔ `crm_cust_info` (Bronze) ➔ CRM
* *Sourced from:* `erp_cust_az12` (Silver) ➔ `erp_cust_az12` (Bronze) ➔ ERP
* *Sourced from:* `erp_loc_a101` (Silver) ➔ `erp_loc_a101` (Bronze) ➔ ERP


* **Dimension: Products** (`dim_products` - Gold)
* *Sourced from:* `crm_prd_info` (Silver) ➔ `crm_prd_info` (Bronze) ➔ CRM
* *Sourced from:* `erp_px_cat_g1v2` (Silver) ➔ `erp_px_cat_g1v2` (Bronze) ➔ ERP



---

### 2. Mermaid.js Flowchart

You can paste this code block into any Markdown viewer that supports Mermaid (like GitHub, Notion, or Obsidian) to automatically generate the visual diagram.

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
