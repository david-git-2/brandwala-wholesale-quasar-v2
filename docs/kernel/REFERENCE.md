# Money kernel — reference

**Job:** One screen for money PRs. **Tests:** [tests.md](../features/bills_pays/tests.md). **Product:** [spec](../features/bills_pays/spec.md) · [00-gaps](../features/bills_pays/00-gaps.md) · [money-story](../features/bills_pays/money-story.md). **Ops SQL:** [08-AUDIT-RECONCILIATION-AND-RUNBOOK.md](08-AUDIT-RECONCILIATION-AND-RUNBOOK.md). **Target columns:** [kernel-schema](../features/bills_pays/kernel-schema.md). Live SQL: `supabase/schemas/` (grep RPC names).

**Live vs target:** Rules below are the contract; DB may lag — see gaps. Live often uses `invoice_*`; target uses `lifecycle_status`, `from_profile_id` / `to_profile_id`, `kernel_*` RPC names.

---

## Invariants (money PR checklist)

| # | Rule |
| :--- | :--- |
| 1 | Issued bill: no silent `UPDATE` of `total_amount`, parties, txn/books currency — use CN/DN children only |
| 2 | AR/AP from direction (`from`/`to` tenant profile), not stored `is_ar` |
| 3 | No new feature FK to `bills` / `pays` — use `(source_type, source_id, source_key)` ([BP9](../features/bills_pays/00-gaps.md)) |
| 4 | One issued AP bill = one currency per bucket ([WA15](../features/bills_pays/00-gaps.md)) |
| 5 | FX frozen on `cashbook_entries` at post time; bill txn/books pair frozen at issue ([BP19](../features/bills_pays/00-gaps.md)) |
| 6 | Tenant cash pays need `cashbook_point_id` ([BP15](../features/bills_pays/00-gaps.md)) |
| 7 | Overpay → profile custody; apply to next bill, not a second invoice |
| 8 | No warehouse / FIFO inside `issue_bill` — feature orchestrates first ([BP17](../features/bills_pays/00-gaps.md)) |
| 9 | No domain-specific payout RPCs in kernel — `source_type` + generic bill/pay ([BP24](../features/bills_pays/00-gaps.md)) |
| 10 | Issued void blocked when settlements or issued CN/DN exist; commercial fix → CN not void |
| 11 | Lifecycle (`draft`/`issued`/`voided`) separate from settlement (`unpaid`/`partial`/`settled`); `reverse_pay` only moves settlement |
| 12 | Balances from `bill_settlements`; features do not sum allocations in app ([BP18](../features/bills_pays/00-gaps.md)) |
| 13 | Partial unique plug excludes `voided` ([BP20](../features/bills_pays/00-gaps.md)) |
| 14 | Custody vs tenant asset separated on `cashbook_accounts.account_class` ([BP21](../features/bills_pays/00-gaps.md)) |
| 15 | `cashbook_entries` append-only; pots maintained by trigger; transfer locks ordered ([BP22](../features/bills_pays/00-gaps.md)) |
| 16 | Reporting may read `v_kernel_bill_summaries`; not base kernel tables ([BP23](../features/bills_pays/00-gaps.md)) |
| 17 | **Spine gate:** new money writer RPCs follow [BP25](../features/bills_pays/00-gaps.md) idempotency; [BP18‑c](../features/bills_pays/00-gaps.md) settlements cutover shipped |
| 18 | All money RPCs follow global lock order — [kernel-schema §0b](../features/bills_pays/kernel-schema.md); pay alloc locks bill before balance read |
| 19 | `sync_shipment_ap_bills` never silent-updates **issued** standard bill totals — draft sync only; after issue use CN/DN |
| 20 | Multi-currency settlement records `fx_realized_books_delta` on `bill_settlements` ([BP19](../features/bills_pays/00-gaps.md)); landed cost still from paid AP rates |

---

## Bill lifecycle

**Lifecycle** (never backward):

