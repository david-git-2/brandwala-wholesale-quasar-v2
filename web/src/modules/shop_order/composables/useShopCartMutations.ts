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
        (oldData: any) => {
          if (!oldData) return data;
          const oldItemsMap = new Map((oldData.items ?? []).map((i: any) => [i.id, i]));
          const enrichedItems = (data.items ?? []).map((i: any) => {
            const oldItem = oldItemsMap.get(i.id) as Record<string, any> | undefined;
            const moq = oldItem?.minimum_quantity ?? oldItem?.minimum_order_quantity ?? i.minimum_quantity ?? 1;
            return {
              ...i,
              minimum_quantity: moq,
              minimum_order_quantity: moq,
            };
          });
          return {
            ...oldData,
            ...data,
            items: enrichedItems,
            permissions: oldData.permissions ?? data.permissions ?? null,
          };
        },
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

  const updateActiveCartsCache = (shopId: number, data: any) => {
    if (data && data.items && data.items.length > 0) {
      queryClient.setQueryData(
        shopOrderQueryKeys.activeCarts(tenantId.value),
        (old: any[] | undefined) => {
          if (!old) return old;
          const itemCount = data.items.reduce((sum: number, i: any) => sum + i.quantity, 0);
          const cartTotal = data.items.reduce((sum: number, i: any) => {
            const price =
              i.customer_sell_price_amount ??
              i.unit_sell_price_amount ??
              i.unit_list_price_amount ??
              0;
            return sum + price * i.quantity;
          }, 0);

          return old.map((c) => {
            if (c.shop_id === shopId) {
              return {
                ...c,
                item_count: itemCount,
                cart_total: cartTotal,
              };
            }
            return c;
          });
        },
      );
    } else {
      invalidateActiveCarts();
    }
  };

  const addItemMutation = useMutation({
    mutationFn: async (params: {
      shopId: number;
      productId: number;
      globalStockAllocationId: number | null;
      globalStockId?: number | null;
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
        params.globalStockId,
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
      updateActiveCartsCache(shopId, data);
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
      updateActiveCartsCache(shopId, data);
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
      updateActiveCartsCache(shopId, data);
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
      updateActiveCartsCache(shopId, data);
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
