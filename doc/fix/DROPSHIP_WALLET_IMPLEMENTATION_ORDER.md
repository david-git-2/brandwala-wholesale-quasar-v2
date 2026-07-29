# Dropship Wallet — Implementation Order

**Follow this file top to bottom.** Open only the listed doc for the current step. Do not skip ahead. Do not implement the next step until the current checklist is green.

**Index:** [README_DROPSHIP_WALLET.md](./README_DROPSHIP_WALLET.md)  
**Legacy drop (same phase as the gap):** [DROPSHIP_WALLET_LEGACY_DROP.md](./DROPSHIP_WALLET_LEGACY_DROP.md)  
**AI rules:** [docs/AI_WORKFLOW_SOP.md](../../docs/AI_WORKFLOW_SOP.md)

---

## Order (do first → do last)

| Step | When | Open this file only | Stop when |
|------|------|---------------------|-----------|
| **1** | Start here | [DROPSHIP_WALLET_IMPL_P0A_invoice_and_collection.md](./DROPSHIP_WALLET_IMPL_P0A_invoice_and_collection.md) | P0A done checklist green |
| **2** | After step 1 | [DROPSHIP_WALLET_IMPL_P0B_remittance_unify.md](./DROPSHIP_WALLET_IMPL_P0B_remittance_unify.md) + mark [LEGACY](./DROPSHIP_WALLET_LEGACY_DROP.md) **R1** | P0B done checklist + R1 |
| **3** | After step 2 | [DROPSHIP_WALLET_IMPL_P0C_return_finalize.md](./DROPSHIP_WALLET_IMPL_P0C_return_finalize.md) + mark **R2** | P0C done checklist + R2; then [P0 verification](./DROPSHIP_WALLET_GAPS_P0.md#verification-checklist-p0) |
| **4** | After P0 checklist | [DROPSHIP_WALLET_GAPS_P1.md](./DROPSHIP_WALLET_GAPS_P1.md) + mark **R3–R4** | P1 verification checklist |
| **5** | After P1 | [DROPSHIP_WALLET_GAPS_P2.md](./DROPSHIP_WALLET_GAPS_P2.md) + mark **R5** | P2 verification checklist |
| **6** | After P2 | [DROPSHIP_WALLET_GAPS_P3.md](./DROPSHIP_WALLET_GAPS_P3.md) Implementation A (backfill) | Backfill critical sets empty / documented |
| **7** | After step 6 | Same P3 doc Implementation B (governance) + mark **R6** | P3 verification checklist |
| **8** | After P3 | [DROPSHIP_WALLET_GAPS_P4.md](./DROPSHIP_WALLET_GAPS_P4.md) — **test only, no new features** | P4 matrix pass → human QA |

Gap statements (read if you need “why”, not for coding):

- [P0 gaps](./DROPSHIP_WALLET_GAPS_P0.md) · [P1](./DROPSHIP_WALLET_GAPS_P1.md) · [P2](./DROPSHIP_WALLET_GAPS_P2.md) · [P3](./DROPSHIP_WALLET_GAPS_P3.md)

---

## Progress tracker

Mark as you finish:

- [x] Step 1 — P0A invoice billed + collection_source
- [x] Step 2 — P0B remittance unify + middleman + R1
- [x] Step 3 — P0C return finalize + stock types + R2 + P0 checklist
- [x] Step 4 — P1 frontend wire + R3–R4
- [x] Step 5 — P2 ops UI / offers / gifts + R5
- [x] Step 6 — P3 backfill
- [x] Step 7 — P3 governance + R6
- [ ] Step 8 — P4 test gate → hand to QA

---

## Rules

1. **One step per agent session** (or one PR).
2. **Deploy/migrate** P0 steps before relying on P1 UI against that RPC.
3. If a step fails P4 later, reopen **that step’s** file only — do not reopen the whole folder.
4. Never start at P2/P3 while P0A–P0C checklists are open.
