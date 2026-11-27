import { useQuery } from '@tanstack/vue-query';
import { computed } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { ppPurchaseRequestRepository } from '../repositories/ppPurchaseRequestRepository';
import { ppPurchaseQueryKeys } from '../shared/queryKeys/ppPurchaseQueryKeys';

export function usePpCustomerOrderLinesQuery(enabled: { value: boolean }) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId);

  return useQuery({
    queryKey: computed(() => ppPurchaseQueryKeys.customerOrderLines(tenantId.value)),
    queryFn: async () => {
      const tid = tenantId.value;
      if (tid == null) throw new Error('Tenant not ready.');
      return ppPurchaseRequestRepository.listLinesForCustomer(tid);
    },
    enabled: computed(() => enabled.value && tenantId.value != null),
  });
}