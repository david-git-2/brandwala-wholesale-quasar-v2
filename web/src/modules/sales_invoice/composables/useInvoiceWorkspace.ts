import { computed } from 'vue';

import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { resolveTenantHierarchyKind } from 'src/modules/tenant/utils/tenantHierarchy';

export const useInvoiceWorkspace = () => {
  const tenantStore = useTenantStore();

  const kind = computed(() =>
    resolveTenantHierarchyKind(tenantStore.selectedTenant, [
      ...tenantStore.availableAdminTenants,
      ...tenantStore.items,
    ]),
  );

  const isParentTenant = computed(() => kind.value === 'parent');
  const isDeskView = computed(() => kind.value !== 'parent');

  return { kind, isParentTenant, isDeskView };
};
