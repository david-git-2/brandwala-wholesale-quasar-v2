# Tenant Auth & Access Control — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/auth/`, `web/src/modules/tenant/`, and `web/src/modules/access_control/`  
> **Stores Target**: `web/src/modules/tenant/stores/tenantStore.ts` and `web/src/modules/auth/stores/useAuthStore.ts`

---

## 1. Component Architecture & Hierarchy

```text
web/src/
├── layouts/
│   ├── AppLayout.vue                     # Backoffice layout with Company switcher
│   ├── ExternalLayout.vue                # Public storefront & auth layout
│   └── InvestorLayout.vue                # Read-only investor portal layout
├── modules/
│   ├── auth/
│   │   ├── pages/AdminLoginPage.vue      # Staff Google OAuth & password login
│   │   └── stores/useAuthStore.ts        # Supabase auth session & token manager
│   ├── tenant/
│   │   ├── pages/AdminTenantPage.vue     # Company & Brand settings page
│   │   ├── stores/tenantStore.ts         # Active workspace & hierarchy child refs
│   │   └── repositories/tenantRepository.ts # Tenant query & RPC methods
│   └── access_control/
│       ├── pages/MembersPage.vue         # Staff user invitation & role matrix
│       └── composables/useModulePermissions.ts # 3-layer permission evaluator
```

---

## 2. Server State Management & Stores

```typescript
// tenantStore.ts (Pinia)
export const useTenantStore = defineStore('tenant', {
  state: () => ({
    activeTenant: null as Tenant | null,
    items: [] as Tenant[],
    hierarchyChildRefs: [] as { id: string; parent_id: string }[],
  }),
  getters: {
    availableAdminTenants: (state) =>
      state.items.filter((t) => t.parent_id === null), // Companies only
  },
  actions: {
    async hydrateHierarchyChildRefs() {
      const parentIds = this.availableAdminTenants.map((t) => t.id);
      this.hierarchyChildRefs = await tenantRepository.listChildTenantRefs(parentIds);
    },
  },
});
```

---

## 3. Key Navigation & Routing Invariants

1. **Company Switcher Only**: The workspace switcher in the header lists `parent_id IS NULL` companies exclusively.
2. **Batch Child Hydration**: Always call `list_child_tenant_refs` with all parent IDs in a single call on layout boot.
3. **Reactive Permission Guard**: `hasModuleAccess(moduleKey, action)` evaluates `tenant_modules` $\rightarrow$ `role` $\rightarrow$ `module_actions` dynamically.
