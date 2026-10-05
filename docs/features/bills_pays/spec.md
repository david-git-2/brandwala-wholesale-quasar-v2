# Bills & pays — spec

One money pack. Layers: **bill** · **pay** · **cashbook**. Not a wallet. Numbers: [money-story](money-story.md). Gaps: [00-gaps](00-gaps.md).

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/bills_pays/spec.md` + [00-gaps](00-gaps.md) |
| UI | **Bills**, **Payments**, **Cashbook** in `bills_pays/` (`/app/sales/invoices`, `/app/finance/payments`, `/app/wallet`). Bills: list, manual compose (trade take/condition; walk-in take), print preview, brand settings. |
| SQL | Live names below; pays in `public.sql`; invoice domain split |
| Access | `app`; `shop` merchant statement |
| Model | BW — [business-models](../../architecture/business-models.md) |

## Where to look

| Need | Path |
| :--- | :--- |
| Invoice RPCs | `supabase/schemas/` invoice domain + grep `sales_invoices` |
| Pays / ledger | Grep `global_payments`, `record_ledger_transaction` in `public.sql` |
| Desks (legacy paths) | `sales_invoice/`, `wallet/` module folders |
| Types | `web/src/types/database.types.ts` |

## Rename map (spec → live)

| Spec | Live today |
| :--- | :--- |
| `profiles` | `billing_profiles` |
| `bills` | `sales_invoices` |
| `bill_lines` | `sales_invoice_items` |
| `bill_charges` | `sales_invoice_charges` |
| `pays` | `global_payments` |
| `pay_instruments` | `global_payment_instruments` |
| `pay_allocations` | `invoice_payments` |
| `cashbook_accounts` | `wallet_accounts` |
| `cashbook_entries` | `universal_wallet_ledger` |
| `banks` | `bd_banks` |

FKs: `profile_id` → live `billing_profile_id`; alloc `bill_id` → `invoice_id`. No wallet product.

**Profile** = money party (`profile_type` customer, merchant, …). Not `recipient_profiles` (delivery). `customer_groups` until [BP3](00-gaps.md).

## Scope

| | |
| :--- | :--- |
| Surfaces | `app`; `shop` statement |
| In | Issued bills (take / condition / dropship merchant; AP from inbound). Pay in/out. Cashbook. Shared profile. |
| Out | Delivery paper / proforma; packing slip / COD face; reports; investor withdraw; Koba/thrift; vendor outcome credit on shipment |

## Desks

| Desk | Job | Code route |
| :--- | :--- | :--- |
| Bills | Issue / void / print | `sales_invoice/` — `/app/sales/invoices` |
| Payments | Pay in / out | `wallet/` — `/app/finance/payments` |
| Cashbook | Audit leftover | `wallet/` — `/app/wallet` |

Paper: `draft` / `issued` / `voided`. Money: `due` / `partially_paid` / `paid`. Kind (take / condition / dropship) ≠ status. Trade compose: one kind per bill. Walk-in: take only. Proforma = Delivery paper, not a bill.

`sell` / `total` = tenant sell. COD ≠ sales. Cost never on print / GP.

| Paper | Cash | Sales |
| :--- | :--- | :--- |
| Proforma | No | No |
| Take | After pay | At issue |
| Condition | After pay | When paid |
| Dropship merchant | Remittance | At issue (merchant total) |
| Walk-in | Collect | At issue |
| AP (vendor/cargo/local) | Pay out (`ap_payout`) | Never sales |

**Pay in** → ALLOC to AR bills; remainder → profile cashbook. **Pay out:** merchant leftover (`dispense_middleman_payout_from_tenant`) or AP alloc (`post_ap_payout_with_allocations`). Inbound AP sync: `sync_shipment_ap_bills` ([WA15](00-gaps.md)).

### AP paper (not AR compose)

AR bills use `bill_lines` (item, qty, sell, disc). AP bills have **no** `bill_lines`. Created only by `sync_shipment_ap_bills`. Print snapshot in `bills.channel_meta.ap_paper` (refreshed while unpaid).

| `ap_kind` | Print shows | Not on paper |
| :--- | :--- | :--- |
| `vendor` | Foreign product total, conversion rate, BDT due | SKU / qty lines |
| `cargo` | Weight (kg), foreign price, conversion rate, BDT due | Item grid |
| `local` | Description + amount per local cost row | Sell / discount |

UI: `ApBillPaper` on bill detail/preview when `invoice_type = ap`. **Parties on paper:** vendor/cargo = **From** (issuer); **To** = tenant (payer). Local AP = tenant only (**Payable by**). `profile_id` stays the payee for pay-out. Bills list **We owe** only; no AP compose.

## Stories

### Bills
- [x] US-1 FIFO issue; print; compose on Payments for collect.
- [x] US-1b Trade take/condition; walk-in take; condition held until paid.
- [ ] US-2 Returns `return_quantity`; excess → customer cashbook.
- [ ] US-3 Never issue bill from pay.
- [ ] US-4 Dropship merchant at ship; packing slip ≠ bill.
- [ ] US-5 Delivery paper close → bills ([SI19](00-gaps.md)).

### Pays + leftover
- [ ] US-6 Cashbook via ledger writer only.
- [ ] US-7 One pay-in writer (collect + remittance).
- [ ] US-8 Split tender; cheque bounce v2 ([WA13](00-gaps.md)).
- [ ] US-9 Merchant leftover payout; not ALLOC.
- [x] US-10 Customer overpay / leftover: cashbook at collect; apply on Pay in (FIFO) or later from the payment.
- [x] US-11 Shipment AP auto-sync; vendor outcome credit costing-only.
