# Shop Ops UX Ease — Implementation Order (Dropship first)

**Index:** [README.md](./README.md)  
**Wallet prerequisite:** [../DROPSHIP_WALLET_IMPLEMENTATION_ORDER.md](../DROPSHIP_WALLET_IMPLEMENTATION_ORDER.md) green before Step 0.  
**AI rules:** [docs/AI_WORKFLOW_SOP.md](../../../docs/AI_WORKFLOW_SOP.md)

Follow top to bottom. Open **only** the listed file. Stop at Done checklist. Do not skip.

## Order

| Step | Open this file only | Stop when |
|------|---------------------|-----------|
| **0** | [UX_P0_settlement_and_cta_gates.md](./UX_P0_settlement_and_cta_gates.md) | Money badge on list+detail+hub; prepaid remittance CTA hidden/disabled |
| **0b** | Migrations `20270129000009_*` (settlement columns) — no separate MD | `collection_source` + `payout_settlement_status` on `shop_orders`; desk list returns them |
| **1** | [UX_P1_single_money_path.md](./UX_P1_single_money_path.md) | Order money CTA deep-links Finance Hub; no order-detail remittance **write** |
| **2** | [UX_P2_return_wizard_only.md](./UX_P2_return_wizard_only.md) | `returned` only via finalize dialog → `finalize_dropship_return` |
| **3** | [UX_P3_readiness_checklist.md](./UX_P3_readiness_checklist.md) | Readiness RPC + card on dropship shop; types regen |
| **4** | [UX_P4_process_order_stepper.md](./UX_P4_process_order_stepper.md) | Detail progressive next-step; advanced blocks collapsed |
| **5** | [UX_P5_merchant_money_page.md](./UX_P5_merchant_money_page.md) | Shop-scoped wallet RPCs + merchant page; types regen |

## Progress tracker

- [x] Step 0 — Settlement + CTA gates (UI)
- [x] Step 0b — Order settlement data contract (`20270129000009_dropship_ux_order_settlement_fields.sql`)
- [x] Step 1 — Single money path
- [x] Step 2 — Return wizard only
- [x] Step 3 — Readiness checklist
- [x] Step 4 — Process Order stepper
- [x] Step 5 — Merchant money page (`20270129000010_*` + shop route)

## Deploy note

Push migrations `…00009` and `…00010` (and prior wallet pack) before relying on badges / merchant wallet in production. Prefer `pnpm run backend:types` after push to refresh generated types.

## Later (out of this pack)

Reuse patterns on fixed-price / vendor-catalog / other desks — **new folder or new phases**, do not expand these files mid-run.

Wallet **P4 test gate** remains a manual QA checklist: [../DROPSHIP_WALLET_GAPS_P4.md](../DROPSHIP_WALLET_GAPS_P4.md).
