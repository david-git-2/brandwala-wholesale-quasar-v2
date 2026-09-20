# Wallet — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| WA1 | sql_split | Stub `supabase/schemas/wallet/` | Live ledger in `public.sql` | Split on next wallet change |
| WA2 | doc_wrong | Persona “reseller withdrawal” vs investor | Dropship payout RPCs exist; **investor** portal has no withdraw | Keep merchant payout only |
| WA3 | doc_wrong | ACs `[ ]` | `record_ledger_transaction` is locked | Tick ledger ACs that match |
| WA4 | design | One receipt RPC; sources include `courier_remittance` | Wholesale collect RPC vs dropship remittance RPCs (payment often `collection_source=recipient`, null billing profile) | Keep **two screens**. Same allocations table. Wholesale receipt = buyer. Dropship receipt = merchant + remittance source |
| WA5 | ~~design~~ | COD face on order; receipt = net bank in | ~~`confirm_dropship_delivered_costing` credited courier COD~~ | **Done (2026-09):** deliver costing saves fields only; cash at remittance |
| WA6 | ~~design~~ | Remainder of remittance → merchant wallet | ~~Profit gated on remittance + separate `transfer_dropship_reseller_profit`~~ | **Done (2026-09):** `record_dropship_courier_remittance` credits merchant remainder; `min(net, due)` allocation |
| WA7 | design | Collect UI is payments, not invoice issue | Collect **page** from Payments list; remittance on dropship finance/management | Keep screens; both must call the receipt RPC |
| WA8 | not_built | Receipt `source` + `shop_order_id` on `global_payments` as in `02-data-model` | `collection_source` on invoice/payment; dropship-specific remittance fields on `shop_orders` | Extend receipts; do not add a second payments product |
| WA9 | ~~not_built~~ | Split tender: `global_payment_instruments` child lines; sum = header `amount` | ~~Single cash amount + method~~ | **Done (2026-09):** `20270918320000_*` + collect RPC `p_instruments`; UI instrument lines |
| WA10 | ~~not_built~~ | Cheque line requires `bd_bank_id`, `cheque_number`, `cheque_date` | ~~No cheque columns~~ | **Done (2026-09):** RPC validation + collect dialog bank/cheque fields |
| WA11 | ~~not_built~~ | Receipt header `note` + line `reference` (bKash trx, till note) | ~~Partial note only~~ | **Done (2026-09):** `p_note` on collect + line `reference` column |
| WA12 | design | Billing-profile collect and invoice collect share one receipt writer | `create_billing_profile_payment_with_allocations` vs `collect_wholesale_invoice_payment` | One RPC (or shared core) posting header + instruments + allocations |
| WA13 | not_built | Cheque bounce / dishonour reversing receipt | v1: cheques count at desk collect; no bounce workflow | Phase 2: reversing entry + optional `cheque_status` on instrument line |
| WA14 | ~~not_built~~ | History drawer + void/re-enter + instrument typo fix on collect desk | ~~Collect dialog only; no edit path~~ | **Done (2026-09):** `list_customer_group_receipts`, `update_payment_instrument_details`, `void_customer_receipt`; `CustomerPaymentHistoryDrawer` |