```text
draft --issue--> issued --void--> voided (guarded)
  |                 |
 void              CN/DN children (issued notes)
```

**Settlement** (derived from `bill_settlements`; live cache: `payment_status`):

```text
unpaid --partial alloc--> partial --full alloc--> settled
                              reverse_pay / debit_note --> partial or unpaid
```

| `settlement_kind` | Revenue | Stock |
| :--- | :--- | :--- |
| `take` | At **issue** | Feature commits FIFO **before** `issue_bill` (target) |
| `condition` | When **paid** | Per condition path |
| `null` (AP) | COGS via shipment | None |

**Do not** issue a bill from the pay desk (spec US-3). **Do not** store `paid` on lifecycle — that is settlement status only.

---

## Pay flows

| Flow | Live writer | Overflow / notes |
| :--- | :--- | :--- |
| Collect / remittance | `post_customer_receipt_with_allocations` | Custody ledger |
| AP payout | `post_ap_payout_with_allocations` | FX → landed cost refresh |
| Merchant profit | `post_money_out` (`source_type=commission`) | `_kernel_post_commission_payout` on money spine ([BP24](../features/bills_pays/00-gaps.md) shipped) |
| Balance read | `get_bill_net_balances(bill_id)` | Target: settlements-based; prefer over `due_amount` cache |
| Apply leftover / CN | `allocate_payment_to_global_invoice` / BP11 paths | Target: `apply_settlement_to_bill` → `bill_settlements` |

Draft/issue/void: `create_sales_invoice`, `issue_sales_invoice`, `sync_shipment_ap_bills`, `issue_shipment_ap_bills`, `create_bill_adjustment` / `issue_bill_adjustment`. Target wrappers: `upsert_draft_bill`, `issue_bill`, `void_bill`. Full bodies: grep `supabase/schemas/`.

---

## Concurrency

| Topic | Rule |
| :--- | :--- |
| Isolation | READ COMMITTED; correctness via `FOR UPDATE` inside RPC |
| Lock | Bills, stock rows (in **feature** RPCs), shipment lock paths before RMW |
| Multi-row | Lock ids `ORDER BY id ASC`; pot transfers `ORDER BY cashbook_point_id, currency_code` |
| Draft races | `upsert_draft_bill` requires matching `version` / `updated_at` ([BP9](../features/bills_pays/00-gaps.md)) |
| Idempotency | `pays.idempotency_key` unique per tenant; duplicate POST returns existing pay ([BP25](../features/bills_pays/00-gaps.md)) |
| Shipment money | Advisory `shipment_money:{id}` lock shared by sync + AP payout ([kernel-schema §0b](../features/bills_pays/kernel-schema.md)) |
| Void replug | Partial unique index on `source_*` excludes voided ([BP20](../features/bills_pays/00-gaps.md)) |
| Pot hotspot | No direct `UPDATE` on `cashbook_point_pots` from writers — trigger on entries ([BP22](../features/bills_pays/00-gaps.md)) |

Shop cart ATP without bill lock: known oversell risk — see [tests Tier 3](../features/bills_pays/tests.md).

---

## Adapter plug matrix

| Feature | `source_type` | `source_key` (examples) |
| :--- | :--- | :--- |
| Wholesale / POS | `compose` | — |
| Shipment AP | `shipment_cost` | `material:USD`, `freight:GBP` |
| Dropship | `shop_order` | `merchant_bill`, `courier_ap` |
| Commission payout | `commission` | order id / slice (target) |
| Delivery close | `delivery_close` | — |

Legacy FKs (`shop_order_id`, `ap_shipment_id`, `global_invoice_id`): retire, do not extend.

---

## Money PR checklist

- [ ] Invariants 1–20 above
- [ ] `assert_kernel_money_access` first in new `SECURITY DEFINER` money RPCs
- [ ] Golden scenario updated if flow changed — [tests.md](../features/bills_pays/tests.md)
- [ ] Audit SQL on local seed — [08](08-AUDIT-RECONCILIATION-AND-RUNBOOK.md)
