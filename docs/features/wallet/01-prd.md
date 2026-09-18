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
| In | **Receipts** (money in, all channels). **Ledger** (balances). **Payouts** (money out vs wallet). |
| Out | Inventing a second ledger. Investor withdraw. Invoice **issue**. Parcel / COD **face** (order). Tenant **sales** (invoice totals). |

See [scopes](../../architecture/scopes.md). Bills: [sales_invoice](../sales_invoice/01-prd.md). Target receipts: [02-data-model](02-data-model.md). Gaps: [00-gaps](00-gaps.md). Worked numbers: [money-story](../sales_invoice/money-story.md).

---

## Locked: one money-in system

Industry: one receipts engine. Cash, bank, store credit, **courier remittance** are **sources**, not extra products.

| Layer | Job |
| :--- | :--- |
| Receipt | Cash that **hit you**. Source: `customer_cash` \| `bank` \| `store_credit` \| `courier_remittance` |
| Allocate | Apply up to invoice `total_amount` (tenant sell). Updates `payment_status` |
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

Example: invoice 1,500; COD 2,200; courier fee 80; remittance 2,120 → receipt 2,120; pay invoice 1,500; ~620 merchant wallet. Sales stay 1,500.

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
- [ ] Wholesale collect and dropship remittance call the **same** receipt RPC (source differs).
- [ ] Allocation ≤ remaining invoice due. Never rewrite `sell_price`.
- [ ] Remittance does not require a human “create invoice” step if the merchant bill was issued at ship.

### US-3: Merchant payable then payout
- [ ] Profit / remainder credits merchant wallet from the **receipt remainder**, not from order status `delivered` alone.
- [ ] Withdraw via `dispense_middleman_payout_from_tenant` (or successor). No investor withdraw.

---

## Desk (target)

Receipts list: source, amount, ref → allocate invoices. Entity ledger: balances. Payout is a separate action on the merchant wallet.
