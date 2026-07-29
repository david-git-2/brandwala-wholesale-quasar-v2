import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import { parseSupabaseError, showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';
import type {
  ProductBasedCostingItem,
  ProductBasedCostingItemCreateInput,
  ProductBasedCostingItemUpdateInput,
} from '../types';

const showMutationWarning = (error: unknown, fallback: string) => {
  showWarningDialog(parseSupabaseError(error, fallback), 'Request failed');
};

export function useCreateProductBasedCostingItemMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: ProductBasedCostingItemCreateInput) =>
      productBasedCostingRepository.createProductBasedCostingItem(payload),
    onSuccess: (data) => {
      showSuccessNotification('Product based costing item created successfully.');
      if (data?.product_based_costing_file_id) {
        queryClient.setQueryData<ProductBasedCostingItem[]>(
          productBasedCostingQueryKeys.itemsList(data.product_based_costing_file_id),
          (oldItems) => (oldItems ? [...oldItems, data] : [data]),
        );
      }
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to create costing item.');
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
    mutationFn: (id: number) => productBasedCostingRepository.deleteProductBasedCostingItem(id),
    onSuccess: (data) => {
      showSuccessNotification('Product based costing item deleted successfully.');
      if (data?.product_based_costing_file_id) {
        queryClient.setQueryData<ProductBasedCostingItem[]>(
          productBasedCostingQueryKeys.itemsList(data.product_based_costing_file_id),
          (oldItems) => (oldItems ? oldItems.filter((item) => item.id !== data.id) : []),
        );
      }
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to delete costing item.');
    },
  });
}

export function useDeleteProductBasedCostingItemsBulkMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ ids }: { fileId: number; ids: number[] }) =>
      productBasedCostingRepository.deleteProductBasedCostingItemsBulk(ids),
    onSuccess: (deletedItems, variables) => {
      const deletedIds = new Set(variables.ids);
      showSuccessNotification(
        `${variables.ids.length} costing item${variables.ids.length === 1 ? '' : 's'} deleted successfully.`,
      );
      queryClient.setQueryData<ProductBasedCostingItem[]>(
        productBasedCostingQueryKeys.itemsList(variables.fileId),
        (oldItems) => (oldItems ? oldItems.filter((item) => !deletedIds.has(item.id)) : []),
      );
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to delete costing items.');
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
        queryKey: productBasedCostingQueryKeys.itemsList(fileId),
      });
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to recalculate offer prices.');
    },
  });
}
