# App dashboard widget registry

Tenant app home (`/:slug/app/dashboard`) is **registry-composed**: modules register widgets; the shell filters by the same access rule as navigation.

## Visibility

A slot renders only when **all** pass:

1. `scopes` includes current auth scope (`app` in v1)
2. Module is enabled for the tenant (`activeModuleKeys`)
3. User may perform the slot’s `action` (default `view`) via `hasModuleAccess` / grants / admin

Formula (same as nav):

`module enabled` AND (`is_admin` OR grant for `module_key` + `action`)

## Slot kinds

| Kind | Calls API? | Use |
| :--- | :--- | :--- |
| `shortcut` | no | Navigate to a module page (tile) |
| `action` | no (until click) | Create / intent CTA (tile) |
| `section` | optional (inside component) | Full-width module UI (action bar, insights + charts) |
| `attention` | yes (inside component) | Queues / pending cards with CTAs |
| `stat` | yes (inside component) | Snapshot numbers / charts |

Thrift overview uses **chart.js** / **vue-chartjs** (doughnut + bar) inside `ThriftInsightsPanel.vue`, gated by `thrift_reports` / `view`.

## How to register a module’s widgets

1. Add `web/src/modules/<module>/dashboard/<module>DashboardSlots.ts` exporting `readonly DashboardSlot[]`.
2. Import that array in [`dashboardSlotRegistry.ts`](../../../web/src/modules/dashboard/registry/dashboardSlotRegistry.ts) and spread into `DASHBOARD_SLOT_REGISTRY`.
3. Do **not** hardcode module UI inside `AdminDashboard.vue`.

Group chrome uses `parentGroupKey` → `getModuleDefinition` (name / `navIcon`). Blocks render above shortcut tiles in the group.

## Code map

| Path | Role |
| :--- | :--- |
| `web/src/modules/dashboard/types/dashboardSlot.ts` | Types |
| `web/src/modules/dashboard/registry/dashboardSlotRegistry.ts` | Aggregator + resolver |
| `web/src/modules/dashboard/composables/useDashboardSlots.ts` | Auth-aware filter + groups |
| `web/src/modules/dashboard/pages/AdminDashboard.vue` | Composer shell |
| `web/src/modules/thrift/dashboard/*` | Thrift actions, Chart.js insights panel + slots |

## Anti-patterns

- Hardcoding thrift (or any vertical) in `AdminDashboard`
- One fat dashboard RPC for all modules
- Separate StaffDashboard / AdminDashboard content forks instead of grant filters
- Showing a parent group when zero slots in that group are visible

## Related

Navigation uses the same enablement + grant filter — see [LOGIN_NAV_PERMISSION_FLOW.md](../LOGIN_NAV_PERMISSION_FLOW.md).

Shop login home (`/:slug/shop/dashboard`) is **not** this registry. Canon: [SHOP_SCOPE.md](../shop_order/SHOP_SCOPE.md).
