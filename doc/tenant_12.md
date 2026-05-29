# Tenant Koba Retail (ID: 12)

Welcome to the documentation for **Tenant Koba Retail (Workspace ID: 12)**. This workspace is configured to manage large-scale retail operations, specifically handling Korean Beauty (K-Beauty) sourcing, order workflows, and commission structures.

---

## 🔄 Data Update & Scraper Workflows

To update the retail product catalog data, execute the scrape and sync script.

### Koba Retail Scraper & Sync Workflow
To run the automated K-Beauty catalog scraper and sync the catalog directly to Supabase under Tenant 12:

```bash
npm run python:koba-retail
```

*Description of the flow:*
1. **Sanctum Authentication**: Fetches CSRF cookies and logs into the Kobareseller platform using credentials set in environment variables (`KOBA_EMAIL` & `KOBA_PASSWORD`).
2. **Inertia Scraping**: Iterates through the paginated products list on Kobareseller, extracting the Inertia.js JSON payloads.
3. **Backup Export**: Saves the raw, unmodified JSON product data locally to `web/public/uk/koba_retail_data.json`.
4. **Relational Synchronization**:
   - Resolves and seeds unique brands in the database (`koba_brands`).
   - Dynamically guesses categories based on product keywords and seeds them (`koba_categories`).
   - Maps products to the target schema, batches, and upserts them into `koba_products` under `tenant_id = 12`.

---

## 📦 Active Features & Pages in Tenant 12

### 1. Products Catalog (`KobaRetailProductsPage.vue`)
- **Product Grid**: Displays K-Beauty products with brand tags, stock status, descriptions, and packaging details.
- **Search & Filtering**: Search products by name/SKU and filter by category or availability.
- **Dynamic Pricing**: Shows base unit prices and calculated commission values.

### 2. Shopping Cart (`KobaCartPage.vue`)
- **Quantity Adjustments**: Increments and decrements item quantities in case-size steps.
- **Custom Price Overrides**: Allows staff to adjust the selling price above the base price to generate additional profit.
- **Real-Time Order Summary**:
  - **Subtotal & Delivery Charge**: Delivery charges are mapped from select districts.
  - **COD Charges**: Automatic Cash-on-Delivery charge calculation based on percentages set in the settings.
  - **Packing & Invoice Fees**: Standard flat fees automatically deducted from the final commission.
  - **Net Order Commission**: Real-time commission breakdown reflecting the formula:
    $$\text{Net Commission} = (\text{Product Commission} + \text{Extra Profit Share}) - \text{COD} - \text{Packing} - \text{Invoice}$$

### 3. Orders List (`KobaOrdersPage.vue`)
- **Overview Dashboard**: Lists all customer orders placed in the retail network.
- **Filters**: Quickly filter orders by statuses (Pending, Confirmed, Processing, Shipped, Delivered, Cancelled).

### 4. Order Details (`KobaOrderDetailPage.vue`)
- **Status Workflows**: Multi-stage order status progression.
- **Admin Quantity Control**: Admins can modify "Confirmed Quantity" (in Pending state) and "Delivered Quantity" (once confirmed) to match real-time inventory adjustments.
- **Soft Delete**: Admins can soft-delete erroneous orders safely.

### 5. Customers List (`KobaRetailCustomersPage.vue`)
- **High-Level Statistics**: Displays a list of all active retail customers, total orders placed, aggregate spending, and last active dates.
- **Search**: Search customer directories by name or phone numbers.

### 6. Customer Profile (`KobaRetailCustomerProfilePage.vue`)
- **Top Brands & Products**: A structured breakdown of the customer's buying habits.
- **Chronological Order Timeline**: Interactive history timeline linking to specific orders.

### 7. Retail Settings (`KobaRetailSettingsPage.vue`)
- **Charge Overrides**: Set custom COD %, packing, invoice, and gateway flat charges.
- **Profit Splits**: Manage the percentage splits between users and the company for extra markup profits.
- **Delivery Rates Matrix**: Custom delivery rates mapping specific districts to delivery fees, including a default fallback fee.
