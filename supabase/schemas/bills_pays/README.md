# `bills_pays` declarative SQL (kernel)

**Product map:** [bridge spec](../../../docs/features/money_bill_bridge/spec.md#atlas)

| File | Role |
| :--- | :--- |
| `01_types.sql` | Enums (archive copy; live types still in `public.sql` until full split) |
| `02_tables.sql` | Core tables (archive reference) |
| `05_money_spine.sql` | **Kernel spine** — settlements, locks, target RPCs (source for migrations) |
| `03_adjustments.sql` | `create_bill_adjustment` (credit/debit notes + optional cash refund) |
| `06_bills_desk_wrappers.sql` | Desk wrappers — `update_draft_bill`, `issue_wholesale_bill`, `issue_retail_bill` |
| `06b_desk_kernel_bridge.sql` | Desk read bridge — `money_kernel.bills` → legacy-compatible list/detail JSON |
| `07_shipment_money_wrappers.sql` | Inbound shipment adapters — sync/issue/pay/read; calls spine; do not edit `05` for shipment |
| `07_shipment_ap_bucket_paper.sql` | `_build_shipment_ap_bucket_paper` — AP bucket paper from kernel shipment AP bill lines |
| `07_shipment_ap_upsert.sql` | `_upsert_shipment_ap_bill` — draft sync, issued immutability, cost-sync notes |
| `07_shipment_cost_lock.sql` | `lock_global_shipment_costs` — lock → sync → issue AP batch |
| `07_shipment_landed_fx_kernel.sql` | `shipment_ap_bucket_paid_totals` — capitalizable totals from kernel shipment AP bill lines |
| `08_kernel_compose_adapters.sql` | BP9 — compose/shop/courier/wholesale kernel upsert + legacy shims |
| `08_shipment_landed_cost_stamp.sql` | `stamp_global_shipment_landed_costs` — landed unit cost stamp |
| `09_kernel_reads.sql` | BP10 + BP23 — `v_kernel_bill_summaries`, `list_*_for_source`, `list_open_on_profile` |
| `09_wholesale_stock_issue.sql` | BP17 — `commit_sales_bill_stock`, `commit_wholesale_bill_stock`, `_bill_line_global_stock_id` |
| `10_returns_kernel.sql` | BP5 — `process_wholesale_invoice_return` CN path, dropship CN helper + `finalize_dropship_return` patch |
| `11_pay_reverse.sql` | BP12 + BP11 custody apply + WA13 — `_kernel_reverse_payment`, `reverse_pay`, `bounce_cheque_instrument` (partial split tender), `_kernel_apply_custody_to_bill` |
| `12_cashbook_wiring.sql` | BP15 + BP16 + BP21 — collect point/pot/FX, `account_class`, `list_books_exchange_rates`, wallet read patches |
| `13_commission_payout.sql` | BP24 — `_kernel_post_commission_payout` (commission on `post_money_out`) |
| `14_post_sales_invoice.sql` | BP17 — `post_sales_invoice` stock via `commit_sales_bill_stock` |
| `15_pay_payout_alloc.sql` | BP18‑c — `post_ap_payout_with_allocations` (settlements-first alloc) |
| `16_cashbook_transfer.sql` | BP15‑t — `transfer_cashbook_point`, `_kernel_lock_cashbook_points_for_transfer` |
| `17_payment_profile_read.sql` | BP26 — payments profile page read & two-sided pay reads |
| `18_money_purposes.sql` | BP27–BP29 — money purpose registry + pay/bill plug columns + tenant deposit/withdraw |
| `19_tenant_default_money_profiles.sql` | Tenant default income/expense sink profiles + pay from/to resolution |
| `20_cashbook_profile_spine.sql` | Cashbook accounts keyed by `profiles.id`; default main point + BDT pot |
| `23_vendor_credit_refund.sql` | `post_vendor_credit_refund` — vendor AP credit note cash refund via kernel |
| `04_rls.sql` | RLS (archive reference) |
| `100_public_bills_kernel_compat.sql` | `public.bills` / `bill_lines` read compat views over kernel (post-cutover) |

> **Note:** This folder is **not** in `supabase/config.toml` (`schema_paths`) yet—active declarative SQL is `public.sql` + `money_kernel_v2/`. Edit `05_money_spine.sql` (or the relevant adapter file) as a reference/source, then add a forward migration that applies the same DDL.

**Money spine v2 (parallel kernel):** declarative SQL lives in [`../money_kernel_v2/`](../money_kernel_v2/) (on `schema_paths` in `config.toml`). Forward migration: `20261111210000_money_spine_v2_kernel.sql`.

Legacy RPC bodies remain in `schemas/public.sql` until domain split; new kernel surface lives in `05_money_spine.sql`.
