import { useQuery } from '@tanstack/vue-query';
import { computed } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { ppShipmentRepository } from '../repositories/ppShipmentRepository';
import { ppShipmentQueryKeys } from '../shared/queryKeys/ppShipmentQueryKeys';

export function usePpShipmentsQuery() {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  return useQuery({
    queryKey: computed(() => ppShipmentQueryKeys.list(tenantId.value)),
    queryFn: () => ppShipmentRepository.listShipments(tenantId.value!),
    enabled: computed(() => tenantId.value != null && tenantId.value > 0),
    staleTime: 0,
    gcTime: 10 * 60_000,
  });
}