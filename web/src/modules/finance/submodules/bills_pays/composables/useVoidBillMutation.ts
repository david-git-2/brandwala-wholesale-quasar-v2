import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { billsRepository } from '../repositories/billsRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { formatBillVoidErrorMessage } from '../utils/formatBillVoidErrorMessage';

export type VoidBillMutationInput = { reason?: string | null };

export function useVoidBillMutation(
  billId: () => number | null,
  options?: () => { tenantId?: number },
) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (input?: VoidBillMutationInput) => {
      const id = billId();
      if (!id) throw new Error('Bill not found.');
      const opts = options?.();
      await billsRepository.voidBill(id, { ...opts, reason: input?.reason });
    },
    onSuccess: () => {
      const id = billId();
      showSuccessNotification('Bill cancelled.');
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
      if (id) {
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.detailBundle(id) });
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.items(id) });
      }
    },
    onError: (error: unknown) => {
      showErrorNotification(formatBillVoidErrorMessage(error));
    },
  });
}
