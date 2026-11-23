import { computed } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';

/** Parent (books) tenant admin may delete groups and toggle active status. */
export function useCanAdministerCustomerGroup() {
  const authStore = useAuthStore();
  const tenantStore = useTenantStore();

  return computed(() => {
    if (authStore.matchedRole === 'superadmin' && authStore.scope === 'platform') {
      return true;
    }
    if (!authStore.isAdmin) return false;
    const tenant = tenantStore.selectedTenant;
    if (!tenant) return false;
    return tenant.parent_id == null;
  });
}
