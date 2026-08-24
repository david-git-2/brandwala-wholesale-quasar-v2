import { useQuery, useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

export function useShopOrderDetailQuery(orderId: Ref<number>) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? null);
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.orderDetail(tenantId.value, orderId.value)),
    queryFn: () => shopOrderRepository.getShopOrderById(tenantId.value!, orderId.value),
    enabled: computed(() => !!tenantId.value && orderId.value > 0),
    staleTime: 15 * 1000,
  });
}

export function useCustomerShopOrderDetailQuery(orderId: Ref<number>) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.orderDetail(tenantId.value, orderId.value)),
    queryFn: () => shopOrderRepository.getCustomerShopOrder(tenantId.value, orderId.value),
    enabled: computed(() => tenantId.value > 0 && orderId.value > 0),
    staleTime: 15 * 1000,
  });
}

export function useSendCustomerCounterMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      items,
    }: {
      orderId: number;
      items: Array<{ id: number; customer_offer_amount: number; customer_offer_currency_id: number }>;
    }) => {
      await shopOrderRepository.customerCounterOffer(orderId, items);
    },
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.orderDetailRoot(),
      });
      showSuccessNotification('Your response was sent.');
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to submit counter offer.', 'Action Failed');
    },
  });
}

export function useCustomerConfirmOrderMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (orderId: number) => {
      await shopOrderRepository.customerConfirmShopOrder(orderId);
    },
    onSuccess: (_, orderId) => {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.orderDetailRoot(),
      });
      showSuccessNotification('Order confirmed successfully!');
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to confirm order.', 'Action Failed');
    },
  });
}

