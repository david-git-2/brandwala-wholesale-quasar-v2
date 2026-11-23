import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { paysRepository } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export function useVoidPayMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: { tenantId: number; paymentId: number; reason: string; source?: string }) => {
      await paysRepository.reversePay(payload.paymentId, payload.reason);
    },
    onSuccess: (_data, vars) => {
      const src = vars.source ?? '';
      const msg =
        src === 'ap_payout' || src === 'commission'
          ? 'Payout voided.'
          : src === 'courier_remittance'
            ? 'Remittance voided.'
            : 'Receipt voided.';
      showSuccessNotification(msg);
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.detail(vars.paymentId) });
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not void receipt.');
    },
  });
}
