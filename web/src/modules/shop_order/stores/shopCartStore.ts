import { defineStore } from 'pinia';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { shopCartService } from '../services/shopCartService';
import type { CartData } from '../repositories/shopCartRepository';

export interface ShopCartState {
  cart: CartData['cart'] | null;
  items: CartData['items'];
  loading: boolean;
  saving: boolean;
  error: string | null;
}

export const useShopCartStore = defineStore('shopCart', {
  state: (): ShopCartState => ({
    cart: null,
    items: [],
    loading: false,
    saving: false,
    error: null,
  }),

  getters: {
    itemCount: (state) => state.items.reduce((sum, item) => sum + item.quantity, 0),
    cartTotal: (state) => {
      // Calculate cart total based on customer sell price or sell price snapshot
      return state.items.reduce((sum, item) => {
        const price =
          item.customer_sell_price_amount ??
          item.unit_sell_price_amount ??
          item.unit_list_price_amount ??
          0;
        return sum + price * item.quantity;
      }, 0);
    },
    currencyCode: (state) => {
      // Find currency code from items (or return default/empty)
      if (state.items.length === 0) return '';
      // In a real application we would look up from global currencies, but we can return the first item's currency symbol/code if snapshot is available
      return '';
    },
  },

  actions: {
    clearCart() {
      this.cart = null;
      this.items = [];
      this.error = null;
    },

    async fetchCart(shopId: number) {
      this.loading = true;
      this.error = null;
      try {
        const res = await shopCartService.getOrCreateCart(shopId);
        if (!res.success) {
          this.error = res.error;
          handleApiFailure(res, res.error);
          return res;
        }
        this.cart = res.data?.cart ?? null;
        this.items = res.data?.items ?? [];
        return res;
      } finally {
        this.loading = false;
      }
    },

    async addItem(
      shopId: number,
      productId: number,
      globalStockAllocationId: number | null,
      quantity: number,
      customerSellPriceAmount?: number | null,
      customerSellPriceCurrencyId?: number | null,
    ) {
      this.saving = true;
      this.error = null;
      try {
        const res = await shopCartService.addToCart(
          shopId,
          productId,
          globalStockAllocationId,
          quantity,
          customerSellPriceAmount,
          customerSellPriceCurrencyId,
        );
        if (!res.success) {
          this.error = res.error;
          handleApiFailure(res, res.error);
          return res;
        }
        this.cart = res.data?.cart ?? null;
        this.items = res.data?.items ?? [];
        showSuccessNotification('Item added to cart.');
        return res;
      } finally {
        this.saving = false;
      }
    },

    async updateQty(cartItemId: number, quantity: number) {
      this.saving = true;
      this.error = null;
      try {
        const res = await shopCartService.updateCartItemQty(cartItemId, quantity);
        if (!res.success) {
          this.error = res.error;
          handleApiFailure(res, res.error);
          return res;
        }
        this.cart = res.data?.cart ?? null;
        this.items = res.data?.items ?? [];
        return res;
      } finally {
        this.saving = false;
      }
    },

    async removeItem(cartItemId: number) {
      this.saving = true;
      this.error = null;
      try {
        const res = await shopCartService.removeCartItem(cartItemId);
        if (!res.success) {
          this.error = res.error;
          handleApiFailure(res, res.error);
          return res;
        }
        this.cart = res.data?.cart ?? null;
        this.items = res.data?.items ?? [];
        showSuccessNotification('Item removed from cart.');
        return res;
      } finally {
        this.saving = false;
      }
    },
  },
});
