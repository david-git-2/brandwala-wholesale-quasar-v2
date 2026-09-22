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

const mergeListRow = (
  old: BatchCodeListRow,
  updated: BatchCodeList,
  relations?: {
    vendor?: BatchCodeListRow['vendor'];
    shipment?: BatchCodeListRow['shipment'];
  },
): BatchCodeListRow => ({
  ...old,
  ...updated,
  vendor: relations?.vendor ?? old.vendor,
  shipment: relations?.shipment ?? old.shipment,
  batch_code_items: old.batch_code_items,
});

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
          'barcode' | 'product_code' | 'batch_id' | 'manufacturing_date' | 'expire_date'
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
    pasteItemsMutation,
  };
}

export type UpdateBatchCodeListInput = {
  listId: number;
  parentTenantId: number;
  payload: Partial<Pick<BatchCodeList, 'name' | 'vendor_id' | 'shipment_id'>>;
  relations?: {
    vendor?: BatchCodeListRow['vendor'];
    shipment?: BatchCodeListRow['shipment'];
  };
};

export function useUpdateBatchCodeListMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ listId, payload }: UpdateBatchCodeListInput) =>
      batchCodeRepository.updateList(listId, payload),
    onSuccess: (updated, variables) => {
      const { listId, parentTenantId, relations } = variables;
      const previous = queryClient.getQueryData<BatchCodeListRow>(listKey(listId));

      patchListDetail(queryClient, listId, (old) => mergeListRow(old, updated, relations));
      patchLists(queryClient, parentTenantId, (rows) =>
        rows.map((row) =>
          row.id === listId ? mergeListRow(row, updated, relations) : row,
        ),
      );

      if (previous?.shipment_id && previous.shipment_id !== updated.shipment_id) {
        queryClient.removeQueries({ queryKey: listByShipmentKey(previous.shipment_id) });
      }
      if (updated.shipment_id) {
        queryClient.setQueryData(listByShipmentKey(updated.shipment_id), updated);
      }
    },
  });
}

export function useDeleteBatchCodeListMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({
      listId,
      parentTenantId,
      shipmentId,
    }: {
      listId: number;
      parentTenantId: number;
      shipmentId: number | null;
    }) => batchCodeRepository.deleteList(listId),
    onSuccess: (_void, variables) => {
      const { listId, parentTenantId, shipmentId } = variables;
      patchLists(queryClient, parentTenantId, (rows) => rows.filter((row) => row.id !== listId));
      queryClient.removeQueries({ queryKey: listKey(listId) });
      queryClient.removeQueries({ queryKey: itemsKey(listId) });
      if (shipmentId) {
        queryClient.removeQueries({ queryKey: listByShipmentKey(shipmentId) });
      }
    },
  });
}

export type CreateBatchCodeListInput = {
  parentTenantId: number;
  payload: Omit<BatchCodeList, 'id' | 'created_at' | 'updated_at'>;
  relations?: {
    vendor?: BatchCodeListRow['vendor'];
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
        vendor: relations?.vendor ?? null,
        shipment: relations?.shipment ?? null,
        batch_code_items: [{ count: 0 }],
      };

      patchLists(queryClient, parentTenantId, (rows) => [row, ...rows]);
      queryClient.setQueryData(listKey(created.id), row);
      queryClient.setQueryData(itemsKey(created.id), []);
      if (created.shipment_id) {
        queryClient.setQueryData(listByShipmentKey(created.shipment_id), created);
      }
    },
  });
}
