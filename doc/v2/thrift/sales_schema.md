# Thrift Sales Invoice Database Schema (v2)

This document specifies the database schema for **Thrift Counter Sales Invoices** and **Sales Invoice Line Items**, tracking store sales, physical counter checkout, discounts, stock deduction, and real-time profit calculations.

---

## 1. Schema Tables

### 1.1 `thrift_sales_invoices` (Sales Header)

Represents a single sales transaction header recorded at the physical store counter or online desk.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | Yes | FK to `tenants.id` (Tenant scope anchor) |
| `invoice_number` | TEXT | Yes | Unique invoice number per tenant (e.g. `INV-2026-000001`) |
| `customer_name` | TEXT | No | Customer full name |
| `customer_phone` | TEXT | No | Customer contact phone number |
| `date` | TIMESTAMPTZ | Yes | Date and timestamp when the sale was completed |
| `payment_method` | ENUM | Yes | Transaction method: `CASH`, `BKASH`, `NAGAD`, `CARD`, `BANK_TRANSFER` |
| `payment_status` | ENUM | Yes | Payment status: `PAID`, `UNPAID`, `PARTIAL` |
| `total_invoice_amount` | NUMERIC(12,2) | Yes | Final total invoice amount after all item discounts |
| `created_by` | TEXT | Yes | Email/User ID of the cashier/staff who created the invoice (`inserted_by`) |
| `notes` | TEXT | No | Optional counter sale notes |
| `created_at` | TIMESTAMPTZ | Yes | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | Yes | Record update timestamp |

---

### 1.2 `thrift_sales_invoice_items` (Sales Line Items)

Represents individual stock items attached to a sales invoice.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `invoice_id` | BIGINT | Yes | FK to `thrift_sales_invoices.id` (`ON DELETE CASCADE`) |
| `tenant_id` | BIGINT | Yes | FK to `tenants.id` (Tenant scope anchor) |
| `stock_id` | BIGINT | Yes | FK to `thrift_stocks.id` (The thrift product item sold) |
| `sell_price` | NUMERIC(12,2) | Yes | Original selling price before discount |
| `discount_amount` | NUMERIC(12,2) | Yes | Discount amount applied to this line item (default `0.00`) |
| `final_price` | NUMERIC(12,2) | Yes | Computed line price: `sell_price - discount_amount` |
| `quantity` | INTEGER | Yes | Quantity sold (default `1` for single thrift pieces) |
| `landed_unit_cost_at_sale` | NUMERIC(12,2) | Yes | Snapshot of item landed cost at moment of sale (COGS) |
| `net_profit` | NUMERIC(12,2) | Yes | Computed profit: `(final_price - landed_unit_cost_at_sale) * quantity` |
| `created_at` | TIMESTAMPTZ | Yes | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | Yes | Record update timestamp |

---

## 2. Business Logic & Calculations

### 2.1 Final Price & Invoice Total Formula
$$\text{Line Final Price} = \text{sell\_price} - \text{discount\_amount}$$
$$\text{total\_invoice\_amount} = \sum (\text{final\_price} \times \text{quantity})$$

### 2.2 Landed Cost & Net Profit Formula
$$\text{net\_profit} = (\text{final\_price} - \text{landed\_unit\_cost\_at\_sale}) \times \text{quantity}$$

---

## 3. Atomic RPC & Stock Deduction Workflow

The sales invoice creation process executes inside a single Postgres transaction via a Supabase RPC function.

* **RPC Documentation**: [create_thrift_sales_invoice.md](./rpc/create_thrift_sales_invoice.md)

### 3.1 Operations Executed in Transaction
1. **Invoice Header Creation**: Inserts record into `thrift_sales_invoices`.
2. **Line Items Bulk Insertion**: Inserts sold stock line items into `thrift_sales_invoice_items`, snapshotting landed cost (`landed_unit_cost_at_sale`) and computing `net_profit`.
3. **Stock Deduction**: Decrements `quantity` on target `thrift_stocks` records and sets `status = 'SOLD'` (`thrift_stock_status` includes `SOLD`).
4. **Ledger Integration**: Records a revenue transaction in `thrift_accounting_ledger` with `type = 'REVENUE'` and `source = 'INVOICE'`.

---

## 4. Invoice Status & Revert

| `status` | Meaning |
| :--- | :--- |
| `ACTIVE` | Normal posted sale |
| `RETURNED` | Customer return — stock restored |
| `STAFF_MISTAKE` | Cashier/error void — stock restored |

**RPC:** `revert_thrift_sales_invoice(p_tenant_id, p_invoice_id, p_reason, p_reverted_by, p_notes)`

- `p_reason`: `RETURN` \| `STAFF_MISTAKE`
- Only `ACTIVE` invoices can be reverted (idempotent guard)
- Restores each line’s stock: `quantity += sold_qty`, `status = AVAILABLE`
- Inserts `REFUND` ledger row for `total_invoice_amount`
- Sets `payment_status = REFUNDED` and stamps `reverted_at` / `reverted_by` / `revert_reason` / `revert_notes`
