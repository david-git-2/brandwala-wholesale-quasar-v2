# Sales Invoice Database Schema (v2)

This document details the database schema for the V2 Sales Invoice system, covering wholesale, retail, and dropship transactions. It is designed to be highly flexible, integrating with the V2 `global_stocks` engine and removing hardcoded charge logic.

> [!NOTE]
> This schema excludes Thrift Counter Sales (`thrift_sales_invoices`), which remain a separate, highly optimized subsystem.

---

## 1. Custom Types & Enums

### 1.1 `invoice_type`
Defines the core sales channel of the invoice.

```sql
CREATE TYPE invoice_type AS ENUM (
  'wholesale',
  'retail',
  'dropship'
);
```

### 1.2 `invoice_status`
The operational lifecycle state of the invoice.

```sql
CREATE TYPE invoice_status AS ENUM (
  'draft',      -- Being built, not posted
  'posted',     -- Finalized and stock deducted
  'void'        -- Cancelled (reverts stock)
);
```

### 1.3 `payment_status`
The financial state of the invoice. Note: actual payment processing should route through the V2 Wallet Ledger.

```sql
CREATE TYPE payment_status AS ENUM (
  'unpaid',
  'partial',
  'paid',
  'refunded'
);
```

### 1.4 `invoice_charge_type`
Flexible enum to categorize dynamic charges applied to an invoice.

```sql
CREATE TYPE invoice_charge_type AS ENUM (
  'shipping',
  'cod_fee',
  'packing',
  'print',
  'delivery',
  'other'
);
```

---

## 2. Schema Tables

### 2.1 `sales_invoices` (Header)
A unified, lean header. Financial totals are cached here for fast reads, but calculated from line items and charges.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | Yes | FK to `tenants.id` |
| `invoice_no` | TEXT | Yes | Sequential or unique invoice identifier |
| `invoice_type` | `invoice_type` | Yes | `wholesale`, `retail`, or `dropship` |
| `invoice_status` | `invoice_status` | Yes | Default: `draft` |
| `payment_status` | `payment_status` | Yes | Default: `unpaid` |
| `billing_profile_id` | BIGINT | No | FK to `billing_profiles.id` (Customer reference) |
| `invoice_date` | DATE | Yes | Sale date |
| `due_date` | DATE | No | Payment deadline (for wholesale/credit) |
| `subtotal_amount` | NUMERIC(12,2)| Yes | Sum of `line_total_amount` from items |
| `discount_amount` | NUMERIC(12,2)| Yes | Global invoice discount applied |
| `charges_total` | NUMERIC(12,2)| Yes | Sum of all `sales_invoice_charges` |
| `final_total_amount`| NUMERIC(12,2)| Yes | Computed: `subtotal - discount + charges` |
| `metadata` | JSONB | No | Flexible data: recipient name, address, phone, notes |
| `deleted_at` | TIMESTAMPTZ | No | Timestamp of soft deletion |
| `deleted_by` | UUID | No | FK to auth.users (soft deleted by) |
| `created_at` | TIMESTAMPTZ | Yes | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | Yes | Record update timestamp |

---

### 2.2 `sales_invoice_items` (Line Items)
Links directly to the V2 stock schema. Records the exact unit price and the landed cost snapshot for accurate profitability analysis.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `invoice_id` | BIGINT | Yes | FK to `sales_invoices.id` |
| `global_stock_id` | BIGINT | Yes | FK to V2 `global_stocks.id` |
| `name_snapshot` | TEXT | Yes | Product name at time of sale |
| `quantity` | INT | Yes | Quantity sold |
| `unit_price` | NUMERIC(12,2)| Yes | Individual selling price before discount |
| `line_discount` | NUMERIC(12,2)| No | Discount applied specifically to this item |
| `line_total_amount` | NUMERIC(12,2)| Yes | Computed: `(quantity * unit_price) - line_discount` |
| `return_quantity` | INT | Yes | Number of returned units (Default: `0`) |
| `landed_cost_bdt` | NUMERIC(12,2)| Yes | Snapshot of the unit landed cost for profit calculation |
| `metadata` | JSONB | No | Item-level notes or attributes |
| `created_at` | TIMESTAMPTZ | Yes | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | Yes | Record update timestamp |

---

### 2.3 `sales_invoice_charges` (Flexible Ledger for Fees)
Replaces hardcoded header columns (`shipping_charge`, `cod_charge`, etc.). Any new fee can be added by inserting a row here, allowing for infinitely scalable charge types.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `invoice_id` | BIGINT | Yes | FK to `sales_invoices.id` |
| `charge_type` | `invoice_charge_type`| Yes | Type of fee (`shipping`, `packing`, `cod_fee`, etc.) |
| `amount` | NUMERIC(12,2)| Yes | The monetary value of the charge |
| `metadata` | JSONB | No | Extra details (e.g., Courier tracking number if `shipping`) |

---

## 3. Core Business Logic & Integration

### 3.1 Financial Formulas
- **Invoice Subtotal**: `Σ sales_invoice_items.line_total_amount`
- **Total Charges**: `Σ sales_invoice_charges.amount`
- **Final Invoice Total**: `Subtotal - discount_amount + Total Charges`
- **Line Net Profit**: `line_total_amount - (quantity * landed_cost_bdt)`

### 3.2 V2 Wallet Integration (Payment Handling)
In V2, payments are routed through the `wallet_ledger` to maintain an immutable accounting trail.
1. When a payment is collected for an invoice, a transaction is posted to the `wallet_ledger` linked to the invoice (or billing profile).
2. The invoice system reacts (via RPC or Postgres Trigger) to recalculate the total paid against the `final_total_amount`.
3. If fully satisfied, the invoice's `payment_status` updates to `paid`.

### 3.3 Posting / Stock Deduction Workflow (RPC)
The process of "Posting" an invoice (`post_sales_invoice` RPC) performs the following inside a single transaction:
1. Validates invoice is in `draft` status.
2. Updates `invoice_status` to `posted`.
3. Loops through `sales_invoice_items`:
   - Decrements `quantity` in `global_stocks` by the item `quantity`.
   - Copies the current `global_stocks.landed_cost` into `sales_invoice_items.landed_cost_bdt`.
4. (Optional) Injects a pending receivable into the accounting ledger.
