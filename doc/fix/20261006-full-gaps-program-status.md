# Full gaps program — status (2026-10-06)

Checklist for the multi-phase gaps alignment program. Product truth stays in `docs/features/*/spec.md` and `00-gaps.md`.

## Shipped in this pass

- Phase 0: US-5 dropship money in shop_order spec; bills_pays rename map (BP4); doc_wrong ticks (TA2, DA1–DA2, NT1/NT3, …).
- Phase 1: Remit deep-link (`orderId` query); settlement → `app-remit-pay-page`; cashbook party **Pay in**; proforma → draft migration; WA4 closed in gaps.
- Phase 2: SO6 `fulfill_shop_order_to_invoice` blocks `fixed_price`.
- Phase 3: `close_global_shipment` RPC (PS10 backend slice; UI button still optional).
- Dropship copy: cashbook not wallet on finance hub payout.

## Still open (honest deferrals)

| Area | IDs | Why |
| :--- | :--- | :--- |
| Bills desk | BP5 US-2 returns, US-6 reversal | Explicitly later in gap |
| Profiles | BP3, CU4 | Large migration |
| Procurement | PS7–PS9, PS2, PS12 UI/doc | Multi-sprint |
| Reporting | RT18–RT19 | Profit RPC + local costs wiring |
| After-sales | AS1 tabs | Rename spec or rebuild hub |
| Notifications | NT2 FCM | Edge + client |
| Investor | IC3, IC7 | Route/balance refactor |
| Schema splits | CU1, PR1, TH1, RT1, TA3, GR2, IC2, PBC3 | One domain per PR |
| Stock | PS9 allocations retire | Highest risk; after shop stable |

## Verify dropship money (local)

1. Deliver dropship order → courier COD receivable (not tenant cash).
2. Payments → Remittance → net bank in → merchant bill paid.
3. Shop leftover on cashbook → pay out from finance hub / payout.
