# Thrift Sales — Workflow (goal)

Schema: [schema.md](./schema.md) · Examples: [scenarios.md](./scenarios.md)

Invoice-centric sales. **Inbound stock/shipment untouched.** Reports use `thrift_sales_pnl_lines` + live landed cost.

---

## Return situations (read this first)

| # | Real-world | System path |
| :---: | :--- | :--- |
| **A** | Customer **did not pick up**; order comes back with courier | **RTO** — whole invoice (§4) |
| **B** | Customer **paid / received**; wants **some or all** items back | **`create_thrift_sales_return`** — partial or full (§5) |

Do **not** use return docs for no-pickup. Do **not** use whole-invoice RTO for post-pay partial returns.

---

## 1. Create invoice

RPC: [rpc/create_thrift_sales_invoice.md](./rpc/create_thrift_sales_invoice.md)  
Permission: `thrift_sales` / `create`.

### 1.1 UI path

```
Add items → Channel
  → Offline: name + phone → Generate → PAID + PnL DELIVERED
  → Online: address + courier provider pick + fee rows + payers → Generate → COD_PENDING / PENDING (no PnL yet)
```

**Offline:** fees forced `0`; economics close immediately as walk-out `DELIVERED`.  
**Online:** required address **line** + `address_parts.district` + `address_parts.thana` (BD catalogs; `post_code` optional); optional `secondary_phone`; optional courier from `thrift_courier_providers` → `courier_provider_id` + name snapshot; fee rows + payers as **invoice columns**; optional `meta` tracking only; derived `cod_expected`; **no** PnL until parcel `DELIVERED` or RTO.

Never on create: return docs, remittance, COGS freeze, RTO fields (`return_courier_amount` stays `0`, `close_reason` null), fee data inside `meta`.

### 1.2 Offline (`IN_STORE`) — insert contract

```text
UI: items + name + phone → Generate
  → customers upsert
  → invoice PAID / ACTIVE / delivery null / fees 0 / economics_closed_at
  → invoice_items + stock SOLD
  → ledger REVENUE (item total only)
  → pnl_lines DELIVERED (one per line, fees 0)
  → { id, invoice_number }
```

| Table | Action | Locked values |
| :--- | :--- | :--- |
| `thrift_customers` | Upsert by `phone_normalized` when phone present | name, phone, optional address/notes |
| `thrift_invoice_counters` | Allocate | `INV-YYYY-MM-#####` |
| `thrift_sales_invoices` | Insert | `sale_channel=IN_STORE`, `payment_method=CASH`, `payment_status=PAID`, `status=ACTIVE`, all fee amounts `0`, fee payers `null`, `delivery_status=null`, `return_courier_amount=0`, `close_reason=null`, `cod_expected` null/unused, customer snapshots, `economics_closed_at=now()` |
| `thrift_sales_invoice_items` | Insert per line | `stock_id`, sell / discount / `final_price`, `quantity` — **no cost columns** |
| `thrift_stocks` | Update | `status=SOLD` (from `AVAILABLE` or matching customer hold) |
| `thrift_accounting_ledger` | Insert | one `REVENUE` / `INVOICE` = Σ(`final_price × quantity`), note `item_revenue` — **no** fee `EXPENSE` |
| `thrift_sales_pnl_lines` | Insert **one per line** | see §1.2a |

#### 1.2a Offline PnL row (per invoice item)

| Field | Value |
| :--- | :--- |
| `outcome` | `DELIVERED` |
| `sell_amount` | `final_price × quantity` |
| `allocated_shop_delivery` / `cod_fee` / `packing` / `return_courier` | `0` |
| `allocated_fees_total` | `0` |
| `cogs_is_loss` | `false` |
| `return_id` | `null` |
| `inbound_shipment_id` | from `thrift_stocks.shipment_id` at write |
| `stock_id` / `quantity` | from sell line |
| `event_at` / `event_date` | sale time |

Reports later join live COGS via `stock_id` — do **not** store cost on create.

### 1.3 Online (`ONLINE`) — insert contract

