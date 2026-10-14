import { computed } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';

/** Parent books tenant base currency (default BDT). */
export function useBooksCurrencyCode() {
  const authStore = useAuthStore();
  const tenantStore = useTenantStore();

  return computed(() => {
    const selected = authStore.selectedTenant;
    if (!selected?.id) return 'BDT';
    const booksId = selected.parent_id ?? selected.id;
    const booksTenant =
      tenantStore.availableAdminTenants.find((t) => t.id === booksId) ??
      (selected.parent_id == null ? selected : null);
    const code = booksTenant?.base_currency_code?.trim().toUpperCase();
    return code && code.length >= 3 ? code : 'BDT';
  });
}
