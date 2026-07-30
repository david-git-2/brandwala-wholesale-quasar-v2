import { useQuery, useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';

export function useShopOrderDetailQuery(orderId: Ref<number>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.orderDetail(orderId.value)),
    queryFn: () => shopOrderRepository.getShopOrderById(orderId.value),
    enabled: computed(() => orderId.value > 0),
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
        queryKey: shopOrderQueryKeys.orderDetail(variables.orderId),
      });
      showSuccessNotification('Counter offer submitted successfully.');
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
        queryKey: shopOrderQueryKeys.orderDetail(orderId),
      });
      showSuccessNotification('Order confirmed successfully!');
    },
    onError: (error: Error) => {
      showWarningDialog(error.message || 'Failed to confirm order.', 'Action Failed');
    },
  });
}

