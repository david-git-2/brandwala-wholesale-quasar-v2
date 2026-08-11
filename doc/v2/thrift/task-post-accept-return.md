# Thrift — Task: Post-accept return (return claim)

Parent overview: [task.md](./task.md) · Sibling: [task-rto.md](./task-rto.md)

Canon:
- [sales/workflow.md](./sales/workflow.md) §5 · §5.0 · §5.0b
- [sales/schema.md](./sales/schema.md)
- [sales/rpc/create_thrift_sales_return.md](./sales/rpc/create_thrift_sales_return.md)
- [sales/rpc/list_thrift_sales_returns_paginated.md](./sales/rpc/list_thrift_sales_returns_paginated.md)
- [sales/scenarios.md](./sales/scenarios.md) §5

**Constraint:** Do **not** change inbound shipment / stock costing schemas. COGS stays live via `stock_id`.

---

## Prerequisite

| Gate | Why |
| :--- | :--- |
| [task-rto.md](./task-rto.md) **Phase A Done** (PnL on first `DELIVERED`) | Online return claims require parcel `DELIVERED` and PnL rows to update to `CUSTOMER_RETURN` |
| Offline desk returns | No delivery prerequisite; still need this RPC |

**Blocked until task-rto Phase A is Done** for Online happy-path claims.

---

## Owns vs does not own

| Owns | Does **not** own |
| :--- | :--- |
| `create_thrift_sales_return` (partial **or** full line set) | Mark RTO / refuse → [task-rto.md](./task-rto.md) |
| Invoice **Return items** UI + invoice return history | Record COD |
| Returns management list/detail hub | Whole-invoice legacy soft `RETURN` as “claim” |
| PnL `CUSTOMER_RETURN` on returned lines only | Rewriting invoice fee columns / `cod_expected` |

```text
After accept (DELIVERED or Offline PAID)
  → Return items (separate UI)
  → thrift_sales_returns + items
  → ledger REFUND + optional LOSS (return courier)
  → PnL only returned lines → CUSTOMER_RETURN
```

Prefer full **Return items** (all lines) over RTO when the customer already received/paid.

---

## Gap snapshot (today)

| Piece | Status |
| :--- | :--- |
| Tables `thrift_sales_returns` + items + RLS | Present (`038`) |
| `create_thrift_sales_return` RPC | **Done** (`053`) |
| `list_thrift_sales_returns_paginated` | **Done** (`054`) |
| UI Return items / returns hub | **Done** |
| Invoice detail **Return** button | Replaced by **Return items** (legacy whole `RETURN` retired) |

---

## Phases

### Phase A — `create_thrift_sales_return` RPC

**Status:** Complete · migration `20270802000053_create_thrift_sales_return.sql`

**Work**
- Validate invoice: not RTO-closed (`close_reason ≠ RTO`); Offline OK; Online requires `delivery_status = DELIVERED` (or `PARTIALLY_RETURNED` after prior deliver)
- `p_items`: ≥1 `{ invoice_item_id, quantity, condition: SELLABLE|DAMAGED }`; lines not already returned; qty within line
- Insert return header + items; allocate `RET-YYYY-MM-#####` (or locked numbering convention in schema)
- Restore stocks per condition (`AVAILABLE` / `DAMAGED`)
- Ledger insert-only: `REFUND` = Σ line refunds; `LOSS` = `return_courier_amount` if &gt; 0 — **never** delete prior expenses
- PnL: **only** returned `invoice_item_id`s → `CUSTOMER_RETURN` (`sell_amount = 0`; keep sunk shop fee alloc; allocate this return’s courier across returned lines by sell value; `cogs_is_loss` if damaged)
- Invoice status / payment:

| Remaining unreturned lines | `status` | `payment_status` (typical) | `close_reason` |
| :--- | :--- | :--- | :--- |
| Some left | `PARTIALLY_RETURNED` | `PARTIALLY_REFUNDED` (if was `PAID`) | `null` |
| None left | `RETURNED` | `REFUNDED` | `CUSTOMER_RETURN` |

