import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  billsRepository,
  type BillDetailBundle,
} from '../repositories/billsRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export type PatchBillDatesInput = {
  tenantId: number;
  billId: number;
  invoiceDate: string;
  dueDate?: string | null;
  touchDueDate: boolean;
};

export function usePatchBillDatesMutation(billId: () => number | null) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: PatchBillDatesInput) => billsRepository.patchBillDates(input),
    onSuccess: (row) => {
      const id = billId();
      showSuccessNotification('Bill dates updated.');
      if (id) {
        queryClient.setQueryData<BillDetailBundle | undefined>(
          billsQueryKeys.detailBundle(id),
          (old) => {
            if (!old) return old;
            return {
              ...old,
              bill: {
                ...old.bill,
                invoice_date: row.invoice_date,
                due_date: row.due_date,
              },
            };
          },
        );
      }
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root, refetchType: 'none' });
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not update bill dates.';
      showErrorNotification(message);
    },
  });
}
