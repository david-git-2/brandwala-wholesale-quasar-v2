# Dropship Wallet — Fix docs index

**Implement in this order:** [DROPSHIP_WALLET_IMPLEMENTATION_ORDER.md](./DROPSHIP_WALLET_IMPLEMENTATION_ORDER.md) ← start here.

Use **one file per agent session**. Do not load the whole folder.

| Priority | Gaps + checklist | Implementation slices |
|----------|------------------|------------------------|
| P0 | [DROPSHIP_WALLET_GAPS_P0.md](./DROPSHIP_WALLET_GAPS_P0.md) | [P0A](./DROPSHIP_WALLET_IMPL_P0A_invoice_and_collection.md) · [P0B](./DROPSHIP_WALLET_IMPL_P0B_remittance_unify.md) · [P0C](./DROPSHIP_WALLET_IMPL_P0C_return_finalize.md) |
| P1 | [DROPSHIP_WALLET_GAPS_P1.md](./DROPSHIP_WALLET_GAPS_P1.md) | (in P1 doc) |
| P2 | [DROPSHIP_WALLET_GAPS_P2.md](./DROPSHIP_WALLET_GAPS_P2.md) | (in P2 doc) |
| P3 | [DROPSHIP_WALLET_GAPS_P3.md](./DROPSHIP_WALLET_GAPS_P3.md) | Phase 4 backfill + Phase 5 governance in P3 doc |
| P4 | [DROPSHIP_WALLET_GAPS_P4.md](./DROPSHIP_WALLET_GAPS_P4.md) | End-to-end test gate before QA |
| Legacy | [DROPSHIP_WALLET_LEGACY_DROP.md](./DROPSHIP_WALLET_LEGACY_DROP.md) | Drop conflicting code the same phase the gap closes |

**AI rules:** [docs/AI_WORKFLOW_SOP.md](../../docs/AI_WORKFLOW_SOP.md) — one phase, listed files only, nothing else.
