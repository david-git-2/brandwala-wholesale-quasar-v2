# Costing File

The **Costing File** module is an internal pricing and sourcing tool that allows customer groups to submit product sourcing requests, and enables tenant staff and admins to enrich, cost, and publish offer prices for each requested item.

---

## Overview

A **Costing File** is a named collection of product items associated with a specific customer group. It moves through a defined workflow — from a draft state created by an admin, through customer request submission, internal enrichment, pricing setup, to a final offered state visible to the customer.

The key value of the module is a centralized, role-appropriate pricing pipeline: customers submit URLs, staff enrich product data, and admins produce final BDT offer prices using a reproducible calculation chain.

---

## User Roles & Permissions

| Role | What They Can Do |
| :--- | :--- |
| **Admin** | Full access — create/edit/delete files, set pricing rules, manage workflow state, override offer prices, manage viewers |
| **Staff** | View files, enrich product details (name, image, weights, web price, delivery charge) |
| **Viewer** | Read-only access to specific costing files granted by admin |
| **Customer Admin / Negotiator / Staff** | Submit item requests (URL + quantity), view offered prices, set buyer profit rate |

---

## Workflow States

### Costing File Status

A costing file moves through the following lifecycle stages:

```
draft → customer_submitted → in_review → priced → offered → completed
                                                          ↘ cancelled
```

| Status | Meaning |
| :--- | :--- |
| `draft` | Created by admin, not yet shared with customer |
| `customer_submitted` | Customer has submitted their item requests |
| `in_review` | Internal team is enriching and reviewing items |
| `priced` | Admin has set pricing parameters (cargo rates, conversion, profit) |
| `offered` | Final offer prices are visible to the customer |
| `completed` | File is closed and finalized |
| `cancelled` | File was cancelled at any stage |

### Costing File Item Status

Each item within a costing file has its own independent status:

| Status | Meaning |
| :--- | :--- |
| `pending` | Newly submitted by customer, awaiting enrichment |
| `accepted` | Admin has accepted the item into the offer |
| `rejected` | Admin has rejected the item from the offer |

---

## Module Screens

### Admin Screens

#### Costing File List (`/app/costing/admin`)
- Lists all costing files for the tenant, paginated
- Filter by customer group
- Create new costing files using the **Create** button
- View file name, market, status, and creation date

#### Costing File Details (`/app/costing/admin/:id`)
- **Product Tab** — View raw item list (customer-submitted URLs, names, images, quantities, weights, web price)
- **Review Tab** — Full pricing breakdown table with calculated values per item
- **Pricing Panel** — Set and save the four file-level pricing inputs:
  - `Cargo Rate 1 KG` (used when item price ≤ £10)
  - `Cargo Rate 2 KG` (used when item price > £10)
  - `Conversion Rate` (GBP → BDT multiplier)
  - `Admin Profit Rate` (percentage margin added to costing price BDT)
- **Status Actions** — Transition the file through workflow states
- **Edit Items** — Open the item edit dialog (enrichment + full admin fields)
- **Add Items** — Manually add new fully-enriched items

#### Costing File Viewers (`/app/costing/admin/:id/viewers`)
- Grant or revoke **Viewer** role access to specific tenant members for this file
- Viewer role can see the file in read-only mode

#### Costing File Preview (`/app/costing/admin/:id/preview`)
- Renders a clean, print-friendly version of the costing file for review or sharing

---

### Staff Screens

#### Costing File List (`/app/costing/staff`)
- View all costing files (read list only)

#### Costing File Details (`/app/costing/staff/:id`)
- View product and review tabs in read-only mode
- Edit enrichment fields only via the **Staff Edit Dialog**:
  - Name
  - Item Type
  - Image URL
  - Product Weight
  - Package Weight
  - Web Price (GBP)
  - Delivery Price (GBP)
- Cannot change pricing rules or workflow status

---

### Viewer Screens

#### Costing File List (`/app/costing/viewer`)
- Lists only the costing files the viewer has been explicitly granted access to

#### Costing File Details (`/app/costing/viewer/:id`)
- Read-only view of the file and items

---

### Customer Screens

#### Customer Costing File List (`/shop/costing`)
- Lists all costing files belonging to the customer's group
- Paginated, shows file name, market, status, date

