import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { showSuccessNotification, handleApiFailure } from 'src/utils/appFeedback';

export function useSaveCatalogRatesMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      payload,
    }: {
      orderId: number;
      payload: {
        conversion_rate?: number | null;
        cargo_rate?: number | null;
        profit_rate?: number | null;
        profit_basis?: 'purchase' | 'total_cost' | null;
      };
    }) => {
      await shopOrderRepository.updateCatalogOrderRates(orderId, payload);
    },
    onSuccess: (_, variables) => {
      showSuccessNotification('Order calculation rates updated');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(variables.orderId) });
    },
    onError: (err: any) => {
      handleApiFailure(err, 'Failed to update order rates');
    },
  });
}

export function useStaffPriceCatalogOrderMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      items,
      profitBasis,
      rates,
    }: {
      orderId: number;
      items: Array<{
        id: number;
        staff_offer_amount: number;
        staff_offer_currency_id: number;
        gross_weight_kg?: number | null;
        cost_price_amount?: number | null;
        product_weight_gm?: number | null;
        package_weight_gm?: number | null;
      }>;
      profitBasis?: string | null;
      rates?: {
        conversion_rate?: number | null;
        cargo_rate?: number | null;
        profit_rate?: number | null;
      };
    }) => {
      if (rates) {
        await shopOrderRepository.updateCatalogOrderRates(orderId, {
          ...rates,
          profit_basis: (profitBasis as any) || undefined,
        });
      }
      await shopOrderRepository.staffPriceShopOrder(orderId, items as any, profitBasis);
    },
    onSuccess: (_, variables) => {
      showSuccessNotification('Costing and staff offer prices saved (Priced)');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(variables.orderId) });
    },
    onError: (err: any) => {
      handleApiFailure(err, 'Failed to save staff pricing');
    },
  });
}

export function useStaffFinalizeCatalogPricesMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      items,
    }: {
      orderId: number;
      items: Array<{
        id: number;
        final_offer_amount: number;
        final_offer_currency_id: number;
      }>;
    }) => {
      await shopOrderRepository.staffFinalizeCatalogPrices(orderId, items);
    },
    onSuccess: (_, variables) => {
      showSuccessNotification('Final offer prices sent to customer');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(variables.orderId) });
    },
    onError: (err: any) => {
      handleApiFailure(err, 'Failed to finalize offer prices');
    },
  });
}

export function useStaffStartCatalogProcurementMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (orderId: number) => {
      await shopOrderRepository.staffStartCatalogProcurement(orderId);
    },
    onSuccess: (_, orderId) => {
      showSuccessNotification('Order status updated to Procuring');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(orderId) });
    },
    onError: (err: any) => {
      handleApiFailure(err, 'Failed to start procurement');
    },
  });
}

export function useStaffSetCatalogOrderedQtyMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      items,
    }: {
      orderId: number;
      items: Array<{ id: number; ordered_quantity: number }>;
    }) => {
      await shopOrderRepository.staffSetCatalogOrderedQty(orderId, items);
    },
    onSuccess: (_, variables) => {
      showSuccessNotification('Ordered quantities saved (Ordered)');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(variables.orderId) });
    },
    onError: (err: any) => {
      handleApiFailure(err, 'Failed to save ordered quantities');
    },
  });
}

export function useStaffSetCatalogDeliveredQtyMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      items,
    }: {
      orderId: number;
      items: Array<{ id: number; delivered_quantity: number }>;
    }) => {
      await shopOrderRepository.staffSetCatalogDeliveredQty(orderId, items);
    },
    onSuccess: (_, variables) => {
      showSuccessNotification('Delivered quantities saved (Delivered)');
      void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.orderDetail(variables.orderId) });
    },
    onError: (err: any) => {
      handleApiFailure(err, 'Failed to save delivered quantities');
    },
  });
}

export function useUpdateCatalogOrderItemMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      orderId,
      itemId,
      productId,
      payload,
    }: {
      orderId: number;
      itemId: number;
      productId: number | null;
      payload: {
        product_weight_gm?: number | null;
        package_weight_gm?: number | null;
        weight_kg?: number | null;
        cost_price_amount?: number | null;
        staff_offer_amount?: number | null;
        final_price_amount?: number | null;
        ordered_quantity?: number | null;
        delivered_quantity?: number | null;
      };
    }) => {
      await shopOrderRepository.updateCatalogOrderItem(orderId, itemId, productId, payload);
    },
    onSuccess: () => {
      showSuccessNotification('Item updated successfully');
    },
    onError: (err: any) => {
      handleApiFailure(err, 'Failed to update item');
    },
  });
}

