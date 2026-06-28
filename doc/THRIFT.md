# Thrift — Stock & Catalog

BrandWala / TradeFlow BD includes a **standalone Thrift vertical** for second-hand retail: inbound shipments, box tracking, stock registration with barcodes, and a shared category/type catalog. Thrift is **tenant-scoped** and **not integrated** with the global entity model in phase 1 (locked decision **D12** in [MASTER_PLAN.md](MASTER_PLAN.md)).

Related: [MASTER_PLAN.md](MASTER_PLAN.md), [APP_SCOPES_AND_ACCESS.md](APP_SCOPES_AND_ACCESS.md), [GLOBAL_REFERENCE_DATA.md](GLOBAL_REFERENCE_DATA.md), Thrift-app [AI_ARCHITECTURE.md](../../Thrift-app/AI_ARCHITECTURE.md).

---

This document answers:

- Who uses each Thrift module and why (user stories)?
- What is stored in each table, and what is each table for?
- How are permissions and RLS enforced?
- What is the API surface (RPCs, direct access, routes)?
- What are the end-to-end flow sequences (web + mobile)?
- How does the cost engine work, and what is planned vs implemented?
- What is the implementation phase order (migration, costing, measurements)?

---

## 1. Overview

| Property | Thrift vertical |
|----------|-----------------|
| Scope | Per-tenant; isolated from `global_stocks` / `global_invoices` |
| `tenant_id` | Owning tenant on every row |
| Auth surface | App (`memberships`) — `admin` / `staff` roles |
| Module gating | Individual `thrift_*` keys via `tenant_modules` (D13) |
| Primary UI | `/:slug/app/thrift/*` |
| Mobile client | **Thrift-app** (Capacitor/Android) |
| Status | Catalog/inventory **STABLE**; P1 migration + measurements **planned**; costing engine + shipment detail **planned** |

### Domain flow

```
settings + tenant prefs → shipment → box → stock (+ barcode at register)
                              ↓
                    shipment detail (pricing) → invoice (DB only)
```

### Costing design principles (target)

| # | Decision |
|---|----------|
| D-T1 | Stock stores **3 cost inputs only:** `origin_unit_price`, `extra_origin_unit_price`, `additional_charges_cost` |
| D-T2 | Shipment stores rates, cargo weight, labour/transport totals, markup |
| D-T3 | Settings store default origin + hand-tag / sticker unit costs |
| D-T4 | `U` = `SUM(quantity)` per shipment — divisor for **ops** allocation |
| D-T5 | Cargo allocated **by weight** `(product_weight + extra_weight) × quantity`; falls back to `shipment_cargo_cost / U` when no weights |
| D-T6 | Sell price = `landed_unit_cost × (1 + markup_rate_override ?? default_markup_rate)` unless `is_listed_price_manual` |
| D-T7 | Deprecate stored `cost_of_goods_sold`, `extra_expense_cost`, `target_price` |
| D-T8 | **Scope lock** — barcode, images, catalog, registration flows **unchanged**; only shipment + cost fields change |
| D-T9 | Garment fit — `size` + `brand_name` on `thrift_stocks`; actual measurements in `thrift_stock_measurements` (inches, all optional); **no** `thrift_brand_size_charts` |

---

## 2. User stories

### 2.1 Shipment — `thrift_shipment`

**As a** thrift admin,  
**I want to** create a shipment with purchase/cost currencies and conversion rates,  
**So that** all stock in that batch shares one financial context.

**As a** thrift admin,  
**I want to** record cargo weight, cargo rate, labour total, and transportation total on a shipment,  
**So that** freight and ops costs split across units automatically when rates change.

**As a** thrift admin,  
**I want to** open a **shipment detail** page with every item and a markup rate,  
**So that** I can review landed cost and adjust sell prices in one place.

**As a** thrift admin,  
**I want to** download shipment images from Cloudinary,  
**So that** I can archive media for an inbound batch.

### 2.2 Box — `thrift_box`

**As a** warehouse user,  
**I want to** label physical boxes within a shipment,  
**So that** I can trace which stock came from which container (text name only — no box barcode).

### 2.3 Stock — `thrift_stock`

**As a** desk user,  
**I want** a paginated stock catalog with inline edit, filters, and images,  
**So that** I can manage inventory without leaving the list.

**As a** desk user,  
**I want** origin price to default from settings but stay editable per item,  
**So that** costing inputs are fast yet accurate for outliers.

**As a** desk user,  
**I want** product cost, cargo share, ops share, and landed cost to **recalculate in the UI**,  
**So that** I never maintain stale COGS in the database.

**As a** desk user,  
**I want** suggested sell price from markup with per-row manual override,  
**So that** formula pricing stays flexible.

**As a** desk user,  
**I want to** record garment measurements (bust, waist, hips, length, and optional extras) per stock item,  
**So that** end customers can judge fit when brands and tag sizes differ.

**As a** desk user,  
**I want** measurements shown as one labeled summary in the stock and shipment item tables,  
**So that** the grid stays readable without a column per measurement.

### 2.4 Barcode — `thrift_barcode`

**As a** thrift admin,  
**I want to** bulk-generate and print barcodes,  
**So that** labels are ready before mobile registration.

