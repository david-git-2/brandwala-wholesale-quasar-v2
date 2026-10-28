# Bills/pays — architecture review resolutions (2026-10-27)

Findings from the kernel doc review are **encoded** in:

| Doc | What changed |
| :--- | :--- |
| [00-gaps](../../docs/features/bills_pays/00-gaps.md) | **Money spine** build order (BP18/BP20/BP25/BP22/BP19) gates new pay/bill writers |
| [kernel-schema](../../docs/features/bills_pays/kernel-schema.md) | Global lock order, idempotency, settlement FX columns, BP18 cutover gate, CQRS pagination |
| [tests](../../docs/features/bills_pays/tests.md) | Tier 1: reconciliation + idempotency; T4-1 tied to BP19 |
| [REFERENCE](../../docs/kernel/REFERENCE.md) | Invariants 17–20; concurrency table |
| [08 runbook](../../docs/kernel/08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) | §1b settlements vs allocations reconciliation |
| [kernel plan](2026-10-12-bills-pays-kernel-plan.md) | Phase order: spine before adapters scale |

**Rule:** No new `SECURITY DEFINER` money writer RPC until spine step **BP18 cutover** (audit §1b clean) and **BP25** idempotency column exist.

Implementation still tracked per gap IDs in [00-gaps](../../docs/features/bills_pays/00-gaps.md).
