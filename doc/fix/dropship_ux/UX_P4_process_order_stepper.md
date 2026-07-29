# UX_P4 — Process Order progressive stepper (impl only)

**Parent:** [IMPLEMENTATION_ORDER.md](./IMPLEMENTATION_ORDER.md) step 4  
**Session:** this file only + listed READ ONLY  
**Prerequisite:** UX_P3 green  
**Reuse later:** progressive process pattern for any consignment desk — dropship detail only now

---

### Goal
Order detail guides staff through **one next step** instead of showing all consignment blocks at once. Advanced blocks stay available under “More”.

### RPCs
- **NONE new**
- Keep existing: process/advance status, create invoice, recipient invoice preview routes

### Suggested step order (UI only)
1. Recipient confirmed / editable
2. Courier + AWB / tracking
3. Parcel + COD collect
4. Print recipient invoice (CTA opens existing preview)
5. `ready_for_pickup` (status)
6. Create accounting invoice (existing primary CTA when due)

Money remittance/payout stay on Finance Hub (P1) — not steps here.

### READ ONLY
- `web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue` — card layout A–E
- `web/src/modules/shop_order/composables/useDropshipOrderActions.ts` — `primaryCta`
- Existing cards: `DropshipRecipientFormCard`, `DropshipCourierCard`, `DropshipParcelFormCard`, `DropshipMerchantFormCard`, `DropshipDeliveryNotesCard`, `DropshipOrderHeader`
- `docs/COMPONENT_MODULARIZATION_GUIDE.md`, `docs/UI_CONSISTENCY.md`, `docs/PAGE_LAYOUT_AND_LOADERS.md`

### CHANGE
- `web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue`
  - Add compact step indicator (Quasar stepper or simple chip strip) derived from order status + missing fields
  - Default: expand only cards needed for current step; others collapsed
- `web/src/modules/shop_order/composables/useDropshipOrderActions.ts` (or small new composable `useDropshipProcessSteps.ts` in same module)
  - Compute `activeProcessStep` + `primaryCta` for ops steps before money CTAs
  - After invoice exists, do not invent remittance as process step (hub only)
- Merchant pickup + driver notes:
  - Wrap behind “More details” expansion; not in default first viewport
- Keep `DropshipOrderStatusWorkflow` visible

**Optional extract (only if detail page exceeds ~250 lines further):**
- `web/src/modules/shop_order/components/DropshipProcessStepStrip.vue`

### DO NOT
- Change status enum or advance RPC rules
- Move remittance back onto detail
- Redesign Finance Hub
- Touch storefront checkout

### Done checklist
- [ ] New staff see one primary next action on detail
- [ ] Courier/parcel cards not all forced open at `confirmed`
- [ ] Recipient invoice + accounting invoice CTAs still reachable at correct statuses
- [ ] Merchant pickup / notes under More
- [ ] No new RPC