| Table | Action | Locked values |
| :--- | :--- | :--- |
| `thrift_customers` | Upsert by phone when present | name, phone, optional secondary_phone, address line, address_parts, notes |
| `thrift_invoice_counters` | Allocate | same |
| `thrift_sales_invoices` | Insert | `sale_channel=ONLINE`, `payment_method=COD`, `payment_status=COD_PENDING`, `status=ACTIVE`, `delivery_status=PENDING`, fee rows + payers, `cod_expected` per schema formula, optional `courier_provider_id` + snapshot `courier_provider`, optional `meta` (tracking only), customer snapshots including `customer_secondary_phone` + `customer_address_parts`, `return_courier_amount=0`, `close_reason=null`, `economics_closed_at=null` |
| `thrift_sales_invoice_items` | Insert per line | same as Offline |
| `thrift_stocks` | Update | `SOLD` |
| `thrift_accounting_ledger` | Insert | `REVENUE` = item total; `EXPENSE` for shop-paid **delivery** and **packing** only (`shop_delivery` / `shop_packing`) |
| `thrift_sales_pnl_lines` | **None** | First write at parcel `DELIVERED` or RTO |

**Courier provider:** load **active system ∪ this tenant’s customs** from `thrift_courier_providers`. On pick: store `courier_provider_id` and snapshot `courier_provider = name`. System rows (`is_system`) are read-only; tenants manage only their own rows.

**Online fee rows (columns — locked):**

| Fee | Amount column | Payer column (`CUSTOMER` \| `SHOP`) | Notes |
| :--- | :--- | :--- | :--- |
| Forward delivery | `courier_amount` | `courier_paid_by` | Required payer iff amount `> 0` |
| COD service fee | `cod_fee_amount` | `cod_fee_paid_by` | Feeds `cod_expected` when customer pays; **no** create-time ledger row |
| Pack / invoice print / packaging | `packing_amount` | `packing_paid_by` | Shop-paid → create-time `EXPENSE` |

**`meta`:** tracking extras only (`tracking_id`, `tracking_url`, …). Do **not** put fee amounts, payers, provider ids, or status fields in `meta`.

**COD fee:** stored on invoice for `cod_expected` / remittance math. **No** create-time ledger row for COD fee (customer- or shop-paid).

### 1.4 Shared server steps

1. Validate channel + fee payers (Offline forces fees `0` / payers null / delivery null).  
2. Upsert customer by normalized phone when present.  
3. Insert invoice + allocate `invoice_number`.  
4. Lock each stock; allow `AVAILABLE` or matching hold; insert sell line; set `SOLD`.  
5. Post ledger (channel rules above).  
6. Offline only: insert PnL `DELIVERED` + set `economics_closed_at`.  
7. Return `{ id, invoice_number }`.

---

## 2. Delivery track (Online)

RPC: [rpc/update_thrift_delivery_status.md](./rpc/update_thrift_delivery_status.md)

Parcel lifecycle is stored **on the invoice** (`delivery_status`). There is no outbound-consignment / separate delivery entity in v1.

```text
PENDING → READY → IN_TRANSIT → DELIVERED     → PnL DELIVERED
                              ↘ RETURNED     → Situation A → RTO close (§4)
```

| Rule | Locked |
| :--- | :--- |
| Write target | `thrift_sales_invoices.delivery_status` (+ RTO fields when closing no-pickup) |
| `DELIVERED` | First time → write `thrift_sales_pnl_lines`; set `economics_closed_at` |
| `DELIVERED` | Does **not** set `payment_status = PAID` |
| `RETURNED` | Whole-invoice RTO (§4) — not a payment remittance |

Independent of §3 cash track (either can move first).

---

## 3. COD remittance (payment track)

RPC: [rpc/record_thrift_cod_remittance.md](./rpc/record_thrift_cod_remittance.md)

Cash settlement is stored **on the same invoice** (`cod_*` + `payment_status`). There is no separate collection document.

