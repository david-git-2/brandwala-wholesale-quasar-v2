# State Management

This document defines state-management conventions for BrandWala / TradeFlow BD.

## Decision

- Use `Pinia` for client/UI/workflow state.
- Use `TanStack Query` for server state.
- Do not duplicate the same server dataset in both Pinia state and query cache.

## Source Of Truth Boundaries

### Pinia owns

- Auth/session and scoped access context (`platform` / `app` / `shop`).
- Permission snapshots and effective grants used for route/action gating.
- Form state, dirty tracking, wizard/step flows, local filters, dialog open/close state.
- Local-only UI composition state that is not fetched from backend.

### TanStack Query owns

- Read models fetched from Supabase/rest/RPC layers.
- Server-list data, details, lookup data, and cache lifecycle.
- Mutation lifecycle (`pending` / `error` / retry) and post-mutation invalidation.

## Query Key Standards

All query keys must be tuple keys and tenant-safe.

```ts
// shape
['module', 'resource', { tenantId, tenantSlug, scope, ...params }]
```

Rules:

- Always include tenant identity when data is tenant-scoped.
- Include route identity (`orderId`, `shopId`, `status`, `search`, paging inputs) for list/detail splits.
- Use stable object param ordering to prevent accidental cache misses.
- Never key by translated labels or UI-only text.

## Stale-Time Tiers

- Reference/master data (currencies, couriers, merchants, static configs): `5-15m`.
- Semi-static transactional lookup (shop lists, access matrices): `1-5m`.
- Hot transactional detail (order detail, cart totals): `10-30s`.
- Explicitly set `gcTime` for large list datasets to avoid memory growth.

## Mutation Policy

- Prefer optimistic updates only when conflict risk is low and rollback is straightforward.
- For high-risk mutations, use pessimistic success updates and targeted invalidation.
- Replace blanket page reloads with:
  1. `setQueryData` patch for updated entity fields.
  2. Narrow invalidation of dependent queries.
- Keep success/error notifications aligned with `src/utils/appFeedback.ts`.

## Loading/Error UX

- Use query/mutation status flags as the primary loading source.
- Keep existing global network activity behavior intact; do not add redundant local spinners for same request.
- Surface user-facing failures through centralized feedback helpers.
- Preserve existing empty/error states per page while swapping data source.

## Anti-Patterns

- Storing server detail lists in Pinia and TanStack Query simultaneously.
- Refetching full screen data after every successful mutation by default.
- Broad invalidation (`invalidate everything in module`) for single-record updates.
- Triggering network calls from multiple watchers for equivalent params.

## Shop Order Strategy

`shop_order` is the first migration target because it has repeated `loading/error/reload` flows and manual orchestration.

### Query Map (initial)

- Order detail:
  - `['shop_order', 'order_detail', { tenantId, orderId }]`
- Staff/customer order lists:
  - `['shop_order', 'orders_list', { tenantId, scope, status, search, page, pageSize, shopId }]`
- Dropship desk list:
  - `['shop_order', 'dropship_orders', { tenantId, status, search, page, pageSize }]`
- Couriers:
  - `['shop_order', 'couriers', { tenantId }]`
- Merchants:
  - `['shop_order', 'merchants', { tenantId }]`
- Shop permissions snapshot:
  - `['shop_order', 'permissions', { tenantId, shopId, customerGroupId }]`

### Mutation Map (initial)

- Update status / advance status / return:
  - Invalidate `order_detail` for that order.
  - Invalidate affected desk/list keys only.
- Update charges / consignment details:
  - Patch `order_detail` cache + invalidate dependent totals/list rows.
- Create dual invoice:
  - Patch `order_detail` invoice linkage fields.
  - Invalidate detail and any invoice-linked list rows.
- Handoff/process order:
  - Invalidate detail + dropship desk list.

## Shop Order Rollout Plan

### Phase A - Foundation

- Add TanStack Query provider and query client defaults.
- Add `shop_order` query key factory (`keys.ts`) to centralize key shapes.
- Keep existing data fetching path as fallback during cutover.

### Phase B - Read Queries

- Migrate `DropshipOrderDetailPage` detail + lookups (couriers/merchants) to read queries.
- Use `staleTime` by data class.
- Enable dedupe and keep-previous-data behavior for list/detail transitions.

### Phase C - Mutations

- Convert order status, charges, consignment, invoice-related actions to `useMutation`.
- Replace broad reload patterns with targeted cache patch + invalidation.
- Keep existing notification UX behavior unchanged.

### Phase D - Store Boundary Cleanup

- Retain Pinia for form-local state and permission/UI orchestration.
- Remove duplicated server-state fields from store modules where query cache is authoritative.
- Keep service/repository layers as backend contract wrappers.

## Acceptance Criteria

- `shop_order` detail flows no longer rely on blanket full data reloads after every mutation.
- Query keys are tenant-safe and route-safe.
- Stale-time defaults are deterministic by data class.
- Existing behavior parity is preserved for notifications/loading/error states.
# State Management

## Decision Summary

Use a split model:
- Pinia for client and session state.
- TanStack Query for server state.

## Source-of-Truth Rules

### TanStack Query Owns Server State
- Fetching, caching, invalidation, and retry logic for API/RPC-backed data.
- Shared server-data lifecycle (loading, stale, refetch) across pages and components.

### Pinia Owns Client/App State
- Auth and effective permission model.
- Workspace/session context.
- Form state and dirty tracking.
- UI preferences and local interaction state.

## Query Key Standards

- Query keys must include tenant identity (`tenantId` and/or `tenantSlug`) when data is tenant-scoped.
- Include auth scope or app surface where relevant (`platform`, `app`, `shop`, `investor`).
- Include stable business identifiers for detail queries (e.g., entity id, date range, filter set).
- Avoid implicit keys that can collide across tenants or scopes.

## Stale-Time Policy Tiers

- **Reference/master data:** longer `staleTime` (minutes to hours) when change frequency is low.
- **Transactional lists:** medium `staleTime`, with explicit invalidation after mutations.
- **Transactional detail views:** shorter `staleTime`, refetch-on-focus only when data freshness is critical.
- **Real-time sensitive values:** keep `staleTime` short and prefer targeted invalidation/events over broad polling.

## Mutation Policy

- Use optimistic updates only when rollback is deterministic and user risk is low.
- For high-risk writes, prefer pessimistic flow with server-confirmed state.
- After mutation, use targeted invalidation for the specific affected keys.
- Fallback to scoped refetch only when key-level invalidation is insufficient.

## Error and Loading UX Standards

- Surface mutation success/error via `appFeedback` helpers (`showSuccessNotification`, `showErrorNotification`).
- Keep query loading indicators granular (section/table/skeleton), not full-page blocking by default.
- Respect existing global network/loading feedback patterns (including global async bar behavior).
- Show actionable error states with retry affordances for recoverable query failures.

## Anti-Patterns to Avoid

- Duplicating the same server entity in both Pinia and TanStack Query cache.
- Broad invalidation (e.g., invalidating entire module trees) when precise keys are available.
- Full-page refetch loops triggered by local UI state changes.
- Storing derived server data in Pinia when it can be selected from query cache.
