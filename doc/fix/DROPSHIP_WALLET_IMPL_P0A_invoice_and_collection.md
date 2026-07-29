# P0A — Invoice billed + collection_source (impl only)

**Parent:** [DROPSHIP_WALLET_GAPS_P0.md](./DROPSHIP_WALLET_GAPS_P0.md) gaps 1–2  
**Session:** this file only + listed READ ONLY

---

**Goal:** Every dropship auto-invoice posts receivable debit and uses correct collection source so COD remittance can run.

### READ ONLY
- `supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql` — `post_global_invoice` / advance status
- `supabase/migrations/20261209000000_fix_is_default_billing_profiles.sql` — `create_dual_invoice_from_dropship_order` (hardcoded billing_profile)
- `supabase/migrations/20261118000004_fix_auto_invoice_schema.sql` — prior prepaid/recipient pattern
- `supabase/migrations/20261220000000_create_universal_wallet_ledger.sql` — `record_ledger_transaction`

### CHANGE
- One migration (or shared P0 migration section A only if doing all P0 in one file — prefer **one migration with clear sections A/B/C**):
  1. Fix `create_dual_invoice_from_dropship_order`:  
     `collection_source = case when is_prepaid_snapshot then billing_profile else recipient end`
  2. Add `ensure_dropship_invoice_billed_entry(invoice_id)`:
     - debit `entity_type` per billing profile (customer receivable as today for invoice_billed, or keep existing customer entity for billed — do not invent new entity for this debit)
     - idempotent by tenant + invoice id + `transaction_type=invoice_billed`
  3. Call ensure after auto-invoice in `advance_dropship_order_status` and from `post_global_invoice` for dropship

### DO NOT
- Touch remittance/return RPCs (P0B/P0C)
- Touch `web/`
- Change invoice status enum

### Done checklist
- [ ] COD invoice → recipient
- [ ] Prepaid invoice → billing_profile
- [ ] `invoice_billed` exists after ready_for_pickup
- [ ] Re-advance / re-post does not duplicate `invoice_billed`
