# Thrift Reports — Workflow (goal)

Schema: [schema.md](./schema.md) · Worked examples: [../sales/scenarios.md](../sales/scenarios.md)

**Engine:** `thrift_sales_pnl_lines` + live inbound COGS. Do not invent COGS from ledger.

---

## 1. Invoice / period P&L

1. Filter PnL lines by `event_date` (or invoice `date` for cash-sales views — prefer **event_date** for RTO timing).  
2. Optional filter: channel, outcome, close_reason.  
3. Per line:

```text
cogs = sell_amount > 0 ? landed(stock_id) * quantity : 0
net  = sell_amount - cogs - allocated_fees_total
```

4. Roll up: revenue, cogs, fees (by type), net, counts by outcome.  
5. COD outstanding: separate query on `ACTIVE` + `COD_PENDING` invoices (not from PnL).

RPC: [rpc/get_thrift_sales_report.md](./rpc/get_thrift_sales_report.md)

---

## 2. Inbound shipment P&L

1. Filter PnL lines where `inbound_shipment_id = :id` (and optional period on `event_date`).  
2. Same COGS rule.  
3. Summary: units, sell, cogs, allocated fees, net, RTO loss share, return share.

```text
shipment net = Σ (sell_amount − cogs − allocated_fees_total)
```

RPC: [rpc/get_thrift_shipment_sales_report.md](./rpc/get_thrift_shipment_sales_report.md)

---

## 3. Money movement (ledger)

Sum `thrift_accounting_ledger` by `type` / day — revenue, expense, refund, loss.  
Do **not** treat this as COGS margin.

---

## 4. Dashboard

Compact: period net from PnL engine + COD outstanding + recent RTO count/loss.

RPC: [rpc/get_thrift_dashboard_metrics.md](./rpc/get_thrift_dashboard_metrics.md)

---

## Example (mixed inbound shipments)

Invoice lines: shipment1 = 1000, shipment2 = 2000; shop pack 10; customer delivery 100 + COD fee 50.

**DELIVERED:** pack allocates 3.33 / 6.67; delivery/COD not shop expense.  
**RTO** with return courier 80: sell 0; pools delivery 100 + pack 10 + return 80 → shares ⅓ / ⅔ as shipment losses.

---

## RPCs

- [rpc/get_thrift_sales_report.md](./rpc/get_thrift_sales_report.md)  
- [rpc/get_thrift_shipment_sales_report.md](./rpc/get_thrift_shipment_sales_report.md)  
- [rpc/get_thrift_dashboard_metrics.md](./rpc/get_thrift_dashboard_metrics.md)
