import { useQuery } from '@tanstack/vue-query';
import { computed, toValue, type MaybeRefOrGetter } from 'vue';
import { batchCodeRepository } from '../repositories/batchCodeRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';

const resolveId = (source: MaybeRefOrGetter<number | null | undefined>) => {
  const raw = toValue(source);
  if (raw == null || Number.isNaN(Number(raw))) return null;
  return Number(raw);
};

export function useBatchCodeListsQuery(
  parentTenantId: MaybeRefOrGetter<number | null | undefined>,
) {
  const resolvedParentTenantId = computed(() => resolveId(parentTenantId));

  return useQuery({
    queryKey: computed(() =>
      resolvedParentTenantId.value != null
        ? procurementStockQueryKeys.batchCodeLists(resolvedParentTenantId.value)
        : ['procurementStock', 'batchCodeLists', 'disabled'],
    ),
    queryFn: () => batchCodeRepository.listByParentTenantId(resolvedParentTenantId.value!),
    enabled: computed(() => resolvedParentTenantId.value !== null),
  });
}

export function useBatchCodeListQuery(listId: MaybeRefOrGetter<number | null | undefined>) {
  const resolvedListId = computed(() => resolveId(listId));

  return useQuery({
    queryKey: computed(() =>
      resolvedListId.value != null
        ? procurementStockQueryKeys.batchCodeList(resolvedListId.value)
        : ['procurementStock', 'batchCodeList', 'disabled'],
    ),
    queryFn: async () => {
      const row = await batchCodeRepository.getById(resolvedListId.value!);
      if (!row) throw new Error('Batch list not found.');
      return row;
    },
    enabled: computed(() => resolvedListId.value !== null),
  });
}

export function useBatchCodeListByShipmentQuery(
  shipmentId: MaybeRefOrGetter<number | null | undefined>,
) {
  const resolvedShipmentId = computed(() => resolveId(shipmentId));

  return useQuery({
    queryKey: computed(() =>
      resolvedShipmentId.value != null
        ? procurementStockQueryKeys.batchCodeListByShipment(resolvedShipmentId.value)
        : ['procurementStock', 'batchCodeListByShipment', 'disabled'],
    ),
    queryFn: () => batchCodeRepository.getByShipmentId(resolvedShipmentId.value!),
    enabled: computed(() => resolvedShipmentId.value !== null),
  });
}

export function useBatchCodeItemsByShipmentQuery(
  shipmentId: MaybeRefOrGetter<number | null | undefined>,
) {
  const resolvedShipmentId = computed(() => resolveId(shipmentId));

  return useQuery({
    queryKey: computed(() =>
      resolvedShipmentId.value != null
        ? procurementStockQueryKeys.batchCodeItemsByShipment(resolvedShipmentId.value)
        : ['procurementStock', 'batchCodeItemsByShipment', 'disabled'],
    ),
    queryFn: async () => {
      const list = await batchCodeRepository.getByShipmentId(resolvedShipmentId.value!);
      if (!list) return [];
      return batchCodeRepository.listItemsByListId(list.id);
    },
    enabled: computed(() => resolvedShipmentId.value !== null),
  });
}

export function useBatchCodeItemsQuery(listId: MaybeRefOrGetter<number | null | undefined>) {
  const resolvedListId = computed(() => resolveId(listId));

  return useQuery({
    queryKey: computed(() =>
      resolvedListId.value != null
        ? procurementStockQueryKeys.batchCodeItems(resolvedListId.value)
        : ['procurementStock', 'batchCodeItems', 'disabled'],
    ),
    queryFn: () => batchCodeRepository.listItemsByListId(resolvedListId.value!),
    enabled: computed(() => resolvedListId.value !== null),
  });
}
