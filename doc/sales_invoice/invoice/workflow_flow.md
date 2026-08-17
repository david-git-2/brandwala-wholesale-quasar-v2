# Sales Invoice Lifecycle & Workflow Specification

Maps desk-sale stages to schema rules. Schema: [schema.md](./schema.md). Stock ATP: [../stock/schema.md](../stock/schema.md). Cost ownership: [../shipment/schema.md](../shipment/schema.md) §4.

---

## Lifecycle Overview

```
[ STAGE 1: DRAFT ]  ➔  [ STAGE 2: EDIT ]  ➔  [ STAGE 3: POST ]  ➔  [ STAGE 4: SETTLE / OPS ]
  status: draft         status: draft         status: posted        posted (or void / return)
  • Create header       • Lines CRUD        • Snapshot COGS       • Pay / allocate (wallet)
  • Type + parties      • Charges CRUD      • Deduct stock        • Fulfillment updates
  • Soft ATP hold       • Face prices opt.  • Lock sell prices    • Returns (credit doc)
                        • Totals preview    • No auto wallet AR   • Customer vs accounting print
```

**One accounting invoice** for wholesale / retail account / retail direct / dropship. `tenant_id` = parent books; `issued_by_tenant_id` = selling child. Customer-facing different prices = **print/face**, not a second posted invoice. Child UI and parent UI are views of the same row.

---

## Stage 1: Create draft

* Pick `invoice_type` (+ `retail_billing_mode` when retail).
* Set `tenant_id` = parent books owner; `issued_by_tenant_id` = selling child (standalone: both = self).
* `collection_source`, optional profiles (`profile.tenant_id` must equal `issued_by_tenant_id`).
* Snapshot recipient name/phone/address when known.
* `invoice_status = draft`; `payment_status = unpaid`; `fulfillment_status = pending`.
* No stock deduct yet — lines (when added) count toward **draft holds** in ATP.

---

## Stage 2: Edit lines & charges

* Add/update/remove `sales_invoice_items` against **pickable sellable** `global_stocks` (shows location). Mixed shipments / mixed assigned-child batches on one invoice are allowed.
* ATP check on add/update: pickable sellable − other drafts − shop carts ≥ qty.
* Copy / require `shipment_item_id` from stock (required column); snapshot `assigned_child_tenant_id` from the shipment assign.
* Optional `face_unit_price` for customer print; `unit_price` = accounting sell.
* Charges as rows (`sales_invoice_charges`); allow types per invoice type in RPC.
* Optional charge `face_amount` for customer print.
* Recompute header `subtotal_amount`, `charges_total`, `final_total_amount`, `due_amount`.
* `landed_cost_bdt` stays **null** until post.

---

## Stage 3: Post

In one transaction (`post_sales_invoice`):

1. Validate draft + situation rules (billing profile required except retail direct).
2. Re-check ATP; only `availability = sellable` and location `is_pickable`.
3. `invoice_status → posted`; set `posted_at` / `posted_by`.
4. Per line: snapshot provisional `landed_cost_bdt` from living shipment stamp; decrement stock qty.
5. Freeze accounting sell prices and charge amounts.
6. **Wallet:** stub-skip receivable day one — stock + snapshot only.

After post: no silent rewrite of `unit_price` or `landed_cost_bdt`. Shipment cost revision updates the **stamp** only; actual P&L is report join.

**Void:** only when unpaid (or policy-equivalent); restore stock; clear draft-style impact; set `void`.

---

## Stage 4: Settle, fulfillment, returns, print

### Pay / allocate

* Explicit Pay action posts `wallet_ledger`:
  * `source_type = 'sales_invoice'`
  * `source_id = sales_invoices.id`
* Refund / return cash: `source_type = 'sales_invoice_return'`, `source_id = sales_invoice_returns.id`.
* Recompute `paid_amount`, `due_amount`, `payment_status`.
* Settlement discount / courier collected adjust balances per schema fields — not a second invoice.
* Post invoice itself never posts wallet (stub-skip) — [schema §5.2](./schema.md).

### Fulfillment

* Update `fulfillment_status` only (`pending` → `packed` → `shipped` → `delivered`).
* Ops signal — does **not** change margin or AR.

### Returns

* Create `sales_invoice_returns` + lines (credit-note style).
* **Stock (locked):** post a `return_inbound` movement in the same txn — [stock/workflow_flow.md](../../procurement_stock/stock/workflow_flow.md) Stage 5. Default **`held` @ returns** location. Return UI records **grade** + **availability** (sell gate). Do **not** increment the original sellable row; staff may re-bin / re-grade later via warehouse movements.
* Bump line `return_quantity`.
* Dropship may set `return_face_amount` ≠ `return_amount`.
* Recompute invoice due / payment_status when credit applies.

### Print modes

| Mode | Audience | Numbers |
| :--- | :--- | :--- |
| `customer` (child UI) | End customer / selling sister | Child `invoice_brands`; `face_unit_price` / `face_amount` (fallback to accounting) |
| `accounting` (parent UI) | Desk / finance | `unit_price`, charge `amount`, AR totals, COGS |

Same `sales_invoices.id`. Never post a second sales invoice only to show different face numbers or to split mixed stock.

---

## Explicit non-goals

* Full GL / chart of accounts on post
* Rewriting provisional COGS after shipment cost revision
* Thrift counter sales on this pack
* Soft-allocation qty as a second warehouse
* Day-one dedicated hold table (query draft lines instead)
* Flipping warehouse `availability` to `held` for draft invoices or shop carts
* Direct increment of the original sellable stock row on return (use `return_inbound`)
* A second customer-invoice table, or auto-split of one mixed sale into per-sister / per-shipment invoices

---

## Open (see issues)

Exact RPC names/args, migration rename `global_invoices*` → `sales_invoices*`, treasury tables vs wallet-only allocate: [SALES_INVOICE_ISSUES.md](../../SALES_INVOICE_ISSUES.md). Return stock path is **locked** (`return_inbound` movement).

**Wallet keys locked:** Pay → `sales_invoice` + invoice id; refund → `sales_invoice_return` + return id.