**As a** mobile operator,  
**I want to** scan a barcode and register stock against it,  
**So that** each physical item maps to one catalog row.

### 2.5 Category & type — `thrift_category`, `thrift_type`

**As a** thrift admin,  
**I want** a global read-only catalog plus tenant-specific types,  
**So that** registration pickers are consistent but extensible.

### 2.6 Shelf — `thrift_shelf`

**As a** warehouse user,  
**I want to** assign shelf codes to stock,  
**So that** I can find items on the shop floor.

### 2.7 Settings — `thrift_settings`

**As a** thrift admin,  
**I want** default origin unit price and hand-tag / sticker unit costs in settings,  
**So that** registration and ops cost totals stay consistent.

**As a** tenant admin,  
**I want** default shipment currencies in tenant preferences,  
**So that** new shipments pre-fill purchase and cost currency.

### 2.8 Mobile — Thrift-app

**As a** floor operator,  
**I want to** select shipment/box, scan barcode, photograph item, and register stock,  
**So that** intake is fast at the warehouse (costing UI deferred to web).

### 2.9 Invoice — `thrift_invoices` (DB only today)

**As a** future desk user,  
**I want to** sell stock and record profit,  
**So that** revenue and COGS flow to `thrift_accounting_ledger` (no web UI yet).

---

## 3. Data model

Legend: **Today** = in production DB | **Target** = planned costing work | **Stored** vs **Computed**

### 3.0 Table index

| Table | Use case | Module key |
|-------|----------|------------|
| `thrift_shipments` | Inbound batch; rates; shared cost allocation | `thrift_shipment` |
| `thrift_boxes` | Physical containers within a shipment | `thrift_box` |
| `thrift_stocks` | Sellable inventory item | `thrift_stock` |
| `thrift_pricings` | Sell price persistence (1:1 stock) | `thrift_stock` |
| `thrift_stock_images` | Product photos | `thrift_stock` |
| `thrift_stock_measurements` | Garment fit (inches, 1:1 stock) | `thrift_stock` |
| `thrift_barcodes` | Pre-printed label catalog | `thrift_barcode` |
| `thrift_categories` | High-level classification | `thrift_category` |
| `thrift_types` | Style within category | `thrift_type` |
| `thrift_shelves` | Physical shelf location | `thrift_shelf` |
| `thrift_settings` | Tenant defaults (origin, label unit costs) | `thrift_settings` |
| `thrift_invoices` | Sales header | *(no UI)* |
| `thrift_invoice_items` | Sales lines | *(no UI)* |
| `thrift_accounting_ledger` | Revenue/expense/loss entries | *(no UI)* |

```mermaid
erDiagram
  thrift_shipments ||--o{ thrift_boxes : contains
  thrift_shipments ||--o{ thrift_stocks : contains
  thrift_boxes ||--o{ thrift_stocks : optional
  thrift_categories ||--o{ thrift_stocks : classifies
  thrift_types ||--o{ thrift_stocks : styles
  thrift_shelves ||--o{ thrift_stocks : locates
  thrift_stocks ||--|| thrift_pricings : prices
  thrift_stocks ||--o| thrift_stock_measurements : fit
  thrift_stocks ||--o{ thrift_stock_images : images
  thrift_barcodes ||--o| thrift_stocks : assigned_via_barcode_string
  thrift_settings ||--|| tenants : one_per_tenant
  thrift_invoices ||--o{ thrift_invoice_items : lines
  thrift_stocks ||--o{ thrift_invoice_items : sold
```

---

### 3.1 `thrift_shipments`

**Use case:** Groups an inbound purchase batch. Owns conversion rates, cargo inputs, labour/transport totals, and default markup. All stock in the shipment inherits these for cost allocation.

| Column | Today | Target | Stored |
|--------|-------|--------|--------|
| `id` | PK | | Yes |
| `tenant_id` | FK → `tenants` | | Yes |
| `name` | text | | Yes |
| `purchase_currency_id` | FK → `global_currencies` | | Yes |
| `cost_currency_id` | FK → `global_currencies` | | Yes |
| `product_conversion_rate` | numeric | | Yes |
| `cargo_conversion_rate` | numeric | | Yes |
| `cargo_rate` | numeric | | Yes |
| `total_cargo_weight_kg` | — | numeric | Yes |
| `labor_total_cost` | — | numeric | Yes |
| `transportation_total_cost` | — | numeric | Yes |
| `washing_total_cost` | — | numeric | Yes |
| `default_markup_rate` | — | numeric | Yes |
| `inserted_by`, timestamps | | | Yes |

**Computed (never stored):** `U`, `shipment_cargo_cost`, `shipment_ops_cost`.

**Access:** Direct Supabase CRUD from `ThriftShipmentPage.vue`. Detail page **planned**.

---

### 3.2 `thrift_boxes`

**Use case:** Track physical packing boxes inside a shipment. Stock optionally references `box_id` for provenance. **No box barcode.**

| Column | Type | Notes |
|--------|------|-------|
| `id` | bigserial PK | |
| `tenant_id` | FK | |
| `shipment_id` | FK → `thrift_shipments` | Required |
| `name` | text | Box label (text only) |
| `weight`, `received_weight` | numeric | kg in UI |
| `inserted_by`, timestamps | | |

