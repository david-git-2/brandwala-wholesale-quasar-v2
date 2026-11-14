# Dashboard — Today’s plan (app home)

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/dashboard/spec.md` + [00-gaps](00-gaps.md) |
| UI | `web/src/modules/dashboard/` |
| App staff home | `pages/AdminDashboard.vue` → shift board layout |
| Data | `get_app_dashboard_bundle` → shop + procurement metrics |
| State | `dashboardBundleStore`, `useTodayPlan` |
| Customer / platform homes | Unchanged (`CustomerDashboard.vue`, `SuperadminDashboard.vue`) |

## Intent

After login, **app** staff see **what to work today** — orders, delivery steps, inbound shipments — not finance KPIs or system reports.

| Surface | Job |
| :--- | :--- |
| `app` | Day load pill, next action, ranked queue, delivery/inbound runways |
| `shop` | Customer order glance (separate page) |
| `platform` | Tenant health (separate page) |

See [scopes](../../architecture/scopes.md).

## Where to look

| Need | Path |
| :--- | :--- |
| Today plan composable | `composables/useTodayPlan.ts` |
| Today plan UI | `TodayPlanHeader`, `TodayPlanWorkQueue`, `TodayPlanRunway`, `TodayPlanDelivery`, `TodayPlanShipment` |
| App staff page | `pages/AdminDashboard.vue` |
| Bundle refresh | `stores/dashboardBundleStore.ts`, `repositories/appDashboardBundleRepository.ts` |
| Deep links | `composables/useAppDashboardRoutes.ts` |
| Shop counts RPC | `get_shop_order_dashboard_metrics` in `supabase/schemas/` |
| Procurement counts RPC | `get_procurement_dashboard_metrics` |
| Customer home RPC | `get_customer_dashboard_summary` |
| Retired cockpit widgets | `DashboardScorecard`, `DashboardLiquidityMatrix`, etc. (unused on app home; cleanup in gaps) |

## Scope

| | |
| :--- | :--- |
| In | Work queue, delivery plan, inbound shipment plan; real counts only; deep links to lists |
| Out | Revenue, cash, AR aging, brand matrix, sparklines on app home; new SQL in v1 |
| Out | Owning domain CRUD |

## App layout (one screen)

1. **Header** — title, status pill (`Clear` / `N need you`), refresh.
2. **Do first** — next-action hero (count + primary Open) + compact ranked list.
3. **Runways** — delivery (brand) and/or inbound shipment (parent): stage cells left→right; non-zero highlighted, zero muted.

## Locked rules

| Rule | Detail |
| :--- | :--- |
| Empty state | Never invent sample rows or demo alerts |
| Work priority | dropship submitted → needs quote → ready pickup → dropship processing/ready → processing → inbound draft → inbound in transit |
| Gating | Delivery when `shop_order` view; shipment when parent + `global_stock` view |
| Links | Each row → orders list, dropship filter, or shipment list |

## Stories

### US-1: Work queue (app)
- [x] Up to 8 items with count &gt; 0, priority order above.
- [x] Each item links to the correct app route.
- [x] No hardcoded fallback alerts.

### US-2: Delivery plan (app)
- [x] Shop-order buckets with counts (needs quote, processing, ready, shipped, dropship states).
- [x] Shown only when user can view shop orders.

### US-3: Inbound shipment plan (app)
- [x] Draft / in transit / received counts from procurement metrics.
- [x] Shown only when user can view stock on parent tenant.

### US-4: Customer storefront dashboard
- Order glance on shop login.
- [ ] `get_customer_dashboard_summary` segments (unchanged scope).

### US-5: Slot registry (legacy)
- Domain slot registry still used by other surfaces; not on app Today’s plan v1.