# Money kernel

Shared ledger: **bills · pays · cashbook**. Features plug in; they do not own invoice tables.

## Read order

| Step | Doc |
| :--- | :--- |
| 1 | [bills_pays README](../features/bills_pays/README.md) — layers, graphs, target behavior |
| 2 | [kernel-schema](../features/bills_pays/kernel-schema.md) — tables, RPC index, lock order |
| 3 | [spec](../features/bills_pays/spec.md) + [00-gaps](../features/bills_pays/00-gaps.md) — desks, scope, live delta |
| 4 | [REFERENCE](REFERENCE.md) — invariants (money PR) |
| 5 | [tests](../features/bills_pays/tests.md) — golden scenarios |
| 6 | [08 runbook](08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) — prod audit SQL only |

Optional: [money-story](../features/bills_pays/money-story.md) for dropship/remittance numbers.

Build history: [kernel plan](../../doc/fix/2026-10-12-bills-pays-kernel-plan.md) (not product truth — prefer spec + gaps).
