import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { moneyKernelRepository } from '../repositories/moneyKernelRepository';
import { createPayIdempotencyKey } from '../repositories/paysRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export function useProfilePayRevertMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: { booksTenantId: number; paysId: number; reason: string }) => {
      await moneyKernelRepository.revertPays({
        tenantId: payload.booksTenantId,
        paysId: payload.paysId,
        reason: payload.reason,
        idempotencyKey: createPayIdempotencyKey(),
      });
    },
    onSuccess: () => {
      showSuccessNotification('Transaction reverted.');
      void queryClient.invalidateQueries({ queryKey: cashbookQueryKeys.root });
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not revert transaction.');
    },
  });
}
