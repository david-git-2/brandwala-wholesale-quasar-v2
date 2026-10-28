import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { paysRepository } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export function useBounceChequeMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: { tenantId: number; instrumentId: number; reason: string }) => {
      return paysRepository.bounceChequeInstrument(
        payload.tenantId,
        payload.instrumentId,
        payload.reason,
      );
    },
    onSuccess: (data) => {
      showSuccessNotification('Cheque marked bounced; payment reversed.');
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
      const payId = (data as { payment_id?: number })?.payment_id;
      if (payId) {
        void queryClient.invalidateQueries({ queryKey: paysQueryKeys.detail(payId) });
      }
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not bounce cheque.');
    },
  });
}
