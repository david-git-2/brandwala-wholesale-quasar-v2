# Thrift vertical (docs)

Standalone tenant-scoped thrift. Not wired to `global_stocks` / `global_invoices`.

> **Note:** Folder reorg (Aug 2026). `web/public/doc` is a **symlink** to `doc` — never `rm` via the public path.

## Domains

| Domain | Schema | Workflow |
| :--- | :--- | :--- |
| [settings](./settings/) | [schema](./settings/schema.md) | [workflow](./settings/workflow.md) |
| [catalog](./catalog/) | [schema](./catalog/schema.md) | [workflow](./catalog/workflow.md) |
| [inbound](./inbound/) | [schema](./inbound/schema.md) | [workflow](./inbound/workflow.md) |
| [barcode](./barcode/) | [schema](./barcode/schema.md) | [workflow](./barcode/workflow.md) |
| [stock](./stock/) | [schema](./stock/schema.md) | [workflow](./stock/workflow.md) |
| [sales](./sales/) | [schema](./sales/schema.md) | [workflow](./sales/workflow.md) — invoices, courier catalog, PnL lines, **returns** · [scenarios](./sales/scenarios.md) |
| [ledger](./ledger/) | [schema](./ledger/schema.md) | [workflow](./ledger/workflow.md) — money events only |
| [reports](./reports/) | [schema](./reports/schema.md) | [workflow](./reports/workflow.md) — PnL lines + live inbound COGS |

Sales economics redesign: [task.md](./task.md). Focused checklists: [task-rto.md](./task-rto.md) (DELIVERED PnL + refuse/RTO) · [task-post-accept-return.md](./task-post-accept-return.md) (return claim). **Do not change** inbound shipment or stock schemas for that work.

Worked examples: [sales/scenarios.md](./sales/scenarios.md).

## Index

- [schema.md](./schema.md) — table map
- [workflow.md](./workflow.md) — lifecycle
- [task.md](./task.md) — sales economics overview
- [task-rto.md](./task-rto.md) — DELIVERED PnL + Mark RTO
- [task-post-accept-return.md](./task-post-accept-return.md) — post-accept Return items + returns hub

## Stock extras

- [stock/costing.md](./stock/costing.md)
- [stock/workflow_hold.md](./stock/workflow_hold.md)
- [stock/fixtures/](./stock/fixtures/)
