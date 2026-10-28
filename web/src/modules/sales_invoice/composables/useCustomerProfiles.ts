import { computed, watch, type Ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useCustomerProfileStore } from '../stores/customerProfileStore';
import type { CustomerProfile } from '../repositories/customerProfileRepository';

export type CustomerProfilesScope = 'customers' | 'desk';

/** Billing profiles — Pinia cache; API only when empty for that tenant. */
export function useCustomerProfiles(
  tenantId: Ref<number | null | undefined>,
  options?: { enabled?: Ref<boolean>; scope?: CustomerProfilesScope },
) {
  const store = useCustomerProfileStore();
  const { byTenantId, deskProfilesByParentId, loadingTenantId, loadingDeskParentId, error } =
    storeToRefs(store);

  const scope = options?.scope ?? 'customers';
  const enabled = options?.enabled;

  const profiles = computed((): CustomerProfile[] => {
    const id = tenantId.value;
    if (!id) return [];
    if (scope === 'desk') {
      return deskProfilesByParentId.value[id] ?? [];
    }
    return byTenantId.value[id] ?? [];
  });

  const isLoading = computed(() => {
    const id = tenantId.value;
    if (!id) return false;
    if (scope === 'desk') {
      return loadingDeskParentId.value === id;
    }
    return loadingTenantId.value === id;
  });

  watch(
    () => ({
      id: tenantId.value,
      on: enabled?.value ?? true,
    }),
    ({ id, on }) => {
      if (id && on) {
        if (scope === 'desk') {
          void store.ensureDeskProfilesLoaded(id);
        } else {
          void store.ensureLoaded(id);
        }
      }
    },
    { immediate: true },
  );

  const ensureLoaded = (force = false) => {
    const id = tenantId.value;
    if (!id) return Promise.resolve([]);
    if (scope === 'desk') {
      return store.ensureDeskProfilesLoaded(id, force);
    }
    return store.ensureLoaded(id, force);
  };

  return {
    profiles,
    isLoading,
    error,
    ensureLoaded,
    profileById: (profileId: number) =>
      profiles.value.find((p) => p.id === profileId) ?? null,
  };
}