**Access:** `thriftRepository` + `ThriftBoxPage.vue`.

---

### 3.3 `thrift_stocks`

**Use case:** One sellable item (or bulk quantity). Links to shipment, optional box, catalog FKs, barcode string, and cost **inputs**. Catalog/registration attrs unchanged by costing work (D-T8).

| Column | Today | Target | Stored | Notes |
|--------|-------|--------|--------|-------|
| `id`, `tenant_id` | | | Yes | |
| `shipment_id` | FK | | Yes | Required |
| `box_id` | FK nullable | | Yes | |
| `category_id`, `type_id` | FK nullable | | Yes | |
| `shelf_id` | FK nullable | | Yes | |
| `barcode` | text | | Yes | Unique per tenant; from `thrift_barcodes` |
| `name`, `brand_name`, `color`, `size`, `note` | text | | Yes | |
| `section` | enum | | Yes | MALE, FEMALE, … |
| `condition` | enum | | Yes | |
| `stock_type` | enum | | Yes | SINGLE, BULK |
| `status` | enum | | Yes | AVAILABLE, OUT_OF_STOCK, … |
| `quantity` | integer | | Yes | Contributes to `U` |
| `product_weight`, `extra_weight` | numeric | | Yes | Grams in DB |
| `origin_unit_price` | `origin_purchase_price` | rename | Yes | Purchase ccy |
| `extra_origin_unit_price` | `extra_origin_purchase_expense` | rename | Yes | Purchase ccy |
| `additional_charges_cost` | — | new | Yes | Cost ccy |
| `inserted_by`, timestamps | | | Yes | |

**Computed per row:** `product_unit_cost`, `cargo_share_per_unit`, `ops_share_per_unit`, `landed_unit_cost`, `suggested_sell_unit_price`.

---

### 3.4 `thrift_pricings`

**Use case:** 1:1 sell-price row per stock. Target: persist only customer-facing price + manual flag; stop storing computed costs.

| Column | Today | Target |
|--------|-------|--------|
| `stock_id` | FK unique | Keep |
| `listed_price` | numeric | → `listed_unit_price` |
| `is_listed_price_manual` | — | **New** |
| `markup_rate_override` | — | **New** — per-item markup decimal; null = use shipment default |
| `markup_rate_override` | — | **New** — per-item markup decimal; null = use shipment default |
| `cost_of_goods_sold` | numeric | **Deprecate** (compute) |
| `extra_expense_cost` | numeric | **Deprecate** (compute) |
| `target_price` | numeric | **Deprecate** (→ suggested sell) |

---

### 3.5 `thrift_stock_images`

**Use case:** Product photos (Cloudinary URL + optional Google Drive `drive_file_id`). Primary flag for list thumbnail. **Unchanged by costing work.**

| Column | Notes |
|--------|-------|
| `stock_id` | FK → `thrift_stocks` |
| `image_url` | Cloudinary URL |
| `drive_file_id` | Optional Drive sync |
| `is_primary` | boolean |

---

### 3.6 `thrift_barcodes`

**Use case:** Pre-generated label pool. Bulk-created on web; consumed on stock registration; released on stock delete. **Unchanged by costing work.**

| Column | Notes |
|--------|-------|
| `barcode_id` | e.g. `AA-26-000001` |
| `status` | `AVAILABLE` / `USED` |
| `is_printed` | 0 / 1 |

---

### 3.7 `thrift_categories` / `thrift_types`

**Use case:** Classification catalog. Global rows (`is_global = true`, `tenant_id IS NULL`) are read-only; tenant rows are CRUD. Types may have `icon`. **Unchanged by costing work.**

| Column | Categories | Types |
|--------|------------|-------|
| `name`, `description` | Yes | Yes |
| `is_global`, `tenant_id` | Yes | Yes |
| `icon` | — | Yes |

---

### 3.8 `thrift_shelves`

**Use case:** Physical shelf codes for stock location. **Unchanged by costing work.**

| Column | Notes |
|--------|-------|
| `name`, `shelf_code`, `location_bay` | Unique `shelf_code` per tenant |

---

### 3.9 `thrift_settings`

**Use case:** Per-tenant defaults for registration and ops cost inputs (one row per `tenant_id`).

| Column | Today | Target |
|--------|-------|--------|
| `tenant_id` | PK/FK | Keep |
| `default_origin_unit_price` | `default_origin_purchase_price` | rename |
| `hand_tag_unit_cost` | — | **New** |
| `hand_tag_unit_currency_id` | — | FK |
| `sticker_unit_cost` | — | **New** |
| `sticker_unit_currency_id` | — | FK |

**Tenant preference (not this table):** `thrift.default_purchase_currency`, `thrift.default_cost_currency` on `tenants.preference`.

---

### 3.10 `thrift_invoices` / `thrift_invoice_items` (DB only)

**Use case:** Record sales, compute line profit, deduct stock. Web UI not built.

| Table | Use case |
|-------|----------|
| `thrift_invoices` | Header: recipient, charges, payment/delivery status |
| `thrift_invoice_items` | Line: `stock_id`, `sold_price`, fees, `net_profit` (trigger), `landed_unit_cost_at_sale` |

