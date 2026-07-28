import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { dropshipFinanceRepository } from '../repositories/dropshipFinanceRepository';
import { dropshipFinanceQueryKeys } from '../shared/queryKeys/dropshipFinanceQueryKeys';
import { showSuccessNotification, showErrorNotification, parseSupabaseError } from 'src/utils/appFeedback';

export function useDropshipFinanceHubMutations(tenantId: { value: number | null | undefined }) {
  const queryClient = useQueryClient();

  const invalidateHub = () => {
    if (tenantId.value) {
      void queryClient.invalidateQueries({
        queryKey: dropshipFinanceQueryKeys.hubData(tenantId.value),
      });
    }
  };

  const confirmDeliveredCostingMutation = useMutation({
    mutationFn: (params: { orderId: number; codAmount?: number; deliveryCharge?: number; courierNotes?: string }) =>
      dropshipFinanceRepository.confirmDeliveredCosting(params),
    onSuccess: (data) => {
      showSuccessNotification(data.message || 'Delivered costing confirmed successfully');
      invalidateHub();
    },
    onError: (err: unknown) => {
      showErrorNotification(parseSupabaseError(err, 'Failed to confirm delivered costing'));
    },
  });

  const confirmCourierRemittanceMutation = useMutation({
    mutationFn: (params: { orderId: number; courierCharge?: number; remittanceRef?: string; bankTrxId?: string }) =>
      dropshipFinanceRepository.confirmCourierRemittance(params),
    onSuccess: (data) => {
      showSuccessNotification(data.message || 'Courier remittance confirmed successfully');
      invalidateHub();
    },
    onError: (err: unknown) => {
      showErrorNotification(parseSupabaseError(err, 'Failed to confirm courier remittance'));
    },
  });

  const dispenseMiddlemanPayoutMutation = useMutation({
    mutationFn: (params: { tenantId: number; billingProfileId: number; amount: number; payoutMethod?: string; referenceNotes?: string }) =>
      dropshipFinanceRepository.dispenseMiddlemanPayout(params),
    onSuccess: (data) => {
      showSuccessNotification(data.message || 'Middleman payout dispensed successfully');
      invalidateHub();
    },
    onError: (err: unknown) => {
      showErrorNotification(parseSupabaseError(err, 'Failed to dispense middleman payout'));
    },
  });

  return {
    confirmDeliveredCostingMutation,
    confirmCourierRemittanceMutation,
    dispenseMiddlemanPayoutMutation,
  };
}
