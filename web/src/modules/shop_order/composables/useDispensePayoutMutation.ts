import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { courierRemittanceRepository } from '../repositories/courierRemittanceRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { showSuccessNotification, showErrorNotification, parseSupabaseError } from 'src/utils/appFeedback';
import type { DispensePayoutPayload } from '../types';

export function useDispensePayoutMutation(tenantId?: number) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (payload: DispensePayoutPayload) => {
      return courierRemittanceRepository.dispensePayout(payload);
    },
    onSuccess: (data) => {
      showSuccessNotification(
        `Payout of ৳${data.amount.toLocaleString()} dispensed successfully. New balance: ৳${data.new_balance.toLocaleString()}`,
      );
      if (tenantId) {
        void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.merchantPayouts(tenantId) });
      } else {
        void queryClient.invalidateQueries({ queryKey: ['merchant-payouts'] });
      }
    },
    onError: (error: unknown) => {
      const msg = parseSupabaseError(error, 'Failed to dispense payout');
      showErrorNotification(msg);
    },
  });
}
