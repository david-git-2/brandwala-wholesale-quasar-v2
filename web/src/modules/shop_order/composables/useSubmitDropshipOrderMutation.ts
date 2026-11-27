import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { dropshipCartService } from '../services/dropshipCartService';
import type { SubmitDropshipOrderPayload } from '../repositories/dropshipCartRepository';

export function useSubmitDropshipOrderMutation() {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const { t } = useI18n();
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
    onSuccess: ({ data, shopId }) => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.dropshipCart(tenantId.value, shopId),
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.activeCarts(tenantId.value),
      });
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.cart(tenantId.value, shopId),
      });
      const message =
        data.status === 'resell_discount_requested'
          ? t('shop.dropship_order_submitted_discount_review')
          : t('shop.dropship_order_placed_success');
      showSuccessNotification(message);
    },
  });

  return mutation;
}
