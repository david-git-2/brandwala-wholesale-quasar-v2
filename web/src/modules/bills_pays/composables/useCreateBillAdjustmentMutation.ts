import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import type { Database } from 'src/types/database.types';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import type { BillAdjustmentRpcLine } from '../utils/billAdjustmentParentLines';

export type CreateBillAdjustmentInput = {
  parentBillId: number;
  kind: Database['public']['Enums']['bill_document_kind'];
  amount: number;
  reason: string;
  lines?: BillAdjustmentRpcLine[];
  refundAmount?: number | null;
  cashbookPointId?: number | null;
};

export function useCreateBillAdjustmentMutation(parentBillId: () => number | null) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: CreateBillAdjustmentInput) => {
      const baseArgs = {
        p_parent_bill_id: payload.parentBillId,
        p_kind: payload.kind,
        p_amount: payload.amount,
        p_reason: payload.reason,
        p_issue: true,
      };

      const refund =
        payload.refundAmount != null && payload.refundAmount > 0 ? payload.refundAmount : null;
      const rpcLines =
        payload.lines?.length
          ? payload.lines.map((line) => ({
              line_kind: line.line_kind,
              name_snapshot: line.name_snapshot,
              quantity: line.quantity,
              currency_code: line.currency_code,
              line_total_amount: line.line_total_amount,
              books_amount: line.books_amount,
              ...(line.parent_line_id != null
                ? { parent_line_id: String(line.parent_line_id) }
                : {}),
              ...(line.global_stock_id != null
                ? { global_stock_id: String(line.global_stock_id) }
                : {}),
            }))
          : null;

      const extendedArgs =
        rpcLines?.length || refund != null
          ? {
              ...baseArgs,
              ...(refund != null
                ? {
                    p_refund_amount: refund,
                    p_cashbook_point_id: payload.cashbookPointId ?? null,
                  }
                : {}),
              ...(rpcLines?.length ? { p_lines: rpcLines } : {}),
            }
          : null;

      const isMissingRpc = (err: { code?: string; message?: string } | null) =>
        err?.code === 'PGRST202' ||
        (err?.message ?? '').includes('Could not find the function public.create_bill_adjustment');

      if (extendedArgs) {
        const { data, error } = await supabase.rpc('create_bill_adjustment', extendedArgs);
        if (!error) return data;
        if (!isMissingRpc(error)) throw error;
      }

      const { data, error } = await supabase.rpc('create_bill_adjustment', baseArgs);
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      const id = parentBillId();
      showSuccessNotification('Credit/debit note issued.');
      void queryClient.invalidateQueries({ queryKey: billsQueryKeys.root });
      void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
      if (id) {
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.detail(id) });
        void queryClient.invalidateQueries({
          queryKey: [...billsQueryKeys.detail(id), 'net-balances'],
        });
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.adjustments(id) });
        void queryClient.invalidateQueries({ queryKey: billsQueryKeys.paymentHistory(id) });
        void queryClient.invalidateQueries({
          queryKey: [...billsQueryKeys.detail(id), 'bill-lines'],
        });
      }
    },
    onError: (error: unknown) => {
      const message =
        error instanceof Error ? error.message : 'Could not create credit/debit note.';
      showErrorNotification(message);
    },
  });
}
