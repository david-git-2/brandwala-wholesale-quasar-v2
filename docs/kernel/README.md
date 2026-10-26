# Money kernel — architecture pack

**New here?** Read [00-ONBOARDING-AND-AUDIT.md](00-ONBOARDING-AND-AUDIT.md) (primer, glossary, flows, fault audit).

**Implementation roadmap:** [PHASE-A-B-IMPLEMENTATION-PLAN.md](PHASE-A-B-IMPLEMENTATION-PLAN.md) (Phase A ops gaps → Phase B BD tax; **B blocked until A accepted**).

**Supabase production:** [PHASE-C-SUPABASE-RUNTIME.md](PHASE-C-SUPABASE-RUNTIME.md) (pooler, RLS, CI, PITR, deploy checklist).

Eight topic docs for **conceptual drift**, **concurrency bugs**, **broken plugs**, **RPC contract drift**, **golden scenarios**, **test gaps**, and **production triage**. Product thin spec: [bills_pays/spec.md](../features/bills_pays/spec.md).

| # | Doc | Description |
| :--- | :--- | :--- |
| 1 | [01-SYSTEM-INVARIANTS.md](01-SYSTEM-INVARIANTS.md) | Core ledger rules: issued-bill immutability, derived AR/AP direction, single-currency AP, cash points/pots, frozen FX on ledger lines. |
| 2 | [02-STATE-MACHINES-AND-LIFECYCLES.md](02-STATE-MACHINES-AND-LIFECYCLES.md) | Bill states, `take` vs `condition` revenue timing, credit/debit notes, pay alloc vs custody/leftover. |
| 3 | [03-TRANSACTIONS-LOCKING-AND-CONCURRENCY.md](03-TRANSACTIONS-LOCKING-AND-CONCURRENCY.md) | Isolation, `FOR UPDATE`, lock ordering, idempotent pay keys, constraints on balance/alloc. |
| 4 | [04-RPC-AND-API-CONTRACTS.md](04-RPC-AND-API-CONTRACTS.md) | `SECURITY DEFINER` RPC params, returns, errors; target `kernel_*` names vs live functions. |
| 5 | [05-ADAPTER-INTEGRATION-GUIDE.md](05-ADAPTER-INTEGRATION-GUIDE.md) | Shipments, shop, POS, delivery: `source_*` plugs, profiles, bucket×currency splits, balance reads. |
| 6 | [06-ACCOUNTING-FLOWS-AND-GOLDEN-SCENARIOS.md](06-ACCOUNTING-FLOWS-AND-GOLDEN-SCENARIOS.md) | Row-level golden scenarios: wholesale overpay, dropship remittance, multi-currency AP → landed cost. |
| 7 | [07-TDD-AND-VERIFICATION-SUITE.md](07-TDD-AND-VERIFICATION-SUITE.md) | Test pyramid: invariant/constraint tests, golden pipeline, concurrency race tests. |
| 8 | [08-AUDIT-RECONCILIATION-AND-RUNBOOK.md](08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) | Audit SQL, cheque bounce, till transfer, count variance SOPs. |

**Also:** [kernel-schema.md](../features/bills_pays/kernel-schema.md) (target columns) · [money-story.md](../features/bills_pays/money-story.md) · [00-gaps.md](../features/bills_pays/00-gaps.md) · Live SQL `supabase/schemas/bills_pays/`.
