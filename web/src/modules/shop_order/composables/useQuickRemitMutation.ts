import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { courierRemittanceRepository } from '../repositories/courierRemittanceRepository';
import { showSuccessNotification, showErrorNotification, parseSupabaseError } from 'src/utils/appFeedback';
import type { ReconcileSingleOrderPayload } from '../types';

export function useQuickRemitMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: ReconcileSingleOrderPayload) => {
      return courierRemittanceRepository.reconcileSingleOrder(payload);
    },
    onSuccess: async (data) => {
      showSuccessNotification(
        `Order payment remitted and middleman profit unlocked (Order #${data.order_id}).`
      );
      // Invalidate shop order queries to update table lists and holding summary
      await queryClient.invalidateQueries({ queryKey: ['shopOrder'] });
    },
    onError: (error: unknown) => {
      showErrorNotification(parseSupabaseError(error, 'Failed to remit order payment'));
    },
  });
}
