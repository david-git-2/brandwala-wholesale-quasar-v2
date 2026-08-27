# Dropship Management Desk (v1 UI shell)

Staff-facing settlement desk for dropship orders **in transit or delivered** — i.e. after the order has left the warehouse (`shipped`) or reached the recipient (`delivered`). **Current state: dummy UI only** — list/detail are not wired to live RPCs; wallet writes and settlement save are not wired.

Related: [`SHOP_ORDER.md`](./SHOP_ORDER.md) (dropship desk inventory), [`WALLET.md`](../wallet/WALLET.md) (ledger rules), existing [`DropshipFinanceHubPage`](../../web/src/modules/shop_order/pages/DropshipFinanceHubPage.vue) (3-step courier remittance flow).

---

## 1. List scope (status filter)

The list page shows **only** dropship orders where `shop_orders.status` is:

| Status | Meaning on desk |
| :--- | :--- |
| `shipped` | Courier has the parcel; COD not yet collected |
| `delivered` | Parcel delivered; staff can reconcile collected COD and costs |

**Excluded** from this desk: `submitted`, `confirmed`, `placed`, `processing`, `ready_for_pickup`, `returned`, `payment_received`, and any earlier lifecycle states.

The status dropdown on the list is a **subset filter** within that set:

| UI option | Server filter |
| :--- | :--- |
| All statuses | `status IN ('shipped', 'delivered')` |
| Shipped | `status = 'shipped'` |
| Delivered | `status = 'delivered'` |

Dummy data still includes `pending` / `processing` for layout only — remove when wiring live data.

---

## 2. Routes (UI shell)

| Route | Page | Status |
| :--- | :--- | :--- |
| `/:tenantSlug?/app/shop/dropship-management` | [`DropshipManagementPage.vue`](../../web/src/modules/shop_order/pages/DropshipManagementPage.vue) | Dummy list + search/filter |
| `/:tenantSlug?/app/shop/dropship-management/:id` | [`DropshipManagementDetailPage.vue`](../../web/src/modules/shop_order/pages/DropshipManagementDetailPage.vue) | Dummy settlement form |

Dummy seed data: [`dropshipManagementDummyOrders.ts`](../../web/src/modules/shop_order/data/dropshipManagementDummyOrders.ts).

---

## 3. API — list page

### Existing RPC: `list_dropship_shop_orders_for_staff`

**Status: exists and wired in repository/service** — same RPC used by [`DropshipOrdersPage`](../../web/src/modules/shop_order/pages/DropshipOrdersPage.vue).

```sql
list_dropship_shop_orders_for_staff(
  p_tenant_id bigint,
  p_limit         integer default 20,
  p_offset        integer default 0,
  p_status        text    default null,   -- single status equality
  p_search        text    default null
) returns table (...)
```

- **Security:** `SECURITY DEFINER`; requires `is_tenant_staff(p_tenant_id)`
- **Scope:** `shop_orders` where `shop_type_snapshot = 'dropship'`
- **Migrations:** `20261115000000_list_dropship_shop_orders_for_staff.sql`, `20270129000009_dropship_ux_order_settlement_fields.sql`

#### Response columns (list)

| Column | Maps to UI field |
| :--- | :--- |
| `order_no` | Order name |
| `customer_group_name` | Merchant |
| `recipient_name` | Recipient |
| `courier_name` | Courier |
| `status` | Status badge |
| `cod_collect_amount` | Calculated COD (expected; confirm against invoice on detail) |
| `courier_awb_number` | AWB (detail meta) |
| `recipient_phone` | Recipient phone (detail meta) |
| `total_amount` | Line-sum fallback total |
| `payout_settlement_status` | Future: hide settled rows |

#### Gap: multi-status default filter

When `p_status` is `null`, the RPC returns **all** operational dropship statuses (confirmed through payment_received). This desk needs **`shipped` + `delivered` only**.

| Approach | Notes |
| :--- | :--- |
| **A. Two calls (v1 wire)** | Parallel `p_status = 'shipped'` and `p_status = 'delivered'`; merge + sort client-side. Works today; pagination is approximate. |
| **B. Extend RPC (preferred)** | Add `p_statuses text[] default null`. When set, `status = any(p_statuses)`. Desk passes `array['shipped','delivered']` on load. |
| **C. Dedicated RPC** | `list_dropship_management_orders_for_staff` with fixed `shipped`/`delivered` filter + settlement flags. Clearer ownership; more surface area. |

