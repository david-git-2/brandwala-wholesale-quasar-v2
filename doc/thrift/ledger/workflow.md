# Thrift Ledger (money events) — Workflow

Schema: [schema.md](./schema.md) · Sales: [../sales/workflow.md](../sales/workflow.md)

`thrift_accounting_ledger` = **cash/money events**, not shipment P&L.

---

## Event map

| Flow | Ledger |
| :--- | :--- |
| Create sale | `REVENUE` / `INVOICE` = item total |
| Shop-paid delivery / packing at create | `EXPENSE` / `INVOICE` each (`shop_delivery` / `shop_packing`) |
| COD fee at create (any payer) | **No row** — invoice field + `cod_expected` only |
| Online COD remittance | **No row** — invoice fields only |
| RTO | `REFUND` = item total; `LOSS` for uncollected delivery if needed; `LOSS` for `return_courier_amount`; **keep** prior expenses |
| Customer return (partial/full) | `REFUND` = return refund_amount; `LOSS` for return courier; **keep** prior expenses |
| `STAFF_MISTAKE` | Delete invoice-sourced rows (block if returns exist); **do not** reset invoice counter |
| Stock damaged / stolen (ops) | Optional `LOSS` / `SHIPMENT` |

---

## Why ledger ≠ shipment report

```text
Ledger          → money in/out by type/date/invoice
PnL lines       → sell + allocated shop fees per line + inbound_shipment_id
Live COGS       → compute_thrift_landed_unit_cost(stock_id)
Shipment P&L    → GROUP PnL lines by inbound_shipment_id + sum live COGS
```

**API:** [api/thrift_ledger_api.md](./api/thrift_ledger_api.md)
