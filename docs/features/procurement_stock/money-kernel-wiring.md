# Inbound shipment ↔ money kernel — wiring map

## As-built

| | |
| :--- | :--- |
| Purpose | How inbound shipment uses the **money kernel spine** via **adapter wrappers only** |
| Adapter SQL | `supabase/schemas/bills_pays/07_shipment_money_wrappers.sql` (migration `20261028150000_*`) |
| Spine (do not edit for shipment) | `supabase/schemas/bills_pays/05_money_spine.sql` — `issue_bill`, `void_bill`, `post_money_out`, … |
| Procurement truth | [spec.md](spec.md) US-1 / US-8, [00-gaps.md](00-gaps.md) |
| Kernel product | [bills_pays/spec.md](../bills_pays/spec.md), [kernel-schema.md](../bills_pays/kernel-schema.md) |
| Web | `shipmentMoneyKernelRepository`, `useShipmentApFinance`, `apPayoutService` — see module map below |

## Scope

| In | Out |
| :--- | :--- |
| Cost rows → AP sync → lock → issue → pay out/in | Delivery paper close (`delivery_close` adapter) |
| Wrapper RPCs + UI read path | Direct `INSERT` into `bills`/`pays` from procurement UI |

---

## Layering

```text
Procurement (cost rows, stamp, outcomes)
        │
        ▼  adapter wrappers (07_shipment_money_wrappers.sql)
Money kernel spine (05_money_spine.sql)
        │
        ▼  legacy bodies still used inside spine
post_ap_payout_with_allocations, create_sales_invoice, …
```

| Layer | Owns |
| :--- | :--- |
| Procurement | `global_shipment_cost_entries`, `costs_locked`, outcomes, landed stamp **inputs** |
| **Adapters** | Map shipment id + buckets → spine calls; advisory lock `shipment_money:{id}` |
| **Spine** | `issue_bill`, `void_bill`, `post_money_out`, `get_bill_net_balances` |
| Legacy (inside spine) | AP draft upsert still in `_upsert_shipment_ap_bill` until BP9 AP payload exists |

---

## Adapter RPCs (public API for inbound)

| RPC | Calls spine / kernel | In | Out |
| :--- | :--- | :--- | :--- |
| `_shipment_money_advisory_lock` | `pg_advisory_xact_lock` | `shipment_id` | — |
| `sync_shipment_ap_bills` | lock → `_upsert_shipment_ap_bill` (draft); cancel/legacy → `void_bill` | `shipment_id` | `{ success, bills \| cancelled }` |
| `issue_shipment_ap_bills` | lock → `issue_bill` per draft AP | `shipment_id` | count issued |
| `issue_shipment_ap_bill_for_kind` | lock → `issue_bill` one bucket | `shipment_id`, `ap_kind` | `bill_id` |
| `get_shipment_money_kernel_bundle` | `get_shipment_settings_finance_bundle` + `get_bill_net_balances` per AP | `shipment_id` | cost entries, AP rows + `net_balances`, FX, `kernel` meta |
| `post_shipment_ap_money_out` | lock → `post_money_out` | shipment + same args as `post_money_out` | `pays` row |
| `settle_shipment_payee` | **Retired** — raises | — | use Payments + `post_shipment_ap_money_out` |

**UI:** `loadSettingsFinanceBundle` → `get_shipment_money_kernel_bundle` only. AP pay → `apPayoutService` → `post_shipment_ap_money_out(_snapshot)` when allocation bills tie to a shipment; else legacy payout RPC inside the service. Do **not** call `listShipmentApBills`, `settle_shipment_payee`, or `post_ap_payout_*` from pages/components.

---

## Action catalog (wired path)

| # | Action | Procurement store | Kernel store | Adapter / spine |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Save cost rows | `global_shipment_cost_entries` | — | save batch RPC → `sync_shipment_ap_bills` |
| 2 | Sync AP | — | draft `bills` | `sync_shipment_ap_bills` → `_upsert_shipment_ap_bill` |
| 3 | Lock costs | `costs_locked` | issued AP | `lock_global_shipment_costs` → sync + `issue_shipment_ap_bills` → **`issue_bill`** |
| 4 | Pay vendor/cargo | — | `pays`, allocations, cashbook | **`post_shipment_ap_money_out`** → **`post_money_out`** |
| 5 | Read AP + open balance | — | bills + settlements | **`get_shipment_money_kernel_bundle`** |
| 6 | Cancel shipment | status | void unpaid AP | sync branch → **`void_bill`** |
| 7 | Commercial fix after issue | cost/outcome (costing) | CN on AP | bills desk `create_bill_adjustment` ([BP8](../bills_pays/00-gaps.md)) |
| 8 | Outcome vendor credit | `global_shipment_outcome_vendor_credits` | — | procurement RPC only; cash via CN/pay |
| 9 | Balance tab wallet settle | — | — | **Blocked** — `settle_shipment_payee` retired |

