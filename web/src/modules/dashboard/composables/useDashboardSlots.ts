import { computed } from 'vue';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import type { DashboardWorkspaceKind } from '../types/dashboardSlot';
import { resolveDashboardSlots } from '../registry/dashboardSlotRegistry';

export const useDashboardSlots = () => {
  const authStore = useAuthStore();
  const tenantStore = useTenantStore();
  const { hasModuleAccess } = useModulePermissions();

  const workspaceKind = computed((): DashboardWorkspaceKind | null => {
    const tenant = tenantStore.selectedTenant;
    if (!tenant) {
      return null;
    }
    return tenant.parent_id ? 'child' : 'parent';
  });

  const resolved = computed(() =>
    resolveDashboardSlots({
      scope: authStore.scope,
      workspaceKind: workspaceKind.value,
      hasAccess: (moduleKey, action) => hasModuleAccess(moduleKey, action),
    }),
  );

  const primaries = computed(() => resolved.value.primaries);
  const groups = computed(() => resolved.value.groups);
  const isEmpty = computed(
    () => resolved.value.primaries.length === 0 && resolved.value.groups.length === 0,
  );

  const tenantSlug = computed(() => authStore.tenantSlug ?? undefined);

  return {
    primaries,
    groups,
    isEmpty,
    tenantSlug,
  };
};
