# Dropship Wallet / Return — P4 Test Gate

**Priority:** P4 — post-implementation verification before human QA  
**Prerequisite:** P0–P3 checklists green + [LEGACY_DROP](./DROPSHIP_WALLET_LEGACY_DROP.md) rows done  
**Index:** [README_DROPSHIP_WALLET.md](./README_DROPSHIP_WALLET.md)  
**This is not a coding phase.** Run checks; fix only failures by opening the owning priority doc.

---

## Gaps this gate catches

### 1. Happy-path COD lifecycle not proven end-to-end
- Invoice → remittance → payout may still diverge in real data.
- What this means in simple terms: Fixes can exist in code but fail when staff click through a real order.

### 2. Return / prepaid / race paths not proven
- Return after remittance, prepaid no-recipient remittance, and payout-vs-return may still break.
- What this means in simple terms: Edge cases can still lose money or stock silently.

### 3. Drift / legacy still callable
- Old RPCs or missing `invoice_billed` may remain.
- What this means in simple terms: Old buttons or bad history can still corrupt balances.

---

## Test matrix (mark each)

### A. COD happy path
- [ ] Create COD dropship order (known face / cost / profit)
- [ ] Advance to `ready_for_pickup` → invoice exists, `collection_source=recipient`, UWL has `invoice_billed` + `dropship_profit` (`middleman`) + revenue
- [ ] Desk remittance for collectible amount → courier + tenant UWL once; invoice payment progress updates
- [ ] Re-submit same remittance → rejected or no-op (no duplicate UWL)
- [ ] Finance hub merchant payable matches middleman profit unpaid

### B. Prepaid path
- [ ] Prepaid order → `collection_source=billing_profile`
- [ ] Recipient remittance CTA hidden / RPC rejects recipient remittance

### C. Return before remittance
- [ ] Return perfect qty → sellable `global_stocks` + allocation up; compensating UWL; no remittance reverse invented
- [ ] Duplicate `p_return_ref` → rejected

### D. Return after remittance
- [ ] Remit then finalize return → remittance legs compensated; stock correct for condition mix

### E. Damaged / open-box return
- [ ] Damaged → damage stock type; open-box → box-less / open-box type; sellable unchanged for those qty

### F. Payout vs return
- [ ] Unpaid profit + return → payout blocked or clawback clear
- [ ] Already paid + return → recovery path documented/enforced (no silent profit leave)

### G. Regression / legacy
- [ ] No UI path hits `billing_profile_wallet_ledger`
- [ ] `confirm_courier_remittance_to_tenant` either wraps same writer or cannot double-post
- [ ] P3 reconciliation report: zero critical open issues on test tenant (or listed exceptions)

### H. Storefront / offers (if P2 shipped)
- [ ] Same product one price per condition bucket in shop
- [ ] Gift applies once per `(order, rule)` for eligible group

---

## Pass rule

All checked items for shipped scope pass → **hand to human QA**.  
Any fail → open owning priority file (`P0A`/`P0B`/`P0C`/`P1`/`P2`/`P3`) and fix only that gap; re-run failed section.
