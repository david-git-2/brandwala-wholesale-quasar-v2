import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { handleApiFailure, parseSupabaseError, showSuccessNotification } from 'src/utils/appFeedback';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import {
  shopOrderRepository,
  type FinalizeDropshipResellDiscountLineInput,
} from '../repositories/shopOrderRepository';
import { useDropshipOrderDetailV2Store } from '../stores/dropshipOrderDetailV2Store';
import { applyStaffOrderDetailToCache } from '../utils/staffOrderDetailCacheUtils';

export function useFinalizeDropshipResellDiscountReviewMutation() {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);

  return useMutation({
    mutationFn: async (payload: {
      orderId: number;
      lines: FinalizeDropshipResellDiscountLineInput[];
    }) => {
      const data = await shopOrderRepository.finalizeDropshipResellDiscountReview(
        tenantId.value,
        payload.orderId,
        payload.lines,
      );
      return { raw: data, orderId: payload.orderId };
    },
    onSuccess: async ({ raw, orderId }) => {
      applyStaffOrderDetailToCache(queryClient, tenantId.value, orderId, raw);
      if (tenantId.value > 0) {
        await useDropshipOrderDetailV2Store().ensureDetail(tenantId.value, orderId, true);
      }
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.orderDetail(tenantId.value, orderId),
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.staffOrdersPageRoot(),
      });
      showSuccessNotification('Order confirmed after discount review.');
    },
    onError: (err) => {
      const raw = parseSupabaseError(err, 'Failed to confirm order');
      const message = /price floor violation/i.test(raw)
        ? 'Approved resell cannot be below the minimum when keeping listed price. Use accept requested or adjust instead.'
        : raw;
      handleApiFailure(err, message);
    },
  });
}