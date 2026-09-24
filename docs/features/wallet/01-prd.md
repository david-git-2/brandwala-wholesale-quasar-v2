# Universal Wallet, Receipts & Ledger — PRD

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/wallet/` |
| UI | `web/src/modules/wallet/` (ledger). Collect UI still on invoices; remittance still on dropship desks |
| SQL | Stub `supabase/schemas/wallet/`; live ledger in `public.sql`. Receipts: `global_payments` + `invoice_payments` |
| Ledger | Only `record_ledger_transaction` |
| Access | Parent books; `operating_tenant_id` for desk |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` books; `shop` merchant statement |
| In | **Receipts** (money in, all channels). **Split tender** (cash + cheques + bKash in one visit). **Ledger** (balances). **Payouts** (money out vs wallet). **Investor capital** (staff deposit/payout posts tenant + `entity_type = investor` — not a receipt; desks in [investor_capital](../investor_capital/01-prd.md)). |
| Out | Inventing a second ledger. Investor **portal** withdraw. Invoice **issue**. Parcel / COD **face** (order). Tenant **sales** (invoice totals). Cheque **bounce** workflow (v2). |

See [scopes](../../architecture/scopes.md). Bills: [sales_invoice](../sales_invoice/01-prd.md). Target receipts: [02-data-model](02-data-model.md). Gaps: [00-gaps](00-gaps.md). Worked numbers: [money-story](../sales_invoice/money-story.md).

---

## Locked: one money-in system

Industry: one receipts engine. Cash, bank, store credit, **courier remittance** are **sources**, not extra products.

| Layer | Job |
| :--- | :--- |
| Receipt | Cash that **hit you** in one posting. Header total + optional note. Wholesale: buyer cash/bank/store credit. Dropship: courier remittance (net). |
| Instrument line | **How** they paid: cash row, cheque row (bank + date + number), bKash row (trx ref). Sum of lines = receipt total. |
| Allocate | Apply receipt total to open bills (`invoice_payments`). Updates `payment_status`. Not stored on the invoice header. |
| Ledger | Remainder / payables: courier clearing, merchant profit, store credit, tenant cash |
| Payout | Money **out** (merchant withdraw). Opposite of a receipt |

**COD collect** stays on the shop order until the courier remits. Then it is a receipt for **net bank in**, not for the face COD.

---

## Channels (same receipts)

| | Wholesale | Dropship |
| :--- | :--- | :--- |
| Receipt source | Buyer cash / bank / store credit | Courier remittance (or prepaid merchant) |
| Allocate to | Buyer invoice | Merchant invoice (`total` = wholesale to reseller) |
| Remainder | Store credit / unallocated | Ledger: merchant payable (COD net − invoice) |
| Not a receipt | — | Recipient COD face; packing slip |

Wholesale example: bill 1,500; bank 1,500 → receipt 1,500; invoice `paid`; sales 1,500; no merchant leftover.

Dropship example: invoice 1,500; COD 2,200; courier fee 80; remittance 2,120 → receipt 2,120; pay invoice 1,500; ~620 merchant wallet. Sales stay 1,500.

Do **not** credit courier wallet with full COD as “delivered costing” plus a second remittance path.

---

## Personas

| Role | Actions |
| :--- | :--- |
| Cashier | Post receipts; allocate to invoices |
| Treasury | Courier remittance inbox (batch later); merchant payouts |
| Reseller | Statement + withdraw (merchant only; not investor) |
| Auditor | Receipt → allocation → ledger; reverse via reversing entries |

---

## Stories

### US-1: One ledger per counterparty
- [ ] Append-only `universal_wallet_ledger` via `record_ledger_transaction`.
- [ ] Reverse with `reverse_wallet_ledger_entry_for_staff`.
- [ ] Parent books + `operating_tenant_id`. Tenant cash pooled at parent.

### US-2: One receipt posts cash and (optional) allocation
- [ ] Wholesale collect: unified receipt RPC (successor to `create_billing_profile_payment_with_allocations` / `collect_wholesale_invoice_payment`). Source ≠ courier remittance.
- [ ] Dropship remittance: same allocations table; source = remittance; billed to **merchant** profile. Refuses without issued `global_invoice_id`.
- [ ] Allocation ≤ remaining invoice due. Never rewrite `sell_price`. Never issue a bill from a receipt.

### US-2b: Split tender at collect (wholesale / billing-profile)
- [ ] Cashier can add **multiple instrument lines** in one visit: cash, one or more cheques, bKash/bank transfer.
- [ ] Each cheque line: pick [BD bank](../global_reference/02-data-model.md#24-bd_banks), cheque number, cheque date, amount.
- [ ] bKash line: amount + trx reference. Cash line: amount + optional till note.
- [ ] Receipt header: total = sum of lines; one optional note for the whole visit.
- [ ] Same receipt can allocate to one invoice (invoice collect) or many (billing-profile collect).
- [ ] Cheque accepted at desk counts toward cash-in; bounce handling is v2 ([WA13](00-gaps.md)).

### US-3: Merchant payable then payout
- [ ] Profit / remainder credits merchant wallet from the **receipt remainder**, not from order status `delivered` alone.
- [ ] Withdraw via `dispense_middleman_payout_from_tenant` (or successor). No investor withdraw.

---

## Desk (target)

Receipts list: source, amount, methods breakdown, ref → allocate invoices. Collect **page** (`CollectCustomerPaymentPage`): left pane = this visit (instrument lines); right pane = open bills + allocation; sticky footer = received / applied / store-credit leftover / post. **History drawer** (`CustomerPaymentHistoryDrawer`): past receipts read-only; fix cheque/trx typos; void + re-enter for wrong amount/split (append-only ledger). Entity ledger: balances. Payout is a separate action on the merchant wallet.
