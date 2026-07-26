import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { globalStockAllocationRepository } from '../repositories/globalStockAllocationRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';

export interface UpsertAllocationInput {
  parentTenantId: number;
  childTenantId: number;
  stockId: number;
  quantity: number;
}

export interface BulkAllocateShipmentInput {
  parentTenantId: number;
  shipmentId: number;
  childTenantId: number;
}

export interface SaveBatchGridInput {
  parentTenantId: number;
  edits: Array<{
    stockId: number;
    childTenantId: number;
    quantity: number;
  }>;
}

export function useSaveAllocationMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: UpsertAllocationInput) =>
      globalStockAllocationRepository.upsertGlobalStockAllocation(
        input.parentTenantId,
        input.childTenantId,
        input.stockId,
        input.quantity,
      ),
    onSuccess: async (_, variables) => {
      await Promise.all([
        queryClient.invalidateQueries({
          queryKey: procurementStockQueryKeys.all,
        }),
        queryClient.invalidateQueries({
          queryKey: procurementStockQueryKeys.stockAllocations(variables.stockId),
        }),
      ]);
    },
  });
}

export function useSaveBatchGridAllocationsMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (input: SaveBatchGridInput) => {
      for (const edit of input.edits) {
        await globalStockAllocationRepository.upsertGlobalStockAllocation(
          input.parentTenantId,
          edit.childTenantId,
          edit.stockId,
          edit.quantity,
        );
      }
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({
        queryKey: procurementStockQueryKeys.all,
      });
    },
  });
}

export function useBulkAllocateShipmentMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: BulkAllocateShipmentInput) =>
      globalStockAllocationRepository.bulkAllocateShipment(
        input.parentTenantId,
        input.shipmentId,
        input.childTenantId,
      ),
    onSuccess: async () => {
      await queryClient.invalidateQueries({
        queryKey: procurementStockQueryKeys.all,
      });
    },
  });
}
