# UX_P0 — Settlement badges + CTA gates (impl only)

**Parent:** [IMPLEMENTATION_ORDER.md](./IMPLEMENTATION_ORDER.md) step 0  
**Session:** this file only + listed READ ONLY  
**Prerequisite:** wallet pack applied  
**Reuse later:** dual-status badge pattern (ops vs money) — ship dropship-only now

---

### Goal
Staff always see **money status** next to ops status, and never get a remittance CTA that cannot succeed (prepaid / missing invoice / already remitted).

### RPCs
- **NONE new**
- If list/detail omit fields, **extend existing** get/list order select only:
  - `collection_source`
  - `payout_settlement_status` (`unpaid` | `partial` | `paid` | null → treat unpaid)
  - `courier_remittance_ref`
  - `global_invoice_id`
  - `is_prepaid_snapshot` (if available)
- Do not invent new write RPCs

### READ ONLY
- `web/src/modules/shop_order/types/index.ts` — `ShopOrder.collection_source`, `payout_settlement_status`
- `web/src/modules/shop_order/components/DropshipSettlementBadge.vue`
- `web/src/modules/shop_order/components/DropshipOrderDialogs.vue` — prepaid banner pattern
- `web/src/modules/shop_order/composables/useDropshipOrderActions.ts` — `canRecordRemittance`, `primaryCta`
- `docs/UI_CONSISTENCY.md`, `docs/PAGE_LAYOUT_AND_LOADERS.md` — layout only, no rewrite

### CHANGE
- `web/src/modules/shop_order/components/DropshipOrderHeader.vue`
  - Render `DropshipSettlementBadge` when order has invoice or delivered+ (use `order.payout_settlement_status`)
- `web/src/modules/shop_order/components/ShopOrdersTable.vue`
  - Ensure settlement column always shown for dropship rows (badge already present — verify data wired)
- `web/src/modules/shop_order/components/finance_hub/FinanceHubOrderQueue.vue`
  - Show settlement badge per row
- `web/src/modules/shop_order/composables/useDropshipOrderActions.ts`
  - `canRecordRemittance` also requires `collection_source !== 'billing_profile'`
  - `primaryCta` remittance branch: same gate; if prepaid, no remittance CTA
- `web/src/modules/shop_order/components/DropshipOrderDialogs.vue`
  - Keep remittance dialog blocked when `collection_source === 'billing_profile'`
- Repository / query that feeds desk list + order detail: ensure fields above selected (only if missing)

### DO NOT
- Change remittance write RPC
- Remove remittance dialog (P1 does write-path removal)
- Touch fixed-price / vendor-catalog pages
- Touch wallet migrations
- Add README

### Done checklist
- [x] Desk list shows settlement badge
- [x] Order detail header shows settlement badge
- [x] Finance Hub queue shows settlement badge
- [x] Prepaid / `billing_profile` order: remittance CTA hidden or disabled with reason
- [x] Already remitted (`courier_remittance_ref` set): remittance CTA gone
