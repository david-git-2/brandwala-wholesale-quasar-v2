# Stock & Inventory Database Schema

This document details the simplified database schema for stock inventory records using condition tag enums (`global_stocks`) and tenant stock allocations (`global_stock_allocations`).

---

## 1. Custom Types & Enums

### 1.1 `stock_condition` (Comprehensive Fixed Condition Tags)
Predefined condition tags for inventory classification. Default condition is `'sellable'`.

```sql
CREATE TYPE stock_condition AS ENUM (
  -- Primary Sellable (Full Price)
  'sellable',          -- Pristine, brand-new condition ready for full-price sale

  -- Minor Packaging Defects (Discounted / Clearance Sellable)
  'box_damaged',       -- Product intact, outer packaging crushed, torn, or dented
  'box_less',          -- Product intact, missing original outer retail box
  'open_box',          -- Unsealed outer packaging, product unused
  'packaging_flaw',    -- Label scuffed, unreadable barcode, or broken security seal

  -- Minor Product Cosmetic Defects & Samples (Clearance / Internal Use)
  'cosmetic_defect',   -- Minor scratch, dent, or scuff on item itself (functional)
  'display_sample',    -- Showroom demo, display model, or tester unit
  'refurbished',       -- Restored item inspected/repaired to working condition

  -- Unsellable / Quarantined / Discrepancy (Held from Sale)
  'damaged',           -- Physically broken, leaking, or unusable item
  'expired',           -- Past expiration date (write-off / disposal)
  'near_expiry',       -- Close to expiration date (requires urgent clearance)
  'missing_parts',     -- Incomplete product missing essential component/accessory
  'under_inspection',  -- Temporarily held in quarantine pending QA check
  'shortage'           -- Missing item count from shipment upon receipt
);
```

---

## 2. Schema Tables

### 2.1 `global_stocks` (Inventory & Condition Records)
Stores inventory quantities grouped by shipment, shipment item, product, and condition tag.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `parent_tenant_id` | BIGINT | Yes | FK to `tenants.id` (Owner tenant) |
| `shipment_id` | BIGINT | Yes | FK to `shipments.id` (Direct shipment reference) |
| `shipment_item_id` | BIGINT | Yes | FK to `shipment_items.id` |
| `product_id` | BIGINT | Yes | FK to `products.id` |
| `condition` | `stock_condition` | Yes | Inventory condition tag (default `'sellable'`) |
| `quantity` | INT | Yes | Quantity for this specific condition (default `0`) |
| `created_at` | TIMESTAMPTZ | Yes | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Yes | Update timestamp |

---

### 2.2 `global_stock_allocations` (Tenant/Shop Stock Distribution)
Tracks allocations of `global_stocks` from a parent tenant to child/shop tenants.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `parent_tenant_id` | BIGINT | Yes | FK to `tenants.id` (Source parent tenant) |
| `child_tenant_id` | BIGINT | Yes | FK to `tenants.id` (Destination child/shop tenant) |
| `stock_id` | BIGINT | Yes | FK to `global_stocks.id` |
| `quantity` | INT | Yes | Quantity allocated to child tenant |
| `created_at` | TIMESTAMPTZ | Yes | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Yes | Update timestamp |

---

## 3. Table Relationships Diagram

```
[shipments] (1) ──┐
                  ├──► (N) [global_stocks] (1) ─── (N) [global_stock_allocations]
[shipment_items] (1) ──┘           │
                                   └── FK: product_id ──► [products]
```
