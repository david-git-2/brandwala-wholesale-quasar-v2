# Thrift — Task: COD advance + customer risk

Parent overview: [task.md](./task.md) · Canon: [sales/workflow.md](./sales/workflow.md) · [sales/schema.md](./sales/schema.md)

RPCs:
- [sales/rpc/create_thrift_sales_invoice.md](./sales/rpc/create_thrift_sales_invoice.md)
- [sales/rpc/get_thrift_customer_sales_risk.md](./sales/rpc/get_thrift_customer_sales_risk.md)
- [sales/rpc/create_thrift_sales_return.md](./sales/rpc/create_thrift_sales_return.md)
- [sales/rpc/revert_thrift_sales_invoice.md](./sales/rpc/revert_thrift_sales_invoice.md)

**Constraint:** Advance is Online COD only; non-refundable on RTO / post-pay return. Offline always `advance_amount = 0`.

---

## Owns vs does not own

| Owns | Does **not** own |
| :--- | :--- |
| `advance_amount` / `advance_note` on invoice | RTO close mechanics → [task-rto.md](./task-rto.md) |
| `get_thrift_customer_sales_risk` + create risk panel | Post-accept return docs → [task-post-accept-return.md](./task-post-accept-return.md) |
| `cod_expected = max(0, gross − advance)` | UX friction backlog → [ux-friction-fix.md](./ux-friction-fix.md) |
| Ledger `REFUND` excludes advance share | Historic PnL backfill → skipped (invoices wiped; parent phase 8) |

---

## Gap snapshot

| Piece | Status |
| :--- | :--- |
| Schema `advance_amount` / `advance_note` (`057`) | Present |
| `create_thrift_sales_invoice` advance → `cod_expected` (`057`) | Present |
| `get_thrift_customer_sales_risk` (`058`) | Present |
| RTO / return ledger clamp advance (`059`) | Present |
| Create UI risk panel + required advance | Present |
| Details RTO/return advance retained copy | Present |
| Types in `database.types.ts` | Present |

---

## Phases

### Phase A — Ship (verify + deploy)

**Status:** Complete

**Work**
1. Verify UI↔RPC:
   - Phone debounce (≥11 digits) → `get_thrift_customer_sales_risk`
   - RTO/return history → require `advance_amount > 0`
   - `cod_expected = max(0, gross − advance)`
   - Offline rejects / forces zero advance
2. Smoke money rules: RTO/return ledger `REFUND` excludes advance; return doc `refund_amount` stays Σ line sell
3. Local `backend:reset` skipped (no Docker) — shipped via linked prod
4. `pnpm run deploy:backend` — remote up to date; types regen
5. Mark this tracker Done

**Acceptance**
- [x] Online create with RTO/return history blocks without advance
- [x] Remittance uses reduced `cod_expected`
- [x] Offline create with non-zero advance rejected (RPC)
- [x] RTO/return ledger REFUND retains advance; return doc refund_amount unchanged
- [x] Prod push clean; types include `advance_amount` + risk RPC

---

## Out of scope

- Partial RTO mid-transit
- Making advance optional when risk history exists
- Changing PnL sell lines for advance (advance is cash track only)
