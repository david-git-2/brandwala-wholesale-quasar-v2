# Thrift Database Schema (index)

Standalone thrift vertical. Currencies: [`global_reference`](../global_reference/schema.md).

**Canonical field detail** is in domain `schema.md` files.

| Domain | Tables |
| :--- | :--- |
| [settings](./settings/schema.md) | `thrift_settings` |
| [catalog](./catalog/schema.md) | `thrift_categories`, `thrift_types`, `thrift_shelves` |
| [inbound](./inbound/schema.md) | `thrift_shipments`, `thrift_boxes` — **do not change for sales redesign** |
| [barcode](./barcode/schema.md) | `thrift_barcodes` |
| [stock](./stock/schema.md) | `thrift_stocks`, `thrift_pricings`, … — **do not change for sales redesign** |
| [sales](./sales/schema.md) | `thrift_customers`, `thrift_sales_invoices`, `thrift_sales_invoice_items`, `thrift_invoice_counters`, **`thrift_courier_providers`**, **`thrift_sales_pnl_lines`**, **`thrift_sales_returns`**, **`thrift_sales_return_items`** |
| [ledger](./ledger/schema.md) | `thrift_accounting_ledger` |
| [reports](./reports/schema.md) | read models over PnL lines + live COGS + ledger |

Landed cost: [stock/costing.md](./stock/costing.md).  
Scenarios: [sales/scenarios.md](./sales/scenarios.md).

## Enums / text conventions

| Enum / field | Values |
| :--- | :--- |
| `thrift_section` | `MALE`, `FEMALE`, `UNISEX`, `KIDS`, `HOME` |
| `thrift_condition` | `NEW_WITH_TAGS`, `EXCELLENT`, `GOOD`, `FAIR` |
| `thrift_stock_type` | `SINGLE`, `BULK` |
| `thrift_stock_status` | `AVAILABLE`, `RESERVED`, `OUT_OF_STOCK`, `DAMAGED`, `STOLEN`, `SOLD` |
| `thrift_ledger_type` | `REVENUE`, `EXPENSE`, `REFUND`, `LOSS` |
| `thrift_ledger_source` | `INVOICE`, `SHIPMENT`, `OPERATIONAL` |
| PnL `outcome` | `DELIVERED`, `RTO`, `CUSTOMER_RETURN` |
| Invoice `status` | `ACTIVE`, `PARTIALLY_RETURNED`, `RETURNED` |
| Invoice `close_reason` | `RTO`, `CUSTOMER_RETURN` (null if open/partial) |
| Return item `condition` | `SELLABLE`, `DAMAGED` |
| Payment | `PAID`, `COD_PENDING`, `PARTIALLY_REFUNDED`, `REFUNDED`, `WRITTEN_OFF` |

Also: barcode `status`; `sale_channel`; fee payers; `delivery_status`.

## Relationships

```mermaid
erDiagram
  thrift_shipments ||--o{ thrift_boxes : contains
  thrift_shipments ||--o{ thrift_stocks : costs
  thrift_stocks ||--|| thrift_pricings : prices
  thrift_customers ||--o{ thrift_sales_invoices : buys
  thrift_courier_providers ||--o{ thrift_sales_invoices : "optional Online"
  thrift_sales_invoices ||--o{ thrift_sales_invoice_items : lines
  thrift_stocks ||--o{ thrift_sales_invoice_items : sold_as
  thrift_sales_invoices ||--o{ thrift_sales_pnl_lines : economics
  thrift_sales_invoice_items ||--|| thrift_sales_pnl_lines : closes_as
  thrift_sales_invoices ||--o{ thrift_sales_returns : post_pay_returns
  thrift_sales_returns ||--o{ thrift_sales_return_items : lines
  thrift_sales_invoice_items ||--o| thrift_sales_return_items : returned_as
  thrift_shipments ||--o{ thrift_sales_pnl_lines : "inbound_shipment_id"
  tenants ||--|| thrift_settings : defaults
```

## Sales economics (summary)

| Layer | Responsibility |
| :--- | :--- |
| Invoice + items | Sell, fees, COD, delivery, courier provider snapshot; **RTO** no-pickup |
| `thrift_courier_providers` | Global **system** BD seed (`is_system`, immutable) + per-tenant customs |
| Return docs | Post-pay **partial or full** returns |
| `thrift_sales_pnl_lines` | Recognized sell + allocated shop logistics per line |
| Inbound shipment via stock | Live COGS |
| Ledger | Money events only |
