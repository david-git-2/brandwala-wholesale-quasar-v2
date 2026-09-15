# Tenant Architecture & Feature Enablement 

This document outlines the architectural shift required to solve two major friction points in the platform:
1. **The Context Switching Penalty:** Forcing parent administrators to "log in" as child companies to perform actions.
2. **The Feature Enablement Chaos:** Managing tenant permissions via dozens of granular micro-features instead of logical applications.

---

## Part 1: The "Act As / On Behalf Of" Paradigm

### Simple English Explanation
Right now, if you are a manager at the Main Parent Company and you need to adjust stock or create an order for "Branch A", you have to change your entire screen (switch tenants) to pretend you are Branch A. This is slow, confusing, and makes you lose your place.

**The Solution:** You stay logged in as the Main Parent Company. 
* **When looking at data:** You see a master list of all orders/shipments across all branches. If you only want to see Branch A, you just use a filter dropdown.
* **When taking action:** If you click "New Order", the form simply asks "Which branch is this for?". You select Branch A, and the system saves it to Branch A while recording that *you* (the Parent Admin) did it.

### Technical Implementation Phase

#### Phase 1: Consolidated Views (UI/UX)
* **Where:** List pages (e.g., `web/src/modules/shop_order/pages/`, `web/src/modules/procurement_stock/pages/`).
* **What:** 
  * Remove restrictions that force lists to only fetch `where tenant_id = activeTenantId` if the user is a Parent Admin.
  * Update API calls/RPCs to return all data the user's role has access to (using RLS policies `user_has_parent_access()`).
  * Add a standard "Entity / Shop" dropdown filter to table toolbars.
  * Add a `Branch / Shop Name` column to data tables to differentiate records.

#### Phase 2: Contextual Actions (Forms & Mutations)
* **Where:** Action modals and dialogs (e.g., `ProcurementPlacementDialog.vue`, `ShopStorefrontCreateProductForm.vue`).
* **What:**
  * Add a `<q-select>` for `Target Tenant` in creation/edit forms, visible *only* if the user is a Parent Admin.
  * Default the target tenant to the user's current `activeTenantId`.
  * Update the API payload to explicitly pass `target_tenant_id` instead of relying on the backend to infer it from the user's session token.
  * **Rule:** Do NOT mutate the global `activeTenantId` Vuex/Pinia state when performing these actions.

#### Phase 3: Database & RLS Adjustments
* **Where:** Supabase schemas (`supabase/schemas/`).
* **What:** 
  * Ensure Row Level Security (RLS) policies allow `INSERT` and `UPDATE` where the target `tenant_id` belongs to a child company of the user's active parent company.

---

## Part 2: Feature Enablement Simplification

### Simple English Explanation
Currently, assigning features to a tenant is a nightmare. There are over 60 tiny toggles (like `shop_pricing`, `global_stock_movement`, `procurement_fulfill`). If an admin forgets to turn one on, the app breaks. 

**The Solution:** We are switching from "Micro-Features" to "Macro-Apps". Instead of assigning 20 different puzzle pieces to a tenant, we just assign them the "Procurement App" or the "Shop App". If they have the Shop App, they automatically get pricing, shipping, and carts. *(Note: The "Thrift" module is specifically excluded from this reorganization and will be left exactly as it is).*

### Technical Implementation Phase

#### Phase 1: Reorganize the Module Registry
* **Where:** `web/src/modules/navigation/moduleRegistry.ts`
* **What:**
  * Identify and define Top-Level Macro-Apps (e.g., `procurement_stock`, `shop_order`, `sales_invoice`, `tasks`).
  * Identify Reference/Config modules (e.g., `global_reference_currency`, `shipment_progress_settings`) and move them out of tenant features entirely. They should be globally available system config modules.
  * **Do NOT touch** `thrift` or any keys starting with `thrift_`.

#### Phase 2: Update the Tenant UI
* **Where:** `web/src/modules/tenant/pages/TenantDetailsPage.vue`
* **What:**
  * Filter the "Available Features" list so it *only* displays Top-Level Macro-Apps.
  * Hide all micro-features (submodules) from the UI. 
  * When an admin clicks "Add", it only assigns the Parent App key to the tenant.

#### Phase 3: Update Routing & Auth Guards
* **Where:** `web/src/router/`, `web/src/modules/auth/` or wherever route-level feature guards exist.
* **What:**
  * Modify the permissions check: `hasFeature('micro_feature_key')`.
  * The logic should be: `if (user_has_feature(micro_feature_key) OR user_has_feature(parent_app_key)) return true`.
  * This allows the frontend to grant access to a sub-page (like `global_stock_movement`) simply because the tenant has the parent `procurement_stock` assigned in the database, eliminating the need to sync 60 rows per tenant in the DB.
