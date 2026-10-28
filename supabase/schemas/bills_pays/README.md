# `bills_pays` declarative SQL (kernel)

**Product map:** [docs/features/bills_pays/README.md](../../../docs/features/bills_pays/README.md)

| File | Role |
| :--- | :--- |
| `01_types.sql` | Enums (archive copy; live types still in `public.sql` until full split) |
| `02_tables.sql` | Core tables (archive reference) |
| `05_money_spine.sql` | **Kernel spine** — settlements, locks, target RPCs (source for migrations) |
| `06_bills_desk_wrappers.sql` | Desk wrappers — `update_draft_bill`, `issue_wholesale_bill`, `issue_retail_bill` |
| `07_shipment_money_wrappers.sql` | Inbound shipment adapters — sync/issue/pay/read; calls spine; do not edit `05` for shipment |
| `04_rls.sql` | RLS (archive reference) |

Edit `05_money_spine.sql` first, then add a forward migration that applies the same DDL or run `pnpm run backend:schema:sync` after adding this folder to `schema_paths`.

Legacy RPC bodies remain in `schemas/public.sql` until domain split; new kernel surface lives in `05_money_spine.sql`.
