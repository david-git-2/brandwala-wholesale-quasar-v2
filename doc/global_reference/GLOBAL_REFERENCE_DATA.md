# Global Reference Data

BrandWala / TradeFlow BD uses **platform-wide reference catalogs** shared across all tenants. Business modules read these catalogs; they do not own them.

Related: [TENANT_MODEL_AND_ACCESS.md](TENANT_MODEL_AND_ACCESS.md), [APP_SCOPES_AND_ACCESS.md](APP_SCOPES_AND_ACCESS.md), [MASTER_PLAN.md](MASTER_PLAN.md).

---

## 1. Overview

| Property | Global reference data | Tenant business data |
|----------|----------------------|----------------------|
| Scope | Entire platform | Single tenant |
| `tenant_id` | None | Required |
| Typical RLS | Authenticated read; superadmin write | Membership-scoped |
| Admin UI | `/platform/reference/*` | `/:slug/app/*` |
| Module gating | Parent + submodule keys | Per-module flags |

**Parent module key:** `global_reference`  
**Submodule keys:**

| Key | Catalog |
|-----|---------|
| `global_reference_currency` | `global_currencies` |
| `global_reference_market` | `markets` |
| `global_reference_payment_method` | `payment_methods` |
| `global_reference_unit_of_measure` | `units_of_measure` |

---

## 2. Module hierarchy

- Assign **`global_reference`** on a tenant to enable all submodules by default.
- Platform can restrict individual submodules via `tenant_module_submodules` without removing the parent.
- `get_active_module_keys_for_tenant` expands parent → enabled submodule keys (parent key itself is not emitted).
- Submodule keys gate **Reference nav/pages** only; cross-module dropdowns (products market, shipment currency) remain available via list RPCs.

---

## 3. Tables

### `global_currencies`

| Field | Notes |
|-------|-------|
| `code`, `symbol`, `name`, `country` | ISO-style currency |
| `is_active` | Gates selects |
| `is_system` | Seeded GBP/BDT protected |

### `markets`

| Field | Notes |
|-------|-------|
| `code` | FK target from `products.market_code`, etc. |
| `region`, `is_system` | ISO seed rows |

### `payment_methods`

| Field | Notes |
|-------|-------|
| `category` | `bd_mobile_wallet`, `bd_bank`, `bd_cash`, `card`, `international` |
| `scope` | `bd`, `international`, `both` |

### `units_of_measure`

| Field | Notes |
|-------|-------|
| `unit_type` | `weight`, `count`, `length`, `volume`, `packaging` |
| `symbol` | Display hint |

### `modules.parent_module_key`

Links submodule rows to parent catalog entries.

### `tenant_module_submodules`

Per-tenant override when `is_enabled = false` restricts a submodule.

---

## 4. List RPCs (always available)

| RPC | Purpose |
|-----|---------|
| `list_global_currencies()` | Active currencies |
| `list_vendor_markets()` | Active markets |
| `list_payment_methods()` | Active payment methods |
| `list_units_of_measure()` | Active units |

---

## 5. UI surfaces

| Surface | Path |
|---------|------|
| Platform hub | `/platform/reference` |
| Platform CRUD | `/platform/reference/{markets,currencies,payment-methods,units}` |
| App read-only | `/:slug/app/reference/*` (submodule-gated) |
| Sidebar | Parent **Global Reference** group with submodule children |

---

## 6. Migration from `thrift_currency`

Tenants with `thrift_currency` are backfilled to `global_reference`. The `thrift_currency` module key is deactivated. App route `/thrift/currencies` redirects to `/reference/currencies`.

---

## 7. Code references

| Area | Path |
|------|------|
| Module registry | `web/src/modules/navigation/moduleRegistry.ts` |
| Nav hierarchy | `web/src/modules/featureCatalog/utils/moduleHierarchy.ts` |
| Platform UI | `web/src/modules/global_reference/` |
| Submodule panel | `web/src/modules/tenant/components/SubmoduleAccessPanel.vue` |
| Migration | `supabase/migrations/20260803000000_global_reference_module.sql` |
