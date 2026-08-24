import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { showSuccessNotification, handleApiFailure } from 'src/utils/appFeedback';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { applyStaffOrderDetailToCache } from '../utils/staffOrderDetailCacheUtils';

function patchStaffOrderDetailCache(
  queryClient: ReturnType<typeof useQueryClient>,
  orderId: number,
  data: Awaited<ReturnType<typeof shopOrderRepository.staffPriceShopOrder>> | undefined,
) {
  const tenantId = useAuthStore().tenantId;
  if (tenantId && data) {
    applyStaffOrderDetailToCache(queryClient, tenantId, orderId, data);
  }
}

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
        first_offer_rate?: number | null;
        final_offer_rate?: number | null;
        profit_basis?: 'purchase' | 'total_cost' | null;
      };
    }) => {
      const tenantId = useAuthStore().tenantId;
      if (!tenantId) throw new Error('Tenant context required.');
      return shopOrderRepository.updateCatalogOrderRates(tenantId, orderId, payload);
    },
    onSuccess: (data, variables) => {
      showSuccessNotification('Order calculation rates updated');
      patchStaffOrderDetailCache(queryClient, variables.orderId, data);
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
        weight_kg?: number | null;
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
      return shopOrderRepository.staffPriceShopOrder(
        orderId,
        items as any,
        profitBasis,
        rates,
      );
    },
    onSuccess: (data, variables) => {
      patchStaffOrderDetailCache(queryClient, variables.orderId, data);
      showSuccessNotification('Costing and staff offer prices saved (Priced)');
      void queryClient.invalidateQueries({ queryKey: ['shopOrder', 'staffOrders'] });
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
    }) => shopOrderRepository.staffFinalizeCatalogPrices(orderId, items),
    onSuccess: (data, variables) => {
      patchStaffOrderDetailCache(queryClient, variables.orderId, data);
      showSuccessNotification('Final offer prices sent to customer');
    },
    onError: (err: any) => {
      handleApiFailure(err, 'Failed to finalize offer prices');
    },
  });
}

export function useStaffStartCatalogProcurementMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (orderId: number) => shopOrderRepository.staffStartCatalogProcurement(orderId),
    onSuccess: (data, orderId) => {
      patchStaffOrderDetailCache(queryClient, orderId, data);
      showSuccessNotification('Order status updated to Procuring');
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
    }) => shopOrderRepository.staffSetCatalogOrderedQty(orderId, items),
    onSuccess: (data, variables) => {
      patchStaffOrderDetailCache(queryClient, variables.orderId, data);
      showSuccessNotification('Order marked ready for shipment');
    },
    onError: (err: any) => {
      handleApiFailure(err, 'Failed to mark order ready for shipment');
    },
  });
}

export function useStaffSetCatalogDeliveredQtyMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ orderId }: { orderId: number }) =>
      shopOrderRepository.staffSetCatalogDeliveredQty(orderId),
    onSuccess: (data, variables) => {
      patchStaffOrderDetailCache(queryClient, variables.orderId, data);
      showSuccessNotification('Order marked delivered');
    },
    onError: (err: any) => {
      handleApiFailure(err, 'Failed to mark order delivered');
    },
  });
}

export function useUpdateCatalogOrderItemMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      tenantId,
      orderId,
      itemId,
      productId,
      payload,
    }: {
      tenantId?: number | null;
      orderId: number;
      itemId: number;
      productId: number | null;
      payload: {
        product_weight_gm?: number | null;
        package_weight_gm?: number | null;
        weight_kg?: number | null;
        cost_price_amount?: number | null;
        staff_offer_amount?: number | null;
        is_first_offer_manual?: boolean | null;
        final_price_amount?: number | null;
        is_final_offer_manual?: boolean | null;
        customer_offer_amount?: number | null;
        customer_offer_currency_id?: number | null;
        confirmed_quantity?: number | null;
        quantity?: number | null;
      };
    }) => {
      if (tenantId) {
        return shopOrderRepository.updateCatalogOrderItemForStaff(
          tenantId,
          orderId,
          itemId,
          payload,
        );
      }
      await shopOrderRepository.updateCatalogOrderItem(orderId, itemId, productId, payload);
      return null;
    },
    onSuccess: (data, variables) => {
      if (variables.tenantId && data) {
        applyStaffOrderDetailToCache(
          queryClient,
          variables.tenantId,
          variables.orderId,
          data,
        );
      }
    },
    onError: (err: any) => {
      handleApiFailure(err, 'Failed to update item');
    },
  });
}
