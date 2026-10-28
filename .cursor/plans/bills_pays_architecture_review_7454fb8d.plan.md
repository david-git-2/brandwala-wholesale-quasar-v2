---
name: Bills Pays Architecture Review
overview: Critical review + doc resolutions for Bills & Pays kernel (spine-first build order, lock graph, BP25, settlement FX, CQRS pagination).
todos:
  - id: impl-spine-s1-s5
    content: "Implement money spine in SQL: BP20 → BP18 (+08 §1b) → BP25 → BP22 → BP19 + Tier 1 tests"
    status: pending
isProject: false
---

# Bills & Pays — architecture review (resolved in docs)

Full analysis: see chat / original review sections.

**Canonical follow-up:** [doc/fix/2026-10-27-bills-pays-architecture-resolutions.md](../../doc/fix/2026-10-27-bills-pays-architecture-resolutions.md)

**Build order:** [docs/features/bills_pays/00-gaps.md](../../docs/features/bills_pays/00-gaps.md) — Money spine S1–S5 gates new writers.

**Remaining work:** SQL migrations and pgTAP for spine (not done in doc-only pass).
