import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import { parseSupabaseError, showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';
import type {
  ProductBasedCostingFile,
  ProductBasedCostingFileCreateInput,
  ProductBasedCostingFileListPage,
  ProductBasedCostingFileUpdateInput,
} from '../types';

const showMutationWarning = (error: unknown, fallback: string) => {
  showWarningDialog(parseSupabaseError(error, fallback), 'Request failed');
};

export function useCreateProductBasedCostingFileMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: ProductBasedCostingFileCreateInput) =>
      productBasedCostingRepository.createProductBasedCostingFile(payload),
    onSuccess: (newFile) => {
      showSuccessNotification('Product based costing file created successfully.');
      queryClient.setQueryData(
        productBasedCostingQueryKeys.fileDetail(newFile.id),
        newFile,
      );
      void queryClient.invalidateQueries({ queryKey: productBasedCostingQueryKeys.all });
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to create costing file.');
    },
  });
}

export function useUpdateProductBasedCostingFileMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: ProductBasedCostingFileUpdateInput) =>
      productBasedCostingRepository.updateProductBasedCostingFile(payload),
    onSuccess: (updatedFile) => {
      showSuccessNotification('Product based costing file updated successfully.');
      // 1. Update the detail query cache directly
      queryClient.setQueryData(
        productBasedCostingQueryKeys.fileDetail(updatedFile.id),
        updatedFile,
      );

      // 2. Update the item in any cached files list queries
      queryClient.setQueriesData<ProductBasedCostingFileListPage>(
        { queryKey: ['productBasedCosting', 'files', 'list'] },
        (oldData) => {
          if (!oldData || !oldData.data) return oldData;
          return {
            ...oldData,
            data: oldData.data.map((item) =>
              item.id === updatedFile.id ? { ...item, ...updatedFile } : item,
            ),
          };
        },
      );
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to update costing file.');
    },
  });
}

export function useDeleteProductBasedCostingFileMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: number) => productBasedCostingRepository.deleteProductBasedCostingFile(id),
    onSuccess: (deletedFile, id) => {
      showSuccessNotification('Product based costing file deleted successfully.');
      queryClient.removeQueries({
        queryKey: productBasedCostingQueryKeys.fileDetail(id),
      });
      queryClient.setQueriesData<ProductBasedCostingFileListPage>(
        { queryKey: ['productBasedCosting', 'files', 'list'] },
        (oldData) => {
          if (!oldData || !oldData.data) return oldData;
          return {
            ...oldData,
            data: oldData.data.filter((item) => item.id !== id),
            meta: {
              ...oldData.meta,
              total: Math.max(0, oldData.meta.total - 1),
            },
          };
        },
      );
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to delete costing file.');
    },
  });
}

export function useCopyProductBasedCostingFileMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (item: ProductBasedCostingFile) => {
      const fileName = (item.name ?? '').trim();
      const nextName = fileName.length > 0 ? `${fileName} Copy` : `File #${item.id} Copy`;

      const fileCreateResult = await productBasedCostingRepository.createProductBasedCostingFile({
        tenant_id: item.tenant_id ?? null,
        name: nextName,
        order_for: item.order_for ?? null,
        billing_profile_id: item.billing_profile_id ?? null,
        note: item.note ?? null,
        vendor_code: item.vendor_code ?? null,
        market_code: item.market_code ?? null,
        cargo_rate_kg_gbp: item.cargo_rate_kg_gbp ?? null,
        profit_rate: item.profit_rate ?? null,
        conversion_rate: item.conversion_rate ?? null,
        status: 'pending',
      });

      if (!fileCreateResult?.id) {
        throw new Error('Failed to create copied costing file.');
      }

      const sourceItems = await productBasedCostingRepository.listProductBasedCostingItems(item.id);
      const copiedFileId = fileCreateResult.id;
      const sortedItems = [...sourceItems].sort((a, b) => (a.id ?? 0) - (b.id ?? 0));

      for (const sourceItem of sortedItems) {
        await productBasedCostingRepository.createProductBasedCostingItem({
          product_based_costing_file_id: copiedFileId,
          product_id: sourceItem.product_id ?? null,
          name: sourceItem.name ?? null,
          image_url: sourceItem.image_url ?? null,
          note: sourceItem.note ?? null,
          quantity: sourceItem.quantity ?? null,
          barcode: sourceItem.barcode ?? null,
          product_code: sourceItem.product_code ?? null,
          brand: sourceItem.brand ?? null,
          vendor_code: sourceItem.vendor_code ?? null,
          market_code: sourceItem.market_code ?? null,
          web_link: sourceItem.web_link ?? null,
          price_gbp: sourceItem.price_gbp ?? null,
          product_weight: sourceItem.product_weight ?? null,
          package_weight: sourceItem.package_weight ?? null,
          offer_price: sourceItem.offer_price ?? null,
          input_type: sourceItem.input_type ?? null,
          assigned_shipment_id: null,
        });
      }

      return { copiedFileId, nextName };
    },
    onSuccess: (data) => {
      showSuccessNotification(`Copied as #${data.copiedFileId} ${data.nextName}`);
      void queryClient.invalidateQueries({ queryKey: productBasedCostingQueryKeys.all });
    },
    onError: (error) => {
      showMutationWarning(error, 'Failed to copy costing file.');
    },
  });
}
