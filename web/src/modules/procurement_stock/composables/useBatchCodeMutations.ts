import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed, toValue, type MaybeRefOrGetter } from 'vue';
import {
  batchCodeRepository,
  type BatchCodeItem,
  type BatchCodeList,
  type BatchCodeListRow,
  type BatchCodePasteRow,
} from '../repositories/batchCodeRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';

const itemsKey = (listId: number) => procurementStockQueryKeys.batchCodeItems(listId);
const listKey = (listId: number) => procurementStockQueryKeys.batchCodeList(listId);
const listsKey = (parentTenantId: number) => procurementStockQueryKeys.batchCodeLists(parentTenantId);
const listByShipmentKey = (shipmentId: number) =>
  procurementStockQueryKeys.batchCodeListByShipment(shipmentId);

const patchItems = (
  queryClient: ReturnType<typeof useQueryClient>,
  listId: number,
  updater: (items: BatchCodeItem[]) => BatchCodeItem[],
) => {
  queryClient.setQueryData<BatchCodeItem[]>(itemsKey(listId), (old) => updater(old ?? []));
};

const patchListDetail = (
  queryClient: ReturnType<typeof useQueryClient>,
  listId: number,
  updater: (row: BatchCodeListRow) => BatchCodeListRow,
) => {
  queryClient.setQueryData<BatchCodeListRow>(listKey(listId), (old) => (old ? updater(old) : old));
};

const patchLists = (
  queryClient: ReturnType<typeof useQueryClient>,
  parentTenantId: number,
  updater: (rows: BatchCodeListRow[]) => BatchCodeListRow[],
) => {
  queryClient.setQueryData<BatchCodeListRow[]>(listsKey(parentTenantId), (old) =>
    updater(old ?? []),
  );
};

const syncLineCount = (
  queryClient: ReturnType<typeof useQueryClient>,
  parentTenantId: number,
  listId: number,
  count: number,
) => {
  const applyCount = (row: BatchCodeListRow): BatchCodeListRow =>
    row.id === listId ? { ...row, batch_code_items: [{ count }] } : row;

  patchLists(queryClient, parentTenantId, (rows) => rows.map(applyCount));
  patchListDetail(queryClient, listId, applyCount);
};

const resolveParentTenantId = (
  queryClient: ReturnType<typeof useQueryClient>,
  listId: number,
): number | null => {
  const detail = queryClient.getQueryData<BatchCodeListRow>(listKey(listId));
  return detail?.parent_tenant_id ?? null;
};

