import { useQuery } from '@tanstack/vue-query';
import { computed } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { ppPurchaseRequestRepository } from '../repositories/ppPurchaseRequestRepository';
import { ppPurchaseQueryKeys } from '../shared/queryKeys/ppPurchaseQueryKeys';

export function usePpSupplierOrderLinesQuery(enabled: { value: boolean }) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId);
  const peopleGroupMemberId = computed(() => authStore.customerGroupMemberId);
  const supplierGroupId = computed(() => authStore.customerGroupId);

  return useQuery({
    queryKey: computed(() =>
      ppPurchaseQueryKeys.supplierOrderLines(tenantId.value, peopleGroupMemberId.value),
    ),
    queryFn: async () => {
      const tid = tenantId.value;
      const memberId = peopleGroupMemberId.value;
      if (tid == null || memberId == null) throw new Error('Proxy supplier session not ready.');
      const lines = await ppPurchaseRequestRepository.listLinesForSupplier(tid, memberId);
      const groupId = supplierGroupId.value;
      if (groupId == null) return lines;
      return lines.filter((line) => line.pp_supplier_group_id === groupId);
    },
    enabled: computed(
      () =>
        enabled.value
        && tenantId.value != null
        && peopleGroupMemberId.value != null,
    ),
  });
}