**Profit trigger details:** In `thrift_invoice_items`, the trigger `calculate_thrift_item_net_profit()` computes the landed cost using `compute_thrift_landed_unit_cost(stock_id)` at sale time, stores it in `landed_unit_cost_at_sale`, and calculates `net_profit := (sold_price - landed_unit_cost_at_sale) * quantity - platform_fees - shipping_cost_paid_by_shop`.

**RPC:** `mark_thrift_items_as_sold` — creates invoice, items, updates stock, writes ledger.

---

### 3.11 `thrift_accounting_ledger` (DB only)

**Use case:** Auto-logged revenue, expense, refund, loss from invoices and stock status changes (DAMAGED/STOLEN).

---

### 3.12 `thrift_stock_measurements` (planned — P1)

**Use case:** Store **actual garment measurements** for end-customer fit (second-hand items vary by brand). **1:1** with `thrift_stocks` (`stock_id` UNIQUE, ON DELETE CASCADE). **Inches only** (`numeric(5,1)`). **No JSONB.** All measurement fields **nullable** — nothing mandatory at intake.

**Stays on `thrift_stocks`:** `size` (tag label, e.g. M / 10 / 38), `brand_name`.

**Explicitly out of scope:** `thrift_brand_size_charts` (no separate brand size-chart table).

| Column | Stored | Notes |
|--------|--------|-------|
| `stock_id` | Yes | FK unique → `thrift_stocks` |
| `tenant_id` | Yes | Denormalized for RLS |
| `bust_in`, `waist_in`, `hips_in`, `length_in` | Yes | Core fit |
| `shoulder_width_in`, `sleeve_length_in`, `arm_circumference_in` | Yes | Sleeves / structure |
| `hem_width_in`, `neck_opening_in` | Yes | Style-dependent |
| `sleeve_type`, `neckline`, `dress_style` | Yes | text |
| `fabric_stretch` | Yes | `none` / `low` / `medium` / `high` |
| `lining` | Yes | boolean |
| `closure_type`, `measurement_notes` | Yes | text |
| `inserted_by`, timestamps | Yes | audit |

**Indexes (future shop filters):** `(tenant_id, bust_in)`, `(tenant_id, waist_in)`, `(tenant_id, hips_in)`.

**Access:** Web — `thriftStockRepository` upsert/delete; `list_thrift_stocks_paginated` returns nested `measurements` object. Mobile measurement inputs **deferred** (P1 web only).

**UI display:** Single table cell with labeled summary, e.g. `Size: M · Bust: 34" · Waist: 28"` — not separate columns per measurement. Edit via actions-column button → `ThriftStockMeasurementsDialog`. The measurements dialog includes a header **info** button that opens `ThriftMeasurementGuideDialog` — a read-only in-app guide with plain-language definitions, how-to-measure copy, and inline SVG flat-lay diagrams per field (shared from stock and shipment item tables).

---

## 4. Permissions and access control

### 4.1 Module keys

| Key | Route | Guard |
|-----|-------|-------|
| `thrift_shipment` | `/app/thrift/shipments` | `createAccessGuard` |
| `thrift_box` | `/app/thrift/boxes` | same pattern |
| `thrift_stock` | `/app/thrift/stocks` | |
| `thrift_barcode` | `/app/thrift/barcodes` | |
| `thrift_category` | `/app/thrift/categories` | |
| `thrift_type` | `/app/thrift/types` | |
| `thrift_shelf` | `/app/thrift/shelves` | |
| `thrift_settings` | `/app/thrift/settings` | |

All routes: `requiredScope: 'app'`, `allowedRoles: ['admin', 'staff']`, `requireTenantContext: true`.

### 4.2 Role matrix (`modulePermissions.ts`)

| Role | thrift_* modules |
|------|------------------|
| `admin` | `view` on all 8 keys |
| `staff` | `view` on all 8 keys |
| `superadmin` | `view` on all 8 keys |
| `customer`, `investor`, `vendor`, `guest` | **NO_ACCESS** |

Today only the **`view`** ability exists in code — CRUD is not split by ability; route access implies full page CRUD for admin/staff.

### 4.3 Tenant enablement

- Modules assigned per tenant via `tenant_modules` (D13 — no parent/child inheritance).
- Disabled module → route guard blocks navigation.
- Global categories/types: `SELECT` for all authenticated members; `WRITE` only tenant-scoped rows (`is_global = false`).

### 4.4 Row Level Security (RLS)

Standard pattern on all `thrift_*` tables:

| Operation | Policy |
|-----------|--------|
| **SELECT** | Active `memberships` row for `tenant_id` + `current_user_email()` |
| **INSERT/UPDATE/DELETE** | Same + `role IN ('admin', 'staff')` |
| **Global catalog** | `is_global = true` → SELECT all authenticated; WRITE tenant rows only |

Child tables (`thrift_pricings`, `thrift_stock_images`, `thrift_stock_measurements`) join through `thrift_stocks.tenant_id`.

### 4.5 Special cases

