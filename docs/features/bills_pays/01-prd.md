# Bills & pays — PRD

One money pack. Layers: **bill** · **pay** · **cashbook**. Not a wallet. Table names: [02](02-data-model.md). Target desks: Bills · Payments · Cashbook ([BP5](00-gaps.md)).

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/bills_pays/` |
| UI | **Bills**, **Payments**, and **Cashbook** desks live in `bills_pays/` (`/app/sales/invoices`, `/app/finance/payments`, `/app/wallet`). Cashbook is read-only audit (directory + ledger). Bills desk: list, **manual compose** (trade FIFO take **or** condition; walk-in take only), **print preview** with `invoice_brands` letterhead, brand settings. Returns still [BP5](00-gaps.md). |
| SQL | Live names in [02 rename map](02-data-model.md#rename-map-spec--live) |
| Access | `app`; `shop` merchant statement |
| Model | BW — [business-models](../../architecture/business-models.md) |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app`; `shop` statement |
| In | Issued bills (take / condition / dropship merchant; **AP** from inbound shipments). Pay in/out. Cashbook leftover. Shared **profile**. |
| Out | Delivery paper / optional proforma. Packing slip / COD face. Reports. Investor withdraw. Koba / thrift. Vendor **outcome** credit (costing) stays on shipment — not a take bill. |

Numbers: [money-story](money-story.md). Gaps: [00-gaps](00-gaps.md).

---

## Desks

| Desk | Job | Code |
| :--- | :--- | :--- |
| Bills | Issue / void / print | `sales_invoice/` — `/app/sales/invoices` |
| Payments | Pay in / pay out | `wallet/` — `/app/finance/payments` |
| Cashbook | Audit leftover | `wallet/` — `/app/wallet` |

Paper status: `draft` / `issued` / `voided`. Money status: `due` / `partially_paid` / `paid`. Kind (take / condition / dropship) is not a status. **Trade compose** picks take or condition for the whole bill. **Walk-in** is take only. Proforma is Delivery paper, not a bill.

`sell` / `total` = tenant sell. COD never sales. Cost never print / GP.

| Paper | Cash | Sales |
| :--- | :--- | :--- |
| Proforma | No | No |
| Take | After pay | At issue |
| Condition | After pay | When paid |
| Dropship merchant | Remittance | Issued merchant total |
| Walk-in | Collect | At issue |
| AP (vendor / cargo / local) | Pay out (`ap_payout`) | Never sales |

**Pay in** (Collect, Remittance) → ALLOC to **AR** bills they owe us. Remainder → **cashbook** on that profile.

**Pay out:** (1) **Merchant leftover** — cashbook only (`dispense_middleman_payout_from_tenant`). (2) **Shipment AP** — ALLOC to open `invoice_type = ap` bills (`post_ap_payout_with_allocations`, `pays.source = ap_payout`). Tenant cash **down**.

Inbound shipment costs sync AP via `sync_shipment_ap_bills` ([WA15](00-gaps.md)); procurement does not post pays ([PS12](../procurement_stock/00-gaps.md)).

---

## Stories

### Bills
- [x] US-1 FIFO issue. Print qty, sell, charges. (`BillComposePage`, `BillPreviewPage`; collect stays on Payments.)
- [x] US-1b Trade compose: Take / Condition switch (one kind per bill). Walk-in stays take. Condition issue: stock `held`, no sale outbound; sales when **paid**. Take issue: sellable leaves inventory. `channel_meta.delivery_kind`.
- [ ] US-2 Returns: `return_quantity` only. Excess paid → customer cashbook.
- [ ] US-3 Never issue a bill from a pay.
- [ ] US-4 Dropship merchant bill at ship. Packing slip ≠ bill. COD ≠ bill.
- [ ] US-5 Delivery paper desk close (dropdown take / condition / return); optional proforma; then take and/or condition bills ([SI19](00-gaps.md)). Same kinds as US-1b.

### Pays + leftover
- [ ] US-6 Cashbook only via ledger writer. Reverse entries. Parent books.
- [ ] US-7 One pay-in writer (collect + remittance). Never rewrite sell.
- [ ] US-8 Split tender. Cheque bounce v2 ([WA13](00-gaps.md)).
- [ ] US-9 Merchant leftover from pay remainder; pay out. Not ALLOC. Live RPC `dispense_middleman_payout_from_tenant` until BP2.
- [ ] US-10 Customer overpay / return leftover → customer cashbook. Next collect may apply it.
- [x] US-11 Shipment **vendor / cargo / local** AP bills auto-sync from procurement costs; pay on Payments **Pay out**. Vendor outcome credit stays costing-only. Not a take bill ([WA15](00-gaps.md)).
