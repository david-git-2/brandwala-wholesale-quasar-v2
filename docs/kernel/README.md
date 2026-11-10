# Platform kernels

## Money

**Single reference:** [money-spine.md](../features/bills_pays/money-spine.md).

| Also | Doc |
| :--- | :--- |
| PR checklist | [REFERENCE.md](REFERENCE.md) |
| pgTAP / goldens | [tests.md](../features/bills_pays/tests.md) |
| Ops audit SQL | [08-AUDIT-RECONCILIATION-AND-RUNBOOK.md](08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) |

Build history: [kernel plan](../../doc/fix/2026-10-12-bills-pays-kernel-plan.md) (not product truth).

## Stock

BW warehouse quantity — **`global_stocks`** spine, separate from money.

| Step | Doc |
| :--- | :--- |
| 1 | [stock-spine.md](stock-spine.md) |
| 2 | [procurement_stock spec](../features/procurement_stock/spec.md) + [00-gaps](../features/procurement_stock/00-gaps.md) |

Inbound shipment **money** adapters: [money-kernel-wiring](../features/procurement_stock/money-kernel-wiring.md).

## Document numbering

| Step | Doc |
| :--- | :--- |
| 1 | [document-numbering.md](document-numbering.md) |