| Case | Rule |
|------|------|
| Tenant preferences (`thrift.default_*_currency`) | Tenant admin via `update_tenant_preference_for_admin` |
| `global_currencies` read | All authenticated (for currency pickers) |
| Mobile RPCs | `security definer` — enforce `tenant_id` + membership inside function |

---

## 5. API surface

### 5.1 RPCs (Postgres)

| RPC | Caller | Purpose | Status |
|-----|--------|---------|--------|
| `generate_thrift_barcodes(tenant_id, prefix, year, quantity, inserted_by)` | Web | Bulk create labels | Today |
| `list_thrift_barcodes_paginated(...)` | Web | Barcode list + stats | Today |
| `list_thrift_stocks_paginated(...)` | Web | Stock list + pricing + images + measurements | Today → P1 extends |
| `resolve_thrift_barcode(tenant_id, scanned)` | Mobile | Normalize scan → `barcode_id` | Today |
| `resolve_thrift_barcode_id_internal(...)` | Internal | Canonical barcode lookup | Today |
| `register_thrift_stock_from_app(...)` | Mobile | Create/update stock + pricing + image | Today |
| `mark_thrift_items_as_sold(...)` | *(none — DB only)* | Invoice + stock deduction + ledger | Today |
| `compute_thrift_landed_unit_cost(stock_id)` | Invoice trigger / RPC | SQL cost engine mirror | Today |

### 5.2 Direct Supabase table access (web)

| Entity | Repository / page | Operations |
|--------|-------------------|------------|
| Shipments | `ThriftShipmentPage` — direct `supabase.from('thrift_shipments')` | CRUD |
| Boxes, categories, types, shelves | `thriftRepository` | CRUD |
| Stock | `thriftStockRepository` | CRUD + pricing + images + measurements |
| Settings | `thriftSettingsRepository` | fetch + upsert |
| Barcodes | `thriftBarcodeRepository` | list RPC + generate RPC + update `is_printed` |
| Currencies | `thriftCurrencyRepository` | read `global_currencies` |

### 5.3 Web routes

| Route | Page | Module |
|-------|------|--------|
| `/:slug/app/thrift/shipments` | `ThriftShipmentPage` | `thrift_shipment` |
| `/:slug/app/thrift/shipments/:id` | `ThriftShipmentDetailsPage` | `thrift_shipment` — **planned** |
| `/:slug/app/thrift/boxes` | `ThriftBoxPage` | `thrift_box` |
| `/:slug/app/thrift/stocks` | `ThriftStockPage` | `thrift_stock` |
| `/:slug/app/thrift/barcodes` | `ThriftBarcodePage` | `thrift_barcode` |
| `/:slug/app/thrift/barcodes/print-preview` | `ThriftBarcodePrintPreviewPage` | `thrift_barcode` |
| `/:slug/app/thrift/categories` | `ThriftCategoryPage` | `thrift_category` |
| `/:slug/app/thrift/types` | `ThriftTypePage` | `thrift_type` |
| `/:slug/app/thrift/shelves` | `ThriftShelfPage` | `thrift_shelf` |
| `/:slug/app/thrift/settings` | `ThriftSettingsPage` | `thrift_settings` |

### 5.4 Mobile API (Thrift-app)

| Step | API |
|------|-----|
| Login | Supabase auth + tenant bootstrap |
| Load catalog | Direct `SELECT` on categories, types, boxes, shelves |
| Scan | `resolve_thrift_barcode` |
| Register | `register_thrift_stock_from_app` |
| Images | Cloudinary upload → URL in RPC |

---

## 6. Flow sequences

### 6.1 Inbound catalog setup (web)

```mermaid
sequenceDiagram
  participant Admin
  participant Web
  participant DB

  Admin->>Web: Open settings
  Web->>DB: upsert thrift_settings
  Admin->>Web: Create shipment
  Web->>DB: insert thrift_shipments
  Admin->>Web: Create boxes
  Web->>DB: insert thrift_boxes
  Admin->>Web: Generate barcodes
  Web->>DB: RPC generate_thrift_barcodes
  Admin->>Web: Print labels
  Web->>DB: update is_printed
```

### 6.2 Mobile stock registration (today — unchanged)

```mermaid
sequenceDiagram
  participant Operator
  participant App
  participant DB

  Operator->>App: Select shipment + optional box
  Operator->>App: Scan barcode
  App->>DB: resolve_thrift_barcode
  Operator->>App: Photo + catalog fields
  App->>DB: register_thrift_stock_from_app
  Note over DB: barcode USED, stock row + pricing + image
```

### 6.3 Shipment costing and pricing (planned)

```mermaid
sequenceDiagram
  participant Admin
  participant Web
  participant CostEngine
  participant DB

  Admin->>Web: Open shipment detail
  Web->>DB: load shipment + stocks + settings
  Web->>CostEngine: computeThriftUnitCosts per row
  CostEngine-->>Web: product/cargo/ops/landed/suggested
  Admin->>Web: Edit markup or origin on row
  Web->>CostEngine: recalculate all rows
  Admin->>Web: Override listed sell + manual flag
  Web->>DB: update thrift_pricings only
  Note over DB: no persisted COGS or landed cost
```

