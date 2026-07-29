import { type Ref } from 'vue';
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import { shopOrderQueryKeys } from '../services/shopOrderQueryKeys';
import { showSuccessNotification, showErrorNotification, parseSupabaseError } from 'src/utils/appFeedback';

export type ReturnCondition = 'perfect' | 'open_box' | 'damaged';

export interface FinalizeReturnPayload {
  orderId: number;
  items: Array<{
    order_item_id: number;
    returned_qty: number;
    condition: ReturnCondition;
  }>;
  actualReturnCharge?: number;
  deductFromMiddleman?: boolean;
  overrideReason?: string | null;
  reason?: string | null;
  returnRef?: string;
}

export function useDropshipReturnMutations(tenantSlug?: Ref<string | null>) {
  const queryClient = useQueryClient();

  const invalidateReturnQueries = async (orderId: number) => {
    const slug = tenantSlug?.value ?? null;
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.detail(slug, orderId) }),
      queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.ledger(slug) }),
      queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.financeHub(slug) }),
    ]);
  };

  const finalizeReturnMutation = useMutation({
    mutationFn: async (payload: FinalizeReturnPayload) => {
      const returnRef =
        payload.returnRef ?? `RET-${payload.orderId}-${Date.now()}`;

      const { data, error } = await supabase.rpc('finalize_dropship_return', {
        p_order_id: payload.orderId,
        p_items: payload.items,
        p_actual_return_charge: payload.actualReturnCharge ?? 0,
        p_deduct_from_middle_man: payload.deductFromMiddleman ?? true,
        p_override_reason: payload.overrideReason ?? payload.reason ?? null,
        p_return_ref: returnRef,
      });

      if (error) throw error;
      if (data && typeof data === 'object' && (data as { success?: boolean }).success === false) {
        throw new Error(
          (data as { error?: string }).error || 'Failed to finalize order return',
        );
      }
      return data;
    },
    onSuccess: async (_, variables) => {
      showSuccessNotification('Order return finalized successfully.');
      await invalidateReturnQueries(variables.orderId);
    },
    onError: (error: unknown) => {
      showErrorNotification(parseSupabaseError(error, 'Failed to finalize order return'));
    },
  });

  return {
    finalizeReturnMutation,
  };
}
