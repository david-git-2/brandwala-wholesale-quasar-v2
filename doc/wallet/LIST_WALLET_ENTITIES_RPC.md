# RPC: `list_wallet_entities_for_staff`

Single server function to load **WalletEntityListPage** rows (name, code, caption, balances) for one wallet category. Replaces the current multi-call pattern (`billing_profiles` / `vendorService` / `cargoCompanyRepository` / `courier_services` + `walletAccountRepository.listAccountsByType`).

**Consumers:** [`WalletEntityListPage.vue`](../../../web/src/modules/wallet/pages/WalletEntityListPage.vue)  
**Related:** [`WALLET.md`](./WALLET.md) §1.1 parent books, [`WALLET_PARENT_BOOKS_IMPLEMENTATION.md`](./WALLET_PARENT_BOOKS_IMPLEMENTATION.md)  
**Status:** Spec only — **not implemented**

---

## Why a new RPC

| Today | Problem |
| :--- | :--- |
| 5+ client queries per list | Slow, easy to mismatch tenant scope |
| Balances joined in browser | `parent_id` vs child `tenant_id` → **0 balances** |
| Courier id = `wallet_entity_id` | Easy to query wrong id if logic stays in UI |
| Search only client-side | Large directories should filter in SQL |

Do **not** extend `get_wallet_account_balances`, `get_wallet_dashboard_summary`, or `list_my_dropship_wallet_ledger` — this is a **directory list** RPC.

---

## Function signature

```sql
list_wallet_entities_for_staff(
  p_tenant_id       bigint,
  p_entity_type     text,
  p_search          text    DEFAULT NULL,
  p_limit           integer DEFAULT 100,
  p_offset          integer DEFAULT 0,
  p_currency_code   text    DEFAULT 'BDT'
)
RETURNS TABLE (
  entity_id           bigint,
  entity_type         text,
  name                text,
  code                text,
  caption             text,
  available_balance   numeric(18,4),
  pending_balance     numeric(18,4),
  locked_balance      numeric(18,4),
  total_balance       numeric(18,4),
  source_uuid         uuid,
  operating_tenant_id bigint,
  has_wallet_activity boolean
)
```

| Param | Meaning |
| :--- | :--- |
| `p_tenant_id` | Active app tenant from auth (`selectedTenant.id`). Child or parent or standalone. |
| `p_entity_type` | One of: `customer`, `vendor`, `courier`, `cargo_company`, `investor`. **Not** `tenant` — company wallet uses company detail route. |
| `p_search` | Optional `ILIKE` on name, code, caption fields (server-side). |
| `p_limit` / `p_offset` | Pagination; default cap 100. |
| `p_currency_code` | Wallet currency; default BDT. |

**Books tenant (internal):**

```text
v_books_id := resolve_parent_tenant_id(p_tenant_id)
```

All `wallet_accounts` joins use **`parent_tenant_id = v_books_id`** after parent-books migration. Until P0 ships, implementation may read legacy `tenant_id = v_books_id` — document both in migration PR; target is `parent_tenant_id`.

---

## Auth & RLS

- `SECURITY DEFINER` with `search_path = public`.
- Caller must pass: `membership_has_module_action(v_books_id, 'universal_wallet', 'view')` OR `is_superadmin()` OR staff on child with `user_can_manage_parent_tenant(v_books_id)` (mirror `global_invoices_select`).
- Return empty set (not error) when denied.

---

## `entity_type` → directory source

### `customer`

| Field | Source |
| :--- | :--- |
| Directory | `billing_profiles` |
| Scope | Profiles where `billing_profiles.tenant_id` is in the **books network**: `v_books_id` plus any `tenants.id` where `parent_id = v_books_id`. |
| `entity_id` | `billing_profiles.id` (wallet key) |
| `name` | `customer_groups.name || ' · ' || billing_profiles.name` when group exists; else profile name |
| `code` | NULL |
| `caption` | `phone • email` |
| `source_uuid` | NULL |
| `operating_tenant_id` | `billing_profiles.tenant_id` |

Join balances: `wallet_accounts` ON `parent_tenant_id = v_books_id AND entity_type = 'customer' AND entity_id = billing_profiles.id`.

Include profiles with **no wallet row** (balances 0).

### `vendor`

| Field | Source |
| :--- | :--- |
| Directory | `vendors` |
| Scope | `vendors.tenant_id = v_books_id` (parent-owned suppliers). |
| `entity_id` | `vendors.id` |
| `name` | `vendors.name` |
| `code` | `vendors.code` |
| `caption` | `phone • email` |
| `operating_tenant_id` | `vendors.tenant_id` |

### `cargo_company`

| Field | Source |
| :--- | :--- |
| Directory | `cargo_companies` |
| Scope | `cargo_companies.tenant_id = v_books_id`. |
| `entity_id` | `cargo_companies.id` |
| `name` / `code` / `caption` | same pattern as vendors |

### `courier`