### 6.4 Barcode lifecycle (unchanged)

```mermaid
stateDiagram-v2
  [*] --> AVAILABLE: generate_thrift_barcodes
  AVAILABLE --> USED: stock registration
  USED --> AVAILABLE: stock delete trigger
```

### 6.5 Sale (DB only today)

```mermaid
sequenceDiagram
  participant System
  participant DB

  System->>DB: mark_thrift_items_as_sold
  DB->>DB: insert invoice + items
  DB->>DB: update stock quantity/status
  DB->>DB: insert accounting_ledger
  Note over DB: net_profit trigger uses compute_thrift_landed_unit_cost
```

---

## 7. Current state summary

| Area | Web | Mobile | DB |
|------|-----|--------|-----|
| Shipment list | Yes | Select | Yes |
| Shipment detail + costing grid | Yes | — | Yes |
| Computed costing engine | Yes | — | Yes |
| Stock catalog | Yes | Yes | Yes |
| Garment measurements (web) | Yes | — | Yes |
| Barcode generate/print/scan | Yes | Yes | Yes |
| Images / Drive sync | Yes | Yes | Yes |
| Settings (hand tag / sticker) | Yes | — | Yes |
| Box, shelf, category, type | Yes | Partial | Yes |
| Invoice UI | No | No | Yes |

---

## 8. Web module layout

Unified under `web/src/modules/thrift/` — folder refactor **completed**.

| Folder | Contents |
|--------|----------|
| `routes/` | Aggregated route definitions |
| `shared/` | `thriftStore`, `thriftRepository`, `computeThriftUnitCosts.ts` (**planned**), `formatThriftStockMeasurements.ts` (**planned P1**) |
| `shipment/`, `box/`, `shelf/`, `category/`, `type/` | Entity pages |
| `stock/` | Stock pages, `ThriftStockMeasurementsDialog.vue` (**planned P1**), repository |
| `barcode/`, `settings/`, `currency/` | Barcodes, settings, currency reader |

---

## 9. Planned work — implementation phases

**Implementation starts at P1** because costing schema changes and the new measurements table affect **live production data**. P1 must run backup copies before any `ALTER`. Column renames break web/RPCs until P1 migration and coordinated app deploy (see deploy note below).

Legend (UI columns): **S** stored | **C** computed | **F** display | **A** action

### 9.1 Phase overview

| Phase | Deliverable | Touches live data? | Status |
|-------|-------------|-------------------|--------|
| **P1 — Migration + measurements** | Backups → costing alters → RPC renames → `thrift_stock_measurements` → stock UI cell + dialog → `supabase.ts` regen | **Yes** | Done |
| **P2 — Cost engine** | `computeThriftUnitCosts.ts` + `compute_thrift_landed_unit_cost` SQL | No | Done |
| **P3 — Settings UI** | Hand-tag / sticker on `ThriftSettingsPage` | No | Done |
| **P4 — Shipment UI** | List cost columns + `ThriftShipmentDetailsPage` (reuses measurements cell/dialog) | No | Done |
| **P5 — Stock costing UI** | Replace cost columns only on `ThriftStockPage` (§9.4) | No | Done |
| **P6 — Mobile RPC** | `register_thrift_stock_from_app` param renames in Thrift-app | Reads/writes migrated cols | Done |
| **P7 — Invoice trigger** | `mark_thrift_items_as_sold` uses computed landed cost | No | Done |
| **P8 — Cleanup + shipment detail UX** | Collapsible two-column layout + sticky table component on `ThriftShipmentDetailsPage`; `DROP` `_bak_*` backup tables | Yes | Done |

```mermaid
flowchart TD
  P1[P1 Migration and measurements]
  P2[P2 Cost engine]
  P3[P3 Settings UI]
  P4[P4 Shipment UI]
  P5[P5 Stock costing UI]
  P6[P6 Mobile RPC]
  P7[P7 Invoice trigger]
  P8[P8 Drop backups]
  P1 --> P2
  P2 --> P3
  P2 --> P4
  P2 --> P5
  P1 --> P6
  P2 --> P7
  P5 --> P8
  P6 --> P8
```

**Deploy note:** P1 migration must recreate `list_thrift_stocks_paginated` and `register_thrift_stock_from_app` in the **same migration file**. P5/P6 web + mobile should ship in the **same deploy window** as `backend:push`, or column-not-found errors occur.

### 9.2 P1 — Part A: Costing migration (live data safe)

#### Backup tables (before any `ALTER`)

`CREATE TABLE … AS SELECT * FROM …` — no FKs, no RLS:

| Backup table | Source | Why |
|--------------|--------|-----|
| `_bak_thrift_shipments` | `thrift_shipments` | New cargo/ops/markup columns |
| `_bak_thrift_stocks` | `thrift_stocks` | Column renames + `additional_charges_cost` |
| `_bak_thrift_pricings` | `thrift_pricings` | `listed_price` rename, `is_listed_price_manual` |
| `_bak_thrift_settings` | `thrift_settings` | Rename + hand-tag/sticker cols |
| `_bak_thrift_stock_images` | `thrift_stock_images` | D-T8 unchanged; FK safety for rollback |

