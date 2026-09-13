import { useMutation, useQueryClient, type QueryClient } from '@tanstack/vue-query';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import { parseSupabaseError, showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';
import type {
  ProductBasedCostingItem,
  ProductBasedCostingItemCreateInput,
  ProductBasedCostingItemListPage,
  ProductBasedCostingItemUpdateInput,
} from '../types';

type DeletePbcItemInput = number | { id: number; fileId?: number };

type InfiniteItemsData = {
  pages: ProductBasedCostingItemListPage[];
  pageParams: unknown[];
};

function resolvePbcFileIdFromItemsCache(
  queryClient: QueryClient,
  itemId: number,
): number | undefined {
  const queries = queryClient.getQueriesData<ProductBasedCostingItem[]>({
    queryKey: ['productBasedCosting', 'items'],
  });

  for (const [, items] of queries) {
    const found = items?.find((item) => item.id === itemId);
    if (found?.product_based_costing_file_id) {
      return found.product_based_costing_file_id;
    }
  }

  return undefined;
}

function isInfiniteItemsData(value: unknown): value is InfiniteItemsData {
  return (
    !!value &&
    typeof value === 'object' &&
    'pages' in value &&
    Array.isArray((value as InfiniteItemsData).pages)
  );
}

function invalidatePbcFileSummary(queryClient: QueryClient, fileId: number) {
  void queryClient.invalidateQueries({
    queryKey: productBasedCostingQueryKeys.fileSummaryRoot(fileId),
  });
}

function removePbcItemFromCache(queryClient: QueryClient, fileId: number, itemId: number) {
  queryClient.setQueryData<ProductBasedCostingItem[]>(
    productBasedCostingQueryKeys.itemsList(fileId),
    (oldItems) => (oldItems ?? []).filter((item) => item.id !== itemId),
  );

  queryClient.setQueriesData<InfiniteItemsData | ProductBasedCostingItem[]>(
    { queryKey: productBasedCostingQueryKeys.itemsRoot(fileId) },
    (oldData) => {
      if (Array.isArray(oldData)) {
        return oldData.filter((item) => item.id !== itemId);
      }

      if (!isInfiniteItemsData(oldData)) {
        return oldData;
      }

      let removed = false;
      const pages = oldData.pages.map((page) => {
        const hadItem = page.data.some((item) => item.id === itemId);
        if (hadItem) removed = true;
        return {
          ...page,
          data: page.data.filter((item) => item.id !== itemId),
        };
      });

      if (!removed) {
        return oldData;
      }

      return {
        ...oldData,
        pages: pages.map((page, index) =>
          index === 0
            ? {
                ...page,
                meta: {
                  ...page.meta,
                  total: Math.max(0, page.meta.total - 1),
                },
              }
            : page,
        ),
      };
    },
  );
}

function addPbcItemToCache(queryClient: QueryClient, fileId: number, item: ProductBasedCostingItem) {
  queryClient.setQueryData<ProductBasedCostingItem[]>(
    productBasedCostingQueryKeys.itemsList(fileId),
    (oldItems) => {
      if (!oldItems) return [item];
      if (oldItems.some((existing) => existing.id === item.id)) return oldItems;
      return [...oldItems, item];
    },
  );

  queryClient.setQueriesData<InfiniteItemsData | ProductBasedCostingItem[]>(
    { queryKey: productBasedCostingQueryKeys.itemsRoot(fileId) },
    (oldData) => {
      if (Array.isArray(oldData)) {
        if (oldData.some((existing) => existing.id === item.id)) return oldData;
        return [...oldData, item];
      }

      if (!isInfiniteItemsData(oldData) || oldData.pages.length === 0) {
        return oldData;
      }

      if (oldData.pages.some((page) => page.data.some((existing) => existing.id === item.id))) {
        return oldData;
      }

      const [firstPage, ...restPages] = oldData.pages;
      if (!firstPage) return oldData;

      return {
        ...oldData,
        pages: [
          {
            ...firstPage,
            data: [...firstPage.data, item],
            meta: {
              ...firstPage.meta,
              total: firstPage.meta.total + 1,
            },
          },
          ...restPages,
        ],
      };
    },
  );
}

function errorText(error: unknown): string {
  if (typeof error === 'string') return error;
  if (error && typeof error === 'object' && 'message' in error) {
    return String((error as { message?: unknown }).message ?? '');
  }
  return '';
}

export function describePbcItemMutationError(
  error: unknown,
  fallback: string,
  kind: 'add' | 'remove' | 'update',
): { message: string; title: string } {
  const raw = errorText(error);
  const lower = raw.toLowerCase();
  if (kind === 'add' && (lower.includes('v_item') || lower.includes('has no field "status"'))) {
    return { message: "Couldn't add this product.", title: "Couldn't add this product" };
  }
  if (
    kind === 'remove' &&
    (lower.includes('v_item') ||
      lower.includes('has no field "status"') ||
      /costing item \d+ not found/i.test(raw))
  ) {
    return { message: "Couldn't remove this product.", title: "Couldn't remove this product" };
  }
  return { message: parseSupabaseError(error, fallback), title: 'Request failed' };
}

const showMutationWarning = (
  error: unknown,
  fallback: string,
  kind: 'add' | 'remove' | 'update' = 'update',
) => {
  const described = describePbcItemMutationError(error, fallback, kind);
  showWarningDialog(described.message, described.title);
};

export function useCreateProductBasedCostingItemMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: ProductBasedCostingItemCreateInput) =>
      productBasedCostingRepository.createProductBasedCostingItem(payload),
    onSuccess: (data) => {
      showSuccessNotification('Product based costing item created successfully.');
      if (data?.product_based_costing_file_id) {
        addPbcItemToCache(queryClient, data.product_based_costing_file_id, data);
        invalidatePbcFileSummary(queryClient, data.product_based_costing_file_id);
      }
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to create costing item.', 'add');
    },
  });
}

export function useUpdateProductBasedCostingItemMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: ProductBasedCostingItemUpdateInput) =>
      productBasedCostingRepository.updateProductBasedCostingItem(payload),
    onSuccess: (data) => {
      showSuccessNotification('Product based costing item updated successfully.');
      if (data?.product_based_costing_file_id) {
        queryClient.setQueryData<ProductBasedCostingItem[]>(
          productBasedCostingQueryKeys.itemsList(data.product_based_costing_file_id),
          (oldItems) => {
            if (!oldItems) return [data];
            return oldItems.map((item) => (item.id === data.id ? data : item));
          },
        );
        void queryClient.invalidateQueries({
          queryKey: productBasedCostingQueryKeys.itemsRoot(data.product_based_costing_file_id),
        });
        invalidatePbcFileSummary(queryClient, data.product_based_costing_file_id);
      }
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to update costing item.');
    },
  });
}

export function useDeleteProductBasedCostingItemMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: DeletePbcItemInput) => {
      const id = typeof input === 'number' ? input : input.id;
      return productBasedCostingRepository.deleteProductBasedCostingItem(id);
    },
    onSuccess: (data, input) => {
      showSuccessNotification('Product based costing item deleted successfully.');
      const fileId =
        data.product_based_costing_file_id ??
        (typeof input === 'object' ? input.fileId : undefined) ??
        resolvePbcFileIdFromItemsCache(queryClient, data.id);

      if (!fileId) {
        void queryClient.invalidateQueries({ queryKey: ['productBasedCosting', 'items'] });
        return;
      }

      removePbcItemFromCache(queryClient, fileId, data.id);
      invalidatePbcFileSummary(queryClient, fileId);
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to delete costing item.', 'remove');
    },
  });
}

export function useDeleteProductBasedCostingItemsBulkMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ ids }: { fileId: number; ids: number[] }) =>
      productBasedCostingRepository.deleteProductBasedCostingItemsBulk(ids),
    onSuccess: (_deletedItems, variables) => {
      showSuccessNotification(
        `${variables.ids.length} costing item${variables.ids.length === 1 ? '' : 's'} deleted successfully.`,
      );
      for (const id of variables.ids) {
        removePbcItemFromCache(queryClient, variables.fileId, id);
      }
      invalidatePbcFileSummary(queryClient, variables.fileId);
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to delete costing items.', 'remove');
    },
  });
}

export function useUpdateProductBasedCostingItemsByFileIdMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ fileId, payload }: { fileId: number; payload: Partial<ProductBasedCostingItem> }) =>
      productBasedCostingRepository.updateProductBasedCostingItemsByFileId(fileId, payload),
    onSuccess: (updatedItems, variables) => {
      if (updatedItems && updatedItems.length > 0) {
        const byId = new Map(updatedItems.map((item) => [item.id, item]));
        queryClient.setQueryData<ProductBasedCostingItem[]>(
          productBasedCostingQueryKeys.itemsList(variables.fileId),
          (oldItems) => {
            if (!oldItems) return updatedItems;
            return oldItems.map((item) => byId.get(item.id) ?? item);
          },
        );
      } else {
        void queryClient.invalidateQueries({
          queryKey: productBasedCostingQueryKeys.itemsList(variables.fileId),
        });
      }
      invalidatePbcFileSummary(queryClient, variables.fileId);
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to update costing items.');
    },
  });
}

export function useRecalculateOfferPricesMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (fileId: number) =>
      productBasedCostingRepository.recalculateProductBasedCostingFileOfferPrices(fileId),
    onSuccess: (_, fileId) => {
      void queryClient.invalidateQueries({
        queryKey: productBasedCostingQueryKeys.itemsRoot(fileId),
      });
      invalidatePbcFileSummary(queryClient, fileId);
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to recalculate offer prices.');
    },
  });
}

export function useReorderProductBasedCostingItemsMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({
      itemsOrder,
    }: {
      fileId: number;
      itemsOrder: { id: number; sort_order: number }[];
    }) => productBasedCostingRepository.updateProductBasedCostingItemsOrder(itemsOrder),
    onSuccess: (_, variables) => {
      showSuccessNotification('Items reordered successfully.');
      void queryClient.invalidateQueries({
        queryKey: productBasedCostingQueryKeys.itemsRoot(variables.fileId),
      });
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to reorder items.');
    },
  });
}