| Rule | Locked |
| :--- | :--- |
| Preconditions | Online, `ACTIVE` (or partially returned as applicable), `payment_status = COD_PENDING` |
| Writes | `cod_remitted_amount` / `cod_remitted_at` / `cod_remittance_ref`; typically `payment_status → PAID` (or keep pending / `WRITTEN_OFF`) |
| Ledger / PnL | No new `REVENUE`; **no** PnL change |
| Does not | Mutate `delivery_status` |

“COD queue” = list filter on invoices where remittance still owed — not a second table.

---

## 4. Situation A — No pickup / RTO (whole invoice)

RPC: [rpc/revert_thrift_sales_invoice.md](./rpc/revert_thrift_sales_invoice.md) with `close_reason = RTO`  
(or delivery RPC that performs full RTO close)

1. `delivery_status = RETURNED`, `status = RETURNED`, `payment_status = REFUNDED`, `close_reason = RTO`.  
2. Staff enters invoice `return_courier_amount`.  
3. Restore **all** stocks `AVAILABLE`.  
4. Ledger: `REFUND` = full item total; `LOSS` for uncollected customer delivery if needed; `LOSS` for return courier; **keep** prior shop packing expense.  
5. PnL: **all** lines → `outcome = RTO`.  
6. **No** `thrift_sales_returns` row.

---

## 5. Situation B — Post-pay return (partial or full)

RPC: [rpc/create_thrift_sales_return.md](./rpc/create_thrift_sales_return.md)

### 5.0 UI (separate from create / RTO)

Post-pay return is a **different staff interaction** — do not reuse Create Invoice or “Mark RTO” as the same form.

| Action | UI surface |
| :--- | :--- |
| Create sale | Create invoice page |
| No pickup / RTO | Invoice detail — delivery action → **Mark RTO** (whole order) |
| **Return item(s)** after pay/deliver | Invoice detail — separate **Return items** action / dialog / page |

**Return items UI must let staff:**

1. See only **returnable** lines (not already returned; invoice not RTO-closed).  
2. Multi-select **some or all** lines.  
3. Per line: condition `SELLABLE` \| `DAMAGED`.  
4. Enter this return’s `return_courier_amount`.  
5. Confirm refund total = Σ selected line sell amounts.  
6. Show return history on the same invoice afterward.

Entry point can stay on invoice detail; the flow/RPC is still `create_thrift_sales_return`, never create-invoice and never whole-order RTO unless every line is intentionally selected for a full post-pay return.

### 5.0b Returns management UI (list / hub)

In addition to **Return items** on a single invoice, staff need a **Returns management** surface (list/report) to operate day-to-day without opening every invoice first.

| Surface | Purpose |
| :--- | :--- |
| **Returns list** (module page or sales sub-tab) | Browse / search completed returns by date, `return_number`, invoice number, phone, condition |
| **Return detail** | Lines returned, refund total, return courier, link to invoice + stocks |
| **Invoice detail → Return items** | Create a new return (write path) |
| **Invoice detail → Return history** | Returns already posted on that invoice |

List is mostly **read** (`thrift_sales_returns` + items + invoice joins). Create stays on invoice (or “New return” that first picks an invoice). Optional filters: date range, partial vs full (invoice still `PARTIALLY_RETURNED` vs `RETURNED`), damaged-only.

Not the same as Mark RTO (RTO has no return doc) and not the period P&L sales report (that uses PnL lines).

Preconditions: Offline always; Online only after `DELIVERED` (or Offline desk). Invoice not RTO-closed. Selected lines not already returned.

### 5.1 Steps

1. Staff opens **Return items** and picks **one or more** invoice lines.  
2. Per line: `SELLABLE` or `DAMAGED`.  
3. Enter this return’s `return_courier_amount` (shop loss; default `0`).  
4. Insert `thrift_sales_returns` + `thrift_sales_return_items`; allocate `return_number`.  
5. Restore each stock (`AVAILABLE` / `DAMAGED`).  
6. Ledger: `REFUND` = Σ line refunds; `LOSS` = return courier if `> 0`.  
7. PnL: **only returned lines** → `CUSTOMER_RETURN` (`sell_amount = 0`; keep sunk shop fee alloc on those lines; allocate this return’s courier across returned lines by sell value); set `cogs_is_loss` if damaged.  
8. Invoice status:

