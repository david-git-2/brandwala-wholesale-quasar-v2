# `bills_pays` declarative SQL (kernel)

**Product map:** [docs/features/bills_pays/README.md](../../../docs/features/bills_pays/README.md)

| File | Role |
| :--- | :--- |
| `01_types.sql` | Enums (archive copy; live types still in `public.sql` until full split) |
| `02_tables.sql` | Core tables (archive reference) |
| `05_money_spine.sql` | **Kernel spine** — settlements, locks, target RPCs (source for migrations) |
| `03_adjustments.sql` | `create_bill_adjustment` (credit/debit notes + optional cash refund) |
| `06_bills_desk_wrappers.sql` | Desk wrappers — `update_draft_bill`, `issue_wholesale_bill`, `issue_retail_bill` |
| `07_shipment_money_wrappers.sql` | Inbound shipment adapters — sync/issue/pay/read; calls spine; do not edit `05` for shipment |
| `08_kernel_compose_adapters.sql` | BP9 — compose/shop/courier/wholesale kernel upsert + legacy shims |
| `09_kernel_reads.sql` | BP10 + BP23 — `v_kernel_bill_summaries`, `list_*_for_source`, `list_open_on_profile` |
| `10_returns_kernel.sql` | BP5 — `process_wholesale_invoice_return` CN path, dropship CN helper + `finalize_dropship_return` patch |
| `11_pay_reverse.sql` | BP12 + BP11 custody apply + WA13 — `_kernel_reverse_payment`, `reverse_pay`, `bounce_cheque_instrument`, `_kernel_apply_custody_to_bill` |
| `12_cashbook_wiring.sql` | BP15 + BP16 + BP21 — collect point/pot/FX, `account_class`, `list_books_exchange_rates`, wallet read patches |
| `13_commission_payout.sql` | BP24 — `_kernel_post_commission_payout`, `dispense_*` shim |
| `09_wholesale_stock_issue.sql` | BP17 — `commit_wholesale_bill_stock`, `_bill_line_global_stock_id` |
| `04_rls.sql` | RLS (archive reference) |

Edit `05_money_spine.sql` first, then add a forward migration that applies the same DDL or run `pnpm run backend:schema:sync` after adding this folder to `schema_paths`.

Legacy RPC bodies remain in `schemas/public.sql` until domain split; new kernel surface lives in `05_money_spine.sql`.
