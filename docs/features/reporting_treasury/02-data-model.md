# Reporting — data (read model)

No extra books. Reports **read** invoices, receipts, orders, ledger. Live RPCs: `public.sql`. Receipts shape: [wallet 02](../wallet/02-data-model.md). Bills: [sales_invoice 02](../sales_invoice/02-data-model.md).

| Report | Reads | Grain |
| :--- | :--- | :--- |
| Invoice book / profit | Issued `sales_invoices` + items + cost snapshot | Invoice / line |
| Customer dues | Invoice `due_amount` by `billing_profile_id` | Billed party |
| Cash in | Receipts (`global_payments`) by `source` / method | Receipt date |
| Courier COD | `shop_orders` COD face + remittance receipts | Order |
| Wallet liability | `universal_wallet_ledger` balances by `entity_type` | Entity |
| Shipment P&L | Shipment landed cost + invoice **sell** on those stocks + unsold qty | Shipment |
| Month snapshot | Sums of the above for the month — **separate tiles** | Month |

Payments tables belong to **wallet**. Reporting must not own `INSERT` into them.

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
