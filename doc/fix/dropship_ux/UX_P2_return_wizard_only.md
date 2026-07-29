# UX_P2 — Return wizard only (impl only)

**Parent:** [IMPLEMENTATION_ORDER.md](./IMPLEMENTATION_ORDER.md) step 2  
**Session:** this file only + listed READ ONLY  
**Prerequisite:** UX_P1 green; wallet P0C `finalize_dropship_return` exists  
**Reuse later:** destructive money/stock outcomes always go through confirm wizard

---

### Goal
Clicking **Returned** never advances status alone. Always open finalize wizard → one RPC that does status + stock + wallet.

### RPCs
- **NONE new**
- **CALL ONLY:** `finalize_dropship_return` (via `useDropshipReturnMutations` / repository)
- Do **not** call bare `advance_dropship_order_status(..., 'returned')` or `mark_dropship_order_returned` from UI

### READ ONLY
- `supabase/migrations/20270129000004_dropship_wallet_p0c_return_finalize.sql` — args/result only
- `web/src/modules/shop_order/composables/useDropshipReturnMutations.ts`
- `web/src/modules/shop_order/components/DropshipReturnFinalizeDialog.vue`
- `web/src/modules/shop_order/composables/useDropshipOrderActions.ts` — `onUpdateStatus`, `submitReturnFinalize`
- `web/src/modules/shop_order/components/DropshipOrderStatusWorkflow.vue`
- `docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md`

### CHANGE
- `web/src/modules/shop_order/composables/useDropshipOrderActions.ts`
  - `onUpdateStatus('returned')` / `executeStatusUpdate('returned')` → open `returnDialogOpen` only
  - `submitReturnFinalize` → mutation to `finalize_dropship_return` only; then refetch
- `web/src/modules/shop_order/components/DropshipOrderStatusWorkflow.vue`
  - Returned control still emits `update-status` with `returned` (parent opens wizard) — no alternate path
- `web/src/modules/shop_order/components/DropshipReturnFinalizeDialog.vue`
  - Show short preview: suggested fee, override reason required if fee ≠ suggested
  - One confirm CTA; disable double-submit while pending
- `web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue`
  - Ensure only one return entry (dialog); no second “Mark returned” button that skips dialog

### DO NOT
- Reimplement stock/wallet in frontend
- Soften override-reason requirement
- Touch Finance Hub remittance
- Touch non-dropship fulfillment returns

### Done checklist
- [ ] Status strip Returned opens finalize dialog
- [ ] Confirm calls `finalize_dropship_return` only
- [ ] Cancel leaves status unchanged
- [ ] Pending mutation disables confirm (no double post)
- [ ] Grep UI: no direct `mark_dropship_order_returned` / advance-to-returned write from Vue
