import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { invoiceRepository } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export function useVoidBillMutation(billId: () => number | null) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async () => {
      const id = billId();
      if (!id) throw new Error('Bill not found.');
      await invoiceRepository.voidGlobalInvoice(id);
    },
    onSuccess: () => {
      const id = billId();
      showSuccessNotification('Bill voided.');
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
      if (id) {
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.detail(id) });
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.items(id) });
      }
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not void bill.';
      showErrorNotification(message);
    },
  });
}
