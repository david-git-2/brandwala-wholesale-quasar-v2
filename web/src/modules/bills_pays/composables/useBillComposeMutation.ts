import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  billsRepository,
  type SalesInvoiceFromPayloadInput,
  type SalesInvoiceUpdatePayloadInput,
} from '../repositories/billsRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export type BillComposeSaveArgs = {
  tenantId: number;
  invoiceId: number | null;
  payload: SalesInvoiceFromPayloadInput;
  removeItemIds?: number[];
  issue: boolean;
};

export function useBillComposeMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (args: BillComposeSaveArgs) => {
      const { tenantId, invoiceId, payload, removeItemIds, issue } = args;

      if (invoiceId) {
        const updatePayload: SalesInvoiceUpdatePayloadInput = {
          invoice: payload.invoice,
          items: payload.items,
          remove_item_ids: removeItemIds?.length ? removeItemIds : undefined,
        };
        const result = await billsRepository.updateDraftBill(tenantId, invoiceId, updatePayload);
        if (issue) {
          await billsRepository.issueBill(invoiceId, {
            invoiceType: payload.invoice.invoice_type,
            stockItems: payload.items
              .filter((i) => i.global_stock_id != null && i.global_stock_id > 0)
              .map((i) => ({
                id: i.id,
                global_stock_id: i.global_stock_id!,
                quantity: i.quantity,
                sell_price_amount: i.sell_price_amount,
              })),
          });
        }
        return { ...result, invoice_id: invoiceId };
      }

      return billsRepository.upsertDraftBill(tenantId, {
        ...payload,
        issue,
      });
    },
    onSuccess: (result, variables) => {
      const id = result.invoice_id ?? variables.invoiceId;
      showSuccessNotification(variables.issue ? 'Bill issued.' : 'Draft saved.');
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
      if (id) {
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.detail(id) });
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.items(id) });
      }
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Could not save bill.';
      showErrorNotification(message);
    },
  });
}
