# Dashboard & insights — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/dashboard/spec.md` + [00-gaps](00-gaps.md) |
| UI | `web/src/modules/dashboard/` |
| SQL | Widget registry in app; no dedicated schema folder |
| State | Slot registry + composables — copy neighbors |
| Access | All scopes; widgets gated by grants |

## Where to look

| Need | Path |
| :--- | :--- |
| Slot registry | `web/src/modules/dashboard/dashboardSlotRegistry.ts`, `useDashboardSlots` |
| Widgets | Grep `dashboard` in domain modules for exported slots |
| Attention queue | `DashboardAttentionList`, `DashboardPulseCard` |
| Customer home RPC | Grep `get_customer_dashboard_summary` in `public.sql` / types |

## Scope

| | |
| :--- | :--- |
| Surfaces | `platform` / `app` / `shop` homes |
| In | Slot registry, attention list, customer summary |
| Out | Owning domain tables; finance report pages |

See [scopes](../../architecture/scopes.md).

## Personas

| Role | Actions |
| :--- | :--- |
| Owner / CFO | KPI pulse, revenue trends, wallet liquidity |
| Operations staff | Attention queue (overdue invoices, COD, stock) |
| Storefront customer | Order glance, recent orders, cart resume |
| Platform superadmin | Tenant counts, platform health |

## Stories

### US-1: Decentralized slot registry
- Domain modules export widget slots; register in `dashboardSlotRegistry.ts`.
  - [ ] Kinds: `section`, `stat`, `attention`, `shortcut`.
  - [ ] `useDashboardSlots` filters by module enablement and grants.

### US-2: Attention work queue
- Top of staff home: urgent items with deep links.
  - [ ] Up to 8 prioritized items.
  - [ ] Stub modules show `DashboardStubBadge`; excluded from counts.

### US-3: Customer storefront dashboard
- Order glance donut + recent POs on shop login.
  - [ ] `get_customer_dashboard_summary`.
  - [ ] Segments: `needs_you`, `in_progress`, `delivered`, `paid`.
