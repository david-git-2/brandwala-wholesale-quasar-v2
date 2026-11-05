# Document numbering

Central **number sequences** for human-facing codes (orders, bills, notes, shipments, stock movements). Same idea as ERP *number sequences* / Odoo *Sequences*.

## API

| Function | Use |
|----------|-----|
| `next_document_number(tenant_id, doc_type, sub_type?, at?)` | Consume next value (atomic) |
| `peek_document_number(...)` | Preview next value without increment |
| `generate_shop_order_number` / `generate_sales_invoice_number` | Legacy wrappers → document numbering |

Thrift (`generate_thrift_*`) stays **outside** this system.

## Config

- **`document_number_configs`** — prefix, period bucket (`day` / `month` / `year` / `none`), padding, `sub_type_mode` (`none` | `invoice_type` | `literal`)
- **`document_number_counters`** — `last_value` per `(tenant_id, doc_type, sub_type, period_key)`

Timezone for buckets: `tenants.preference->>'timezone'`, then config default, then `UTC`.

## Default `doc_type` rows

| doc_type | Example |
|----------|---------|
| `shop_order` | `SO-251105-0042` |
| `sales_invoice` | `INV-WS-2511-0042` |
| `credit_note` / `debit_note` | `CN-WS-2511-0007` |
| `ap_bill` | `AP-2511-0031` |
| `dropship_b2b_invoice` | `DS-2511-0009` |
| `shipment` | `SHP-1042` (`tenant_shipment_id` = numeric suffix) |
| `stock_movement` / `SM` / `RP` / `VR` | `MOV-251105-0187`, etc. |

Historical rows keep old strings (`ORD-*`, `INV-DS-{order_no}`, …). Only **new** rows use the formats above.

## Gaps

If an RPC fails after `next_document_number`, the number is consumed. Gaps are allowed.

## Production deploy

1. Ship DDL + code (`pnpm run backend:prod`).
2. [`scripts/sql/document_numbering_seed_configs.sql`](../../scripts/sql/document_numbering_seed_configs.sql)
3. After phased rollout, [`scripts/sql/document_numbering_backfill_counters.sql`](../../scripts/sql/document_numbering_backfill_counters.sql) (per section)
4. [`scripts/sql/document_numbering_verify.sql`](../../scripts/sql/document_numbering_verify.sql)

Do **not** bulk-update existing `order_no` / `invoice_no` / `movement_no` unless product signs a separate rewrite runbook.

## Rollback

Re-point wrapper bodies to prior SQL from git. Do **not** delete `document_number_counters` rows.

`sales_invoice_counters` and `tenant_scoped_counters` stay in the schema for reference; they are no longer written by the main generators. See [`scripts/sql/document_numbering_rollback.md`](../../scripts/sql/document_numbering_rollback.md).
