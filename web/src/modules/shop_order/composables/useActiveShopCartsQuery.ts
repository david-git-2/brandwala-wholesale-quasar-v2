import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopCartService } from '../services/shopCartService';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

export function useActiveShopCartsQuery(enabled?: Ref<boolean>) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);
  const enabledRef = enabled ?? computed(() => true);

  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.activeCarts(tenantId.value)),
    queryFn: async () => {
      const res = await shopCartService.listActiveShopCarts(tenantId.value);
      if (!res.success) {
        throw new Error(res.error || 'Failed to fetch active shop carts');
      }
      return res.data ?? [];
    },
    staleTime: 60 * 1000,
    enabled: computed(() => enabledRef.value && !!tenantId.value),
  });
}
