import { computed, type MaybeRefOrGetter, toValue } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export function useDropshipOrderDetailV2Query(options: {
  tenantSlug: MaybeRefOrGetter<string | null>;
  orderId: MaybeRefOrGetter<number>;
  enabled?: MaybeRefOrGetter<boolean>;
}) {
  const authStore = useAuthStore();

  const tenantId = computed(() => authStore.tenantId ?? 0);
  const tenantSlug = computed(() => toValue(options.tenantSlug));
  const orderId = computed(() => toValue(options.orderId));
  const enabled = computed(() => {
    const extra = options.enabled === undefined ? true : toValue(options.enabled);
    return extra && tenantId.value > 0 && orderId.value > 0;
  });

  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.dropshipDetailV2(tenantId.value, orderId.value)),
    enabled,
    staleTime: 15_000,
    queryFn: () => shopOrderRepository.getDropshipOrderDetailV2(tenantId.value, orderId.value),
  });
}
