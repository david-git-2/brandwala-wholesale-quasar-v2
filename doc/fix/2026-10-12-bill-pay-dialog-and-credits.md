# Bill pay dialog + credits (target)

Not as-built. Complements [2026-10-10 inbound money](2026-10-10-shipment-inbound-money.md). Spec: [bills_pays](../../docs/features/bills_pays/spec.md) AP paper / pays, [money-story](../../docs/features/bills_pays/money-story.md) vendor credit, [procurement](../../docs/features/procurement_stock/spec.md) US-7 / lock. Gaps: [WA15](../../docs/features/bills_pays/00-gaps.md), [PS8](../../docs/features/procurement_stock/00-gaps.md).

## Jobs

| Object | Job | Not its job |
| :--- | :--- | :--- |
| Issued AP/AR bill | What was invoiced; print snapshot | Morph after pay when goods/VAT change |
| Pay out / pay in | Cash (or leftover) against that paper | SKU qty, land splits |
| Vendor credit / debit | Later cut: shortage, price drop, VAT refund | Silent edit of paid bill total |
| Shipment cost / outcomes | True landed cost + missing qty | Hiding a bank refund |

**Do not** rewrite a paid 220 bill down to 180. Keep 220 + payment history, then a **credit** and a **refund / leftover**.

## Issue per bucket, then freeze shipment

Today issue runs on **cost lock** (stock must be posted). Target: **Issue invoice** on each cost bucket. That sets that bucket’s AP bill `draft` → `issued`. Pay is allowed only after issue. Other buckets may stay draft.

**After a bucket is issued: no edit or delete of that bucket from the shipment.** Cost rows stay as issued. All later money work is on the **bill**.

| Staff action | Unpaid issued | Any pay on that bill |
| :--- | :--- | :--- |
| **Issue** | Draft → issued. Pay on. Shipment bucket frozen. | Already issued. |
| **Change amount** | **Credit/debit note** on the bill (`document_kind` + `parent_bill_id`). Original total stays. | Same notes. Then refund / leftover / agent. |
| **Delete / void** | On the **bill**: **void**. Shipment cannot delete the bucket. | **Block.** Do not void a paid bill. Credit, then settle. |

Notes live on **`bills`**, not a second table. `bills.note` is a comment only. Same RPCs for AR and AP. Shipment is an adapter: it creates AP drafts from costs and **reads** pays/notes; it does not own money.

Cost lock stays a **unit stamp** freeze. It is not “issue.” You may issue and pay before stock is posted.

Landed cost must **follow the bill credit** (restamp remaining qty, or costing-only outcome credit). Staff must not type 180 back into the frozen shipment bucket.

`bills.note` is **audit only**. It does not replace credit / debit / pay-in.

## Record payment on the bill (UI)

`BillDetailPage` has totals, no pay button, no history. Backend already can pay.

| Need | Use |
| :--- | :--- |
| AP pay out | `post_ap_payout_with_allocations` (FX already) |
| AR collect | `post_customer_receipt_with_allocations` (pass FX like AP if non-BDT) |
| History | `list_invoice_payment_history` (`invoiceRepository.listInvoicePaymentHistory`) — not wired |

**Dialog** (copy currency block from `PayoutPayPage` AP tab):

| Settlement | User enters | System |
| :--- | :--- | :--- |
| BDT | Amount (default = due) | Instrument + alloc = that BDT |
| Not BDT | Foreign amount + rate (BDT per 1) | BDT = foreign × rate (readonly); instruments must match |

Also: paid-on, method + extras, reference, notes. One alloc `{ bill_id, amount }` = this payment’s BDT. Partial pay OK.

Show **Record payment** only when issued, `due_amount > 0`, not void, user can collect. Draft AP still syncs from shipment until **that bucket is issued**. After issue, shipment sync must not change that bill.

After submit: invalidate bill detail + history.

## After pay: shortage, refund, VAT

Worked pattern: billed **220**, paid **220**, received **180**, vendor returns **40**. VAT paid up front, cash back later.

| Event | Shipment | Bills / pays |
| :--- | :--- | :--- |
| Original invoice | Cost rows 220; **Issue** material bucket | Pay out 220; history on bill; bucket frozen |
| Shortage / missing | Qty outcomes only; **no** bucket amount edit | Unpaid → amend. Paid → credit −40 |
| Vendor returns 40 | Costing follows the credit (not a shipment edit) | AP **credit** −40, then settle |
| Cash to us | — | **Pay in** alloc to that credit (or overpay on original bill) |
| Cash to money agent | — | Pay in / leftover on **agent profile**; still link shipment + bill |
| Credit on account | — | 40 leftover on **vendor profile**; apply to next AP bill |
| Refundable VAT | Cost row `is_capitalizable = false` stays | Pay in when certificate returns; do not delete the VAT row after lock |

Industry: **invoice → payment → credit note → refund**. Auditors want four records, not one edited total.

Lock / `costs_locked` = freeze **unit stamp**. Issued bucket freeze = freeze **commercial paper** on the shipment. After pay, do not restamp `ap_paper` from shipment sync.

## Code today vs target

| Today | Target |
| :--- | :--- |
| Issue all AP on `lock_global_shipment_costs` | **Issue** per bucket; lock ≠ issue |
| Sync updates draft **and** can still change issued unpaid totals | After issue: shipment cannot edit that bucket; no sync onto that bill |
| Pay only from Payments desk | Same RPCs from a bill dialog |
| History RPC unused on bill page | List on `BillDetailPage`; optional FX columns on RPC |
| Outcome vendor credit = costing only | Credit on the bill; costing follows that credit |
| WA15: AP pay-in not built | Pay in for VAT / goods refund; middleman float on profile cashbook |

`postCustomerReceipt` client payload does not yet send `settlement_currency_code` / `foreign_amount` / `exchange_rate` (RPC already accepts them).

## Build order

1. Per-bucket **Issue**; freeze that bucket on shipment; pay only when issued.
2. History on bill detail (`list_invoice_payment_history`).
3. Record-payment dialog — **AP first** (copy `PayoutPayPage` submit). Then AR + FX on collect.
4. Unpaid or paid issued: `create_bill_adjustment` (credit/debit). Paid AP: then pay-in / leftover. Costing follows the credit. No silent amend of the original total.

Kernel (notes UI, source plug, leftover apply, reverse pay, returns): [2026-10-12-bills-pays-kernel-plan.md](2026-10-12-bills-pays-kernel-plan.md).