| Field | Source |
| :--- | :--- |
| Directory | `courier_services` |
| Scope | `is_active = true` AND (`tenant_id IS NULL` OR `tenant_id = v_books_id` OR `tenant_id IN (SELECT id FROM tenants WHERE parent_id = v_books_id)`). |
| `entity_id` | **`courier_services.wallet_entity_id`** (UI navigates with this — **not** courier UUID) |
| `name` | `courier_services.name` |
| `code` | `upper(courier_services.code)` |
| `caption` | `notes` or fallback `Courier service` |
| `source_uuid` | `courier_services.id` (for admin/debug; UI does not route on this) |
| `operating_tenant_id` | `courier_services.tenant_id` or `v_books_id` when global |

Exclude rows where `wallet_entity_id IS NULL`.

Join balances: `entity_type = 'courier'`, `entity_id = wallet_entity_id`.

### `investor`

| Field | Source |
| :--- | :--- |
| Directory | `investors` |
| Scope | `investors.tenant_id = v_books_id`. |
| `entity_id` | `investors.id` |
| `name` / `caption` | name; phone • email |

---

## Balance columns

From `wallet_accounts` (left join):

```text
available_balance  := coalesce(wa.available_balance, 0)
pending_balance    := coalesce(wa.pending_balance, 0)
locked_balance     := coalesce(wa.locked_balance, 0)
total_balance      := available + pending + locked
has_wallet_activity := wa.id IS NOT NULL
```

Sort default: `name ASC`, then `entity_id ASC`.

Optional secondary sort: `total_balance DESC` when `p_search` is null (configurable later; default name sort for v1).

---

## Search (`p_search`)

When `trim(p_search)` is not empty, filter rows where any of:

- `name ILIKE '%' || search || '%'`
- `code ILIKE '%' || search || '%'`
- `caption ILIKE '%' || search || '%'`

Apply before `LIMIT`/`OFFSET`.

---

## Return shape → UI mapping

Maps 1:1 to `WalletEntityRow` in `WalletEntityListPage.vue`:

| RPC column | UI field |
| :--- | :--- |
| `entity_id` | `id` (route param `entityId`) |
| `name` | `name` |
| `code` | `code` |
| `caption` | `caption` |
| `total_balance` | `totalBalance` |

`openWalletDetail` route: `walletType` slug from `ENTITY_TYPE_TO_SLUG[entity_type]`, `entityId` = `entity_id`.

---

## JSON alternative (optional v2)

If the team prefers one jsonb blob instead of `RETURNS TABLE`:

```json
{
  "success": true,
  "books_tenant_id": 10,
  "entity_type": "courier",
  "rows": [ { ... } ],
  "total_count": 42
}
```

v1 should use `RETURNS TABLE` for TanStack Query + stable column typing via `backend:types`.

---

## Implementation checklist

**Schema / migration**

- [ ] Function in `supabase/schemas/public.sql` (or `wallet/` when split).
- [ ] Migration `YYYYMMDDHHMMSS_list_wallet_entities_for_staff.sql`.
- [ ] `GRANT EXECUTE ON FUNCTION ... TO authenticated`.
- [ ] `pnpm run backend:types`.

**Depends on**

- Parent-books columns on `wallet_accounts` (P0) **or** interim join on `tenant_id = v_books_id` with comment to switch to `parent_tenant_id`.

**Frontend (separate PR)**

- [ ] `walletRepository.listEntitiesForStaff(...)` calling this RPC only.
- [ ] `WalletEntityListPage.loadEntitiesAndBalances` — remove direct table access and `listAccountsByType`.
- [ ] Query key: `walletQueryKeys.entityDirectory({ booksTenantId, entityType, search, limit, offset })`.
- [ ] Server-side search: debounce `p_search` 300ms or keep client filter on loaded page (v1 client filter OK if limit 100).

**Tests / verify**

- [ ] Child tenant Dropshipping: courier list shows Steadfast balance 60 (entity_id 1).
- [ ] Customer list shows David Admin (31) balance 11091 after data migration.
- [ ] Empty directory returns `[]`, not error.
- [ ] Wrong `p_entity_type` → exception with clear message.

---

## Out of scope (this RPC)

| Item | Where instead |
| :--- | :--- |
| Company / tenant cash wallet | `app-wallet-company-detail` + `get_wallet_detail_for_staff` |
| Home hub card grid | [`WalletHomePage.vue`](../../../web/src/modules/wallet/pages/WalletHomePage.vue) — static cards today; optional future `summarize_wallet_directories` RPC |
| Ledger lines on detail page | [`UNIVERSAL_WALLET_DETAIL_RPC.md`](./UNIVERSAL_WALLET_DETAIL_RPC.md) — `list_wallet_ledger_for_staff` |
| Pay modal counterparty picker | Reuse this RPC filtered by `p_entity_type` per selected payee type |
| Merchant shop wallet | `list_my_dropship_wallet_ledger` (shop scope) |

---

## Optional follow-up RPC (not v1)

`summarize_wallet_directories(p_tenant_id)` — one row per slug with `entity_count` + `total_balance_sum` for badges on [`WalletHomePage.vue`](../../../web/src/modules/wallet/pages/WalletHomePage.vue). Defer until list RPC is stable.

---

*Spec created 2026-08-27. No SQL implementation in this file.*