**Targets:** new migration; [sales/rpc/create_thrift_sales_return.md](./sales/rpc/create_thrift_sales_return.md)

**Acceptance**
- [ ] Scenario §5 partial: only selected lines PnL `CUSTOMER_RETURN`; others stay `DELIVERED`
- [ ] Full line selection closes invoice with `close_reason = CUSTOMER_RETURN` (not `RTO`)
- [ ] Reject RTO-closed invoices and already-returned lines
- [ ] Online before `DELIVERED` rejected

---

### Phase B — `list_thrift_sales_returns_paginated`

**Status:** Complete · migration `20270802000054_list_thrift_sales_returns_paginated.sql`

**Work**
- Tenant-scoped paginated list: filters date range, search (`return_number`, invoice #, phone), optional `invoice_id`, optional damaged flag, `skip_count`
- Return header fields per RPC doc; detail via join or get-by-id

**Targets:** new migration; [sales/rpc/list_thrift_sales_returns_paginated.md](./sales/rpc/list_thrift_sales_returns_paginated.md)

**Acceptance**
- [ ] List returns for tenant; filter by invoice id returns history for one sale
- [ ] Permission `thrift_sales` view (or documented equivalent)

---

### Phase C — UI Return items + invoice history

**Status:** Complete

**Work**
- Invoice detail separate **Return items** action (not Create Invoice, not Mark RTO, not Record COD)
- Show only returnable lines; multi-select; per line `SELLABLE` \| `DAMAGED`; enter return courier; confirm refund total = Σ selected sell amounts
- After post: show return history on same invoice
- Replace post-pay use of legacy whole **Return** with this flow

**Targets:** `ThriftSalesInvoiceDetailsPage.vue` (+ dialog/page component); repository + mutation

**Acceptance**
- [ ] Staff cannot confuse Mark RTO with Return items (separate CTAs)
- [ ] Partial return updates badges to `PARTIALLY_RETURNED` / `PARTIALLY_REFUNDED` when applicable
- [ ] History lists return number(s) linked to this invoice

---

### Phase D — UI Returns management hub

**Status:** Complete

**Work**
- Module page or sales sub-route: list/search returns; open return detail (lines, refund, courier, link to invoice/stocks)
- Nav entry under thrift sales (or sibling) with `thrift_sales` view
- Optional “New return” that routes to invoice pick → Return items

**Targets:** new page(s) under `web/src/modules/thrift/sales/`; routes + nav seed if required

**Acceptance**
- [ ] Ops can find a return by return # / invoice / phone without opening every invoice first
- [ ] Detail shows lines + condition + amounts; link back to invoice

---

### Phase E — Smoke + deploy

**Status:** Pending · migrations ready; verify on `backend:reset` / deploy + `backend:types`

**Work**
- Smoke [sales/scenarios.md](./sales/scenarios.md) §5 partial + full via return doc
- Confirm RTO path untouched (no return row on refuse)
- Types regen if RPC signatures are new: `backend:types` after deploy

**Acceptance**
- [ ] Partial + full claim match scenario ledger/PnL expectations
- [ ] Refuse still has zero `thrift_sales_returns` rows

---

## Out of scope

- Mark RTO / refuse economics → [task-rto.md](./task-rto.md)
- COD remittance
- Partial RTO mid-transit
- Customer self-serve RMA portal
- Period sales report redesign (parent [task.md](./task.md) phase 6)

---

## Smoke matrix (post-accept)

| Case | Expect |
| :--- | :--- |
| Partial return after deliver | Return doc; one+ lines `CUSTOMER_RETURN`; invoice `PARTIALLY_RETURNED` |
| All lines returned | `RETURNED` + `close_reason = CUSTOMER_RETURN`; not RTO |
| Damaged condition | Stock damaged; PnL `cogs_is_loss` as schema |
| Online not yet DELIVERED | RPC rejects — use Mark RTO sibling if refuse |