| Remaining unreturned lines | `status` | `payment_status` (typical) | `close_reason` |
| :--- | :--- | :--- | :--- |
| Some left | `PARTIALLY_RETURNED` | `PARTIALLY_REFUNDED` (if was `PAID`) | `null` |
| None left | `RETURNED` | `REFUNDED` | `CUSTOMER_RETURN` |

Original delivery/packing on the invoice are **not** refunded to the customer by default (BD thrift default). Only item refund + optional return courier shop loss.

### 5.2 Full invoice via return doc

Selecting **all** lines is valid — same **Return items** UI + RPC as partial. Prefer this over RTO when the customer already received/paid.

---

## 6. Staff mistake

RPC: [rpc/revert_thrift_sales_invoice.md](./rpc/revert_thrift_sales_invoice.md) with `p_reason = STAFF_MISTAKE`.  
Permission: `thrift_sales` / `staff_mistake`.

**Meaning:** Wrong invoice entered — erase the document as if it never happened.  
**Not** RTO (no pickup). **Not** post-pay customer return.

### 6.0 UI

Invoice detail → separate **Staff mistake** action (not Mark RTO, not Return items) → confirm → invoice gone from list.

### 6.1 Preconditions

- Block if any `thrift_sales_returns` exist on the invoice (use return / reverse ops instead; optional admin force later).  
- Do **not** soft-close the invoice (`status`/`close_reason` unused).

### 6.2 Steps

1. Restore **all** line stocks to `AVAILABLE` (hold metadata cleared).  
2. Delete all `thrift_accounting_ledger` rows with `source = INVOICE` for that invoice (REVENUE + any fee EXPENSE — scrub, no `REFUND`/`LOSS`).  
3. Delete PnL lines for that invoice.  
4. Hard-delete invoice (+ items cascade).  
5. Return `{ deleted: true, invoice_number, … }`.

### 6.3 Invoice number / counter (**locked**)

**Do not reset or reuse** `thrift_invoice_counters`.  
Deleting `INV-YYYY-MM-00007` leaves a **gap**; the next create is still `…00008`.  
Never decrement the monthly sequence. Gaps are acceptable for audit simplicity.

---

## 7. Read surfaces vs write ownership (backend)

**All Online mutations for one sale target the invoice (or its return docs).** List hubs are filters / joins only.

| Capability | Write model | RPC / notes |
| :--- | :--- | :--- |
| Advance delivery / Mark RTO | Invoice | `update_thrift_delivery_status` / RTO via revert or delivery close |
| Record COD / write-off | Invoice `cod_*` + `payment_status` | `record_thrift_cod_remittance` |
| Post-pay return | `thrift_sales_returns` (+ items) linked to invoice | `create_thrift_sales_return` |
| Staff mistake | Hard-delete invoice | `revert_thrift_sales_invoice` (`STAFF_MISTAKE`) |
| Invoice list / COD queue / delivery filter | Read | `list_thrift_sales_invoices_paginated` + filters |
| Returns management list | Read | `list_thrift_sales_returns_paginated` |

Do **not** introduce a parallel “delivery order” or “collection” table for v1 Online happy path.

---

## 8. Reporting hook

```text
PnL line (per invoice line, current outcome)
  + live COGS when sell_amount > 0
  + COGS-as-loss when cogs_is_loss
  → period / invoice / inbound shipment P&L
```

See [../reports/workflow.md](../reports/workflow.md).

---

## 9. Out of scope

- Changing inbound shipment / stock / costing schemas  
- Outbound multi-parcel consignments  
- Partial RTO mid-transit (courier splits)  
- Customer self-serve return portal / multi-step approval  
- Freezing COGS on invoice  
- Auto-`PAID` on `DELIVERED`
