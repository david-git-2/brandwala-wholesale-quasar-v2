# Dropship Wallet / Return — P3 Gaps & Implementation

**Priority:** P3 — governance / ongoing control  
**Prerequisite:** P0–P2 done  
**Drop:** [LEGACY_DROP](./DROPSHIP_WALLET_LEGACY_DROP.md) R6 (revoke leftover execute)  
**Next:** [DROPSHIP_WALLET_GAPS_P4.md](./DROPSHIP_WALLET_GAPS_P4.md) test gate  
**Index:** [README_DROPSHIP_WALLET.md](./README_DROPSHIP_WALLET.md)  
**Execute:** one agent session; files listed below only; stop at review gate.  
**Follow:** [docs/AI_WORKFLOW_SOP.md](../../docs/AI_WORKFLOW_SOP.md)

---

## Gaps

### 1. No scheduled reconciliation control loop
- Backfill queries exist as one-time work, but no periodic reconciliation job enforces drift detection.
- Impact: silent inconsistencies can reappear after release.
- What this means in simple terms: Even after fixes, errors can slowly come back if there is no routine health check.
- Related: `supabase/migrations/20260728202828_backfill_middleman_universal_wallet.sql`

### 2. Legacy endpoint exposure risk after canonicalization
- Even after unifying logic, old RPC entry points can remain callable unless explicitly restricted/deprecated.
- Impact: duplicate semantic writes from mixed clients.
- What this means in simple terms: Old and new app paths may both stay active, causing the same event to be recorded twice.
- Related: `web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts`, `web/src/modules/shop_order/repositories/courierRemittanceRepository.ts`

---

## Implementation A — Backfill / drift checks (Phase 4)

**Goal:** Detect/fix historic bad ledger and pricing rows so production matches the new rules.

### READ ONLY
- P0–P2 RPC/table names; gap check list below

### CHANGE
- One new migration: `supabase/migrations/YYYYMMDDHHMMSS_dropship_wallet_gap_backfill.sql`
  - Insert missing `invoice_billed` where dropship invoice exists
  - Flag/fix remitted orders missing courier UWL
  - Flag returns missing compensating entries
  - Flag mixed `customer` vs `middleman` profit rows needing transition handling
  - Flag inconsistent `source_id` shapes for same order lifecycle
  - Flag conflicting active offer prices in one shop
  - Flag missing/duplicate gifts for same `(order, rule)`
- Optional note in `doc/SHOP_ORDER_DROPSHIP.md` **only if user asks**

### DO NOT
- Change application feature code
- Invent new business features

### Done when
Check queries return empty critical sets or documented exceptions; **stop for review gate** before Implementation B if desired.

---

## Implementation B — Governance (Phase 5)

**Goal:** Ongoing drift detection + prevent old clients from writing duplicate wallet events.

### READ ONLY
- P0 wrapper RPCs; Phase 4 check SQL

### CHANGE
- Migration: callable reconciliation report RPC  
  - Use `pg_cron` only if project already uses it — do not invent cron infra
- Revoke or wrap execute on legacy remittance entry points after cutover window
- No UI beyond a minimal “run reconciliation” action if finance hub already exists — otherwise RPC-only

### DO NOT
- Redesign finance hub
- Add new wallet entity types
- Reopen P0–P2 scope

### Done when
One reconciliation report RPC exists and legacy write path is guarded; **stop**.

---

## Verification checklist (P3)

- [ ] Backfill/check SQL: critical drift sets empty or documented exceptions
- [ ] Reconciliation report RPC callable by authorized role
- [ ] Divergent remittance write path not independently executable (wrap or revoke)
- [ ] LEGACY_DROP R6 marked done
- [ ] Proceed to [P4](./DROPSHIP_WALLET_GAPS_P4.md) before human QA
