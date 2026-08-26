import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopCartService } from '../services/shopCartService';
import type {
  ActiveCartItem,
  ActiveCartShopMeta,
  CartChargesPayload,
} from '../repositories/shopCartRepository';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { resolveShopCartItemMoq } from '../utils/cartQuantityUtils';
import { sumCartSubtotal } from '../utils/cartPriceUtils';
import {
  mergeDropshipCartFromCatalogResponse,
} from '../utils/dropshipCartCacheUtils';
import type { DropshipCartData } from '../repositories/dropshipCartRepository';
import type { ShopType } from '../types';

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
          const shopType = data.cart?.shop_type ?? oldData.cart?.shop_type;
          const enrichedItems = (data.items ?? []).map((i: any) => {
            const oldItem = oldItemsMap.get(i.id) as Record<string, any> | undefined;
            const moq = resolveShopCartItemMoq(
              { ...oldItem, ...i },
              { dropship: shopType === 'dropship' },
            );
            return {
              ...i,
              minimum_quantity: moq,
              minimum_order_quantity: moq,
            };
          });
          return {
            ...oldData,
            ...data,
            permissions: data.permissions ?? oldData.permissions,
            items: enrichedItems,
          };
        },
      );
    } else {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.cart(tenantId.value, shopId),
      });
    }
  };

  const patchDropshipCartCache = (shopId: number, data: any): DropshipCartData | null => {
    let merged: DropshipCartData | null = null;
    queryClient.setQueryData(
      shopOrderQueryKeys.dropshipCart(tenantId.value, shopId),
      (old: DropshipCartData | null | undefined) => {
        merged = mergeDropshipCartFromCatalogResponse(old, data);
        return merged ?? old ?? null;
      },
    );
    return merged;
  };

  const updateDropshipActiveCartsCache = (shopId: number, dropshipData: DropshipCartData | null) => {
    if (!dropshipData) return;

    const itemCount = dropshipData.totals.item_count;
    const cartTotal = dropshipData.totals.purchase_subtotal;

    queryClient.setQueryData(
      shopOrderQueryKeys.activeCarts(tenantId.value),
      (old: ActiveCartItem[] | undefined) => {
        if (!old) return old;
        return old.map((c) =>
          c.shop_id === shopId ? { ...c, item_count: itemCount, cart_total: cartTotal } : c,
        );
      },
    );
  };

  const invalidateActiveCarts = () => {
    void queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.activeCarts(tenantId.value),
    });
  };

  const buildActiveCartEntry = (
    shopId: number,
    data: any,
    shopMeta: ActiveCartShopMeta,
  ): ActiveCartItem => {
    const itemCount = data.items.reduce((sum: number, i: any) => sum + i.quantity, 0);
    const shopType = data.cart?.shop_type as ShopType;
    const cartTotal = sumCartSubtotal(shopType, data.items);

    return {
      cart_id: data.cart.id,
      shop_id: shopId,
      shop_name: shopMeta.shop_name,
      shop_slug: shopMeta.shop_slug,
      shop_logo_url: shopMeta.shop_logo_url,
      shop_type: shopType,
      can_see_buy_price: Boolean(
        data.cart?.can_see_buy_price_snapshot ?? data.permissions?.can_see_buy_price,
      ),
      can_see_sell_price: Boolean(
        data.cart?.can_see_sell_price_snapshot ?? data.permissions?.can_see_sell_price,
      ),
      currency_id: shopMeta.currency_id,
      currency_code: shopMeta.currency_code,
      currency_symbol: shopMeta.currency_symbol,
      item_count: itemCount,
      cart_total: cartTotal,
      updated_at: data.cart?.updated_at ?? new Date().toISOString(),
    };
  };

  const updateActiveCartsCache = (shopId: number, data: any, shopMeta?: ActiveCartShopMeta) => {
    if (data?.items?.length > 0) {
      const itemCount = data.items.reduce((sum: number, i: any) => sum + i.quantity, 0);
      const shopType = data.cart?.shop_type as ShopType | undefined;
      const cartTotal = sumCartSubtotal(shopType, data.items);

      queryClient.setQueryData(
        shopOrderQueryKeys.activeCarts(tenantId.value),
        (old: ActiveCartItem[] | undefined) => {
          if (!old) {
            return shopMeta ? [buildActiveCartEntry(shopId, data, shopMeta)] : old;
          }

          const hasShop = old.some((c) => c.shop_id === shopId);
          if (hasShop) {
            return old.map((c) =>
              c.shop_id === shopId ? { ...c, item_count: itemCount, cart_total: cartTotal } : c,
            );
          }

          if (shopMeta) {
            return [buildActiveCartEntry(shopId, data, shopMeta), ...old];
          }

          invalidateActiveCarts();
          return old;
        },
      );
      return;
    }

    queryClient.setQueryData(
      shopOrderQueryKeys.activeCarts(tenantId.value),
      (old: ActiveCartItem[] | undefined) => {
        if (!old) return old;
        return old.filter((c) => c.shop_id !== shopId);
      },
    );
  };

  const syncCartCachesAfterMutation = (
    shopId: number,
    data: any,
    shopMeta?: ActiveCartShopMeta,
  ) => {
    updateCartCache(shopId, data);
    const dropshipData = patchDropshipCartCache(shopId, data);
    if (dropshipData) {
      updateDropshipActiveCartsCache(shopId, dropshipData);
      return;
    }
    updateActiveCartsCache(shopId, data, shopMeta);
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
      shopMeta?: ActiveCartShopMeta;
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
      return { data: res.data, shopId: params.shopId, shopMeta: params.shopMeta };
    },
    onSuccess: ({ data, shopId, shopMeta }) => {
      syncCartCachesAfterMutation(shopId, data, shopMeta);
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
      syncCartCachesAfterMutation(shopId, data);
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
      syncCartCachesAfterMutation(shopId, data);
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
