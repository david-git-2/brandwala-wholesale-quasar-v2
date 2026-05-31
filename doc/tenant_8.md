# Tenant 8

Welcome to the workspace documentation for **Tenant 8**. This workspace is configured around the **Costing File** module — a structured pricing and sourcing pipeline that enables customer groups to submit product sourcing requests and allows internal team members to enrich, cost, and publish offer prices.

---

## 📦 Active Feature: Costing File

The **Costing File** (`costing_file`) is the primary feature of this tenant. It connects customer-side sourcing requests with internal pricing workflows, producing BDT offer prices that customers can use as wholesale or resale planning inputs.

> For the full technical breakdown of the module — including the pricing formula chain, data model, and all screens — refer to the **[Costing File Module Guide](module_costing_file)** in the documentation sidebar.

---

## 🔄 How the Costing File Workflow Works

The workflow in this tenant follows a structured pipeline with clear hand-offs between roles:

```
Admin creates file
      ↓
Customer submits item requests (URLs + quantity)
      ↓
Staff enriches product details (name, image, weight, price)
      ↓
Admin sets pricing rules (cargo rates, conversion rate, profit rate)
      ↓
System calculates offer prices → Admin reviews & finalizes
      ↓
Customer views offer prices & sets their resale profit rate
      ↓
File completed
```

---

## 👥 Who Does What

### Admin

- Creates new costing files and assigns them to a customer group
- Sets file-level pricing parameters:
  - **Cargo Rate 1 KG** — for items priced at £10 or below
  - **Cargo Rate 2 KG** — for items priced above £10
  - **Conversion Rate** — GBP to BDT multiplier
  - **Admin Profit Rate** — % margin applied on top of the BDT costing price
- Reviews item-level calculated prices in the Review tab
- Can manually override the offer price BDT for any item
- Moves the file through workflow states (draft → offered → completed)
- Can accept or reject individual items
- Manages which tenant members have Viewer access to a specific file

### Staff

- Views costing files and their items
- Enriches item details by filling in:
  - Product name
  - Item type (Watch, Perfume, Others)
  - Image URL
  - Product weight (grams)
  - Package weight (grams)
  - Web price (GBP)
  - Delivery charge (GBP)
- Cannot change pricing rules or file status

### Viewer

- Read-only access to specific costing files granted by an admin
- Can see file details and all item data

### Customer (Shop Side)

- Submits item requests with product URL and quantity
- Views offer prices once the file reaches `offered` state
- Sets a **Customer Profit Rate** (%) per item or bulk-applies it to all items
- This profit rate calculates their **Buyer Selling Price** — a resale planning estimate

---

## 📐 Pricing Formula Quick Reference

The pricing engine runs in this order for every item:

| Step | Formula | Notes |
| :--- | :--- | :--- |
| 1. Total Weight | `product_weight + package_weight` | In grams, not stored |
| 2. Auxiliary Price GBP | Tiered surcharge on base price | Watch/Perfume add £3.00 |
| 3. Item Price GBP | `web_price + delivery + auxiliary` | Purchase cost GBP |
| 4. Cargo Rate | `1kg rate if item ≤ £10, else 2kg rate` | Can be manually overridden |
| 5. Costing Price GBP | `item_price + (weight_kg × cargo_rate)` | Full landed cost |
| 6. Costing Price BDT | `costing_gbp × conversion_rate` | Rounded up to 0 or 5 |
| 7. Offer Price BDT | `costing_bdt + (costing_bdt × profit_rate%)` | Rounded up to 0 or 5 |
| 8. Buyer Sell Price | `offer_bdt + (offer_bdt × customer_profit%)` | Customer resale estimate |

> **BDT Rounding Rule**: All BDT values are always rounded **up** to the nearest integer ending in 0 or 5.  
> Example: 41 → 45 | 46 → 50 | 100 → 100

---

## 🖥️ Key Pages & Navigation

### App Side (Internal Users)

| Page | Path | Who |
| :--- | :--- | :--- |
| Costing File List | `/app/costing/admin` | Admin |
| File Details & Pricing | `/app/costing/admin/:id` | Admin |
| Viewer Management | `/app/costing/admin/:id/viewers` | Admin |
| Print Preview | `/app/costing/admin/:id/preview` | Admin |
| Staff File List | `/app/costing/staff` | Staff |
| Staff File Details | `/app/costing/staff/:id` | Staff |
| Viewer File List | `/app/costing/viewer` | Viewer |
| Viewer File Details | `/app/costing/viewer/:id` | Viewer |

Navigating to `/app/costing` will automatically redirect to the correct list based on your role.

### Shop Side (Customer Users)

| Page | Path | Who |
| :--- | :--- | :--- |
| My Costing Files | `/shop/costing` | Customer |
| File Details & Items | `/shop/costing/:id` | Customer |
| Print Preview | `/shop/costing/:id/preview` | Customer |

---

## ⚙️ Item Statuses

Each item in a costing file tracks its own status independently of the file status:

| Status | Meaning |
| :--- | :--- |
| `pending` | Submitted, awaiting enrichment and review |
| `accepted` | Admin has confirmed this item in the offer |
| `rejected` | Admin has excluded this item from the offer |

---

## 📋 Operational Notes

- **Market field** must be entered in uppercase (e.g. `UK`, `EU`, `US`).
- **Item URLs and quantities** submitted by customers cannot be edited after submission. If a correction is needed, the admin must delete the item and re-add it manually.
- **Cargo rate per item** — admin can manually set a cargo rate on a specific item. Once set manually, the file-level formula is no longer used for that item.
- **Offer price override** — if admin sets a manual offer price for an item, the manual value is saved as `offer_price_bdt` and the original input is preserved in `offer_price_override_bdt` for audit purposes.
- **Viewer access** is granted per file. Granting someone viewer access to one file does not give them access to other files.
- **Customer Profit Rate** can be set individually per item, or bulk-applied to all items at once using the bulk-update control on the customer details page.
