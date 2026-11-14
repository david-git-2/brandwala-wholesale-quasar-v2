import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { moneyKernelRepository } from '../repositories/moneyKernelRepository';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

export type WriteOffBillInput = {
  billId: number;
  tenantId: number;
  amount: number;
  reason: string;
};

export function useWriteOffBillMutation(parentBillId: () => number | null) {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();

  return useMutation({
    mutationFn: async (payload: WriteOffBillInput) => {
      const tenantId =
        payload.tenantId
        ?? authStore.selectedTenant?.parent_tenant_id
        ?? authStore.selectedTenant?.id
        ?? 0;
      if (!tenantId) throw new Error('Tenant not ready.');
      await moneyKernelRepository.writeOffBill({
        tenantId,
        billId: payload.billId,
        amount: payload.amount,
        reason: payload.reason.trim(),
      });
    },
    onSuccess: () => {
      const id = parentBillId();
      showSuccessNotification('Write-off recorded.');
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
      if (id) {
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.detailBundle(id) });
        void queryClient.invalidateQueries({
          queryKey: [...billsQueryKeys.detail(id), 'bill-lines'],
        });
      }
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not write off bill.';
      showErrorNotification(message);
    },
  });
}