import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { paysRepository } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export function useAllocatePayMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: {
      tenantId: number;
      paymentId: number;
      lines: Array<{ bill_id: number; amount: number }>;
    }) => {
      for (const line of payload.lines) {
        if (line.amount <= 0) continue;
        await paysRepository.allocatePayToBill({
          tenant_id: payload.tenantId,
          payment_id: payload.paymentId,
          bill_id: line.bill_id,
          amount: line.amount,
        });
      }
    },
    onSuccess: (_data, vars) => {
      showSuccessNotification('Leftover applied to bills.');
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.detail(vars.paymentId) });
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not apply leftover.');
    },
  });
}