**Not backed up** (D-T8 frozen): `thrift_barcodes`, `thrift_boxes`, `thrift_categories`, `thrift_types`, `thrift_shelves`.

#### Schema changes (after backups)

Align with §3.1–3.4:

| Table | Change |
|-------|--------|
| `thrift_shipments` | Add `total_cargo_weight_kg`, `labor_total_cost`, `transportation_total_cost`, `default_markup_rate` |
| `thrift_stocks` | Rename `origin_purchase_price` → `origin_unit_price`, `extra_origin_purchase_expense` → `extra_origin_unit_price`; add `additional_charges_cost` |
| `thrift_pricings` | Rename `listed_price` → `listed_unit_price`; add `is_listed_price_manual` (keep deprecated COGS cols) |
| `thrift_settings` | Rename `default_origin_purchase_price` → `default_origin_unit_price`; add hand-tag/sticker unit cost + currency FKs |

#### RPC updates (same migration)

- `list_thrift_stocks_paginated` — JSON keys use new costing names **and** nested `measurements` (Part B)
- `register_thrift_stock_from_app` — `p_origin_unit_price`, `p_extra_origin_unit_price`, `p_listed_unit_price` (deprecated COGS params no-op until P7)

#### Verification (after `npm run deploy:backend`)

- Row counts: each live table = matching `_bak_*` count
- List RPC returns `image_url` and `measurements`
- Mobile register still creates stock + image
- Measurements dialog save/load on web

#### Rollback (if verification fails before app deploy)

`TRUNCATE` live → `INSERT INTO live SELECT * FROM _bak_*` (FK order: shipments → stocks → pricings/images), or Supabase point-in-time restore.

#### P8 cleanup (separate migration — manual gate)

After P5 + P6 tested in production:

```sql
drop table if exists public._bak_thrift_stock_images;
drop table if exists public._bak_thrift_pricings;
drop table if exists public._bak_thrift_stocks;
drop table if exists public._bak_thrift_shipments;
drop table if exists public._bak_thrift_settings;
```

Do **not** run P8 until sign-off.

#### P1 migration file (skeleton)

`supabase/migrations/20260813000000_thrift_p1_costing_and_measurements.sql`:

```sql
begin;
-- 1) Backups (_bak_*)
-- 2) Costing alters
-- 3) Create thrift_stock_measurements + RLS
-- 4) Recreate list_thrift_stocks_paginated
-- 5) Recreate register_thrift_stock_from_app
commit;
```

### 9.3 P1 — Part B: Garment measurements (web)

See §3.12 for table shape. **P1 web deliverables:**

| Item | Detail |
|------|--------|
| Stock table column | Replace standalone **Size** with **Measurements** — one cell, labeled inline text (only values present), e.g. `Size: M · Bust: 34" · Waist: 28"` |
| Actions | `straighten` icon opens `ThriftStockMeasurementsDialog` |
| Dialog | Shows **Size** (saves to `thrift_stocks.size`); numeric/select inputs for all measurement fields; **no required fields**; header **info** button opens in-app measurement guide with SVG diagrams |
| Save | Upsert `thrift_stock_measurements`; delete row if all measurement fields empty |

**Code (P1):** `formatThriftStockMeasurements.ts`, `ThriftStockMeasurementsDialog.vue`, `ThriftMeasurementGuideDialog.vue`, `thriftMeasurementGuide.ts`, `MeasurementDiagramFlat.vue`, `thriftStockRepository` upsert/delete.

**Not in P1:** Thrift-app measurement inputs, customer shop filters, `thrift_brand_size_charts`.

Simplified to only: **SL**, **Shipment Name** (linking to detail page), and **Actions** (Download Cloudinary images with progress dialogue, edit settings metadata, and delete). Costing inputs and detail columns live entirely within the detail page layout.

### 9.5 UI columns — shipment detail items (P4, P8-A)

Catalog cols (barcode, image, category, type) **unchanged**. **Measurements:** single **F** cell (same formatter + dialog as stock table) — **not** separate bust/waist/hips columns.

Cost block: origin, extra origin, product cost (C), cargo/unit (C), ops/unit (C), add'l charges, landed (C) + info breakdown dialog, item markup %, effective markup %, suggested sell (C), listed sell, manual flag.

**Two-Column Layout Redesign (P8-A):**
- **Left Sidebar:** Collapsible panel containing the shipment info summary and the cargo / operational costing inputs (e.g. weight, cargo rate, labor, transport costs, conversion rates, and markup).
- **Right Panel:** Search filter (client-side matching barcode/brand/name), column dropdown group picker, and the sticky table `ThriftShipmentItemsTable.vue` displaying items.
- **Sticky Column Scrolling:** Left-most columns (`SL`, `Image` as a 1in thumbnail, and `Barcode`) remain sticky during horizontal scroll.
- **Bottom Summary Row:** Structured **Shipment cost overview** panel divided into four clean panels:
  - **HOW COSTS ARE SPLIT**: Unit Count (U) explaining division of bills.
  - **SHIPMENT TOTALS**: Cargo total, labor, transport, hand tags, stickers, and Ops totals.
  - **PER-UNIT SHARE**: Direct calculation metrics for Cargo Share and Ops Share.
  - **PER-ITEM LANDED COST**: Mathematical formula layout representing `Product + Cargo Share + Ops Share + Additional Charges`.


