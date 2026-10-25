import { defineStore } from 'pinia';

/** Parent shops list: remembered child-tenant (business) filter across list ↔ shop setup. */
export const useShopsListUiStore = defineStore('shopsListUi', {
  state: () => ({
    selectedBusinessTenantId: null as number | null,
  }),

  actions: {
    setSelectedBusinessTenantId(tenantId: number | null) {
      this.selectedBusinessTenantId = tenantId;
    },
  },
});
