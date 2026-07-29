# Shop Ops UX Ease — Fix docs (Dropship first)

**Implement in this order:** [IMPLEMENTATION_ORDER.md](./IMPLEMENTATION_ORDER.md) ← start here.

Use **one file per agent session**. Do not load the whole folder.

## Framing (read once)

These phases fix **ease-of-use patterns** that will later apply across shop types (fixed-price, vendor-catalog) and other money desks.

| Pattern | Meaning | This pack ships on |
|---------|---------|-------------------|
| Dual status | Ops status ≠ money status | Dropship list/detail/hub |
| Single money path | One write desk for remittance/payout | Dropship Finance Hub |
| Finalize-only returns | Status click never skips ledger/stock | Dropship return |
| Readiness checklist | Block go-live until deps green | Dropship shop |
| Progressive process | Next-step CTA, collapse advanced | Dropship order detail |
| Actor money page | Self-serve balance + deductions | Dropship merchant (shop scope) |

**Do not** generalize to other shop types in these sessions. Extract shared components only when a later pack asks.

**Prerequisite:** Wallet pack applied — [../DROPSHIP_WALLET_IMPLEMENTATION_ORDER.md](../DROPSHIP_WALLET_IMPLEMENTATION_ORDER.md).

## Phase index

| Step | File | RPC |
|------|------|-----|
| 0 | [UX_P0_settlement_and_cta_gates.md](./UX_P0_settlement_and_cta_gates.md) | NONE (extend selects if missing) |
| 1 | [UX_P1_single_money_path.md](./UX_P1_single_money_path.md) | NONE |
| 2 | [UX_P2_return_wizard_only.md](./UX_P2_return_wizard_only.md) | CALL `finalize_dropship_return` only |
| 3 | [UX_P3_readiness_checklist.md](./UX_P3_readiness_checklist.md) | NEW `get_dropship_shop_readiness` |
| 4 | [UX_P4_process_order_stepper.md](./UX_P4_process_order_stepper.md) | NONE |
| 5 | [UX_P5_merchant_money_page.md](./UX_P5_merchant_money_page.md) | NEW shop-scoped wallet RPCs |

**Also shipped:** `supabase/migrations/20270129000009_dropship_ux_order_settlement_fields.sql` (order `collection_source` + `payout_settlement_status`) and `20270129000010_dropship_ux_merchant_wallet_shop_scope.sql`.

**AI rules:** [docs/AI_WORKFLOW_SOP.md](../../../docs/AI_WORKFLOW_SOP.md) — one phase, listed files only, nothing else.
