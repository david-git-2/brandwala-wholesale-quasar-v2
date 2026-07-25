import { useQuery } from '@tanstack/vue-query';
import { computed } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopCartService } from '../services/shopCartService';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

export function useActiveShopCartsQuery() {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);

  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.activeCarts(tenantId.value)),
    queryFn: async () => {
      const res = await shopCartService.listActiveShopCarts();
      if (!res.success) {
        throw new Error(res.error || 'Failed to fetch active shop carts');
      }
      return res.data ?? [];
    },
    staleTime: 60 * 1000,
    enabled: computed(() => !!tenantId.value),
  });
}
