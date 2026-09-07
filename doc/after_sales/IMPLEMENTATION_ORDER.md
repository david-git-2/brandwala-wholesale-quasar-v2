# After-Sales — Implementation Order

Phased delivery: **Returns Hub**, parent policy, wholesale cases, dropship off-system intake, replacement, warranty. Each phase shippable independently.

**Prerequisites:** `process_wholesale_invoice_return` live; `finalize_dropship_return` live. Parent-books wallet migration in progress or done — [`WALLET_PARENT_BOOKS_IMPLEMENTATION.md`](../wallet/WALLET_PARENT_BOOKS_IMPLEMENTATION.md).

---

## Phase 0 — Documentation

| Item | Status |
| :--- | :--- |
| `doc/after_sales/AFTER_SALES.md` | Done |
| `doc/after_sales/RETURNS_HUB.md` | Done |
| `doc/after_sales/WHOLESALE_AFTER_SALES.md` | Done |
| `doc/after_sales/DROPSHIP_AFTER_SALES.md` | Done |
| `doc/after_sales/UI_FLOW.md` | Done |
| `doc/after_sales/IMPLEMENTATION_ORDER.md` | Done |
| Cross-links (MASTER_PLAN, sales_invoice, shop_order) | Done |

---

## Phase H1 — Returns Hub shell

**Goal:** Dedicated nav entry and overview; case list with parent/child scope (may be empty).

### Frontend

| File | Route |
| :--- | :--- |
| `AfterSalesOverviewPage.vue` | `/app/after-sales` |
| `AfterSalesCaseListPage.vue` | `/app/after-sales/cases`, `/wholesale`, `/dropship` |
| App shell nav | **Returns** module `after_sales` |

### Backend

| RPC | Notes |
| :--- | :--- |
| `list_after_sales_cases_paginated` | `parent_tenant_id` books; child filter by `operating_tenant_id`; parent operator sees all |
| `get_after_sales_hub_summary` | KPI counts (stub zeros until cases exist) |

### Done when

- [ ] Hub loads for parent and child workspaces
- [ ] List scope matches §3.3 in `AFTER_SALES.md`
- [ ] Nav registered; grant `after_sales.view`

---

## Phase 1 — Parent policy + guided wholesale credit

**Goal:** Policy settings; wholesale return page reads policy.

### Database

`after_sales_program`, `after_sales_policies`, `resolve_after_sales_policy`, `upsert_after_sales_policies`

### Frontend

`AfterSalesPolicyPage.vue`, policy hints on `WholesaleInvoiceReturnPage.vue`

**UI cleanup (same phase or phase 2):** Remove **Process return** from `InvoiceDetailsPage.vue` and `CreateWholesaleInvoicePage.vue`. Replace with **Open return case** / **View case**.

### Done when

- [ ] Parent saves four programs
- [ ] Return page pre-fills fee / window warning

---

## Phase 2 — Wholesale cases

**Goal:** Case lifecycle for wholesale **credit**; hub as primary inbox.

### Database

`after_sales_cases` (`source_channel = wholesale`), lines, events, `sales_return_items.after_sales_case_id`

### Frontend

`AfterSalesCaseDetailPage.vue`, invoice **Open return case**, return page `?case_id=`

### Done when

- [ ] Hub list shows wholesale cases
- [ ] Credit execution links case → closed

---

## Dropship track

### Phase D1 — Intake + case schema

**Goal:** Log off-system recipient reports.

| Object | Notes |
| :--- | :--- |
| `after_sales_cases` | `source_channel = dropship`, intake fields §3.2 |
| `DropshipIntakePage.vue` | `/app/after-sales/dropship/intake` |
| `create_after_sales_case` | Dropship payload |

### Phase D2 — Triage & hub queue

- `reported_to`, status transitions
- Hub **Dropship complaints** preset filter
- Management desk **Log complaint** shortcut

### Phase D3 — Link finalize

- `finalize_dropship_return` optional `p_after_sales_case_id`
- Case detail → return finalize with `?case_id=`
- **View case** on management detail

### Phase D4 — Merchant read-only (optional)

- Shop scope case list for merchant’s orders

---

## Phase 3 — Replacement (wholesale)

`process_after_sales_replacement` — DOA/wrong item.

---

## Phase 4 — Warranty / repair (lightweight)

Case line `in_repair` → `repaired` / `failed`; no full workshop app.

---

## Phase 5 — Overrides & customer portal

Customer group / product overrides; wholesale shop return request.

---

## Phase 6 — Vendor claim handoff (optional)

Case line → procurement vendor return queue.

---

## Explicit non-goals

- Thrift / Koba in this module
- Replacing `finalize_dropship_return` or `process_wholesale_invoice_return` math
- Recipient self-service portal v1
- Standalone **Process return** on invoice toolbars (use hub + case only)

---

## Per-phase SQL checklist

1. `supabase/schemas/after_sales/` (or `public.sql`)
2. `pnpm run backend:schema:diff` → review
3. `pnpm run backend:local` + `pnpm run backend:types:local`
4. Register `after_sales` module grant
5. Update checkboxes here
