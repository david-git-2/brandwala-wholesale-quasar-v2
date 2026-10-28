import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { billsRepository } from '../repositories/billsRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export type ApplySettlementLine = {
  bill_id: number;
  amount: number;
  allocator_kind: 'pay' | 'credit_note';
  allocator_id: number;
};

export function useApplySettlementMutation(options?: { successMessage?: string }) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: { tenantId: number; lines: ApplySettlementLine[] }) => {
      for (const line of payload.lines) {
        if (line.amount <= 0) continue;
        await billsRepository.applySettlementToBill({
          tenant_id: payload.tenantId,
          bill_id: line.bill_id,
          allocator_kind: line.allocator_kind,
          allocator_id: line.allocator_id,
          books_amount: line.amount,
        });
      }
    },
    onSuccess: (_data, vars) => {
      showSuccessNotification(options?.successMessage ?? 'Settlement applied.');
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
      const payLine = vars.lines.find((l) => l.allocator_kind === 'pay');
      if (payLine) {
        void queryClient.invalidateQueries({ queryKey: paysQueryKeys.detail(payLine.allocator_id) });
      }
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not apply settlement.');
    },
  });
}
