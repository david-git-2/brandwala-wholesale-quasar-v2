import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { dropshipCartService } from '../services/dropshipCartService';
import type { SubmitDropshipOrderPayload } from '../repositories/dropshipCartRepository';

export function useSubmitDropshipOrderMutation() {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);

  const mutation = useMutation({
    mutationFn: async (payload: SubmitDropshipOrderPayload) => {
      const res = await dropshipCartService.submitDropshipOrderFromCart(payload);
      if (!res.success) {
        handleApiFailure(res, res.error);
        throw new Error(res.error || 'Failed to place dropship order');
      }
      return { data: res.data, shopId: payload.shopId };
    },
    onSuccess: ({ shopId }) => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.dropshipCart(tenantId.value, shopId),
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.dropshipReviewCart(tenantId.value, shopId),
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.activeCarts(tenantId.value),
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.cart(tenantId.value, shopId),
      });
      showSuccessNotification('Order placed successfully.');
    },
  });

  return mutation;
}
