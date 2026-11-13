import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { billsRepository } from '../repositories/billsRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export function useVoidBillMutation(
  billId: () => number | null,
  options?: () => { tenantId?: number; spine?: 'legacy' | 'kernel' },
) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async () => {
      const id = billId();
      if (!id) throw new Error('Bill not found.');
      const opts = options?.();
      await billsRepository.voidBill(id, opts);
    },
    onSuccess: () => {
      const id = billId();
      showSuccessNotification('Bill voided.');
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
      if (id) {
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.detailBundle(id) });
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.items(id) });
      }
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not void bill.';
      showErrorNotification(message);
    },
  });
}
