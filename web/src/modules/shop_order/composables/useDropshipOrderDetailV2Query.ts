import { computed, ref, watch, type MaybeRefOrGetter, toValue } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  dropshipOrderDetailV2StoreKey,
  useDropshipOrderDetailV2Store,
} from '../stores/dropshipOrderDetailV2Store';
import { useCourierServicesStore } from '../stores/courierServicesStore';
import { usePickupLocationsStore } from '../stores/pickupLocationsStore';

export function useDropshipOrderDetailV2Query(options: {
  tenantSlug: MaybeRefOrGetter<string | null>;
  orderId: MaybeRefOrGetter<number>;
  enabled?: MaybeRefOrGetter<boolean>;
}) {
  const authStore = useAuthStore();
  const detailStore = useDropshipOrderDetailV2Store();
  const courierStore = useCourierServicesStore();
  const pickupStore = usePickupLocationsStore();

  const tenantId = computed(() => authStore.tenantId ?? 0);
  const orderId = computed(() => toValue(options.orderId));
  const enabled = computed(() => {
    const extra = options.enabled === undefined ? true : toValue(options.enabled);
    return extra && tenantId.value > 0 && orderId.value > 0;
  });

  const storeKey = computed(() => dropshipOrderDetailV2StoreKey(tenantId.value, orderId.value));

  const fetchError = ref<Error | null>(null);

  watch(
    [tenantId, orderId, enabled],
    ([id, oid, isEnabled]) => {
      if (!isEnabled || id <= 0 || oid <= 0) return;
      fetchError.value = null;
      void detailStore.ensureDetail(id, oid).catch((err: unknown) => {
        fetchError.value = err instanceof Error ? err : new Error('Failed to load order detail');
      });
      void courierStore.ensureCouriers();
      void pickupStore.ensureLocations();
    },
    { immediate: true },
  );

  const data = computed(() => detailStore.byKey[storeKey.value] ?? null);
  const isLoading = computed(() => detailStore.loadingKeys[storeKey.value] === true);
  const isError = computed(() => fetchError.value != null || Boolean(detailStore.errorKeys[storeKey.value]));
  const error = computed(
    () =>
      fetchError.value ??
      (detailStore.errorKeys[storeKey.value]
        ? new Error(detailStore.errorKeys[storeKey.value]!)
        : null),
  );

  const refetch = async () => {
    if (tenantId.value <= 0 || orderId.value <= 0) return { data: null };
    fetchError.value = null;
    try {
      const detail = await detailStore.ensureDetail(tenantId.value, orderId.value, true);
      return { data: detail };
    } catch (err: unknown) {
      fetchError.value = err instanceof Error ? err : new Error('Failed to load order detail');
      throw err;
    }
  };

  return {
    data,
    isLoading,
    isError,
    error,
    refetch,
  };
}
