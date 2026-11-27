import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { ppPurchaseRequestRepository } from '../repositories/ppPurchaseRequestRepository';
import { ppPurchaseQueryKeys } from '../shared/queryKeys/ppPurchaseQueryKeys';

export function usePpPurchaseRequestPageQuery(requestId: Ref<number | null>) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId);

  const enabled = computed(
    () => tenantId.value != null && requestId.value != null && requestId.value > 0,
  );

  const requestQuery = useQuery({
    queryKey: computed(() => ppPurchaseQueryKeys.request(tenantId.value, requestId.value)),
    queryFn: async () => {
      const tid = tenantId.value;
      const rid = requestId.value;
      if (tid == null || rid == null) throw new Error('Missing context.');
      return ppPurchaseRequestRepository.getRequest(tid, rid);
    },
    enabled,
  });

  const linesQuery = useQuery({
    queryKey: computed(() => ppPurchaseQueryKeys.requestLines(tenantId.value, requestId.value)),
    queryFn: async () => {
      const tid = tenantId.value;
      const rid = requestId.value;
      if (tid == null || rid == null) throw new Error('Missing context.');
      return ppPurchaseRequestRepository.listLines(tid, rid);
    },
    enabled,
  });

  return { requestQuery, linesQuery };
}