import { computed, watch, type Ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useCustomerAccountsStore } from '../stores/customerAccountsStore';

/** Tenant customer accounts (groups) — Pinia cache, API only when empty for that tenant. */
export function useCustomerAccounts(tenantId: Ref<number | null | undefined>) {
  const store = useCustomerAccountsStore();
  const { byTenantId, loadingTenantId, error } = storeToRefs(store);

  const accounts = computed(() => {
    const id = tenantId.value;
    if (!id) return [];
    return byTenantId.value[id] ?? [];
  });

  const customerGroupOptions = computed(() =>
    accounts.value.map((row) => ({
      customer_group_id: row.customer_group_id,
      group_name: row.group_name,
    })),
  );

  const isLoading = computed(
    () => loadingTenantId.value !== null && loadingTenantId.value === tenantId.value,
  );

  watch(
    tenantId,
    (id) => {
      if (id) {
        void store.ensureLoaded(id);
      }
    },
    { immediate: true },
  );

  return {
    accounts,
    customerGroupOptions,
    isLoading,
    error,
    ensureLoaded: () => {
      const id = tenantId.value;
      if (!id) return Promise.resolve([]);
      return store.ensureLoaded(id);
    },
  };
}
