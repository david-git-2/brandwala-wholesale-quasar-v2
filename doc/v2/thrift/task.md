# Thrift — Sales economics redesign (docs)

Canon: [README.md](./README.md) · [sales/schema.md](./sales/schema.md) · [sales/workflow.md](./sales/workflow.md) · [sales/scenarios.md](./sales/scenarios.md)

**Constraint:** Do **not** change inbound `thrift_shipments` / stock schemas or costing engine. COGS stays live via `stock_id`.

---

## Done (prior)

- Domain folder split; thin COD + payment track; soft-delete stock; live-cost report RPCs (pre-PnL design)
- Delivery status migration direction (`037` family) — may need follow-up migration for new columns

## Redesign — goal locked

| Piece | Decision |
| :--- | :--- |
| New | `thrift_sales_pnl_lines` |
| New | `thrift_sales_returns` + `thrift_sales_return_items` (partial **or** full post-pay returns) |
| Invoice adds | `return_courier_amount` (RTO only), `close_reason`, `economics_closed_at`; status includes `PARTIALLY_RETURNED`; payment includes `PARTIALLY_REFUNDED` |
| **A. No pickup** | Whole-invoice **RTO** (no return doc) |
| **B. Paid return** | Return docs — select some or all lines; sellable/damaged |
| Ledger | Insert-only on RTO/return; never delete expenses |
| Reports | PnL lines + live COGS; group by `inbound_shipment_id` |

---

## Implementation phases

Focused trackers: [task-rto.md](./task-rto.md) · [task-post-accept-return.md](./task-post-accept-return.md) · [task-advance-risk.md](./task-advance-risk.md)

| # | Work | Status |
| :---: | :--- | :--- |
| 1 | Migration: invoice columns + `thrift_sales_pnl_lines` + returns tables + RLS (`20270802000038`) | Done (schema only — RPCs follow) |
| 2 | `create_thrift_sales_invoice` — Offline PnL; Online money rules | Done (`20270802000039`) |
| 2b | `thrift_courier_providers` — system BD seed (`is_system`) + tenant customs; invoice `courier_provider_id` / `meta` | Done (`20270802000041`–`042` + UI) |
| 3 | `update_thrift_delivery_status` — PnL on `DELIVERED` | Done → [task-rto.md](./task-rto.md) Phase A |
| 4 | `revert_thrift_sales_invoice` — **RTO** + staff mistake | Done → [task-rto.md](./task-rto.md) |
| 5 | `create_thrift_sales_return` — partial/full post-pay returns | Done (`053`) → [task-post-accept-return.md](./task-post-accept-return.md) |
| 6 | Reports RPCs — PnL + live COGS; shipment group by inbound shipment | Period Done (`055`); shipment Already PnL (`052`+`055` cogs_is_loss) |
| 7 | UI — **Mark RTO** · **Return items** · **Returns management** · reports | Done (RTO + Return items + hub + period report cards) |
| 7b | COD advance + customer risk (`057`–`059`) | Done → [task-advance-risk.md](./task-advance-risk.md) |
| 8 | Backfill — existing closed invoices → PnL; optional historic returns | Skipped — historic invoices wiped; no backfill |

---

## Fee / close rules (locked)

### Online fee rows

| Fee | Amount | Payer |
| :--- | :--- | :--- |
| Delivery | `courier_amount` | `courier_paid_by` |
| COD fee | `cod_fee_amount` | `cod_fee_paid_by` |
| Packing (pack / invoice print / packaging) | `packing_amount` | `packing_paid_by` |
| RTO courier | invoice `return_courier_amount` | Shop |
| Post-pay return courier | return header `return_courier_amount` | Shop |

Fees + payers are **invoice columns**. Invoice `meta` is tracking extras only — never fee amounts/payers. Online parcel + COD cash are **two independent tracks on the same invoice** (`delivery_status` vs `payment_status`/`cod_*`); no separate delivery/collection tables in v1.

### PnL pools

| Outcome | Sell | Fee pool |
| :--- | :--- | :--- |
| `DELIVERED` | line value | Shop-paid invoice fees |
| `RTO` | 0 | Full forward delivery + packing + invoice return courier |
| `CUSTOMER_RETURN` | 0 | Keep line’s shop fee alloc + share of **return** courier among returned lines |

### Money vs parcel vs returns

| Track | Where |
| :--- | :--- |
| Parcel | `delivery_status` |
| Cash | `payment_status` + COD remittance |
| No-pickup | Invoice RTO |
| Paid return | `thrift_sales_returns` |
| Economics | `thrift_sales_pnl_lines` |

---

## Out of scope

- Inbound shipment / stock / costing table changes  
- Outbound multi-parcel consignments  
- Partial RTO mid-transit  
- Customer self-serve RMA portal  
- Freezing COGS onto invoice lines  
