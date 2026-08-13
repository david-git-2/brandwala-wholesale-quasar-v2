# Thrift Ledger (money events) — Schema

Part of [Thrift](../README.md). Index: [../schema.md](../schema.md).

Workflow: [workflow.md](./workflow.md)

**Money events only — not COGS, not company GL.** Shipment-wise profit uses [../sales/schema.md](../sales/schema.md) `thrift_sales_pnl_lines` + live inbound cost.

---

## `thrift_accounting_ledger`

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | BIGSERIAL PK | |
| `tenant_id` | BIGINT | |
| `date` | TIMESTAMPTZ | Event time for money reporting |
| `type` | `thrift_ledger_type` | `REVENUE` \| `EXPENSE` \| `REFUND` \| `LOSS` |
| `source` | `thrift_ledger_source` | `INVOICE` \| `SHIPMENT` \| `OPERATIONAL` |
| `reference_id` | BIGINT | Usually invoice id when `source = INVOICE` |
| `amount` | NUMERIC(12,2) | Always `>= 0`; sign implied by `type` |
| `note` | TEXT | Optional (e.g. `rto_delivery`, `return_courier`, `packing`) |
| `inserted_by` | TEXT | |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

### Immutability rules (sales)

| Event | Allowed |
| :--- | :--- |
| Sale / RTO / return | **Insert** only |
| RTO / customer return | **Must not DELETE** prior `EXPENSE` rows |
| `STAFF_MISTAKE` | Delete all `source = INVOICE` for that invoice |
| COD remittance | **No** ledger row |

### Recommended `note` tags (convention)

| Note | When |
| :--- | :--- |
| `item_revenue` | Create `REVENUE` |
| `shop_delivery` | Shop-paid delivery `EXPENSE` |
| `shop_packing` | Shop-paid packing `EXPENSE` |
| `rto_delivery_loss` | Delivery shop must eat on RTO (was customer-paid at create) |
| `return_courier` | `return_courier_amount` `LOSS` |
| `item_refund` | `REFUND` on close |

---

## Not in this table

| Concern | Where |
| :--- | :--- |
| COGS / margin | Stock → inbound shipment costing |
| Allocated fees per line / shipment | `thrift_sales_pnl_lines` |
| COD outstanding | Invoice `payment_status` + `cod_*` |
