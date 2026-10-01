# Reporting — data (read model)

No extra books. Reports **read** invoices, receipts, orders, ledger. Live RPCs: `public.sql`. Money tables: [bills_pays 02](../bills_pays/02-data-model.md).

| Report | Reads | Grain |
| :--- | :--- | :--- |
| Invoice book / profit | Issued `bills` (live `sales_invoices`) + lines + cost snapshot | Bill / line |
| Customer dues | Bill `due_amount` by `profile_id` (live `billing_profile_id`) | Profile |
| Cash in | `pays` (live `global_payments`) by `source` / method | Pay date |
| Courier COD | `shop_orders` COD face + remittance pays | Order |
| Cashbook we owe | `cashbook_entries` (live `universal_wallet_ledger`) by party | Profile / entity |
| Shipment P&L | Shipment landed cost + bill **sell** on those stocks + unsold qty | Shipment |
| Month snapshot | Sums of the above for the month — **separate tiles** | Month |

Pay tables belong to **bills_pays**. Reporting must not `INSERT` them.

---

## KPI math (money-story both deals)

WS bill 1,500 paid 1,500. DS bill 1,500, remittance 2,120, payable 620. Cost 1,000 each.

| Tile | Value |
| :--- | :--- |
| Sales | 3,000 |
| GP | 1,000 |
| Cash in | 3,620 |
| AR | 0 (if both bills paid) |
| Merchant payable | 620 |

If a report shows sales 5,200 (3,000 + 2,200) or cash 3,000, it is wrong.
