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
  mergeDropshipReviewFromCatalogResponse,
  patchDropshipItemResellPrice,
} from '../utils/dropshipCartCacheUtils';
import type { DropshipCartData, DropshipReviewCartData } from '../repositories/dropshipCartRepository';
import type { ShopType } from '../types';

export function useShopCartMutations() {
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);

  const resolveShopMetaForCache = (
    shopId: number,
    shopMeta?: ActiveCartShopMeta,
  ): ActiveCartShopMeta | undefined => {
    if (shopMeta) return shopMeta;

    const active = queryClient.getQueryData<ActiveCartItem[]>(
      shopOrderQueryKeys.activeCarts(tenantId.value),
    );
    const match = active?.find((cart) => cart.shop_id === shopId);
    if (!match) return undefined;

    return {
      shop_name: match.shop_name,
      shop_slug: match.shop_slug,
      shop_logo_url: match.shop_logo_url,
      currency_id: match.currency_id,
      currency_code: match.currency_code,
      currency_symbol: match.currency_symbol,
    };
  };

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
            const moq = resolveShopCartItemMoq({ ...oldItem, ...i }, shopType);
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
            currency: data.currency ?? oldData.currency,
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

  const patchDropshipReviewCartCache = (
    shopId: number,
    data: any,
    shopMeta?: ActiveCartShopMeta,
  ): DropshipReviewCartData | null => {
    let merged: DropshipReviewCartData | null = null;
    queryClient.setQueryData(
      shopOrderQueryKeys.dropshipReviewCart(tenantId.value, shopId),
      (old: DropshipReviewCartData | null | undefined) => {
        merged = mergeDropshipReviewFromCatalogResponse(
          old,
          data,
          resolveShopMetaForCache(shopId, shopMeta),
        );
        return merged ?? old ?? null;
      },
    );
    return merged;
  };

  const patchDropshipCartCache = (
    shopId: number,
    data: any,
    shopMeta?: ActiveCartShopMeta,
  ): DropshipCartData | null => {
    const resolvedMeta = resolveShopMetaForCache(shopId, shopMeta);
    let merged: DropshipCartData | null = null;
    queryClient.setQueryData(
      shopOrderQueryKeys.dropshipCart(tenantId.value, shopId),
      (old: DropshipCartData | null | undefined) => {
        merged = mergeDropshipCartFromCatalogResponse(old, data, resolvedMeta);
        return merged ?? old ?? null;
      },
    );
    return merged;
  };

  const updateDropshipActiveCartsCache = (
    shopId: number,
    dropshipData: DropshipCartData | null,
    shopMeta?: ActiveCartShopMeta,
  ) => {
    if (!dropshipData) return;

    const itemCount = dropshipData.totals.item_count;
    const cartTotal = dropshipData.totals.purchase_subtotal;
    const resolvedMeta = resolveShopMetaForCache(shopId, shopMeta);

    queryClient.setQueryData(
      shopOrderQueryKeys.activeCarts(tenantId.value),
      (old: ActiveCartItem[] | undefined) => {
        if (!old) {
          if (!resolvedMeta) return old;
          return [
            {
              cart_id: dropshipData.cart.id,
              shop_id: shopId,
              shop_name: resolvedMeta.shop_name,
              shop_slug: resolvedMeta.shop_slug,
              shop_logo_url: resolvedMeta.shop_logo_url,
              shop_type: 'dropship',
              can_see_buy_price: Boolean(dropshipData.permissions?.can_see_buy_price),
              can_see_sell_price: Boolean(dropshipData.permissions?.can_see_sell_price),
              currency_id: resolvedMeta.currency_id,
              currency_code: resolvedMeta.currency_code,
              currency_symbol: resolvedMeta.currency_symbol,
              item_count: itemCount,
              cart_total: cartTotal,
              updated_at: dropshipData.cart.updated_at,
            },
          ];
        }

        const hasShop = old.some((cart) => cart.shop_id === shopId);
        if (!hasShop && resolvedMeta) {
          return [
            {
              cart_id: dropshipData.cart.id,
              shop_id: shopId,
              shop_name: resolvedMeta.shop_name,
              shop_slug: resolvedMeta.shop_slug,
              shop_logo_url: resolvedMeta.shop_logo_url,
              shop_type: 'dropship',
              can_see_buy_price: Boolean(dropshipData.permissions?.can_see_buy_price),
              can_see_sell_price: Boolean(dropshipData.permissions?.can_see_sell_price),
              currency_id: resolvedMeta.currency_id,
              currency_code: resolvedMeta.currency_code,
              currency_symbol: resolvedMeta.currency_symbol,
              item_count: itemCount,
              cart_total: cartTotal,
              updated_at: dropshipData.cart.updated_at,
            },
            ...old,
          ];
        }

        return old.map((cart) =>
          cart.shop_id === shopId
            ? { ...cart, item_count: itemCount, cart_total: cartTotal }
            : cart,
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
    const resolvedMeta = resolveShopMetaForCache(shopId, shopMeta);

    if (data?.items?.length > 0) {
      const itemCount = data.items.reduce((sum: number, i: any) => sum + i.quantity, 0);
      const shopType = data.cart?.shop_type as ShopType | undefined;
      const cartTotal = sumCartSubtotal(shopType, data.items);

      queryClient.setQueryData(
        shopOrderQueryKeys.activeCarts(tenantId.value),
        (old: ActiveCartItem[] | undefined) => {
          if (!old) {
            return resolvedMeta ? [buildActiveCartEntry(shopId, data, resolvedMeta)] : [];
          }

          const hasShop = old.some((cart) => cart.shop_id === shopId);
          if (hasShop) {
            return old.map((cart) =>
              cart.shop_id === shopId
                ? { ...cart, item_count: itemCount, cart_total: cartTotal }
                : cart,
            );
          }

          if (resolvedMeta) {
            return [buildActiveCartEntry(shopId, data, resolvedMeta), ...old];
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
        return old.filter((cart) => cart.shop_id !== shopId);
      },
    );
  };

  const syncCartCachesAfterMutation = (
    shopId: number,
    data: any,
    shopMeta?: ActiveCartShopMeta,
  ) => {
    updateCartCache(shopId, data);
    const dropshipData = patchDropshipCartCache(shopId, data, shopMeta);
    patchDropshipReviewCartCache(shopId, data, shopMeta);

    if (data?.cart?.shop_type === 'dropship') {
      void queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.dropshipReviewCart(tenantId.value, shopId),
      });
      if (dropshipData) {
        updateDropshipActiveCartsCache(shopId, dropshipData, shopMeta);
      }
    }

    updateActiveCartsCache(shopId, data, shopMeta);
  };

  const addItemMutation = useMutation({
    mutationFn: async (params: {
      shopId: number;
      productId: number;
      globalStockAllocationId: number | null;
      globalStockId?: number | null;
      listingId?: number | null;
      gradeSlug?: string | null;
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
        params.listingId,
        params.gradeSlug,
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
    onSuccess: ({ data, shopId }, variables) => {
      const resolvedMeta = resolveShopMetaForCache(shopId);
      updateCartCache(shopId, data);
      const dropshipData = patchDropshipCartCache(shopId, data, resolvedMeta);
      queryClient.setQueryData(
        shopOrderQueryKeys.dropshipReviewCart(tenantId.value, shopId),
        (old: DropshipReviewCartData | null | undefined) => {
          if (!old) return old;
          return patchDropshipItemResellPrice(old, variables.cartItemId, variables.price);
        },
      );
      if (dropshipData) {
        updateDropshipActiveCartsCache(shopId, dropshipData, resolvedMeta);
      } else {
        updateActiveCartsCache(shopId, data, resolvedMeta);
      }
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
      syncCartCachesAfterMutation(shopId, data);
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
