import { computed } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { canAccessModule } from 'src/modules/navigation/modulePermissions';

export function usePaymentsVoidAccess() {
  const authStore = useAuthStore();

  return computed(() =>
    canAccessModule({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      moduleKey: 'payments',
      action: 'void',
      activeModuleKeys: authStore.activeModuleKeys,
      effectiveGrants: authStore.effectiveGrants,
      isAdmin: authStore.isAdmin,
    }),
  );
}
