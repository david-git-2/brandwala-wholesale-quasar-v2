import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { paysRepository } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import type { WholesalePaymentInstrumentInput } from 'src/modules/sales_invoice/types';

export type CollectPayPayload = {
  tenantId: number;
  billingProfileId: number;
  receivedOn: string;
  note?: string | null;
  reference?: string | null;
  instruments: WholesalePaymentInstrumentInput[];
  /** Separate receipt; allocations must sum to this amount only. */
  storeCreditAllocations?: Array<{ bill_id: number; amount: number }>;
  allocations: Array<{ bill_id: number; amount: number }>;
};

export function useCollectPayMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: CollectPayPayload) => {
      const cashTotal = payload.instruments.reduce((s, i) => s + (Number(i.amount) || 0), 0);
      const allocTotal = payload.allocations.reduce((s, a) => s + a.amount, 0);
      const scTotal = (payload.storeCreditAllocations ?? []).reduce((s, a) => s + a.amount, 0);
      if (cashTotal < allocTotal) {
        throw new Error('Cash/bank total is less than cash allocations.');
      }
      const hasBank = payload.instruments.some((i) =>
        ['bank_transfer', 'bank', 'cheque'].includes((i.payment_method_code || '').toLowerCase()),
      );

      if (cashTotal > 0) {
        await paysRepository.postCustomerReceipt({
          tenant_id: payload.tenantId,
          billing_profile_id: payload.billingProfileId,
          received_on: payload.receivedOn,
          note: payload.note,
          reference: payload.reference,
          source: hasBank ? 'bank' : 'customer_cash',
          instruments: payload.instruments,
          allocations: payload.allocations,
        });
      }

      if (scTotal > 0) {
        await paysRepository.postCustomerReceipt({
          tenant_id: payload.tenantId,
          billing_profile_id: payload.billingProfileId,
          received_on: payload.receivedOn,
          note: payload.note,
          reference: payload.reference,
          source: 'store_credit',
          allocations: payload.storeCreditAllocations ?? [],
        });
      }
    },
    onSuccess: () => {
      showSuccessNotification('Payment recorded.');
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not record payment.');
    },
  });
}
