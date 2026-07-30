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
