import { computed } from 'vue';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import type { DashboardSlot, DashboardWorkspaceKind } from '../types/dashboardSlot';
import { isDashboardBlockKind } from '../types/dashboardSlot';
import { resolveDashboardSlots } from '../registry/dashboardSlotRegistry';

const isActionBarSlot = (slot: DashboardSlot) => slot.id.endsWith('.actions');

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

  const actionSlots = computed(() =>
    groups.value
      .flatMap((group) => group.slots)
      .filter((slot) => isDashboardBlockKind(slot.kind) && isActionBarSlot(slot))
      .sort((a, b) => a.order - b.order),
  );

  const stories = computed(() =>
    groups.value
      .flatMap((group) => group.slots.map((slot) => ({ slot, weight: group.weight })))
      .filter(({ slot }) => isDashboardBlockKind(slot.kind) && !isActionBarSlot(slot))
      .sort((a, b) => a.weight - b.weight || a.slot.order - b.slot.order)
      .map(({ slot }) => slot),
  );

  return {
    primaries,
    groups,
    actionSlots,
    stories,
    isEmpty,
    tenantSlug,
  };
};
