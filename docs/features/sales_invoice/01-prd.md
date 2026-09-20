# Sales Invoice — Product Requirements Document (PRD)

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/sales_invoice/` |
| UI | `web/src/modules/sales_invoice/`, `invoice_shared/` |
| SQL | **Split** `supabase/schemas/sales_invoice/` |
| Access | `app`; invoices owned at company |
| Money | Invoice = **bill**. Payments = cash applied later. Cost = internal snapshot, not the bill. |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` desk |
| In | Company sales bill (`sales_invoices`): freeze tenant sell, issue/void, print voucher. Wholesale desk create. Dropship merchant bill (same table). Link `shop_order_id` when from dropship. |
| Out | Recording payment (collections / remittance). Dropship **packing slip** (COD face). Shop cart. Parcel status. Reseller wallet payout. Recipient as its own pack. |

See [scopes](../../architecture/scopes.md). Target columns: [02-data-model](02-data-model.md). Gaps vs code: [00-gaps](00-gaps.md). Receipts plan: [wallet 01](../wallet/01-prd.md). Worked numbers: [money-story](money-story.md).

---

## Locked money rules

| Field | Meaning | Sales report |
| :--- | :--- | :--- |
| `sell_price_amount` / `total_amount` | **Tenant sell** — wholesale buyer price, or dropship **merchant** price | Yes |
| Merchant-owed charges | Print/packing/delivery **the billed party owes** | Yes (in total) |
| COD collect, reseller face / resell | Channel extra (`channel_meta` / `line_meta` or the shop order) | **Never** |
| `unit_cost_price` | Internal snapshot at issue | Margin only; **not on print** |

Issue does not post cash. `payment_status` changes only via **receipts** (wallet module), including courier remittance as a source.

---

## Channels (same invoice)

| | Wholesale | Dropship |
| :--- | :--- | :--- |
| Billed | Buyer (`billing_profile`) | Reseller (`billing_profile`) |
| Stock | FIFO sellable at Issue | Held picks; deduct those lots at ship |
| When to issue | Staff **Issue** on invoice desk (`create_sales_invoice_from_payload`) | **Mark as shipped** (`ship_dropship_order_and_issue_merchant_bill`) |
| Print | Invoice voucher (sell, no cost) | Merchant voucher + packing slip (COD, not a bill) |
| Cash-in | Collect on invoice detail | Courier remittance after delivered |
| Leftover | Unallocated / store credit | Merchant wallet |

Do not bill dropship `total_amount` as recipient COD. Do not issue dropship from the trade-bill composer (`CreateWholesaleInvoicePage`, route `/app/sales/invoices/create`). Numbers: [money-story](money-story.md).

**Trade desk UI:** Staff see **Invoice**. Type chip **Trade** or **Retail** on the same composer (`/app/sales/invoices/create`, `?type=retail` for new retail). Storage: Trade = `invoice_type = wholesale`; Retail on account = `retail` + `retail_billing_mode = account`. Walk-in stays the list dialog (`direct`). Dropship stays on ship.

**Invoice browse UI:** `InvoicesListPage` is a **row list** (customer + money per row), not the ops spreadsheet `q-table`. Exception to [ui-standards](../../guides/ui-standards.md) table rule for this page only.

**Invoice desk UI (create / details):** Shared emerald desk workspace — sticky chrome, parties strip, dense line grid, sticky totals panel. Theme tokens (`--bw-theme-*`), not cream Georgia paper. Heading **Invoice** + type chip (Trade / Retail / Walk-in / Dropship). Status and payment are chips in chrome, not a stepper. Issue / collect / remittance live in chrome. List/report open **issued/voided** bills at `/app/sales/invoices/:id`. Trade and retail-on-account **draft/proforma** stay on `/create?id=`. Cost and margin are off the bill unless staff open **Margin**. **Print** = preview sheet only (`InvoicePreviewPage` / `InvoicePrintSheet`).

---

## Personas

| Role | Actions |
| :--- | :--- |
| Desk staff | Draft/proforma, FIFO search, issue wholesale, print voucher (no cost) |
| Cashier | Collect / write-off (**payments**, not this module’s issue) |
| Wholesale manager | Discounts, returns against issued lines |
| Admin | Void unpaid, invoice brand |
| Auditor | Issued totals + allocated payments; margin from cost snapshot |

---

## Stories

### US-1: FIFO stock search and issue
- [ ] Search ranks sister allocation then warehouse FIFO.
- [ ] Create/issue via `create_sales_invoice_from_payload` (`issue: true` freezes the bill + sellable stock). Wholesale/retail desk only.
- [ ] Print shows qty, tenant sell, charges owed, total — not cost, not COD.

### US-2: Wholesale returns
- [ ] Sold `quantity` never decreases; `return_quantity` grows.
- [ ] Restock fee off return credit; excess paid → wallet credit.

### US-3: Payments stay off issue
- [ ] Wholesale collect: cash / bank / store credit + write-off ≤ due — `create_billing_profile_payment_with_allocations`.
- [ ] Dropship remittance: net bank in; allocate ≤ merchant `total_amount`; leftover is wallet, not extra sales.

### US-4: Dropship merchant bill
- [ ] One issue path (`issue_dropship_tenant_b2b_invoice` inside the ship RPC); packing slip is not a `sales_invoices` row.
- [ ] Lines from `shop_order_item_stock_picks` (`held_stock_id`, pick qty). `sell_price_amount` = merchant `unit_sell_price`. Resell/COD in meta or order.
- [ ] `collection_source` = `billing_profile`. One invoice per `shop_order_id`.
- [ ] Invoice may stay `issued` + `due` while the parcel is delivered.

---

## Trade desk (compose)

Route: `/app/sales/invoices/create` (legacy `/create-wholesale` redirects). Sticky chrome + desk body — not a three-step status wizard. Print voucher is separate preview route.

```text
Parties: brand | bill-to
Lines: Qty | Tenant sell | Discount | Line total
Totals panel: Subtotal − discount + merchant-owed charges = NET (sales)
Chrome actions: Save draft | Save | Make proforma | Issue (by status)
```