#### Customer Costing File Details (`/shop/costing/:id`)
- **Product Tab** — Item grid showing offer prices, buyer selling prices, and profit estimates
- **Submit Item** — Customer submits new requests with:
  - Website URL (required)
  - Quantity (required)
  - Item Type (optional: Watch, Perfume, Others)
- **Profit Rate** — Customer can set a `Customer Profit Rate` (%) per item or bulk-apply across all items. This calculates the **Buyer Selling Price** used for their own resale estimate.
- Customer **cannot** edit website URL or quantity after submission

#### Customer Preview (`/shop/costing/:id/preview`)
- Print-friendly preview for the customer

---

## Pricing Calculation Chain

All item pricing is calculated client-side from the file-level pricing inputs and item-level data. The full chain is:

### 1. Total Weight

```
total_weight = product_weight + package_weight  (in grams)
```

> Not stored in the database — always derived.

---

### 2. Auxiliary Price GBP

```
base_price_gbp = price_in_web_gbp + delivery_price_gbp

if base_price_gbp ≤ 10:
  auxiliary_price_gbp = 0

if base_price_gbp > 10 and ≤ 100:
  auxiliary_price_gbp = 2.00

if base_price_gbp > 100:
  auxiliary_price_gbp = 2 + CEILING((base_price_gbp - 100) / 50)
```

Special surcharge applies to item types `Watch` and `Perfume`: **+£3.00** is added to the auxiliary price.

---

### 3. Item Price GBP (Purchase Price)

```
item_price_gbp = price_in_web_gbp + delivery_price_gbp + auxiliary_price_gbp
```

---

### 4. Cargo Rate Selection

```
if item_price_gbp > 10:
  cargo_rate = file.cargo_rate_2kg
else:
  cargo_rate = file.cargo_rate_1kg
```

> Admin can also manually override the `cargo_rate` per item.

---

### 5. Costing Price GBP

```
costing_price_gbp = item_price_gbp + (total_weight / 1000) * cargo_rate
```

---

### 6. Costing Price BDT

```
costing_price_bdt = costing_price_gbp × conversion_rate
```

> Rounded **up** to the nearest integer ending in `0` or `5`.  
> Example: 41 → 45, 46 → 50.

---

### 7. Offer Price BDT

```
offer_price_bdt = costing_price_bdt + (costing_price_bdt × admin_profit_rate / 100)
```

> Rounded up to the nearest integer ending in `0` or `5`.

If the admin sets an **Offer Price Override BDT**, that value replaces the calculated offer price for the stored `offer_price_bdt`.

---

### 8. Buyer Sell Price (Customer-Side Estimate)

```
buyer_sell_price = offer_price_bdt + (offer_price_bdt × customer_profit_rate / 100)
```

> Rounded up to the nearest integer ending in `0` or `5`.  
> This is a planning estimate only — not stored as a final transaction value.

---

## Data Model Summary

### `costing_files`

| Field | Type | Notes |
| :--- | :--- | :--- |
| `id` | bigint | Primary key |
| `name` | text | File label |
| `market` | text | Stored uppercase (e.g. `UK`, `EU`) |
| `status` | enum | See workflow states above |
| `cargo_rate_1kg` | numeric(12,2) | Rate for items ≤ £10 |
| `cargo_rate_2kg` | numeric(12,2) | Rate for items > £10 |
| `conversion_rate` | numeric(12,2) | GBP to BDT multiplier |
| `admin_profit_rate` | numeric(12,2) | Percentage profit on top of costing price BDT |
| `customer_group_id` | bigint | FK → customer_groups |
| `tenant_id` | bigint | FK → tenants |
| `created_by_email` | text | Actor email at time of creation |
| `created_at` | timestamptz | — |
| `updated_at` | timestamptz | Auto-updated by trigger |

### `costing_file_items`

