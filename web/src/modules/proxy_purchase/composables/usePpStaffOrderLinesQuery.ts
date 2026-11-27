import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { ppPurchaseRequestRepository } from '../repositories/ppPurchaseRequestRepository';
import { ppPurchaseQueryKeys } from '../shared/queryKeys/ppPurchaseQueryKeys';
import type { PpAppOrderLineListFilters } from '../types/ppAppOrderLineFilters';
import { serializePpAppOrderLineListFilters } from '../types/ppAppOrderLineFilters';

export function usePpStaffOrderLinesQuery(
  enabled: { value: boolean },
  filters: Ref<PpAppOrderLineListFilters>,
) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId);
  const filtersKey = computed(() => serializePpAppOrderLineListFilters(filters.value));

  return useQuery({
    queryKey: computed(() =>
      ppPurchaseQueryKeys.staffOrderLines(tenantId.value, filtersKey.value),
    ),
    queryFn: async () => {
      const tid = tenantId.value;
      if (tid == null) throw new Error('Tenant not ready.');
      return ppPurchaseRequestRepository.listLinesForStaff(tid, filters.value);
    },
    enabled: computed(() => enabled.value && tenantId.value != null),
  });
}