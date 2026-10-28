import { ref } from 'vue';
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { createPayIdempotencyKey, paysRepository } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import type { WholesalePaymentInstrumentInput } from 'src/modules/sales_invoice/types';

export type CollectPayPayload = {
  tenantId: number;
  profileId: number;
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
  const attemptKey = ref<string | null>(null);

  return useMutation({
    onMutate: () => {
      if (!attemptKey.value) {
        attemptKey.value = createPayIdempotencyKey();
      }
    },
    mutationFn: async (payload: CollectPayPayload) => {
      const batchKey = attemptKey.value ?? createPayIdempotencyKey();
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
        await paysRepository.postMoneyIn({
          tenant_id: payload.tenantId,
          profile_id: payload.profileId,
          received_on: payload.receivedOn,
          note: payload.note,
          reference: payload.reference,
          source: hasBank ? 'bank' : 'customer_cash',
          instruments: payload.instruments,
          allocations: payload.allocations,
          idempotency_key: `${batchKey}:cash`,
        });
      }

      if (scTotal > 0) {
        await paysRepository.postMoneyIn({
          tenant_id: payload.tenantId,
          profile_id: payload.profileId,
          received_on: payload.receivedOn,
          note: payload.note,
          reference: payload.reference,
          source: 'store_credit',
          allocations: payload.storeCreditAllocations ?? [],
          idempotency_key: `${batchKey}:store_credit`,
        });
      }
    },
    onSettled: () => {
      attemptKey.value = null;
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
