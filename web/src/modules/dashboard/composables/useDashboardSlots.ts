import { computed } from 'vue';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { resolveDashboardSlots } from '../registry/dashboardSlotRegistry';

export const useDashboardSlots = () => {
  const authStore = useAuthStore();
  const { hasModuleAccess } = useModulePermissions();

  const resolved = computed(() =>
    resolveDashboardSlots({
      scope: authStore.scope,
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
