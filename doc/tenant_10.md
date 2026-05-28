# Tenant Wholesale (ID: 10)

Welcome to the documentation for **Tenant Wholesale (Workspace ID: 10)**. This workspace is configured to manage large-scale wholesale operations, sourcing catalogs, costing files, and order workflows.

---

## 🔄 Data Update & Scraper Workflows

To update wholesale product catalog data, execute the scripts in the following sequence.

### PriceCheck (PC) Workflow
Follow this exact command flow to update PriceCheck data:

```mermaid
graph LR
    A[python:scrape:pc] -->|Scrapes Web| B[python:sync:scraped-pc]
    B -->|Syncs to DB| C[python:pc]
    C -->|Processes Excel & Syncs| D[Completed]
```

1. **Scrape Web Data**:
   ```bash
   npm run python:scrape:pc
   ```
   *Description:* Scrapes the latest raw product details from PriceCheck website.
   
2. **Sync Scraped Data**:
   ```bash
   npm run python:sync:scraped-pc
   ```
   *Description:* Syncs the scraped website product data directly into Supabase.

3. **Update Excel Data & Sync**:
   ```bash
   npm run python:pc
   ```
   *Description:* Processes product updates from the local Excel file located in the project's data folder (e.g. `web/public/uk/pc_data.json`) and runs final cleaning, VAT stripping, and database sync.

---

### WTS Workflow
To update WTS scrape and sync catalogs:
```bash
npm run python:sync:wts
```
*Description:* Runs the scraping and catalog sync routine specifically configured for WTS vendor.

---

## 📦 Active Modules in Tenant 10

The following core modules are enabled and configured for this workspace:

| Module Key | Module Name | Description & Active Features |
| :--- | :--- | :--- |
| **`vendor`** | Vendor Directory | Manages vendor records, supplier codes, and directory contact collaborations. |
| **`products`** | Product Catalog | Handles catalog records, brands, packaging sizes, and category lookup indexes. |
| **`product_based_costing`**| Product Costing | Provides margin overrides, price calculations, and quotation files. |
| **`accounting`** | General Ledger | Records journal transactions, balances, and invoice ledger entries. |
| **`store`** | Wholesale Store | Admin dashboard for setting wholesale storefront visibility rules. |
| **`cart`** | Shopping Cart | Enables wholesalers to select, checkout, and hold product items. |
| **`order_management`** | Orders & Approvals | Directs purchase approval cycles, status tracking, and orders intake. |
| **`shipment`** | Shipping Logistics | Coordinates cargo tracking, freight dispatching, and carrier information. |
| **`inventory`** | Stock Inventory | Monitors warehouse storage levels, stock adjustments, and incoming packages. |
| **`invoice`** | Commercial Invoicing | Generates commercial invoices and handles billing profiles. |
| **`investor`** | Investor Accounts | Manages funding portfolios, investments, and wholesale profit margins. |
