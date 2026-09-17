# Tenant Auth & Access Control — Page-to-API Matrix

Mapping of all authentication screens, workspace switchers, member invitation modals, and permission matrices to their corresponding Supabase RPCs, database operations, and stores.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`AdminLoginPage`** | Click "Sign in with Google" | `authStore.loginWithOAuth` | `supabase.auth.signInWithOAuth` | Redirects to Google OAuth flow |
| **`AppLayout`** | Layout Mount / Boot | `tenantStore.hydrateHierarchyChildRefs` | `RPC: list_child_tenant_refs` | Hydrates Pinia `hierarchyChildRefs` |
| **`AppLayout`** | Switch Company Workspace | `tenantStore.setActiveTenant` | Local Pinia state update | Updates route `:tenantSlug` parameter |
| **`MembersPage`** | Mount / List Staff | `useMembersQuery` | `Table: memberships` join `auth.users` | Cached on `['members', tenantId]` |
| **`MembersPage`** | Update Action Permissions | `useUpdateModuleActionsMutation` | `Table: module_actions` (UPSERT) | Invalidates member permissions |
| **`AdminTenantPage`** | Create Child Brand | `useCreateBrandMutation` | `Table: tenants` (with `parent_id`) | Appends brand, invalidates tenant tree |
