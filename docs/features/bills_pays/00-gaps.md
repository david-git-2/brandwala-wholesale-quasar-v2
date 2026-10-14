# Bills & pays — gaps

Open with [spec.md](spec.md). Types: `not_built` | `doc_wrong` | `sql_split` | `design`.

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| BP5 | not_built | Returns money via credit note; desks live | Return RPCs can shrink totals; after-sales incomplete | After-sales calls `create_bill_adjustment`; excess → cashbook |
| BP2 | design | Rename UI/RPC off `wallet` | Routes `/app/wallet`; module `wallet/` | Copy says cashbook; full rename later |
| BP3 | ~~design~~ | FK `profile_id`; drop `billing_profiles` | **Done (2026-10-12):** customer fields on `profiles`; `billing_profiles` dropped; RPCs use `p_profile_id` | — |
| BP6 | ~~design~~ | Bill paper draft/issued/voided; no new proforma | ~~`proforma_generated` on desk~~ | **Done (2026-10):** backfill migration; desk treats proforma as draft in UI |
| WA4 | ~~design~~ | One pay RPC; remittance `source` | `RemitPayPage` + `CollectPayPage`; remittance RPC → `post_customer_receipt_with_allocations` | **Done (2026-10)** |
| WA13 | not_built | Cheque bounce | Cheques at desk | Reversing pay later |
| WA15 | partial | Inbound shipment AP per **bucket × currency** + FX from pays ([kernel-schema](kernel-schema.md)) | `sync_shipment_ap_bills` still one bill per bucket; mixed currencies → one `mixed_currencies` paper | Split sync: `source_key` `{bucket}:{currency}`; single-currency paper per bill; void orphan slices; issue-all per bucket; AP pay-in on shipment bills |
| BP8 | partial | Credit/debit notes in money kernel (same `bills` table) | Desk: compose notes, parent settlement panel, **Record vendor refund** (`post_vendor_credit_refund` pay-in on AP CN) | Shipment adapter on shortage; AR CN refund; apply CN to next bill (BP11); full CN/DN print |
| BP9 | not_built | Generic source plug + one upsert/issue for adapters | `ap_shipment_id` / `shop_order_id` only | Target columns: [kernel-schema](kernel-schema.md). `source_type` + `source_id` + `source_key`; wrap shipment sync |
| BP10 | not_built | Kernel reads: by source, by profile | Custom FX RPCs on shipment only | `list` pays/docs/balances; features do not sum allocs |
| BP11 | partial | Apply leftover / open credit to next bill | AR collect leftover (US-10); not AP / not credit-note remainder | Same apply RPC for customer and vendor |
| BP12 | not_built | Reverse a pay (bounce / wrong payout) | Collect void exists; AP reverse and cheque bounce open | Reverse pay; bill stays |
| BP13 | not_built | Modular bill compose: any paper, stock optional | Compose = wholesale/walk-in stock lines only; AP only from shipment sync | Slots: party, direction, stock lines, header lines; same issue/print/notes |
| BP14 | not_built | Modular pay desk: receive, pay out, from accounts | Collect / remittance / AP payout as separate tabs/pages | One in/out flow; instrument or cashbook (tenant / profile custody) |
| BP15 | partial | Cash points under tenant cashbook | Points CRUD UI; `cashbook_entries.cashbook_point_id`; `record_ledger_transaction` optional point; delete clears tags | Persist `cashbook_point_id` on `pays` + `pay_instruments`; copy to ledger on collect/AP; point transfer RPC. [kernel-schema](kernel-schema.md) |
| BP16 | partial | Place × currency pots + frozen FX pair on cash lines | Tables: `cashbook_point_pots`, `books_exchange_rates`; entry `quote_currency_code` / `rate_date` / `cashbook_point_pot_id`. Refund still posts BDT @ 1 | `record_ledger_transaction` + refund/collect/AP write cash currency onto the pot; cashbook UI shows pot amounts. Rate table = form default only |

Kernel build: [doc/fix/2026-10-12-bills-pays-kernel-plan.md](../../../doc/fix/2026-10-12-bills-pays-kernel-plan.md).

Done rows (keep IDs): BP1, BP4, BP7, SI5–SI9, SI19, WA1, WA12, WA16 — see git history.
