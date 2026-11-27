import { useQuery } from '@tanstack/vue-query';
import { computed, type MaybeRefOrGetter, toValue } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { ppPurchaseRequestRepository } from '../repositories/ppPurchaseRequestRepository';
import {
  ppPurchaseQueryKeys,
  ppSupplierListExcludePlacementsCacheKey,
} from '../shared/queryKeys/ppPurchaseQueryKeys';
import { PP_SUPPLIER_LIST_EXCLUDE_PLACEMENT_STATUSES } from '../utils/ppOrderLinePlacement';
import {
  serializePpSupplierOrderLineListFilters,
  type PpSupplierOrderLineListFilters,
} from '../types/ppSupplierOrderLineFilters';

export function usePpSupplierOrderLinesQuery(
  enabled: MaybeRefOrGetter<boolean>,
  appliedFilters: MaybeRefOrGetter<PpSupplierOrderLineListFilters>,
) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId);
  const peopleGroupMemberId = computed(() => authStore.customerGroupMemberId);
  const supplierGroupId = computed(() => authStore.customerGroupId);

  return useQuery({
    queryKey: computed(() =>
      ppPurchaseQueryKeys.supplierOrderLines(
        tenantId.value,
        peopleGroupMemberId.value,
        ppSupplierListExcludePlacementsCacheKey(),
        serializePpSupplierOrderLineListFilters(toValue(appliedFilters)),
      ),
    ),
    queryFn: async () => {
      const tid = tenantId.value;
      const memberId = peopleGroupMemberId.value;
      if (tid == null || memberId == null) throw new Error('Proxy supplier session not ready.');
      const filters = toValue(appliedFilters);
      const lines = await ppPurchaseRequestRepository.listLinesForSupplier(tid, memberId, {
        excludePlacementStatuses: PP_SUPPLIER_LIST_EXCLUDE_PLACEMENT_STATUSES,
        placementStatuses: filters.placement_statuses,
      });
      const groupId = supplierGroupId.value;
      if (groupId == null) return lines;
      return lines.filter((line) => line.pp_supplier_group_id === groupId);
    },
    enabled: computed(
      () =>
        toValue(enabled)
        && tenantId.value != null
        && peopleGroupMemberId.value != null,
    ),
  });
}