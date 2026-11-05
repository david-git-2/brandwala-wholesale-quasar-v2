# Platform kernels

## Money

Shared ledger: **bills · pays · cashbook**. Features plug in; they do not own invoice tables.

## Read order (money)

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

## Stock

BW warehouse quantity and movements — **`global_stocks`** spine, separate from money.

| Step | Doc |
| :--- | :--- |
| 1 | [stock-spine.md](stock-spine.md) — Tier 1/2 action catalog, movement types, RPC index, dispatch vs bill issue |
| 2 | [procurement_stock spec](../features/procurement_stock/spec.md) + [00-gaps](../features/procurement_stock/00-gaps.md) |
| 3 | Grep `create_and_post_stock_movement` / `commit_sales_bill_stock` in `supabase/schemas/` |

Inbound shipment **money** adapters: [money-kernel-wiring](../features/procurement_stock/money-kernel-wiring.md) (do not confuse with stock spine).

## Document numbering

Human-facing document codes (orders, bills, shipments, movements) — not thrift.

| Step | Doc |
| :--- | :--- |
| 1 | [document-numbering.md](document-numbering.md) — sequences, `doc_type` catalog, prod scripts |
| 2 | Grep `next_document_number` in `supabase/schemas/public.sql` |