**Recommendation:** **B** — extend `list_dropship_shop_orders_for_staff` with optional `p_statuses`; keep `p_status` for single-tab use on `DropshipOrdersPage`.

#### Frontend wiring (today)

| Layer | Name |
| :--- | :--- |
| RPC | `list_dropship_shop_orders_for_staff` |
| Repository | `shopOrderRepository.listDropshipShopOrdersForStaff(tenantId, { status, search, limit, offset })` |
| Service | `shopOrderService.fetchDropshipStaffOrders(...)` |
| Query key (proposed) | `shopOrderQueryKeys.dropshipManagementList(tenantId, { status, search })` |

Search (`p_search`) matches: `order_no`, `recipient_name`, `recipient_phone`, `courier_awb_number`, `courier_name`, courier service name, `customer_group_name`, `created_by_email`.

---

## 4. API — detail page

### Existing RPC: `get_dropship_order_detail_v2`

**Status: exists** — use for header, recipient, courier, AWB, COD summary, charge breakdown, and line items. See [`SHOP_ORDER.md` §10.2](./SHOP_ORDER.md#102-rpc-get_dropship_order_detail_v2).

| Desk field | Source key |
| :--- | :--- |
| Order name | `order.order_no` |
| Merchant | `order.customer_group_name` |
| Recipient / phone | `order.recipient_name`, `order.recipient_phone` |
| Courier / AWB | `fulfillment.courier`, `order.courier_awb_number` |
| Total calculated COD | `summary.cod_collect_amount` or `computed.recipient_grand_total` |
| Charge rows | `summary` + `computed` |

### Missing RPCs (settlement)

| RPC | Purpose | Status |
| :--- | :--- | :--- |
| `get_dropship_management_order` | Detail + draft settlement from `dropship_order_settlements` | **Not implemented** |
| `save_dropship_settlement_draft` | Upsert settlement header + charge lines (`draft`) | **Not implemented** |
| `mark_dropship_order_delivered` | Step ① — status + courier COD credit + invoice | **Not implemented** |
| `record_dropship_courier_bank_transfer` | Step ② — remittance + invoice paid + tenant credit | **Not implemented** |
| `transfer_dropship_reseller_profit` | Step ③ — tenant debit + merchant credit | **Not implemented** |

Until settlement RPCs exist, detail can load `get_dropship_order_detail_v2` and keep settlement edits client-only (as dummy UI does today).

### Field mapping — load (v1 auto-fill)

| Form field | Source today | Gap |
| :--- | :--- | :--- |
| Header / courier / AWB | `get_dropship_order_detail_v2` | None |
| Calculated COD | `computed.recipient_grand_total` or `summary.cod_collect_amount` | None |
| Collected COD | `shop_orders.cod_collect_amount` (temporary) | Needs `collected_cod_amount` on settlement table |
| Delivery / print / packing amount | `shop_orders.*_charge_amount` | None for amounts |
| Charge payer (recipient / merchant) | `deduct_*_from_margin` booleans | 2-way only; **company** payer missing |
| Charge payer = company | — | Needs `dropship_settlement_charge_lines.payer` |
| Return cost | `shop_orders.return_charge_amount` | None for amount |
| Return reason | `return_override_reason` (partial) | Settlement-specific note on settlement table |
| Discount (company pay) | `shop_orders.discount_amount` (checkout) | Do not reuse — needs `discount_company_pay` on settlement |
| Reseller purchase cost | Sum `shop_order_items.cost_price_amount × qty` | Editable override → `reseller_purchase_cost` on settlement |

---

## 5. Data model — three layers (no legacy settlement table)

There is **no** `dropship_settlement_snapshots` table in the database. That name was a doc placeholder only — nothing to drop or retire.

Today’s live settlement path (keep until this desk replaces it end-to-end):

| Piece | Role |
| :--- | :--- |
| `shop_orders` columns | Operational charges, COD, remittance refs, `payout_settlement_status` |
| **Finance Hub** | 3-step: delivered costing → courier remittance → merchant payout |
| `universal_wallet_ledger` | Actual money (`delivered_costing`, `courier_remittance`, `dropship_profit`) |

This desk adds a **new accounting layer** — not a replacement for an existing settlement table.

```mermaid
flowchart LR
    A["shop_orders<br/>(operations — editable)"] --> B["dropship_order_settlements<br/>(accounting — draft → confirmed)"]
    B --> C["universal_wallet_ledger<br/>(cash movements)"]
```

### Why not store accounting on `shop_orders`?

| Problem | Settlement table fixes it |
| :--- | :--- |
| One `cod_collect_amount` — no expected vs collected split | `calculated_cod_amount` + `collected_cod_amount` |
| `deduct_*_from_margin` = recipient vs merchant only | 3-way payer enum per charge line |
| Checkout `discount_amount` ≠ settlement “company pays discount” | `discount_company_pay` |
| Values change during processing | Immutable record after `confirmed` |
| Wallet ledger has amounts, not full charge + payer breakdown | Normalized charge lines for reports / future GL |

**Do not** add 15 accounting columns to `shop_orders`. Keep operational fields there; settlement facts live in the new tables.

### Proposed tables (not migrated yet)

#### `dropship_order_settlements` (1 row per order)

| Column | Type | Notes |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `tenant_id` | bigint | RLS scope |
| `shop_order_id` | bigint UNIQUE | FK → `shop_orders` |
| `billing_profile_id` | bigint | Merchant entity for payout |
| `currency_id` | bigint | Sell currency |
| `calculated_cod_amount` | numeric | Expected COD at settlement time |
| `collected_cod_amount` | numeric | Actual cash collected |
| `reseller_purchase_cost` | numeric | Editable override (default from item sum) |
| `discount_company_pay` | numeric | Company-paid discount |
| `return_reason_note` | text | |
| `total_cost` | numeric | Stored computed (optional) |
| `reseller_profit` | numeric | Stored computed (optional) |
| `company_profit` | numeric | Stored computed (optional) |
| `status` | text | `draft` \| `confirmed` |
| `confirmed_at` | timestamptz | Set on step ③ confirm |
| `confirmed_by` | uuid | Staff user |
| `courier_cod_booked_at` | timestamptz | Step ① complete |
| `remittance_at` | timestamptz | Step ② complete |
| `merchant_payout_at` | timestamptz | Step ③ complete |
| `wallet_ledger_batch_id` | text | Link to ledger entries |

#### `dropship_settlement_charge_lines` (child rows)

| Column | Type | Notes |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `settlement_id` | bigint FK | → `dropship_order_settlements` |
| `charge_type` | text | `delivery` \| `print` \| `packing` \| `return` \| `cod` |
| `amount` | numeric | |
| `payer` | text | `recipient` \| `merchant` \| `company` |

Unique constraint: `(settlement_id, charge_type)`.

### What stays on `shop_orders` (operational only)

- `status`, recipient, courier, AWB, `delivered_at`
- Processing-time charge defaults (`*_charge_amount`, `deduct_*_from_margin`)
- `courier_remittance_ref`, `courier_bank_trx_id`, `payout_settlement_status`
- Line-level buy/sell/resell on `shop_order_items`

---

## 6. List page fields

| Field | Source (today) | Target (live) |
| :--- | :--- | :--- |
| Order name | `name` | `shop_orders.order_no` |
| Merchant | `merchant` | Reseller / customer group display name |
| Recipient | `recipient` | Delivery contact name |
| Courier | `courierName` | Assigned courier service |
| Status | `status` | `shop_orders.status` — **`shipped` or `delivered` only** on list (§1) |
| Calculated COD | `calculatedCod` | Confirmed resell invoice total |

---

## 7. Detail page — field inventory

### Header / context

| Field | UI | Notes |
| :--- | :--- | :--- |
| Order name | Title | |
| Merchant · Recipient | Subtitle | |
| Status badge | Header | |
| Recipient phone | Meta strip | |
| Courier name | Meta strip | |
| AWB | Meta strip | |

### COD summary

| Field | Editable | Notes |
| :--- | :--- | :--- |
| **Total calculated COD** | No (auto) | Expected COD from confirmed resell invoice before delivery adjustments |
| **Total collected COD** | Yes (input) | Actual cash collected by courier at delivery |

Show variance when collected ≠ calculated.

### Cost breakdown (invoice paper summary layout)

Two columns per row — **label** on the left, **value or input** on the right. Same pattern as `DropshipOrderConfirmedInvoicePaper` summary. Auto rows show **Auto** under the label.

| Row | Right side | Notes |
| :--- | :--- | :--- |
| Total calculated COD | Amount (auto) | Expected COD from confirmed resell invoice |
| Total collected COD | Number input | Actual cash collected by courier |
| Recipient pays | Amount (auto) | Resell items total |
| Delivery | Amount input + payer toggle | Payer: recipient / merchant / company |
| Print | Amount input + payer toggle | Same pattern |
| Packing | Amount input + payer toggle | Same pattern |
| Return cost | Amount input + payer toggle | Same pattern |
| Return reason note | Textarea | Free text when return cost &gt; 0 |
| Discount (company pay) | Amount input | **Deduct from company profit** |
| Reseller purchase cost | Amount input | Wholesale / floor purchase total |
| Reseller profit | Amount (auto) | See §8 |
| Total cost | Amount (auto) | Purchase + all charge lines |
| Company profit | Amount (auto) | After discount |

### Settlement actions (3-step wallet flow — dummy UI)

Replace the single “payment received” button with **three gated actions**. Each step maps to wallet ledger movements ([`WALLET.md`](../wallet/WALLET.md) §2.2). Buttons are **not wired** in v1 shell.

```mermaid
flowchart TD
    A["shipped"] --> B["① Mark as delivered"]
    B --> C["delivered"]
    C --> D["② Bank transfer from courier"]
    D --> E["payment_received"]
    E --> F["③ Transfer to reseller"]
```

| Step | Button label | Enabled when (dummy) | Wallet effect (target) | Order / invoice |
| :--- | :--- | :--- | :--- | :--- |
| **①** | **Mark as delivered** | `status = shipped` | Courier wallet **credit** = collected COD | `delivered`; post tenant B2B shipment invoice |
| **②** | **Bank transfer from courier** | `status = delivered` | Courier **debit** gross COD; tenant **credit** net; courier fee as separate line | `payment_received`; tenant invoice **paid** |
| **③** | **Transfer to reseller** | `status = delivered` or `payment_received` (dummy) | Tenant **debit**; reseller wallet **credit** = `reseller_profit` | `payout_settlement_status` → paid |

**Form fields** (COD, charges, payers, purchase cost) feed steps ① and ②. Step ③ uses computed `reseller_profit`.

**Existing RPCs to wrap (when wiring):**

| Step | Orchestration RPC (new) | Composes |
| :--- | :--- | :--- |
| ① | `mark_dropship_order_delivered` | `save_dropship_settlement_draft` + `advance_dropship_order_status` + `confirm_dropship_delivered_costing` + invoice create/post |
| ② | `record_dropship_courier_bank_transfer` | `record_dropship_courier_remittance` (`process_dropship_courier_remittance_uwl`) |
| ③ | `transfer_dropship_reseller_profit` | `dispense_middleman_payout_from_tenant` (order-scoped amount from settlement) |

Finance Hub remains the **live** path until this desk wires all three steps (§11).

---

## 8. Proposed calculated formulas (discussion — not locked)

Dummy UI uses placeholder math so the page feels alive. **Replace before wiring backend.**

```
total_cost = reseller_purchase_cost
           + delivery + print + packing + return_cost

reseller_profit = total_collected_cod
                - reseller_purchase_cost
                - sum(charges where payer = merchant)

company_profit = reseller_profit - discount_company_pay
```

**Open questions**

1. Should **company-paid** charges reduce `company_profit` directly (in addition to discount)?
2. Should **recipient-paid** charges affect `recipient_pays` vs `total_collected_cod` reconciliation?
3. How do **partial delivery / partial return** qty changes flow from processing desk into this page?

---

## 9. Wallet flow (locked — 3 steps)

Wallet = money in/out ledger per entity (`courier`, `tenant`, `merchant`). This desk exposes the same 3-step model as Finance Hub, as **three separate buttons** — not one combined confirm.

```mermaid
flowchart LR
    A["① Mark delivered<br/>Courier +COD"] --> B["② Bank from courier<br/>Courier -gross<br/>Tenant +net"]
    B --> C["③ Reseller payout<br/>Tenant -profit<br/>Merchant +profit"]
```

### Step ① — Mark as delivered

| What | Detail |
| :--- | :--- |
| Trigger | Staff confirms collected COD + charge breakdown on form |
| Order | `shipped` → `delivered` |
| Courier wallet | **Credit** `collected_cod_amount` (courier holds COD owed to tenant) |
| Invoice | Create/post **tenant B2B shipment invoice** (accounting) — **product change:** move from `ready_for_pickup` to `delivered` if shipment-based accounting is adopted |
| Settlement table | Upsert `dropship_order_settlements` (`draft`); set `courier_cod_booked_at` |

### Step ② — Bank transfer from courier

| What | Detail |
| :--- | :--- |
| Trigger | Staff enters remittance ref, net amount, courier charge |
| Order | `delivered` → `payment_received` |
| Courier wallet | **Debit** gross COD (split: net to tenant + courier fee — two visible ledger lines preferred) |
| Tenant wallet | **Credit** net remitted amount |
| Invoice | `global_invoices` linked to order marked **paid** (up to amount received) |
| Settlement table | Set `remittance_at`, store bank ref |

### Step ③ — Transfer to reseller

| What | Detail |
| :--- | :--- |
| Trigger | Staff confirms `reseller_profit` from settlement form |
| Tenant wallet | **Debit** payout amount |
| Merchant / reseller wallet | **Credit** `reseller_profit` |
| Order | `payout_settlement_status` → `paid` |
| Settlement table | `status = confirmed`, `merchant_payout_at` |

### What stays on Finance Hub until desk is wired

| Finance Hub step | Maps to desk button |
| :--- | :--- |
| Delivered costing | ① Mark as delivered |
| Courier remittance | ② Bank transfer from courier |
| Merchant payout | ③ Transfer to reseller |

Retire Finance Hub for dropship **only after** all three desk buttons call the orchestration RPCs above.

---

## 10. Invoice creation

| Invoice | Page / component | When (today) | When (desk target) |
| :--- | :--- | :--- | :--- |
| Internal confirmed invoice | `DropshipOrderConfirmedInvoicePaper` | After order confirm / processing | Unchanged |
| Recipient resell invoice | Customer invoice preview | Ready for pickup / print | Unchanged |
| Tenant B2B shipment invoice | `create_dual_invoice_from_dropship_order` | **`ready_for_pickup`** (auto) | **`delivered`** (step ①) if shipment-based accounting adopted |

**Locked defaults:**

- Settlement form does **not** create a new customer-facing invoice.
- Step ② marks the existing **tenant B2B `global_invoices`** row paid when courier bank transfer is recorded.
- Accounting audit lives in **`dropship_order_settlements`** + charge lines (§5), not mutable `shop_orders` charge columns.
- Recipient-facing invoice stays unchanged.

**Open (minor):**

1. Should discount (company pay) appear as invoice line, metadata, or credit note?
2. Split courier fee into two courier ledger lines on step ② for clearer statements?

---

## 11. Next implementation steps

1. Agree formulas (§8).
2. Migration: `dropship_order_settlements` + `dropship_settlement_charge_lines` + RLS + payer enum; add `courier_cod_booked_at`, `remittance_at`, `merchant_payout_at` timestamps.
3. RPCs: `get_dropship_management_order`, `save_dropship_settlement_draft`, `mark_dropship_order_delivered`, `record_dropship_courier_bank_transfer`, `transfer_dropship_reseller_profit`.
4. Product: move B2B invoice trigger `ready_for_pickup` → `delivered` (inside step ①) if shipment-based accounting approved.
5. Extend `list_dropship_shop_orders_for_staff` with `p_statuses` **or** v1 two-call merge (§3).
6. Wire list page; wire detail form load from `get_dropship_order_detail_v2` + settlement draft.
7. Wire three footer buttons to orchestration RPCs (§7); store ledger refs on settlement row.
8. Optional: split courier remittance into two courier ledger lines (net transfer + fee).
9. Add TanStack query keys; remove dummy data file when live.
10. Retire Finance Hub dropship tabs after desk parity verified.

---

## 12. Out of scope (v1 shell)

- Permissions beyond `shop_order_mgmt`
- Reversal / edit-after-settlement
- Multi-currency
- Integration with wholesale `global_invoices` AR
