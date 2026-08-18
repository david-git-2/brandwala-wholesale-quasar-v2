# Execution Task Matrix: Shipment Public Progress Tracking

Superseded by the flow-aware shipment progress model: parent tenant manages multiple flows, each flow owns its ordered stages, each shipment selects one flow, and public tracking renders only that selected flow.

## Phase 0: Scope Lock & Contracts
- **Goal:** Lock product scope: fixed stage category (`shipment_progress`), tenant-managed flows + stages, and public no-auth tracking route.
- **Depends On:** Existing shipment lifecycle/progress implementation
- **Files to Change:**
  - `[NEW]` `doc/procurement_stock/SHIPMENT_PUBLIC_PROGRESS_TRACKING.task.md`
  - `[MODIFY]` `doc/procurement_stock/IMPLEMENTATION_ORDER.md`
- **Specification:**
  - Keep shipment lifecycle status fixed (`draft`, `in_transit`, `received`, `cancelled`).
  - Treat journey states as stages under fixed group/category `shipment_progress`.
  - Parent tenant configures flows and ordered stages; shipment details selects one flow and one current stage.
  - Public page reads tokenized shipment progress payload only.
- **Rollback:** Remove plan row and task file.
- **Review Gate:** Team alignment on category-fixed vs tenant-tag-custom model.
- **Status:** [Planned]

---

## Phase 1: DB & RPC Foundation
- **Goal:** Add safe backend contract for tenant-managed progress tags and public read access.
- **Depends On:** Phase 0
- **Files to Change:**
  - `[NEW]` `supabase/migrations/<timestamp>_shipment_public_progress_tracking.sql`
  - `[MODIFY]` `web/src/types/database.types.ts` (generated via backend types command)
- **Specification:**
  - Add `public_tracking_token` (or equivalent) on shipment header with unique index.
  - Add RPC to regenerate/revoke token for authorized parent-tenant users.
  - Add RPC to list/manage `shipment_progress` tags for parent tenant (create/update/archive/reorder).
  - Harden existing ensure RPC to avoid overwriting tenant custom names/order once user-managed tags exist.
  - Add `security definer` RPC for public tracking payload by token; return shipment-safe fields only.
- **Rollback:** Drop token column/index and new RPCs.
- **Review Gate:** Fresh reset migration passes; RPCs enforce tenant boundaries and no-auth payload minimization.
- **Status:** [Planned]

---

## Phase 2: Procurement Progress Settings Page (Parent Tenant)
- **Goal:** Provide dedicated UI under procurement to configure progress tags.
- **Depends On:** Phase 1
- **Files to Change:**
  - `[NEW]` `web/src/modules/procurement_stock/pages/ShipmentProgressSettingsPage.vue`
  - `[NEW]` `web/src/modules/procurement_stock/components/ShipmentProgressTagFormDialog.vue`
  - `[NEW]` `web/src/modules/procurement_stock/components/ShipmentProgressTagOrderList.vue`
  - `[MODIFY]` `web/src/modules/procurement_stock/routes/index.ts`
  - `[MODIFY]` `web/src/modules/navigation/moduleRegistry.ts`
- **Specification:**
  - Show active/archived tags in `shipment_progress`.
  - Allow create, rename, color update, archive/unarchive.
  - Allow sequence update via drag/drop or up/down controls (`sort_order` writeback).
  - Gate by parent-tenant settings permission.
- **Rollback:** Remove new page/components and route/nav entries.
- **Review Gate:** Parent tenant can fully manage tag list without SQL/manual intervention.
- **Status:** [Planned]

---

## Phase 3: Shipment Details Integration Hardening
- **Goal:** Keep details workflow clean while consuming tenant-configured tag list.
- **Depends On:** Phase 2
- **Files to Change:**
  - `[MODIFY]` `web/src/modules/procurement_stock/pages/InboundShipmentDetailsPage.vue`
  - `[MODIFY]` `web/src/modules/procurement_stock/components/ShipmentStatusWorkflowBar.vue`
  - `[MODIFY]` `web/src/modules/procurement_stock/stores/globalShipmentStore.ts`
  - `[MODIFY]` `web/src/modules/procurement_stock/repositories/globalShipmentRepository.ts`
- **Specification:**
  - Preserve one-select progress UX in details page.
  - Load only tenant-configured active tags in order.
  - Remove dependency on reseed/overwrite behavior for every load.
  - Keep fixed lifecycle status controls separate from progress tags.
- **Rollback:** Revert details page/store/repository changes.
- **Review Gate:** Shipment progress dropdown reflects settings page edits immediately.
- **Status:** [Planned]

---

## Phase 4: Public Tracking Route (No Auth)
- **Goal:** Deliver shareable public progress page for external viewers.
- **Depends On:** Phase 3
- **Files to Change:**
  - `[NEW]` `web/src/modules/procurement_stock/pages/PublicShipmentTrackingPage.vue`
  - `[MODIFY]` `web/src/modules/procurement_stock/routes/index.ts`
  - `[NEW]` `web/src/modules/procurement_stock/repositories/publicShipmentTrackingRepository.ts`
- **Specification:**
  - Add public route pattern (for example `/:tenantSlug/shipment-track/:token`) without auth guard.
  - Read tokenized RPC payload: shipment label, lifecycle status, current progress tag, ordered progress list, optional last-updated time.
  - Render simple timeline/stepper and "not found/expired" state.
  - Exclude prices, costs, supplier financials, internal notes.
- **Rollback:** Remove public route/page/repository and token RPC usage.
- **Review Gate:** External browser can open link and see progress safely without login.
- **Status:** [Planned]

---

## Phase 5: Share Link UX + Security QA
- **Goal:** Make sharing easy for staff and verify security boundaries.
- **Depends On:** Phase 4
- **Files to Change:**
  - `[MODIFY]` `web/src/modules/procurement_stock/components/ShipmentHeaderBar.vue`
  - `[MODIFY]` `web/src/modules/procurement_stock/pages/InboundShipmentDetailsPage.vue`
  - `[MODIFY]` `doc/procurement_stock/shipment/workflow_flow.md`
  - `[MODIFY]` `doc/procurement_stock/shipment/schema.md`
- **Specification:**
  - Add "Copy public tracking link" action in shipment details.
  - Optional token regenerate action with confirmation (old link invalidated).
  - Add docs on public tracking contract and privacy boundary.
  - Run permission checks: only authorized parent-tenant members can generate/revoke links.
- **Rollback:** Remove share action and revert docs.
- **Review Gate:** Share flow works end-to-end; no sensitive fields exposed via public endpoint.
- **Status:** [Planned]
