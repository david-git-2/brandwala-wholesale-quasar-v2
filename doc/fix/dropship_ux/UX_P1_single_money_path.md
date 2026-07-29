# UX_P1 — Single money path (impl only)

**Parent:** [IMPLEMENTATION_ORDER.md](./IMPLEMENTATION_ORDER.md) step 1  
**Session:** this file only + listed READ ONLY  
**Prerequisite:** UX_P0 green  
**Reuse later:** “ops surface deep-links money desk” — ship dropship Finance Hub now

---

### Goal
One remittance/payout **write** surface: Dropship Finance Hub. Order detail and Merchants page only **navigate** with query context. Labels say **Merchant** (not Middleman) on these surfaces.

### RPCs
- **NONE new**
- CALL ONLY existing hub mutations (already wired):
  - remittance → canonical `record_dropship_courier_remittance` (via repo)
  - payout → existing dispense RPC used by hub
- Order detail must **not** call remittance mutate after this phase

### READ ONLY
- `web/src/modules/shop_order/pages/DropshipFinanceHubPage.vue` — `route.query.step`, `merchantId`
- `web/src/modules/shop_order/routes/adminRoutes.ts` — `app-shop-dropship-finance-hub-page`
- `web/src/modules/shop_order/composables/useDropshipOrderActions.ts` — `primaryCta`, remittance dialog open/save
- `web/src/modules/shop_order/pages/DropshipMerchantsPage.vue` — existing hub deep-link
- `docs/TANSTACK_QUERY_GUIDE.md`, `docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md`

### CHANGE
- `web/src/modules/shop_order/composables/useDropshipOrderActions.ts`
  - Remittance branch of `primaryCta`: `router.push({ name: 'app-shop-dropship-finance-hub-page', query: { orderId: String(id), step: 'courier_remittance' } })`
  - Remove or no-op `openOrderRemittanceDialog` / `saveOrderRemittance` from primary path (delete dialog open from CTA)
  - Keep settlement card read-only display
- `web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue`
  - Stop binding remittance dialog for write (or leave dialog unused / remove props if unused)
- `web/src/modules/shop_order/components/DropshipOrderDialogs.vue`
  - Remove remittance dialog block **or** leave dead code removed in this phase (prefer remove unused remittance dialog markup)
- `web/src/modules/shop_order/pages/DropshipFinanceHubPage.vue`
  - On mount/watch: if `route.query.orderId`, select that order in queue and set `activeTab` from `step`
- `web/src/modules/shop_order/components/finance_hub/FinanceHubOrderQueue.vue`
  - Support preselect by order id from parent
- `web/src/modules/shop_order/pages/DropshipMerchantsPage.vue`
  - Title/subtitle: Merchant (not Middleman); payout button still deep-links hub `step=middleman_payout` (route query key may stay; **UI label** = Merchant Payout)
- `web/src/modules/shop_order/pages/DropshipFinanceHubPage.vue` tab label: `3. Merchant Payout`

### DO NOT
- Add second remittance RPC
- Change wallet ledger schema
- Build merchant self-serve wallet (P5)
- Generalize hub to other shop types

### Done checklist
- [ ] Order detail “Record remittance” navigates to Finance Hub with `orderId` + `step`
- [ ] Hub opens with that order selected and remittance tab active
- [ ] No remittance write from order detail dialog
- [ ] Merchants “Dispense” still opens hub payout step
- [ ] Visible copy uses Merchant on hub/merchants surfaces
