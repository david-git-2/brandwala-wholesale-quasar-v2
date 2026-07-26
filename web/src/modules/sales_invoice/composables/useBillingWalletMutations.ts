import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  billingWalletRepository,
  type CreateWalletPayoutInput,
} from '../repositories/billingWalletRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';

export function useCreateWalletPayoutMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: CreateWalletPayoutInput) => billingWalletRepository.createWalletPayout(input),
    onSuccess: () => {
      // Invalidate all wallet and sales invoice queries to trigger background refetch
      void queryClient.invalidateQueries({ queryKey: salesInvoiceQueryKeys.root });
    },
  });
}
