import { type Ref } from 'vue';
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { courierRemittanceRepository } from '../repositories/courierRemittanceRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { showSuccessNotification, showErrorNotification, parseSupabaseError } from 'src/utils/appFeedback';

export function useDropshipRemittanceMutations(tenantSlug?: Ref<string | null>) {
  const queryClient = useQueryClient();

  const recordOrderRemittanceMutation = useMutation({
    mutationFn: async (payload: {
      orderId: number;
      netAmount: number;
      remittanceRef: string;
      bankTrxId?: string | null;
      note?: string | null;
    }) => {
      return courierRemittanceRepository.recordOrderRemittance(payload);
    },
    onSuccess: async (_, variables) => {
      showSuccessNotification('Courier remittance recorded successfully.');
      const slug = tenantSlug?.value ?? null;
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.detail(slug, variables.orderId) }),
        queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.ledger(slug) }),
        queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.ledgerPendingCod(slug) }),
        queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.financeHub(slug) }),
      ]);
    },
    onError: (error: unknown) => {
      showErrorNotification(parseSupabaseError(error, 'Failed to record courier remittance'));
    },
  });

  return {
    recordOrderRemittanceMutation,
  };
}
