# RPC: `create_thrift_sales_invoice`

Creates invoice + lines, marks stock sold, posts ledger money events. Offline also writes `thrift_sales_pnl_lines`.

Permission: `thrift_sales` / `create`.  
Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md) §1.

## Behaviour

1. Validate channel (`IN_STORE` \| `ONLINE`) and fee rows (amount `> 0` ⇒ payer required; Offline forces fees `0` / payers null / delivery null).  
2. Upsert customer by normalized phone when phone present (`secondary_phone`, `address`, `address_parts`).  
3. Insert invoice (snapshots including `customer_secondary_phone` / `customer_address_parts`, fees, COD fields; Online `delivery_status = PENDING`; Offline `delivery_status = null`). Online may store `advance_amount` / `advance_note`; `cod_expected = max(0, gross_cod − advance)` where `gross_cod` = items + customer-paid courier + COD fee + packing.  
4. Allocate `invoice_number`.  
5. For each line: lock stock; allow `AVAILABLE` or matching hold; insert sell line; set stock `SOLD`.  
6. Ledger: `REVENUE` = item total; Online only — `EXPENSE` for shop-paid **delivery** and **packing** (notes: `shop_delivery` / `shop_packing`). **No** ledger row for COD fee at create.  
7. **Offline only:** insert PnL lines `outcome = DELIVERED` (all fee allocations `0`); set invoice `economics_closed_at`.  
8. **Online:** no PnL yet (wait for `DELIVERED` or RTO); leave `economics_closed_at` null.  
9. Return `{ id, invoice_number }`.

Does **not** freeze COGS. Does **not** post remittance. Does **not** insert return docs.

## Writes by channel

### Offline (`IN_STORE`)

| Table | Write |
| :--- | :--- |
| `thrift_customers` | Upsert by phone |
| `thrift_sales_invoices` | `CASH` / `PAID` / `ACTIVE`; fees `0`; `delivery_status=null`; `economics_closed_at=now()` |
| `thrift_sales_invoice_items` | One per sold stock |
| `thrift_stocks` | `SOLD` |
| `thrift_accounting_ledger` | `REVENUE` = item total only |
| `thrift_sales_pnl_lines` | One per line — see below |

**PnL row (Offline)**

| Field | Value |
| :--- | :--- |
| `outcome` | `DELIVERED` |
| `sell_amount` | `final_price × quantity` |
| Fee allocations / `allocated_fees_total` | `0` |
| `cogs_is_loss` | `false` |
| `return_id` | `null` |
| `inbound_shipment_id` | from stock at write |
| `event_at` / `event_date` | sale time |

### Online (`ONLINE`)

| Table | Write |
| :--- | :--- |
| `thrift_customers` | Upsert by phone |
| `thrift_sales_invoices` | `COD` / `COD_PENDING` / `ACTIVE` / `PENDING`; fees + optional `advance_amount` / `advance_note`; `cod_expected = max(0, gross_cod − advance)`; optional `courier_provider_id` + name snapshot + `meta` tracking; `economics_closed_at=null` |
| `thrift_sales_invoice_items` | One per sold stock |
| `thrift_stocks` | `SOLD` |
| `thrift_accounting_ledger` | `REVENUE` + shop delivery/packing `EXPENSE` |
| `thrift_sales_pnl_lines` | **None** |

## Key args (conceptual)

| Arg | Notes |
| :--- | :--- |
| `p_tenant_id` | |
| `p_sale_channel` | `IN_STORE` \| `ONLINE` |
| `p_items` | stock_id, sell_price, discount, quantity |
| `p_customer_*` | name / phone / address line / notes |
| `p_customer_secondary_phone` | optional alternate phone |
| `p_customer_address_parts` | JSONB `{ district, thana, post_code }` — Online requires district + thana |
| `p_courier_*` / `p_cod_fee_*` / `p_packing_*` | Online fee **columns** (amount + `CUSTOMER`\|`SHOP` payer); packing = pack/print/packaging |
| `p_courier_provider_id` | optional → system or own-tenant row in `thrift_courier_providers`; RPC snapshots `courier_provider` name |
| `p_courier_provider` | optional override label (rare); prefer snapshot from catalog name |
| `p_meta` | optional JSONB tracking extras only (`tracking_id`, `tracking_url`, …) — **never** fees, payers, provider id, or status |
| `p_advance_amount` | Online only; default `0`. Deducted from COD (`cod_expected = max(0, gross − advance)`). Not a line discount; PnL `sell_amount` unchanged. IN_STORE rejects non-zero. Non-refundable. |
| `p_advance_note` | optional note / payment ref for advance |

## Call

```ts
await supabase.rpc('create_thrift_sales_invoice', { /* … */ })
```
