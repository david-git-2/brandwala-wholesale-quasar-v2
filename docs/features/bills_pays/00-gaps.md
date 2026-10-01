# Bills & pays — gaps

Open with [01-prd.md](01-prd.md). Types: `not_built` | `doc_wrong` | `sql_split` | `design`.

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| BP1 | ~~doc_wrong~~ | One pack Bills & pays | Two doc folders | **Done (2026-10):** this folder; `docs/features/wallet/` is a pointer |
| BP2 | design | Rename UI/RPC off `wallet` | `web/src/modules/wallet/`, `record_ledger_transaction` | Later; cashbook is the product |
| BP3 | design | FK **`profile_id`**; drop `billing_profiles`; customer `subject_id` → group when 1:1 | `billing_profiles` on bills/pays | Party sync **done** (`20271001130000_profile_party_sync_triggers.sql`); [02 § Profile](02-data-model.md#profile-profiles) |
| BP4 | design | Rename live tables to spec (`bills`, `pays`, `cashbook_*`, …) | `sales_invoices`, `global_payments`, `wallet_accounts`, `universal_wallet_ledger` | [02 rename map](02-data-model.md#rename-map-spec--live) |
| SI5 | design | **No** `sales_invoice_item_costs` / bill-line cost table | Table + line `unit_cost_price` snapshots; margin RPCs | Drop table; GP = shipment P&L only. [RT19](../reporting_treasury/00-gaps.md) |
| SI6 | design | Channel extras in meta | Header COD/fulfill columns | Meta + order; charges = merchant-owed only |
| SI9 | design | Collect/remittance are pays | Two collect writers | Unify ([WA12](#wa12)) |
| SI19 | not_built | Paper + proforma → take + condition | Fulfill create = pack bill | Paper; proforma is not take |
| WA1 | sql_split | Pays schema stub | Ledger in `public.sql` | Split on next pay change |
| WA4 | design | One pay RPC; remittance `source` | Wholesale vs dropship RPCs | Two screens; same allocations |
| WA12 | design | One receipt writer | `create_billing_profile_payment_with_allocations` vs `collect_wholesale_invoice_payment` | Shared core |
| WA13 | not_built | Cheque bounce | Cheques count at desk | Reversing pay later |
| WA15 | not_built | Vendor/cargo AP bill + pay out | Credit is costing only ([PS7](../procurement_stock/00-gaps.md)) | Cash-out vendor/cargo; not customer pay in |

Done rows (keep IDs for other packs): SI3–SI4, SI7–SI8, SI10–SI18, WA5–WA11, WA14 — shipped 2026-09. SI2: never resurrect invoice status `posted`.
