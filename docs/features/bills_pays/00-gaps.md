# Bills & pays — gaps

Open with [spec.md](spec.md). Types: `not_built` | `doc_wrong` | `sql_split` | `design`.

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| BP5 | not_built | Rebuild Bills / Payments / Cashbook desks | Desks live; **returns on Bills** and US-6 ledger reverse still open | Returns on Bills; reversal later |
| BP2 | design | Rename UI/RPC off `wallet` | Routes `/app/wallet`; module `wallet/` | Copy says cashbook; full rename later |
| BP3 | design | FK `profile_id`; drop `billing_profiles` | Partly done 2026-10 | Migrate shop_order/demand FKs when `profiles` ready |
| BP6 | ~~design~~ | Bill paper draft/issued/voided; no new proforma | ~~`proforma_generated` on desk~~ | **Done (2026-10):** backfill migration; desk treats proforma as draft in UI |
| WA4 | ~~design~~ | One pay RPC; remittance `source` | `RemitPayPage` + `CollectPayPage`; remittance RPC → `post_customer_receipt_with_allocations` | **Done (2026-10)** |
| WA13 | not_built | Cheque bounce | Cheques at desk | Reversing pay later |

Done rows (keep IDs): BP1, BP4, BP7, SI5–SI9, SI19, WA1, WA12, WA16 — see git history.
