# Thrift Lifecycle & Workflow (index)

Schema index: [schema.md](./schema.md) · Tasks: [task.md](./task.md)

```
[ SETUP ] → [ INBOUND ] → [ LABELS ] → [ STOCK ] → [ SALE ] → [ CLOSE / REPORT ]
```

| Stage | Domain |
| :--- | :--- |
| Setup | [settings](./settings/workflow.md) · [catalog](./catalog/workflow.md) |
| Inbound | [inbound](./inbound/workflow.md) — purchase costing (unchanged) |
| Labels | [barcode](./barcode/workflow.md) |
| Stock | [stock](./stock/workflow.md) · [hold](./stock/workflow_hold.md) — unchanged |
| Sale | [sales](./sales/workflow.md) |
| Money | [ledger](./ledger/workflow.md) |
| Reports | [reports](./reports/workflow.md) — PnL lines + live COGS |

## Sales happy path (canon)

1. Add items (may span multiple **inbound** shipments via different stocks).  
2. Channel `IN_STORE` | `ONLINE`.  
3. IN_STORE → generate (`PAID`) → **PnL `DELIVERED`**.  
4. ONLINE → optional `courier_provider_id` + fee **columns** (delivery / COD fee / packing + payers) + optional `meta` tracking → generate (`COD_PENDING` / `delivery_status=PENDING`).  
5. ONLINE after create — **two invoice tracks** (independent): parcel via `update_thrift_delivery_status` (`DELIVERED` → PnL, or RTO); cash via `record_thrift_cod_remittance` (`PAID`). `DELIVERED` ≠ `PAID`.  
6. **Paid return:** `create_thrift_sales_return` for **some or all** lines (partial → `PARTIALLY_RETURNED`).  

Canon detail: [sales/schema.md](./sales/schema.md) · [sales/workflow.md](./sales/workflow.md).  
Margin / shipment P&L: `thrift_sales_pnl_lines` + live COGS.  
Examples: [sales/scenarios.md](./sales/scenarios.md).