| Field | Type | Notes |
| :--- | :--- | :--- |
| `id` | bigint | Primary key |
| `costing_file_id` | bigint | FK → costing_files |
| `name` | text | Product name (enriched) |
| `item_type` | text | e.g. `Watch`, `Perfume`, `Others` |
| `size` | text | e.g. `XL`, `250ml` |
| `color` | text | Product color |
| `extra_information_1` | text | HTML rich text note |
| `extra_information_2` | text | HTML rich text note |
| `image_url` | text | Product image URL |
| `website_url` | text | Customer-submitted product link |
| `quantity` | integer | Requested quantity |
| `product_weight` | integer | In grams |
| `package_weight` | integer | In grams |
| `price_in_web_gbp` | numeric(12,2) | Web listing price GBP |
| `delivery_price_gbp` | numeric(12,2) | UK delivery fee GBP |
| `auxiliary_price_gbp` | numeric(12,2) | Calculated handling surcharge |
| `item_price_gbp` | numeric(12,2) | Total purchase price GBP |
| `cargo_rate` | numeric(12,2) | Applied cargo rate (manual or derived) |
| `cargo_rate_is_manual` | boolean | Whether cargo rate was manually set |
| `costing_price_gbp` | numeric(12,2) | Full landed cost GBP |
| `costing_price_bdt` | integer | Costing price in BDT (rounded) |
| `offer_price_override_bdt` | integer | Admin manual override input |
| `offer_price_bdt` | integer | Final published offer price BDT |
| `customer_profit_rate` | numeric(12,2) | Customer's resale margin (%) |
| `status` | enum | `pending` / `accepted` / `rejected` |
| `created_by_email` | text | Actor email |
| `created_at` | timestamptz | — |
| `updated_at` | timestamptz | Auto-updated by trigger |

---

## Key Supabase Functions Used

| Function | Purpose |
| :--- | :--- |
| `list_costing_files_for_actor` | Paginated list with RLS-based filtering |
| `get_costing_file_by_id` | Single file fetch with pricing fields |
| `create_costing_file` | Creates a new file |
| `update_costing_file` | Updates name, market, customer group |
| `update_costing_file_status` | Transitions the file workflow status |
| `update_costing_file_pricing` | Saves cargo rates, conversion rate, admin profit |
| `create_costing_file_item_request` | Customer-side item submission |
| `update_costing_file_item_enrichment` | Staff/admin product data enrichment |
| `update_costing_file_item_offer` | Admin offer price override |
| `update_costing_file_item_customer_profit` | Per-item customer profit rate |
| `update_costing_file_items_customer_profit` | Bulk customer profit rate update |
| `update_costing_file_item_status` | Accept or reject individual items |
| `list_tenant_viewers` | Lists tenant members eligible for viewer grant |
| `list_costing_file_viewers` | Lists viewers granted to a specific file |
| `grant_costing_file_viewer` | Grants viewer access to a tenant member |
| `revoke_costing_file_viewer` | Removes viewer access |

---

## Route Summary

| Route | Name | Access |
| :--- | :--- | :--- |
| `/:slug/app/costing/admin` | `admin-costing-file-page` | Admin |
| `/:slug/app/costing/admin/:id` | `admin-costing-file-details-page` | Admin |
| `/:slug/app/costing/admin/:id/viewers` | `admin-costing-file-viewers-page` | Admin |
| `/:slug/app/costing/admin/:id/preview` | `admin-costing-file-preview-page` | Admin |
| `/:slug/app/costing/staff` | `staff-costing-file-page` | Staff |
| `/:slug/app/costing/staff/:id` | `staff-costing-file-details-page` | Staff |
| `/:slug/app/costing/viewer` | `viewer-costing-file-page` | Viewer |
| `/:slug/app/costing/viewer/:id` | `viewer-costing-file-details-page` | Viewer |
| `/:slug/shop/costing` | `customer-costing-file-page` | Customer |
| `/:slug/shop/costing/:id` | `customer-costing-file-details-page` | Customer |
| `/:slug/shop/costing/:id/preview` | `customer-costing-file-preview-page` | Customer |

The entry point `/:slug/app/costing` auto-redirects to the correct role-specific list based on the logged-in user's role.

---

## Notes for Operators

- **Market field** is always stored in uppercase. Enter `UK`, `EU`, `US`, etc.
- **BDT values** are always rounded up to the nearest 0 or 5. This is intentional and non-negotiable.
- **Cargo rate per item** can be overridden manually by admin — this persists the manual rate and ignores the file-level formula for that item.
- **Offer price override** — if admin sets a manual offer price, it replaces the calculated value in the database. The original override input is stored in `offer_price_override_bdt` for audit.
- **Viewer access** is per-file — a viewer granted access to one costing file does not automatically see others.
- Customer-submitted item URLs and quantities **cannot be edited** after submission. Admin can delete and re-add items if a correction is needed.
