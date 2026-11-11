# Module → money spine v2 RPCs

**For feature modules only.** Call these RPCs. Do not write kernel tables. Do not call `rpc_allocate_invoice_no` (internal).

Signatures: [02-actions.md](02-actions.md).

## Do not call

| Forbidden | Why |
| :--- | :--- |
| Direct `INSERT`/`UPDATE`/`DELETE` on pots, pays, bills, settlements, events | Kernel-owned |
| `rpc_allocate_invoice_no` | Only `rpc_create_bill` may call it |

## Write RPCs (use these)

| When the module needs to… | Call |
| :--- | :--- |
| Put cash into a profile pot | `rpc_deposit` |
| Take cash out of a profile pot | `rpc_withdraw` |
| Move cash between pots (same profile) | `rpc_transfer_same_profile` |
| Move cash between profiles (incl. FX) | `rpc_transfer_p2p` |
| Collect / pay **one** bill | `rpc_pay_bill` |
| Collect / pay **many** bills in one cash move | `rpc_pay_bills` |
| Apply a credit note onto a bill (no cash; same party pair) | `rpc_apply_document_settlement` |
| Undo one credit-note apply | `rpc_void_document_settlement` |
| Reverse a cash move (and its pay settlements) | `rpc_void_pays` |
| Correct a cash move (void + recreate; single-bill only) | `rpc_update_pays` |
| Create a bill (draft; optional `auto_issue`) | `rpc_create_bill` |
| Issue a draft bill | `rpc_issue_bill` |
| Void a bill | `rpc_void_bill` (if on a multi-bill pays → `rpc_void_pays` first) |
| Forgive remaining due | `rpc_write_off_bill` |
| Add a currency pot for a profile | `rpc_provision_cashbook_currency` |
| Ensure tenant collection cashbook/pot | `rpc_provision_tenant_cashbook` |

## Read RPCs (use these)

| When the module needs to… | Call |
| :--- | :--- |
| Load one bill (+ optional lines / settlements / events) | `rpc_get_bill` |
| Search / list bills | `rpc_query_bills` (`p_limit` + `p_cursor`; no totals; keep `p_include` = summary) |
| One pot balance | `rpc_get_pot_balance` |
| Many pot balances | `rpc_get_pot_balances` |
| Profile cash activity | `rpc_profile_transactions` |
| Active bill kinds (registry) | `rpc_list_bill_kinds` |

## Quick map by job

| Job | RPCs |
| :--- | :--- |
| AR collect | `rpc_pay_bill` / `rpc_pay_bills` (customer pot → tenant `to_pot`) |
| AP payout | `rpc_pay_bill` / `rpc_pay_bills` (**pass vendor `to_pot`** — omit defaults to tenant pot; see AP to-pot decision in [00-overview.md](00-overview.md)) |
| Credit note | `rpc_create_bill` (kind `credit_note`) → `rpc_issue_bill` → `rpc_apply_document_settlement` |
| Wallet in/out | `rpc_deposit` / `rpc_withdraw` |
| FX then pay | `rpc_transfer_p2p` then `rpc_pay_bill` (same currency) |
| Undo cash | `rpc_void_pays` (or `rpc_update_pays` for single-bill fix) |
| Undo CN apply | `rpc_void_document_settlement` |
