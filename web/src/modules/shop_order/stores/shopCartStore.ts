import { defineStore } from 'pinia';

/**
 * @deprecated Server state for shop cart has been migrated to TanStack Query.
 * Use `useShopCartQuery`, `useActiveShopCartsQuery`, and `useShopCartMutations` from `src/modules/shop_order/composables/`.
 */
export const useShopCartStore = defineStore('shopCart', {
  state: () => ({
    selectedShopId: null as number | null,
  }),

  actions: {
    setSelectedShop(shopId: number | null) {
      this.selectedShopId = shopId;
    },
  },
});
