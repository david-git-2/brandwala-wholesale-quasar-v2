import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  invoiceRepository,
  type SalesInvoiceFromPayloadInput,
  type SalesInvoiceUpdatePayloadInput,
} from 'src/modules/sales_invoice/repositories/invoiceRepository';
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
        const result = await invoiceRepository.updateSalesInvoiceFromPayload(
          tenantId,
          invoiceId,
          updatePayload,
        );
        if (issue) {
          await invoiceRepository.postGlobalInvoice(invoiceId);
        }
        return { ...result, invoice_id: invoiceId };
      }

      return invoiceRepository.createSalesInvoiceFromPayload(tenantId, {
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