### 9.6 UI columns — stock catalog

Cols 1–14 (image, barcode, catalog, weights) **unchanged**. **Measurements** column replaces standalone Size (§9.3). Cols 16–25 are cost block per §3.3 (P5).

### 9.7 Code files by phase

| Phase | Paths |
|-------|-------|
| P1 | `supabase/migrations/20260813000000_thrift_p1_costing_and_measurements.sql`; `ThriftStockPage.vue`; `ThriftStockMeasurementsDialog.vue`; `formatThriftStockMeasurements.ts`; `thriftStockRepository.ts`; `supabase.ts` regen |
| P2 | `web/src/modules/thrift/shared/utils/computeThriftUnitCosts.ts` |
| P3 | `thriftSettingsRepository.ts`, `ThriftSettingsPage.vue` |
| P4 | `ThriftShipmentDetailsPage.vue` (reuses measurements dialog) |
| P5 | `ThriftStockPage.vue` — costing column renames |
| P6 | `Thrift-app` `RegisterStock.vue` |
| P7 | `supabase/migrations/20260815000000_thrift_p7_invoice_landed_cost.sql` trigger updates |
| P8 | `ThriftShipmentItemsTable.vue`, `ThriftShipmentDetailsPage.vue` layout updates; `supabase/migrations/20260816000000_thrift_p8_drop_migration_backups.sql` |

---

## 10. Cost engine reference

`U` = `SUM(quantity)` per shipment (min 1 in UI).

```
product_unit_cost = (origin_unit_price + extra_origin_unit_price) × product_conversion_rate

shipment_cargo_cost = (total_cargo_weight_kg × cargo_rate) × cargo_conversion_rate

shipment_ops_cost = (hand_tag_unit_cost × U) + (sticker_unit_cost × U) + labor_total_cost + transportation_total_cost + washing_total_cost

line_weight_kg = ((product_weight + extra_weight) / 1000) × quantity
total_weight_kg = SUM(line_weight_kg) per shipment

cargo_share_per_unit = if total_weight_kg > 0:
                         (line_weight_kg / total_weight_kg) × shipment_cargo_cost / quantity
                       else:
                         shipment_cargo_cost / U
ops_share_per_unit   = shipment_ops_cost / U

landed_unit_cost = product_unit_cost + cargo_share_per_unit + ops_share_per_unit + additional_charges_cost

suggested_sell_unit_price = landed_unit_cost × (1 + (markup_rate_override ?? default_markup_rate))
listed_unit_price = is_listed_price_manual ? stored : suggested_sell_unit_price
effective_markup_pct = is_listed_price_manual && landed > 0
  ? ((listed_unit_price - landed) / landed) × 100
  : (markup_rate_override ?? default_markup_rate) × 100
```

**Code (planned):** `web/src/modules/thrift/shared/utils/computeThriftUnitCosts.ts`

---

## 11. Migration and scope

### In scope

**P1 — Costing:** Backup tables (`_bak_thrift_*`), column renames on shipments/stocks/pricings/settings, deprecate stored COGS/extra_expense/target (columns kept), `is_listed_price_manual`, RPC renames in same migration, P8 backup drop after sign-off.

**P1 — Measurements:** `thrift_stock_measurements` (§3.12), inches only, all optional, web list cell + edit dialog. **No** `thrift_brand_size_charts`.

**P2–P7:** Cost engine, settings/shipment/stock UI, mobile RPC, invoice computed landed cost (see §9.1).

### Explicitly unchanged (D-T8)

`thrift_barcodes`, `thrift_stock_images`, barcode RPCs, scan/register flow, catalog FKs and attrs, box/shelf/category/type/barcode modules.

### Out of scope

`thrift_brand_size_charts`, Thrift-app measurement UI (P1), customer storefront measurement filters, Thrift-app costing UI, invoice web UI, moving shipment currencies from tenant preference.

---

## 12. Key source files

| Purpose | Path |
|---------|------|
| Core schema | `supabase/migrations/20260628000000_create_thrift_module.sql` |
| Shipments | `supabase/migrations/20260630000300_create_thrift_shipments.sql` |
| Barcodes | `supabase/migrations/20260701000000_thrift_barcodes_module.sql` |
| Mobile register | `supabase/migrations/20260706000000_register_thrift_stock_from_app.sql` |
| List stocks RPC | `supabase/migrations/20260809000000_thrift_stock_images_drive_file_id.sql` |
| **P1 migration (planned)** | `supabase/migrations/20260813000000_thrift_p1_costing_and_measurements.sql` |
| Measurements dialog (planned P1) | `web/src/modules/thrift/stock/components/ThriftStockMeasurementsDialog.vue` |
| Measurements formatter (planned P1) | `web/src/modules/thrift/shared/utils/formatThriftStockMeasurements.ts` |
| Permissions | `web/src/modules/navigation/modulePermissions.ts` |
| Routes | `web/src/modules/thrift/routes/` |
| Landed-cost reference | `web/src/modules/procurement_stock/utils/landedCost.ts` |
