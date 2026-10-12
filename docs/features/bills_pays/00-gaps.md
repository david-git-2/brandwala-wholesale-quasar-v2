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
| WA15 | partial | Inbound shipment AP per cost bucket + FX from pays | Bucket bills; FX + leftover from pays; restamp on AP payout | AP pay-in on shipment bills |
| BP8 | partial | Credit/debit notes in money kernel (same `bills` table) | Columns + `create_bill_adjustment` / balances; no desk UI | Bill detail issue/print; shipment adapter on shortage |
| BP9 | not_built | Generic source plug + one upsert/issue for adapters | `ap_shipment_id` / `shop_order_id` only | Target columns: [kernel-schema](kernel-schema.md). `source_type` + `source_id` + `source_key`; wrap shipment sync |
| BP10 | not_built | Kernel reads: by source, by profile | Custom FX RPCs on shipment only | `list` pays/docs/balances; features do not sum allocs |
| BP11 | partial | Apply leftover / open credit to next bill | AR collect leftover (US-10); not AP / not credit-note remainder | Same apply RPC for customer and vendor |
| BP12 | not_built | Reverse a pay (bounce / wrong payout) | Collect void exists; AP reverse and cheque bounce open | Reverse pay; bill stays |
| BP13 | not_built | Modular bill compose: any paper, stock optional | Compose = wholesale/walk-in stock lines only; AP only from shipment sync | Slots: party, direction, stock lines, header lines; same issue/print/notes |
| BP14 | not_built | Modular pay desk: receive, pay out, from accounts | Collect / remittance / AP payout as separate tabs/pages | One in/out flow; instrument or cashbook (tenant / profile custody) |
| BP15 | partial | Cash points under tenant cashbook | Points CRUD UI; `cashbook_entries.cashbook_point_id`; `record_ledger_transaction` optional point; delete clears tags | Persist `cashbook_point_id` on `pays` + `pay_instruments`; copy to ledger on collect/AP; point transfer RPC. [kernel-schema](kernel-schema.md) |

Kernel build: [doc/fix/2026-10-12-bills-pays-kernel-plan.md](../../../doc/fix/2026-10-12-bills-pays-kernel-plan.md).

Done rows (keep IDs): BP1, BP4, BP7, SI5–SI9, SI19, WA1, WA12, WA16 — see git history.
