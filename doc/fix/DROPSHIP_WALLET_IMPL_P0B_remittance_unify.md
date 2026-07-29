# P0B — Remittance unify + merchant entity (impl only)

**Parent:** [DROPSHIP_WALLET_GAPS_P0.md](./DROPSHIP_WALLET_GAPS_P0.md) gaps 3, 5, 10  
**Drop:** [LEGACY_DROP](./DROPSHIP_WALLET_LEGACY_DROP.md) R1 same migration  
**Session:** this file only + listed READ ONLY

---

**Goal:** One remittance ledger writer; new profit credits use `middleman`; canonical `source_id`.

### READ ONLY
- `supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql` — `record_dropship_courier_remittance`
- `supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql` — courier UWL pattern to port
- `supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql` — profit credit as `customer` today
- `doc/wallet/UNIVERSAL_WALLET_LEDGER.md`

### CHANGE
- Shared internal routine for remittance UWL (courier debit/credit legs + tenant remittance credit as designed in finance hub pattern)
- `record_dropship_courier_remittance` = authoritative caller of shared routine + existing payment/invoice updates
- `confirm_courier_remittance_to_tenant` = thin wrapper to same shared routine (no divergent metadata/purpose)
- Cap remittance amount vs collectible/outstanding
- Resolve courier entity from **order’s** `courier_service_id` (not global `limit 1`)
- In `advance_dropship_order_status`: profit credit `entity_type='middleman'`, `source_id=order.id::text`, `order_no` in metadata only
- Currency/exchange from order when available

### DO NOT
- Touch return finalize (P0C)
- Touch frontend
- Leave two independent remittance writers

### Done checklist
- [x] Desk remittance posts courier+tenant UWL once
- [x] Old confirm RPC produces same ledger semantics (wrapper)
- [x] New profit rows are `middleman`
- [x] Wrong courier no longer possible via limit-1 join
- [x] Over-remit rejected
- [x] LEGACY_DROP R1 marked done
