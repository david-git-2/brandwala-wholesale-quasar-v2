import { computed } from 'vue';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { resolveTenantHierarchyKind } from 'src/modules/tenant/utils/tenantHierarchy';

export const useInvoiceWorkspace = () => {
  const authStore = useAuthStore();
  const tenantStore = useTenantStore();

  const currentTenant = computed(() => {
    if (tenantStore.selectedTenant) return tenantStore.selectedTenant;
    if (authStore.selectedTenant) return authStore.selectedTenant;
    if (authStore.tenant) return authStore.tenant;
    if (authStore.tenantId) {
      return (
        tenantStore.availableAdminTenants.find((t) => t.id === authStore.tenantId) ??
        tenantStore.items.find((t) => t.id === authStore.tenantId) ??
        null
      );
    }
    return null;
  });

  const kind = computed(() =>
    resolveTenantHierarchyKind(currentTenant.value, [
      ...tenantStore.availableAdminTenants,
      ...tenantStore.items,
    ]),
  );

  const isParentTenant = computed(() => kind.value === 'parent');
  const isDeskView = computed(() => kind.value !== 'parent');

  return { kind, isParentTenant, isDeskView };
};
