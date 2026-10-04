import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { paysRepository } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export function useVoidPayMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: { tenantId: number; paymentId: number; reason: string }) => {
      await paysRepository.voidCustomerReceipt(payload.tenantId, payload.paymentId, payload.reason);
    },
    onSuccess: (_data, vars) => {
      showSuccessNotification('Receipt voided.');
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.detail(vars.paymentId) });
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not void receipt.');
    },
  });
}
