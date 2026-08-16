import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export function useProcessDropshipOrderMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (orderId: number) => shopOrderRepository.processDropshipShopOrder(orderId),
    onSuccess: (res, orderId) => {
      if (res.success) {
        showSuccessNotification('Order opened for processing.');
        void queryClient.invalidateQueries({ queryKey: ['shopOrder', 'staffOrders'] });
        void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(orderId) });
      } else {
        handleApiFailure(res as any, res.error || 'Failed to process dropship order');
      }
    },
    onError: (err: any) => {
      handleApiFailure({ success: false }, err.message || 'Error processing dropship order');
    },
  });
}

export function useUpdateOrderStatusMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ orderId, status }: { orderId: number; status: string }) => {
      await shopOrderRepository.updateOrderStatus(orderId, status);
    },
    onSuccess: (_, variables) => {
      showSuccessNotification('Order status updated successfully.');
      void queryClient.invalidateQueries({ queryKey: ['shopOrder', 'staffOrders'] });
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(variables.orderId) });
    },
    onError: (err: any) => {
      handleApiFailure({ success: false }, err.message || 'Failed to update order status');
    },
  });
}

export function useSubmitStaffPricingMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      items,
      isInitialSubmission,
    }: {
      orderId: number;
      items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>;
      isInitialSubmission: boolean;
    }) => {
      if (isInitialSubmission) {
        await shopOrderRepository.staffPriceShopOrder(orderId, items);
      } else {
        await shopOrderRepository.staffCounterOffer(orderId, items);
      }
    },
    onSuccess: (_, variables) => {
      showSuccessNotification('Pricing submitted successfully.');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(variables.orderId) });
      void queryClient.invalidateQueries({ queryKey: ['shopOrder', 'staffOrders'] });
    },
    onError: (err: any) => {
      handleApiFailure({ success: false }, err.message || 'Failed to submit pricing');
    },
  });
}

export function useConfirmShopOrderMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (orderId: number) => shopOrderRepository.confirmShopOrder(orderId),
    onSuccess: (_, orderId) => {
      showSuccessNotification('Order confirmed successfully.');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(orderId) });
      void queryClient.invalidateQueries({ queryKey: ['shopOrder', 'staffOrders'] });
    },
    onError: (err: any) => {
      handleApiFailure({ success: false }, err.message || 'Failed to confirm order');
    },
  });
}

export function usePlaceOrderForProcurementMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (orderId: number) => shopOrderRepository.placeShopOrderForProcurement(orderId),
    onSuccess: (_, orderId) => {
      showSuccessNotification('Order placed for procurement.');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(orderId) });
      void queryClient.invalidateQueries({ queryKey: ['shopOrder', 'staffOrders'] });
    },
    onError: (err: any) => {
      handleApiFailure({ success: false }, err.message || 'Failed to place order for procurement');
    },
  });
}

export function useFulfillOrderToInvoiceMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (orderId: number) => shopOrderRepository.fulfillShopOrderToInvoice(orderId),
    onSuccess: (_, orderId) => {
      showSuccessNotification('Order fulfilled to invoice successfully.');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(orderId) });
      void queryClient.invalidateQueries({ queryKey: ['shopOrder', 'staffOrders'] });
    },
    onError: (err: any) => {
      handleApiFailure({ success: false }, err.message || 'Failed to fulfill order to invoice');
    },
  });
}

export function useUpdateOrderChargesMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      payload,
    }: {
      orderId: number;
      payload: {
        delivery_charge_amount: number;
        deduct_delivery_from_margin: boolean;
        cod_charge_amount: number;
        deduct_cod_from_margin: boolean;
        print_charge_amount: number;
        deduct_print_from_margin: boolean;
        packing_charge_amount: number;
        deduct_packing_from_margin: boolean;
      };
    }) => {
      await shopOrderRepository.updateOrderCharges(orderId, payload);
    },
    onSuccess: (_, variables) => {
      showSuccessNotification('Order charges updated successfully.');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(variables.orderId) });
    },
    onError: (err: any) => {
      handleApiFailure({ success: false }, err.message || 'Failed to update order charges');
    },
  });
}

export function useDeleteShopOrderMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (orderId: number) => shopOrderRepository.deleteShopOrder(orderId),
    onSuccess: (_, orderId) => {
      showSuccessNotification('Order deleted successfully.');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(orderId) });
      void queryClient.invalidateQueries({ queryKey: ['shopOrder', 'staffOrders'] });
    },
    onError: (err: any) => {
      handleApiFailure({ success: false }, err.message || 'Failed to delete order');
    },
  });
}

