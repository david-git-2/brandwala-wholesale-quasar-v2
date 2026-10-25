import { computed, watch, type Ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useCustomerProfileStore } from '../stores/customerProfileStore';
import type { CustomerProfile } from '../repositories/customerProfileRepository';

/** Tenant customer billing profiles — Pinia cache, API only when empty for that tenant. */
export function useCustomerProfiles(
  tenantId: Ref<number | null | undefined>,
  options?: { enabled?: Ref<boolean> },
) {
  const store = useCustomerProfileStore();
  const { byTenantId, loadingTenantId, error } = storeToRefs(store);

  const enabled = options?.enabled;

  const profiles = computed((): CustomerProfile[] => {
    const id = tenantId.value;
    if (!id) return [];
    return byTenantId.value[id] ?? [];
  });

  const isLoading = computed(
    () => loadingTenantId.value !== null && loadingTenantId.value === tenantId.value,
  );

  watch(
    () => ({
      id: tenantId.value,
      on: enabled?.value ?? true,
    }),
    ({ id, on }) => {
      if (id && on) {
        void store.ensureLoaded(id);
      }
    },
    { immediate: true },
  );

  return {
    profiles,
    isLoading,
    error,
    ensureLoaded: (force = false) => {
      const id = tenantId.value;
      if (!id) return Promise.resolve([]);
      return store.ensureLoaded(id, force);
    },
    profileById: (profileId: number) =>
      profiles.value.find((p) => p.id === profileId) ?? null,
  };
}
