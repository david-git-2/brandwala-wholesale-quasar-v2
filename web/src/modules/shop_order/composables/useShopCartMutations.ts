import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopCartService } from '../services/shopCartService';
import type { CartChargesPayload } from '../repositories/shopCartRepository';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

export function useShopCartMutations() {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);

  const updateCartCache = (shopId: number, data: any) => {
    if (data) {
      queryClient.setQueryData(
        shopOrderQueryKeys.cart(tenantId.value, shopId),
        data,
      );
    } else {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.cart(tenantId.value, shopId),
      });
    }
  };

  const invalidateActiveCarts = () => {
    void queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.activeCarts(tenantId.value),
    });
  };

  const addItemMutation = useMutation({
    mutationFn: async (params: {
      shopId: number;
      productId: number;
      globalStockAllocationId: number | null;
      quantity: number;
      customerSellPriceAmount?: number | null;
      customerSellPriceCurrencyId?: number | null;
    }) => {
      const res = await shopCartService.addToCart(
        params.shopId,
        params.productId,
        params.globalStockAllocationId,
        params.quantity,
        params.customerSellPriceAmount,
        params.customerSellPriceCurrencyId,
      );
      if (!res.success) {
        handleApiFailure(res, res.error);
        throw new Error(res.error || 'Failed to add item to cart');
      }
      return { data: res.data, shopId: params.shopId };
    },
    onSuccess: ({ data, shopId }) => {
      updateCartCache(shopId, data);
      invalidateActiveCarts();
      showSuccessNotification('Item added to cart.');
    },
  });

  const updateQtyMutation = useMutation({
    mutationFn: async (params: { cartItemId: number; quantity: number; shopId: number }) => {
      const res = await shopCartService.updateCartItemQty(params.cartItemId, params.quantity);
      if (!res.success) {
        handleApiFailure(res, res.error);
        throw new Error(res.error || 'Failed to update item quantity');
      }
      return { data: res.data, shopId: params.shopId };
    },
    onSuccess: ({ data, shopId }) => {
      updateCartCache(shopId, data);
      invalidateActiveCarts();
    },
  });

  const removeItemMutation = useMutation({
    mutationFn: async (params: { cartItemId: number; shopId: number }) => {
      const res = await shopCartService.removeCartItem(params.cartItemId);
      if (!res.success) {
        handleApiFailure(res, res.error);
        throw new Error(res.error || 'Failed to remove item from cart');
      }
      return { data: res.data, shopId: params.shopId };
    },
    onSuccess: ({ data, shopId }) => {
      updateCartCache(shopId, data);
      invalidateActiveCarts();
      showSuccessNotification('Item removed from cart.');
    },
  });


  const updatePriceMutation = useMutation({
    mutationFn: async (params: { cartItemId: number; price: number; shopId: number }) => {
      const res = await shopCartService.updateCartItemPrice(params.cartItemId, params.price);
      if (!res.success) {
        handleApiFailure(res, res.error);
        throw new Error(res.error || 'Failed to update price');
      }
      return { data: res.data, shopId: params.shopId };
    },
    onSuccess: ({ data, shopId }) => {
      updateCartCache(shopId, data);
      invalidateActiveCarts();
    },
  });

  const updateChargesMutation = useMutation({
    mutationFn: async (params: {
      shopId: number;
      cartId: number;
      charges: CartChargesPayload;
    }) => {
      const res = await shopCartService.updateShopCartCharges(
        params.shopId,
        params.cartId,
        params.charges,
      );
      if (!res.success) {
        handleApiFailure(res, res.error);
        throw new Error(res.error || 'Failed to update cart charges');
      }
      return { data: res.data, shopId: params.shopId };
    },
    onSuccess: ({ data, shopId }) => {
      updateCartCache(shopId, data);
      invalidateActiveCarts();
    },
  });


  return {
    addItemMutation,
    updateQtyMutation,
    removeItemMutation,
    updatePriceMutation,
    updateChargesMutation,
  };
}
