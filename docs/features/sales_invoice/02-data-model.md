# Sales Invoice — Data model

Live SQL: `supabase/schemas/sales_invoice/`. Types: `web/src/types/database.types.ts`.

This file is the **target bill**. Code today still puts cost, COD-ish charges, and fulfillment on the header/lines — [00-gaps](00-gaps.md).

```text
TENANT books ── sales_invoices ── sales_invoice_items
                     │                    │
                     │                    └── sales_invoice_item_costs  (internal)
                     ├── sales_invoice_charges  (merchant-owed only)
                     └── invoice_payments ← global_payments   (not this module)
Dropship: shop_orders.global_invoice_id → sales_invoices
```

---

## Document vs money

| Column | Values | Job |
| :--- | :--- | :--- |
| `invoice_status` | `draft`, `proforma_generated`, `issued`, `voided` | Does the bill exist? Never `posted`. |
| `payment_status` | `due`, `partially_paid`, `paid`, `settled_with_write_off` | Cash against `total_amount` only |

`invoice_type`: `wholesale`, `retail`, `dropship` — same bill shape.

---

## `sales_invoices` (bill)

**Keep as columns:** `parent_tenant_id`, `issued_by_tenant_id`, `invoice_no`, `invoice_type`, `invoice_date`, `due_date`, `invoice_status`, `billing_profile_id`, `shop_order_id` (nullable), `subtotal_amount`, `discount_amount`, `charges_amount`, `total_amount`, `paid_amount`, `written_off_amount`, `due_amount`, `payment_status`, `note`, `channel_meta` jsonb.

`total_amount` = subtotal − discount + `charges_amount`. Tenant **sales** = this after `issued`.

**`channel_meta` (not sales):** recipient snapshot, `cod_collect_amount`, `collection_source`, courier labels. Expand new channels with keys here.

**Do not keep on the bill:** `fulfillment_status` (parcel lives on the invoice for wholesale today; dropship uses `shop_orders`). Do not store COD collect as `total_amount` or as a sales charge.

---

## `sales_invoice_items` (bill lines)

**Keep:** stock/product, name/barcode snapshots, `quantity`, `sell_price_amount` (**tenant sell**), `line_discount_amount`, `line_total_amount`, `return_quantity`, `line_meta` jsonb.

**`line_meta`:** `resell_price_amount`, per-line COD face. Never copy into `sell_price_amount`.

**Move off the line:** `unit_cost_price` → costing table below.

---

## `sales_invoice_item_costs` (internal)

One row per item at **issue**: `invoice_item_id`, `unit_cost_price`, `costing_locked_at`. Margin reports only. Print must not read this.

---

## `sales_invoice_charges` (merchant-owed)

`charge_type` + `amount` (print, packing, delivery, other). Header `charges_amount` = sum. Courier COD **fee the billed party owes** can be a charge. Courier **collect** cannot.

---

## Payments (out of invoice schema)

Receipts + allocations: [wallet 02](../wallet/02-data-model.md). Invoice rows only store `paid_amount` / `due_amount` / `payment_status` after a receipt allocates.

Wholesale: allocate the collect amount to that buyer bill. Dropship remittance: allocate **min(net remittance, merchant `total_amount`)**. COD − invoice total → ledger, not extra `sell`.

---

## Report split

| Sum | Source |
| :--- | :--- |
| Tenant revenue / bill margin | Issued `total_amount`; cost from `sales_invoice_item_costs` |
| Courier cash | Remittance / COD on **order** or `channel_meta` — not invoice sales (wholesale has no COD face) |
| Reseller profit | Wallet |

Never `SUM(channel_meta)` or `SUM(line_meta)` for sales.
