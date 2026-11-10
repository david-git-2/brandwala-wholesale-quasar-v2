# Money kernel — PR checklist

**Full spine (layers, flows, cases, gaps, examples):** [money-spine.md](../features/bills_pays/money-spine.md).

**Tests:** [tests.md](../features/bills_pays/tests.md) · **Ops SQL:** [08-AUDIT-RECONCILIATION-AND-RUNBOOK.md](08-AUDIT-RECONCILIATION-AND-RUNBOOK.md). Live SQL: `supabase/schemas/bills_pays/`.

**Live vs target:** Rules below are the contract; DB may lag — see [money-spine § Gaps](../features/bills_pays/money-spine.md#gaps-open).

---

## Invariants (money PR checklist)

| # | Rule |
| :--- | :--- |
| 1 | Issued bill: no silent `UPDATE` of `total_amount`, parties, txn/books currency — use CN/DN children only |
| 2 | AR/AP from direction (`from`/`to` tenant profile), not stored `is_ar` |
| 3 | No new feature FK to `bills` / `pays` — use `(source_type, source_id, source_key)` |
| 4 | One issued AP bill = one currency per bucket |
| 5 | FX frozen on `cashbook_entries` at post time; bill txn/books pair frozen at issue |
| 6 | Tenant cash pays need `cashbook_point_id` |
| 7 | Overpay → profile custody; apply to next bill, not a second invoice |
| 8 | No warehouse / FIFO inside `issue_bill` — feature orchestrates first |
| 9 | No domain-specific payout RPCs in kernel — `source_type` + generic bill/pay |
| 10 | Issued void blocked when settlements or issued CN/DN exist; commercial fix → CN not void |
| 11 | Lifecycle (`draft`/`issued`/`voided`) separate from settlement; `reverse_pay` only moves settlement |
| 12 | Balances from `bill_settlements`; features do not sum allocations in app |
| 13 | Partial unique plug excludes `voided` |
| 14 | Custody vs tenant asset separated on `cashbook_accounts.account_class` |
| 15 | `cashbook_entries` append-only; pots maintained by trigger; transfer locks ordered |
| 16 | Reporting may read `v_kernel_bill_summaries`; not base kernel tables |
| 17 | New money writer RPCs: `pays.idempotency_key` per tenant |
| 18 | All money RPCs follow global lock order; pay alloc locks bill before balance read |
| 19 | `sync_shipment_ap_bills` never silent-updates **issued** standard bill totals |
| 20 | Multi-currency settlement records `fx_realized_books_delta` on `bill_settlements` |

---

## Bill lifecycle

**Lifecycle** (never backward): `draft` → `issued` → `voided` (guarded).

**Settlement** (from `bill_settlements`): `unpaid` → `partial` → `settled`; `reverse_pay` moves settlement only.

| `settlement_kind` | Revenue | Stock |
| :--- | :--- | :--- |
| `take` | At **issue** | Feature commits FIFO **before** `issue_bill` |
| `condition` | When **paid** | Per condition path |
| `null` (AP) | COGS via shipment | None |

**Do not** issue a bill from the pay desk. **Do not** store `paid` on lifecycle.

---

## Pay flows (writers)

| Flow | Live writer | Overflow / notes |
| :--- | :--- | :--- |
| Collect / remittance | `post_customer_receipt_with_allocations` | Custody ledger |
| AP payout | `post_ap_payout_with_allocations` | FX → landed cost refresh |
| Merchant profit | `post_money_out` (`commission`) | `_kernel_post_commission_payout` |
| Balance read | `get_bill_net_balances(bill_id)` | Prefer over `due_amount` cache |
| Apply leftover / CN | `apply_settlement_to_bill` | `bill_settlements` |

---

## Concurrency

| Topic | Rule |
| :--- | :--- |
| Isolation | READ COMMITTED; `FOR UPDATE` inside RPC |
| Lock order | Bills, stock in feature RPCs, shipment lock paths |
| Multi-row | Lock ids `ORDER BY id ASC`; pots `ORDER BY cashbook_point_id, currency_code` |
| Idempotency | `pays.idempotency_key` per tenant |
| Shipment money | Advisory `shipment_money:{id}` |
| Pots | No direct `UPDATE` on `cashbook_point_pots` from writers |

---

## Adapter plug matrix

| Feature | `source_type` | `source_key` (examples) |
| :--- | :--- | :--- |
| Wholesale / POS | `compose` | — |
| Shipment AP | `shipment_cost` | `material:USD`, `freight:GBP` |
| Dropship | `shop_order` | merchant bill / courier AP |
| Commission payout | `commission` | order id |
| Delivery close | `delivery_close` | — |

Legacy FKs (`shop_order_id`, `global_invoice_id`): retire, do not extend.

---

## Money PR checklist (before merge)

- [ ] Invariants 1–20 above
- [ ] `assert_kernel_money_access` in new `SECURITY DEFINER` money RPCs
- [ ] Golden scenario updated if flow changed — [tests.md](../features/bills_pays/tests.md)
- [ ] Audit SQL on local seed — [08](08-AUDIT-RECONCILIATION-AND-RUNBOOK.md)
