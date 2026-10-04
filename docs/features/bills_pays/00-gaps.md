# Bills & pays — gaps

Open with [spec.md](spec.md). Types: `not_built` | `doc_wrong` | `sql_split` | `design`.

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| BP5 | not_built | Rebuild Bills / Payments / Cashbook desks | Three desks live (`bills_pays/`); Cashbook read-only; **FIFO composer + branded preview + invoice brands** on Bills; returns not on Bills | Returns on Bills; ledger reverse (US-6) later |
| BP1 | ~~doc_wrong~~ | One pack Bills & pays | Two doc folders | **Done (2026-10):** `spec.md` + `money-story.md` only |
| BP2 | design | Rename UI/RPC off `wallet` | `web/src/modules/wallet/`, `record_ledger_transaction` | Later; cashbook is the product |
| BP3 | ~~design~~ | FK **`profile_id`**; drop `billing_profiles`; customer `subject_id` → group when 1:1 | `bills.profile_id`, `pays.profile_id` → `profiles` | **Partly done (2026-10, `20271006120000_bills_pays_backend_pack.sql`):** FK on bills/pays. `billing_profiles` **kept**: shop orders, demand buckets, costing files, and cashbook still point at it, and `profiles` has no group/tenant/color yet. RPC param `p_billing_profile_id` = `profiles.id` |
| BP4 | ~~design~~ | Rename live tables to spec (`bills`, `pays`, `cashbook_*`, …) | `bills`, `bill_lines`, `bill_charges`, `pays`, `pay_instruments`, `pay_allocations`, `cashbook_accounts`, `cashbook_entries` | **Done (2026-10):** table renames only; columns (`invoice_id`, `payment_id`, `wallet_id`) not renamed. `global_invoices` view dropped |
| SI5 | ~~design~~ | **No** `sales_invoice_item_costs` / bill-line cost table | Dropped table + `unit_cost_price` | **Done (2026-10):** bill COGS reports = 0; shipment P&L uses landed cost. [RT19](../reporting_treasury/00-gaps.md) |
| SI6 | ~~design~~ | Channel extras in meta | `channel_meta.cod_charge_amount`, `channel_meta.fulfillment_status` | **Done (2026-10):** columns dropped; COD not in bill total |
| SI9 | ~~design~~ | Collect/remittance are pays | One writer | **Done** via [WA12](#wa12) |
| SI19 | ~~not_built~~ | Paper close dropdown → take + condition bills; return restocks | `close_preorder_demand_document` on Delivery paper packed tab | **Done (2026-10).** [PS6](../procurement_stock/00-gaps.md). |
| BP6 | design | Bill paper `draft`/`issued`/`voided`; pay `due`/`partially_paid`/`paid` | Live enum still has `proforma_generated`; old rows | Bills desk must not write proforma; leftover rows open as draft |
| BP7 | ~~not_built~~ | Trade compose Take / Condition. `channel_meta.delivery_kind`; condition → `held` on issue | `BillComposePage` + `post_sales_invoice` | **Done (2026-10)** |
| WA1 | ~~sql_split~~ | Pays schema split | `supabase/schemas/bills_pays/` 01–04 | **Done (2026-10):** moved from `public.sql` + old `sales_invoice/` |
| WA4 | design | One pay RPC; remittance `source` | `pays.source` (`customer_cash`, `bank`, `store_credit`, `courier_remittance`) | Two screens; same allocations |
| WA12 | ~~design~~ | One receipt writer | `post_customer_receipt_with_allocations` | **Done (2026-10):** courier remittance calls it; old `create_billing_profile_payment_with_allocations`, `collect_wholesale_invoice_payment`, `record_batch_customer_payment` dropped |
| WA13 | not_built | Cheque bounce | Cheques count at desk | Reversing pay later |
| WA15 | partial | Shipment auto-sync **vendor / cargo / local** AP bills; `post_ap_payout_with_allocations` (`ap_payout`); Payments **Pay out** lists AP pays | Sync RPC + pay writer + desk UI | Backfill existing shipments; void AP on cancel when unpaid only |

Done rows (keep IDs for other packs): SI3–SI4, SI7–SI8, SI10–SI18, WA5–WA11, WA14 — shipped 2026-09. SI5, SI6, SI9, WA1, WA12, BP4 (tables) — 2026-10. SI2: never resurrect invoice status `posted`.