export function useBatchCodeItemMutations(listId: MaybeRefOrGetter<number>) {
  const queryClient = useQueryClient();
  const resolvedListId = computed(() => toValue(listId));

  const createItemMutation = useMutation({
    mutationFn: (
      payload: Omit<BatchCodeItem, 'id' | 'list_id' | 'created_at' | 'updated_at'>,
    ) =>
      batchCodeRepository.createItem({ list_id: resolvedListId.value, ...payload }),
    onSuccess: (created) => {
      const id = resolvedListId.value;
      patchItems(queryClient, id, (items) => [...items, created]);
      const parentTenantId = resolveParentTenantId(queryClient, id);
      if (parentTenantId !== null) {
        const count = (queryClient.getQueryData<BatchCodeItem[]>(itemsKey(id)) ?? []).length;
        syncLineCount(queryClient, parentTenantId, id, count);
      }
    },
  });

  const updateItemMutation = useMutation({
    mutationFn: ({
      id,
      payload,
    }: {
      id: number;
      payload: Partial<
        Pick<
          BatchCodeItem,
          | 'barcode'
          | 'product_code'
          | 'batch_id'
          | 'manufacturing_date'
          | 'expire_date'
          | 'is_arrived'
        >
      >;
    }) => batchCodeRepository.updateItem(id, payload),
    onSuccess: (updated) => {
      const listIdValue = resolvedListId.value;
      patchItems(queryClient, listIdValue, (items) =>
        items.map((row) => (row.id === updated.id ? updated : row)),
      );
    },
  });

  const deleteItemMutation = useMutation({
    mutationFn: (id: number) => batchCodeRepository.deleteItem(id),
    onSuccess: (_void, id) => {
      const listIdValue = resolvedListId.value;
      patchItems(queryClient, listIdValue, (items) => items.filter((row) => row.id !== id));
      const parentTenantId = resolveParentTenantId(queryClient, listIdValue);
      if (parentTenantId !== null) {
        const count =
          (queryClient.getQueryData<BatchCodeItem[]>(itemsKey(listIdValue)) ?? []).length;
        syncLineCount(queryClient, parentTenantId, listIdValue, count);
      }
    },
  });

  const deleteItemsMutation = useMutation({
    mutationFn: (ids: number[]) =>
      batchCodeRepository.deleteItems(resolvedListId.value, ids),
    onSuccess: (_void, ids) => {
      const listIdValue = resolvedListId.value;
      const idSet = new Set(ids);
      patchItems(queryClient, listIdValue, (items) => items.filter((row) => !idSet.has(row.id)));
      const parentTenantId = resolveParentTenantId(queryClient, listIdValue);
      if (parentTenantId !== null) {
        const count =
          (queryClient.getQueryData<BatchCodeItem[]>(itemsKey(listIdValue)) ?? []).length;
        syncLineCount(queryClient, parentTenantId, listIdValue, count);
      }
    },
  });

  const pasteItemsMutation = useMutation({
    mutationFn: ({
      startRowIndex,
      rows,
    }: {
      startRowIndex: number;
      rows: BatchCodePasteRow[];
    }) => batchCodeRepository.pasteItems(resolvedListId.value, startRowIndex, rows),
    onSuccess: async () => {
      const listIdValue = resolvedListId.value;
      const items = await batchCodeRepository.listItemsByListId(listIdValue);
      queryClient.setQueryData(itemsKey(listIdValue), items);
      const parentTenantId = resolveParentTenantId(queryClient, listIdValue);
      if (parentTenantId !== null) {
        syncLineCount(queryClient, parentTenantId, listIdValue, items.length);
      }
    },
  });

  return {
    createItemMutation,
    updateItemMutation,
    deleteItemMutation,
    deleteItemsMutation,
    pasteItemsMutation,
  };
}

export function useDeleteBatchCodeListMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({
      listId,
    }: {
      listId: number;
      parentTenantId: number;
      shipmentId: number;
    }) => batchCodeRepository.deleteList(listId),
    onSuccess: (_void, variables) => {
      const { listId, parentTenantId, shipmentId } = variables;
      patchLists(queryClient, parentTenantId, (rows) => rows.filter((row) => row.id !== listId));
      queryClient.removeQueries({ queryKey: listKey(listId) });
      queryClient.removeQueries({ queryKey: itemsKey(listId) });
      queryClient.removeQueries({ queryKey: listByShipmentKey(shipmentId) });
    },
  });
}

export type CreateBatchCodeListInput = {
  parentTenantId: number;
  payload: Omit<BatchCodeList, 'id' | 'created_at' | 'updated_at'>;
  relations?: {
    shipment?: BatchCodeListRow['shipment'];
  };
};

export function useCreateBatchCodeListMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ payload }: CreateBatchCodeListInput) => batchCodeRepository.createList(payload),
    onSuccess: (created, variables) => {
      const { parentTenantId, relations } = variables;
      const row: BatchCodeListRow = {
        ...created,
        shipment: relations?.shipment ?? null,
        batch_code_items: [{ count: 0 }],
      };

      patchLists(queryClient, parentTenantId, (rows) => [row, ...rows]);
      queryClient.setQueryData(listKey(created.id), row);
      queryClient.setQueryData(itemsKey(created.id), []);
      queryClient.setQueryData(listByShipmentKey(created.shipment_id), created);
    },
  });
}
