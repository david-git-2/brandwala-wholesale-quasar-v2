# Money kernel — PR checklist

**Full spine:** [money-spine-v2](../features/bills_pays/money-spine-v2/README.md).

**Module RPCs:** [04-module-rpcs.md](../features/bills_pays/money-spine-v2/04-module-rpcs.md).

**Tests:** [tests.md](../features/bills_pays/tests.md) · v2 cases [03-tests.md](../features/bills_pays/money-spine-v2/03-tests.md).

**Ops SQL:** [08-AUDIT-RECONCILIATION-AND-RUNBOOK.md](08-AUDIT-RECONCILIATION-AND-RUNBOOK.md). Live SQL: `supabase/schemas/bills_pays/` (may lag v2 until cutover).

---

## Invariants (v2)

| # | Rule |
| :--- | :--- |
| 1 | Features call RPCs only — no table DML on pots / pays / bills / settlements / events |
| 2 | Writers: `SECURITY DEFINER` + `SET search_path` + `assert_kernel_money_access` |
| 3 | Pot `amount` only via `fn_pays_apply` (I4–I5) |
| 4 | Posted pays immutable except void (I6); void needs to-pot credit still present (I20) |
| 5 | Bill parties = payer/payee: `from_profile_id` debtor, `to_profile_id` creditor |
| 6 | Cash pay: from-pot owned by `bill.from_profile_id`; payment same currency; `exchange_rate=1` |
| 7 | AP: pass vendor `to_pot` (kernel default to-pot is wrong for vendor custody) |
| 8 | `credit_note`: no cash pay, no write-off; apply via `rpc_apply_document_settlement` only |
| 9 | CN parties = swap of parent; parent issued/partial/paid/written_off |
| 10 | Settlements: `pay` \| `document`; multi-bill pay = one pays + N pay rows |
| 11 | `paid+due+written_off=total` unless voided (I10–I11) |
| 12 | Totals freeze if bill is settle target **or** document source (I21) |
| 13 | Void settlement may reopen `paid/partial → issued` (T4 reverse paths) |
| 14 | `rpc_void_bill` refuses multi-bill pays — void pays first (I23) |
| 15 | Idempotency: pays unique while **posted**; bills exclude voided; settlements deleted on void |
| 16 | Transfer credit = `round(amount×rate,4)` on post and void (I22) |
| 17 | Lock order: bills by id ASC → pots by id ASC → pays |
| 18 | No feature FK to `bills`/`pays` — use `(source_type, source_id, source_key)` |
| 19 | One AP bill = one currency (feature orchestration) |
| 20 | Do not call `rpc_allocate_invoice_no` from features |

---

## Writers (v2 names)

| Need | RPC |
| :--- | :--- |
| Cash in/out | `rpc_deposit` / `rpc_withdraw` |
| Transfer / FX | `rpc_transfer_same_profile` / `rpc_transfer_p2p` |
| Pay bill(s) | `rpc_pay_bill` / `rpc_pay_bills` |
| Credit note apply | `rpc_apply_document_settlement` / `rpc_void_document_settlement` |
| Reverse / correct cash | `rpc_void_pays` / `rpc_update_pays` (single-bill) |
| Bill lifecycle | `rpc_create_bill` / `rpc_issue_bill` / `rpc_void_bill` / `rpc_write_off_bill` |
| Provision pots | `rpc_provision_cashbook_currency` / `rpc_provision_tenant_cashbook` |

---

## Money PR checklist (before merge)

- [ ] Invariants 1–20 above
- [ ] New writers match [02-actions.md](../features/bills_pays/money-spine-v2/02-actions.md)
- [ ] Golden / v2 case updated if flow changed
- [ ] Audit SQL on local seed — [08](08-AUDIT-RECONCILIATION-AND-RUNBOOK.md)
