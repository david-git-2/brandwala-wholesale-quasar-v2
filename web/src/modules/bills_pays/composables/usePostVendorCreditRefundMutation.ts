import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export type PostVendorCreditRefundInput = {
  creditNoteId: number;
  parentBillId: number | null;
  amount: number;
  cashbookPointId: number;
  cashbookPointPotId?: number | null;
  receivedOn: string;
  note: string | null;
  settlementCurrencyCode?: string;
  foreignAmount?: number | null;
  exchangeRate?: number | null;
  sourceCurrencyCode?: string | null;
  transactionRate?: number | null;
};

export function usePostVendorCreditRefundMutation(billId: () => number | null) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: PostVendorCreditRefundInput) => {
      const { data, error } = await supabase.rpc('post_vendor_credit_refund', {
        p_credit_note_id: payload.creditNoteId,
        p_amount: payload.amount,
        p_cashbook_point_id: payload.cashbookPointId,
        p_received_on: payload.receivedOn,
        p_note: payload.note,
        p_settlement_currency_code: payload.settlementCurrencyCode ?? 'BDT',
        p_foreign_amount: payload.foreignAmount ?? null,
        p_exchange_rate: payload.exchangeRate ?? null,
        p_source_currency_code: payload.sourceCurrencyCode ?? null,
        p_transaction_rate: payload.transactionRate ?? null,
        p_cashbook_point_pot_id: payload.cashbookPointPotId ?? null,
      });
      if (error) throw error;
      return data;
    },
    onSuccess: (_data, payload) => {
      showSuccessNotification('Vendor refund recorded.');
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
      const ids = [billId(), payload.creditNoteId, payload.parentBillId].filter(
        (id): id is number => id != null && id > 0,
      );
      for (const id of [...new Set(ids)]) {
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.detailBundle(id) });
      }
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not record refund.');
    },
  });
}