---

## Web module map (do not call from UI)

| Layer | Path | Role |
| :--- | :--- | :--- |
| Read RPC | `procurement_stock/repositories/shipmentMoneyKernelRepository.ts` | `fetchShipmentMoneyKernelBundle`, `syncShipmentApBills`, `issueShipmentApBillForKind` |
| Types / find | `procurement_stock/repositories/shipmentApBillsRepository.ts` | `ShipmentApBillRow`, `findShipmentApBill` |
| Display | `procurement_stock/utils/shipmentApBillDisplay.ts` | due, chips, bill route |
| Finance state | `procurement_stock/stores/globalShipmentStore.ts` | `loadSettingsFinanceBundle` (one load = SQL sync) |
| After AP pay | `procurement_stock/composables/useShipmentApFinance.ts` | `invalidateAfterApPay` — query keys only |
| Pay router | `bills_pays/services/apPayoutService.ts` | only place that chooses `post_shipment_ap_money_out*` vs legacy payout RPCs |
| Bill → shipment | `bills_pays/utils/shipmentApBillSource.ts` | `resolveShipmentIdsForApPayout` |

**Banned in pages/components:** `post_ap_payout_with_allocations*`, `get_shipment_settings_finance_bundle`, `listShipmentApBills`, `settle_shipment_payee`, client `refresh_global_shipment_fx_from_ap_payments` after pay.

---

## Kernel plug fields

| Field | Value |
| :--- | :--- |
| `source_type` | `shipment_cost` |
| `source_id` | shipment id (string) |
| `source_key` | bucket name today; target `{bucket}:{currency}` ([WA15](../bills_pays/00-gaps.md)) |
| Payee | vendor / cargo / company profile per bucket ([spec US-1](spec.md)) |

---

## Why `upsert_draft_bill` is not used for shipment AP (spine change only if you must)

| Fact | Implication |
| :--- | :--- |
| `upsert_draft_bill` → `create_sales_invoice_from_payload` | Payload path requires AR-style `items` and rejects `invoice_type = ap` (“AP bills are created by sync_shipment_ap_bills only”) |
| Shipment AP has **no** `bill_lines` | Not compatible with compose payload today |

**Adapter choice:** keep `_upsert_shipment_ap_bill` for **draft face + source plug** until BP9 adds an AP branch to the payload writer (change would live in **`create_sales_invoice_from_payload` / public.sql**, not in `05_money_spine.sql`).

**Already on spine (no change needed):** issue (`issue_bill`), void (`void_bill`), pay out (`post_money_out` → `post_ap_payout_with_allocations`), balances (`get_bill_net_balances`).

---

## Mandatory spine edit? **No** for current wiring

Shipment can fully use:

- `issue_bill` / `void_bill` / `post_money_out` / `get_bill_net_balances`

via `07_shipment_money_wrappers.sql` without editing `05_money_spine.sql`.

**Optional later (BP9, not spine file):** teach `create_sales_invoice_from_payload` to accept AP + `source_*` so `_upsert_shipment_ap_bill` can call `upsert_draft_bill` instead of direct `INSERT`. That is a **legacy compose guard**, not a new settlement primitive.

---

## Legacy (do not use)

| RPC | Replacement |
| :--- | :--- |
| `pay_settle_shipment_costs` | sync + `post_shipment_ap_money_out` |
| `settle_shipment_payee` | Payments + AP alloc |
| `return_shipment_to_vendor` (ledger half) | AP CN + `post_vendor_credit_refund` ([BP8](../bills_pays/00-gaps.md)) |

---

## Open gaps

| ID | Job |
| :--- | :--- |
| [WA15](../bills_pays/00-gaps.md) | `source_key` bucket × currency; orphan void slices |
| [BP8](../bills_pays/00-gaps.md) | Shortage/return → AP CN adapter |
| [BP9](../bills_pays/00-gaps.md) | AP via `upsert_draft_bill` after payload AP support |
| [PS13](00-gaps.md) | Full bucket stamp (FX still from material/freight pays) |

---

## RPC quick reference

| Job | RPC |
| :--- | :--- |
| Save costs | `save_shipment_cost_entries` |
| Sync AP drafts | `sync_shipment_ap_bills` |
| Issue AP | `issue_shipment_ap_bills` / `issue_shipment_ap_bill_for_kind` |
| Read finance + balances | `get_shipment_money_kernel_bundle` |
| Pay out (shipment-scoped) | `post_shipment_ap_money_out` / `post_shipment_ap_money_out_snapshot` |
| FX for stamp | `refresh_global_shipment_fx_from_ap_payments` |
| CN / refund | `create_bill_adjustment`, `post_vendor_credit_refund` |
