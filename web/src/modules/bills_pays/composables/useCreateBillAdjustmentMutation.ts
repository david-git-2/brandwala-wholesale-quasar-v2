import { useMutation, useQueryClient } from '@tanstack/vue-query';
import type { Database } from 'src/types/database.types';
import type { Json } from 'src/types/database.types';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import type { BillAdjustmentRpcLine } from '../utils/billAdjustmentParentLines';
import { moneyKernelRepository } from '../repositories/moneyKernelRepository';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

export type CreateBillAdjustmentInput = {
  parentBillId: number;
  tenantId: number;
  kind: Database['public']['Enums']['bill_document_kind'];
  amount: number;
  reason: string;
  lines?: BillAdjustmentRpcLine[];
  refundAmount?: number | null;
  cashbookPointId?: number | null;
};

export function useCreateBillAdjustmentMutation(parentBillId: () => number | null) {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();

  return useMutation({
    mutationFn: async (payload: CreateBillAdjustmentInput) => {
      const tenantId =
        payload.tenantId
        ?? authStore.selectedTenant?.parent_tenant_id
        ?? authStore.selectedTenant?.id
        ?? 0;
      if (!tenantId) throw new Error('Tenant not ready.');

      const kind = payload.kind === 'debit_note' ? 'debit_note' : 'credit_note';
      const rpcLines =
        payload.lines?.length
          ? payload.lines.map((line) => ({
              item_kind: line.line_kind ?? 'charge',
              description: line.name_snapshot,
              quantity: line.quantity,
              unit_price: line.line_total_amount / Math.max(line.quantity, 1),
              line_total: line.line_total_amount,
              meta: {
                currency_code: line.currency_code,
                books_amount: line.books_amount,
                parent_line_id: line.parent_line_id,
                global_stock_id: line.global_stock_id,
              },
            }))
          : [
              {
                item_kind: 'charge',
                description: payload.reason,
                quantity: 1,
                unit_price: payload.amount,
                line_total: payload.amount,
              },
            ];

      const body = {
        tenant_id: tenantId,
        kind,
        parent_bill_id: payload.parentBillId,
        note: payload.reason,
        auto_issue: true,
        meta: { reason: payload.reason },
        lines: rpcLines,
      } as Json;

      const created = await moneyKernelRepository.createBill(body);
      if (!created.bill_id) {
        throw new Error(created.error ?? 'Could not create credit/debit note.');
      }
      if (created.status !== 'issued') {
        await moneyKernelRepository.issueBill(tenantId, created.bill_id);
      }
      return created;
    },
    onSuccess: () => {
      const id = parentBillId();
      showSuccessNotification('Credit/debit note issued.');
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
      const message =
        error instanceof Error ? error.message : 'Could not create credit/debit note.';
      showErrorNotification(message);
    },
  });
}
