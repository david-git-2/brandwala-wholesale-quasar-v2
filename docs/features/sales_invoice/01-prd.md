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
| When to issue | Staff Issue on desk | When stock leaves (ready/ship), one idempotent issue |
| Print | Invoice voucher (sell, no cost) | Merchant invoice + separate packing slip (COD) |
| Who pays later | Buyer cash / bank / store credit | Courier remittance (or prepaid) — **payment**, not issue |

Do not bill dropship `total_amount` as recipient COD.

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
- [ ] Create/issue via `create_sales_invoice_from_payload` (`issue: true` freezes the bill + stock).
- [ ] Print shows qty, tenant sell, charges owed, total — not cost, not COD.

### US-2: Wholesale returns
- [ ] Sold `quantity` never decreases; `return_quantity` grows.
- [ ] Restock fee off return credit; excess paid → wallet credit.

### US-3: Payments stay off issue
- [ ] Collect cash + store credit + write-off ≤ due — **payments** RPCs.
- [ ] Dropship remittance allocates to **issued** merchant `total_amount` only; leftover vs COD is wallet, not extra sales.

### US-4: Dropship merchant bill
- [ ] One issue path; packing slip is not a `sales_invoices` row.
- [ ] `sell_price_amount` = `unit_sell_price` (merchant). Resell/COD in meta or order.
- [ ] Invoice may stay `issued` + `due` while the parcel is delivered.

---

## Wholesale desk (print)

```text
Qty | Tenant sell | Discount | Line total
Subtotal − discount + merchant-owed charges = NET (sales)
[ Draft ] [ Proforma ] [ Issue ]
```
