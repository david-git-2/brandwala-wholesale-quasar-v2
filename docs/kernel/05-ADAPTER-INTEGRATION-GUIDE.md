# Adapter integration guide

**Job:** How Shipments, Dropship Shop, POS, and Delivery Close plug into the kernel — `source_*` tuples, profiles, mixed-currency bucket splits, and **balance reads without direct table math**.

RPC detail: [04-RPC-AND-API-CONTRACTS](04-RPC-AND-API-CONTRACTS.md). Invariants: [01-SYSTEM-INVARIANTS](01-SYSTEM-INVARIANTS.md).

---

## Plug matrix

| Feature | `source_type` | `source_id` | `source_key` | From → To | Lines |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Wholesale / walk-in POS | `compose` | bill id / null | — | Tenant → Customer | `stock`, `charge`, `description` |
| Trade desk | `compose` | null | — | Selected → Selected | same |
| Shipment AP | `shipment_cost` | shipment id | `{bucket}:{currency}` | Vendor/Cargo → Tenant | **No stock** |
| Dropship shop | `shop_order` | order id | `merchant_bill`, `courier_ap`, … | Tenant → Merchant/Courier | `description`, `charge` |
| Delivery close | `delivery_close` | paper id | — | Tenant → Customer | per close |
| After-sales | parent `source_*` | | | same as parent | `kernel_create_bill_adjustment` |

**Live legacy (retire, do not extend):** `bills.ap_shipment_id`, `bills.shop_order_id`, `shop_orders.global_invoice_id` → migrate to source plug [BP9](../features/bills_pays/00-gaps.md).

---

## Building `source_*`

1. **`source_type`** — stable adapter id string (not `invoice_type`).
2. **`source_id`** — string form of domain pk (`shipment_id`, `order_id`).
3. **`source_key`** — optional slice; **required** for shipment AP per [WA15](../features/bills_pays/00-gaps.md): `material:USD`, `freight:GBP`.

One **standard** issued bill per `(parent_tenant_id, source_type, source_id, source_key)` when plug is set.

---

## Profile mapping

| Party | `profiles` |
| :--- | :--- |
| Customer / buyer | `profile_type = customer`, `subject_id` = group or party |
| Dropship merchant | Shop-linked customer profile |
| Vendor / cargo | `vendor` / `cargo` profiles on shipment header |
| Tenant books | Tenant or company profile for `parent_tenant_id` |

Pass **`p_profile_id`** on pays (counterparty). From/to on bill header (target) or derive from `invoice_type` + `profile_id` (live).

---

## Shipment AP — mixed currency

1. Group cost rows: **bucket** × **currency_code**.
2. One `kernel_upsert_draft_bill` per group — never one issued bill with mixed line currencies.
3. Sync while unlocked: refresh drafts; on lock → `kernel_issue_bill` batch.
4. After issue: commercial change = **note**, not header total edit.

Live: `sync_shipment_ap_bills` / `ap_kind` until WA15 fully shipped.

---

## What adapters must call

| Need | Call | Do not |
| :--- | :--- | :--- |
| Draft / issue | `kernel_upsert_draft_bill`, `kernel_issue_bill` (live equivalents) | `INSERT INTO bills` |
| Collect / pay out | `kernel_post_payment` | Direct `pays` insert |
| Correct issued paper | `kernel_create_bill_adjustment` | `UPDATE total_amount` |
| Due / open credit | `get_bill_net_balances`, `list_*_for_source` (when BP10 lands) | `SUM(pay_allocations)` in feature SQL |
| Custody balance | Cashbook read RPCs / entity ledger | Ad-hoc wallet tables |

---

## Dropship adapter sequence (reference)

1. Ship → issue merchant AR + courier AP (`shop_order` source).
2. Deliver → courier custody ledger (not tenant sales).
3. Remittance → `kernel_post_payment` with `source = courier_remittance`, alloc merchant bill, leftover → merchant custody.
4. Payout profit → `dispense_middleman_payout_from_tenant` (cashbook only).

Numbers: [06-ACCOUNTING-FLOWS-AND-GOLDEN-SCENARIOS](06-ACCOUNTING-FLOWS-AND-GOLDEN-SCENARIOS.md).

## Supabase client discipline

- Adapters call **RPCs** via `supabase-js` (PostgREST), not raw Postgres from the SPA.
- Do not point server drivers with named prepared statements at the **transaction** pooler (port 6543); use **session** pooler (5432) or disable prepare mode. `[verify against current Supabase docs]`
- Writes and reads use the same Supabase project HTTPS URL unless a documented worker sets `DATABASE_URL_SESSION`.
- Details: [PHASE-C-SUPABASE-RUNTIME.md](PHASE-C-SUPABASE-RUNTIME.md) (C1–C2).
