import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { courierRemittanceRepository } from '../repositories/courierRemittanceRepository';
import type { SaveCourierRemittanceBatchPayload } from '../types';

export function useCourierRemittanceMutations() {
  const queryClient = useQueryClient();

  const saveBatchDraftMutation = useMutation({
    mutationFn: (payload: SaveCourierRemittanceBatchPayload) =>
      courierRemittanceRepository.saveBatchDraft(payload),
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['courier-remittances', variables.tenant_id],
      });
      if (variables.batch_id) {
        void queryClient.invalidateQueries({
          queryKey: ['courier-remittance-detail', variables.tenant_id, variables.batch_id],
        });
      }
    },
  });

  const postBatchMutation = useMutation({
    mutationFn: (params: { tenantId: number; batchId: number }) =>
      courierRemittanceRepository.postBatch(params.batchId),
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['courier-remittances', variables.tenantId],
      });
      void queryClient.invalidateQueries({
        queryKey: ['courier-remittance-detail', variables.tenantId, variables.batchId],
      });
      void queryClient.invalidateQueries({
        queryKey: ['delivered-orders-unremitted'],
      });
      void queryClient.invalidateQueries({
        queryKey: ['shopOrder'],
      });
    },
  });

  return {
    saveBatchDraftMutation,
    postBatchMutation,
  };
}
