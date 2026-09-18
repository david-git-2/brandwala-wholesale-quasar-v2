# Wallet — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| WA1 | sql_split | Stub `supabase/schemas/wallet/` | Live ledger in `public.sql` | Split on next wallet change |
| WA2 | doc_wrong | Persona “reseller withdrawal” vs investor | Dropship payout RPCs exist; **investor** portal has no withdraw | Keep merchant payout only |
| WA3 | doc_wrong | ACs `[ ]` | `record_ledger_transaction` is locked | Tick ledger ACs that match |
| WA4 | design | One receipt RPC; sources include `courier_remittance` | Wholesale collect RPC vs dropship remittance RPCs (payment often `collection_source=recipient`, null billing profile) | Keep **two screens**. Same allocations table. Wholesale receipt = buyer. Dropship receipt = merchant + remittance source |
| WA5 | ~~design~~ | COD face on order; receipt = net bank in | ~~`confirm_dropship_delivered_costing` credited courier COD~~ | **Done (2026-09):** deliver costing saves fields only; cash at remittance |
| WA6 | ~~design~~ | Remainder of remittance → merchant wallet | ~~Profit gated on remittance + separate `transfer_dropship_reseller_profit`~~ | **Done (2026-09):** `record_dropship_courier_remittance` credits merchant remainder; `min(net, due)` allocation |
| WA7 | design | Collect UI is payments, not invoice issue | Collect dialog on invoice detail; remittance on dropship finance/management | Keep screens; both must call the receipt RPC |
| WA8 | not_built | Receipt `source` + `shop_order_id` on `global_payments` as in `02-data-model` | `collection_source` on invoice/payment; dropship-specific remittance fields on `shop_orders` | Extend receipts; do not add a second payments product |
