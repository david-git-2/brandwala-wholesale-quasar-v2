# Bills & pays — gaps (desk cutover)

**Money docs:** [bridge § Atlas](../money_bill_bridge/spec.md#atlas) · [money](../money/spec.md) · [bills](../bills/spec.md) · [bridge](../money_bill_bridge/spec.md).

**Golden tests (live):** [tests.md](tests.md). **Bridge cases:** [bridge/spec.md § Test matrix](../money_bill_bridge/spec.md#test-matrix).

**Legacy drop list:** [bills/spec.md § Legacy cutover](../bills/spec.md#legacy-cutover). **Backfill SQL:** [07-backfill-cutover.sql](../bills/07-backfill-cutover.sql).

---

## Cutover blockers (caller checklist)

### Web — legacy RPC (→ v2 `rpc_*` when deployed)

| RPC | File |
| :--- | :--- |
| `post_money_in` / `post_money_out` | `web/src/modules/bills_pays/repositories/paysRepository.ts`, `web/src/modules/sales_invoice/repositories/invoiceRepository.ts` |
| `reverse_pay`, `void_customer_receipt`, `bounce_cheque_instrument` | `paysRepository.ts` |
| `allocate_payment_to_global_invoice` | `paysRepository.ts` (prefer `apply_settlement_to_bill` until `rpc_pay_bills`) |
| `upsert_draft_bill`, `update_draft_bill`, `issue_*`, `void_bill`, `apply_settlement_to_bill` | `billsRepository.ts` |
| `transfer_cashbook_point` | `cashbookRepository.ts` |
| `post_shipment_ap_money_out*`, `post_ap_payout_with_allocations*` | `apPayoutService.ts` |
| `create_bill_adjustment` | `useCreateBillAdjustmentMutation.ts` |
| `get_bill_net_balances` | `useBillNetBalancesQuery.ts` |

### Cashbook lots (kernel live; desk lag)

Docs: [money spec](../money/spec.md). **`money_kernel.cashbook_lots`** + **`pay_lot_lines`** replaced **`cashbook_point_pots`**. **`rpc_pay_bills.p_lot_debits`** supports manual multi-lot pay.

**Pay dialog (as-built 2026-11):** `get_bill_detail_bundle.pay_cashbook_legs` lists **locations + bundles** (`books_rate`, `drawer_group`) for picker; UI = location dropdown then bundle chips; balances from bundle, not standalone pot-RPC reads. **Still open:** `public.pays` / `post_ap_payout_*` legacy paths; multi-bundle `p_bundle_debits` in pay UI.

### Payment dialog — FX, deposit, partial pays

Full plan: [bridge/spec.md § Payment dialog](../money_bill_bridge/spec.md#payment-dialog). **As-built:** FX from books rates (Phase 1); **Add money** top-up / new bundle (Phase 2); editable payment amount ≤ bill due, in words, partial **Paying now** summary (Phase 3). **Still open:** kernel I7b vs desk AP FX edge cases.

### AP `from_profile_id` / `to_profile_id` (kernel)

On `money_kernel.bills`, **from = payer (tenant on AP)**, **to = payee (vendor/cargo)**. Pay UI `pay_cashbook_legs` and `MoneyPayDialog` map **From pot → from**, **To pot → to** — no AP swap. Shipment AP bills created with document orientation (vendor on `from`) were backfilled in `20261112220000_ap_pay_cashbook_legs_spine_orientation.sql`.

### Desk AR From/To labels (as-built 2026-11)

Kernel stores **debtor → creditor** (`from_profile_id` / `to_profile_id`). Desk **AR** list/detail/preview show document flow **issuer (tenant) → customer** by mapping **From = `to_profile`**, **To = `from_profile`**. AP list keeps payer → payee order on kernel columns.

### Desk list (as-built 2026-11)

- **List:** `list_bills_desk_page(p_to_profile_type, p_from_profile_id, status filters)` — kernel-only (`money_kernel.bills`); no `ar_side` / search.
- **Detail:** `get_bill_detail_bundle` / `get_bill_desk_row` — kernel-only; `public.bills` is a **read view** over `money_kernel.bills` (legacy table dropped 2026-11-14).
- **Void (kernel):** `BillDetailPage` → `rpc_void_bill` when bundle `bill.spine = kernel`.
- **Legacy rows** without `to_profile_id` do not appear on payee-type tabs until backfilled.

### Web — direct table read

| Table | File | Replacement |
| :--- | :--- | :--- |
| `cashbook_entries` | `shop_order/repositories/courierRemittanceRepository.ts` | `get_cashbook_account_balances` per profile |
| `pay_instruments` | `paysRepository.ts` (pay detail) | `pays.meta` / v2 shape |

### SQL — legacy table writers (→ settlements / pots only)

| Table | Schema files (non-exhaustive) |
| :--- | :--- |
| `cashbook_entries` | `12_cashbook_wiring.sql`, `16_cashbook_transfer.sql`, `05_money_spine.sql`, `10_returns_kernel.sql`, `11_pay_reverse.sql`, `18_money_purposes.sql`, … |
| `pay_allocations` | `05_money_spine.sql` (`_kernel_record_pay_bill_settlement` — stop INSERT) |
| `pay_instruments` | Customer receipt / cheque paths in `12_cashbook_wiring.sql`, `11_pay_reverse.sql` |
| `money_purposes` | `18_money_purposes.sql` |

---

## Open

| # | Gap |
| :---: | :--- |
| 1 | Publish live-vs-v2 column diff on `bills` / `pays` / `profiles` |
| 2 | Cheque flow without `pay_instruments` |
| 3 | `pnpm run backend:local` for `20261111203000_money_spine_settlements_only_legacy_deprecate.sql`; then backfill + uncomment DROP in `99_legacy_kernel_cutover.sql` |
