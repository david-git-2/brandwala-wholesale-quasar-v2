import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { cashbookRepository } from '../repositories/cashbookRepository';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export function useTransferCashbookPointMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: {
      tenantId: number;
      fromPointId: number;
      toPointId: number;
      currencyCode: string;
      amount: number;
      note?: string | null;
    }) =>
      cashbookRepository.transferCashbookPoint({
        tenantId: payload.tenantId,
        fromPointId: payload.fromPointId,
        toPointId: payload.toPointId,
        currencyCode: payload.currencyCode,
        amount: payload.amount,
        note: payload.note,
      }),
    onSuccess: () => {
      showSuccessNotification('Cash moved between locations.');
      void queryClient.invalidateQueries({ queryKey: cashbookQueryKeys.root });
    },
    onError: (error: unknown) => {
      showErrorNotification(
        error instanceof Error ? error.message : 'Could not move cash.',
      );
    },
  });
}
