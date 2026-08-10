# Thrift — Task: DELIVERED PnL + RTO (refuse)

Parent overview: [task.md](./task.md) · Sibling: [task-post-accept-return.md](./task-post-accept-return.md)

Canon:
- [sales/workflow.md](./sales/workflow.md) §2 (delivery) · §4 (Situation A RTO)
- [sales/schema.md](./sales/schema.md)
- [sales/rpc/update_thrift_delivery_status.md](./sales/rpc/update_thrift_delivery_status.md)
- [sales/rpc/revert_thrift_sales_invoice.md](./sales/rpc/revert_thrift_sales_invoice.md)
- [sales/scenarios.md](./sales/scenarios.md) §3–4

**Constraint:** Do **not** change inbound shipment / stock costing schemas. COGS stays live via `stock_id`.

---

## Owns vs does not own

| Owns | Does **not** own |
| :--- | :--- |
| First `DELIVERED` → write `thrift_sales_pnl_lines` | Record COD / remittance ([sales COD track](./sales/workflow.md) §3 — done) |
| Whole-invoice **Mark RTO** / refuse | Post-accept return docs / Return items UI → [task-post-accept-return.md](./task-post-accept-return.md) |
| Soft close `close_reason = RTO` | Staff mistake erase (already shipped) |
| Retire Online legacy whole **Return** as refuse path | Returns management hub |

```text
ONLINE ACTIVE
  parcel → DELIVERED  → PnL DELIVERED  (Phase A)   ── never sets PAID
         ↘ Mark RTO   → close RTO      (Phase B–C) ── no thrift_sales_returns row
```

**RTO write entry (locked):** `revert_thrift_sales_invoice` with `p_reason = RTO` + `p_return_courier_amount`. Delivery RPC must **not** flip to `RETURNED` without this full close (current reject-on-`RETURNED` stays).

---

## Gap snapshot (today)

| Piece | Status |
| :--- | :--- |
| Schema: `delivery_status`, `close_reason`, `return_courier_amount`, `thrift_sales_pnl_lines` | Present (`038` / `037` family) |
| Advance delivery UI + `update_thrift_sales_delivery_status` | **Done** — PnL on first `DELIVERED` (`048`) |
| `revert` STAFF_MISTAKE | Done (`040`) |
| `revert` RTO economics | **Done** (`049`) |
| UI Mark RTO | **Done** — Online Mark RTO; Record COD separate; legacy Return retired |

---

## Phases

### Phase A — PnL on first `DELIVERED`

**Status:** Complete

**Work**
- Replace/extend `update_thrift_sales_delivery_status` so first transition to `DELIVERED` on Online `ACTIVE`:
  - Insert `thrift_sales_pnl_lines` with `outcome = DELIVERED` (shop-paid fee pool alloc only — see schema / task.md fee pools)
  - Set `economics_closed_at`
  - Idempotent: second call with already-`DELIVERED` must not duplicate PnL
- **Never** change `payment_status` / COD fields

**Targets:** `supabase/migrations/*_thrift_delivery_pnl.sql` (new); repo already calls `update_thrift_sales_delivery_status`

**Acceptance**
- [x] Online invoice: `IN_TRANSIT → DELIVERED` creates one PnL row per sell line
- [x] `economics_closed_at` set; `payment_status` unchanged (`COD_PENDING` can remain)
- [x] Offline invoices still have null `delivery_status` and create-time PnL only
- [x] Re-marking / noop when already `DELIVERED` does not double-insert PnL

---

### Phase B — Backend RTO on `revert_thrift_sales_invoice`

**Status:** Complete · Depends on Phase A for correct “already delivered then refuse?” guardrails if any; RTO itself is mainly for **never delivered / refuse** per §4

**Work**
- Accept `p_reason = RTO` (legacy `RETURN` may map → RTO temporarily; document removal)
- Args: `p_return_courier_amount` (≥ 0), optional notes
- Reject if any `thrift_sales_returns` exist
- Soft close invoice:
  - `status = RETURNED`, `payment_status = REFUNDED`, `close_reason = RTO`
  - Online: `delivery_status = RETURNED`
  - Store `return_courier_amount`
- Restore **all** line stocks → `AVAILABLE`
- Ledger **insert-only:** `REFUND` = item total; `LOSS` uncollected customer-paid forward delivery if needed; `LOSS` return courier; **keep** prior shop packing/expense rows (never delete expenses)
- PnL: **all** lines → `outcome = RTO`, `sell_amount = 0`, fee pool per schema
- Set / refresh `economics_closed_at`
- **No** `thrift_sales_returns` row

**Targets:** new migration replacing `revert_thrift_sales_invoice`; update [sales/rpc/revert_thrift_sales_invoice.md](./sales/rpc/revert_thrift_sales_invoice.md) if arg names drift

**Acceptance**
- [x] Scenario §4 amounts: stock restored; payment `REFUNDED`; delivery `RETURNED`; `close_reason = RTO`
- [x] Shop packing expense retained; return courier posts `LOSS` when &gt; 0
- [x] All PnL lines `RTO`
- [x] Invoice with existing return docs rejected
- [x] Staff mistake path still hard-deletes and never posts REFUND/LOSS

---

### Phase C — UI Mark RTO

**Status:** Complete · Depends on Phase B

**Work**
- Invoice detail (Online, not RTO-closed / not staff-mistake): **Mark RTO** action
  - Input: `return_courier_amount` (+ optional notes)
  - Confirm → `revert` with `RTO`
- Hide/retire Online legacy whole-invoice **Return** (`reason = RETURN`) as the refuse path
- Keep **Staff mistake** separate
- Do **not** open Record COD for refuse

**Targets:** `ThriftSalesInvoiceDetailsPage.vue`, status tracks if needed, `thriftSalesRepository.revertSalesInvoice` args (`reason: 'RTO'`, `returnCourierAmount`)

**Acceptance**
- [x] Staff can Mark RTO without going through COD dialog
- [x] Legacy Online **Return** no longer presented as refuse (or clearly replaced)
- [x] After success: badges show RETURNED / REFUNDED / delivery RETURNED; stock available again

---

### Phase D — Smoke + deploy

**Status:** Pending · Depends on A–C

**Work**
- Smoke matrix from [sales/scenarios.md](./sales/scenarios.md) §3 (delivered remittance independent) + §4 (RTO)
- `npm run deploy:backend` + `backend:types` if signatures changed
- Note: post-accept Online returns blocked until **Phase A** Done — see sibling task

**Acceptance**
- [ ] §4 RTO numbers match ledger + PnL expectations in a manual/scripted check
- [ ] Delivered invoice can still Record COD separately (cash track)

---

## Out of scope

- Post-pay / post-accept return docs and Returns hub → [task-post-accept-return.md](./task-post-accept-return.md)
- Partial RTO mid-transit (courier splits)
- COD remittance changes
- Reports PnL rewrite / backfill of historic closed invoices (parent [task.md](./task.md) phase 6–8)
- Dual RTO implementation inside delivery RPC

---

## Smoke matrix (RTO)

| Case | Expect |
| :--- | :--- |
| Online refuse before deliver | RTO close; PnL all `RTO`; no return doc; packing expense kept |
| Online delivered then… | Refuse is **not** this path — use post-accept return sibling |
| Remittance before/after deliver | Unchanged by RTO work; `DELIVERED` ≠ `PAID` |
| Staff mistake | Still hard-delete; unchanged by RTO phases |
