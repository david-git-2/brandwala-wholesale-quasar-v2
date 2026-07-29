# P0C — Return finalize + stock + wallet (impl only)

**Parent:** [DROPSHIP_WALLET_GAPS_P0.md](./DROPSHIP_WALLET_GAPS_P0.md) gaps 4, 6–9  
**Stock model:** [doc/PROCUREMENT_STOCK.md](../PROCUREMENT_STOCK.md) — `global_stocks` by `stock_type_id`  
**Drop:** [LEGACY_DROP](./DROPSHIP_WALLET_LEGACY_DROP.md) R2  
**Session:** this file only + listed READ ONLY

---

**Goal:** One atomic return finalization: stock by type, invoice return rows, UWL compensations, idempotent; desk cannot bypass.

### READ ONLY
- `supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql` — `mark_dropship_order_returned`
- `supabase/migrations/20260806000000_procurement_stock_schema.sql` — `global_stocks` / allocations
- `doc/PROCUREMENT_STOCK.md` — stock types (sellable, box less, box damage, etc.)
- `supabase/migrations/20260825000000_sales_invoice_phase4_rpcs.sql` — return item patterns
- P0B canonical `source_id` / middleman rules

### CHANGE
- Add `finalize_dropship_return(...)`:
  - Params: `p_order_id`, `p_items` JSON (`order_item_id`, `returned_qty`, `condition` in `perfect|open_box|damaged`), `p_actual_return_charge`, `p_deduct_from_middle_man`, `p_override_reason` if fee overridden, `p_return_ref` unique
  - Lock order + stock rows
  - Validate qty ≤ net delivered
  - Sub-state → `return_finalized` (keep `shop_orders.status='returned'`)
  - Restock: map condition → tenant `global_stock_types` (perfect→sellable, open_box→box less / open-box type, damaged→box damage); bump `global_stocks.quantity` + `global_stock_allocations`
  - Insert `global_return_items` / bump line `return_quantity` as needed
  - Compensating UWL: reverse `invoice_billed`, `dropship_profit`, `revenue`, remittance legs by remitted vs not; payout hard-gate / recovery if paid
  - Idempotent on `p_return_ref`
- Redefine `mark_dropship_order_returned` to call finalize with safe defaults **or** raise: must not leave status returned without finalize side effects
- Schema if missing: return sub-state, suggested/actual return fee, override audit columns

### DO NOT
- Add `open_box_quantity` columns on `global_stocks`
- Change invoice status enum
- Touch remittance unify (P0B) or web UI (P1/P2)
- Skip wrapper on `mark_dropship_order_returned`

### Done checklist
- [ ] Finalize restocks sellable vs damage types correctly
- [ ] Allocations shown qty updated
- [ ] Duplicate `p_return_ref` rejected
- [ ] Desk `mark_dropship_order_returned` cannot skip wallet/stock
- [ ] Remitted return reverses remittance legs; unremitted does not invent remittance reverses
- [ ] LEGACY_DROP R2 marked done
