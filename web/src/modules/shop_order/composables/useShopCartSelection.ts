import { computed, ref, watch, type Ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { ActiveCartItem } from '../repositories/shopCartRepository';
import {
  getLastVisitedShopSlug,
  getLastVisitedShopId,
  resolveCartShopId,
  shopCartPath,
  shopCatalogEntryPath,
  shopCatalogPath,
} from '../utils/catalogShop';
import { filterActiveCartsByKind, type ShopCartKindFilter } from '../utils/shopCartScope';

export function useShopCartSelection(
  activeCarts: Ref<ActiveCartItem[]>,
  isCartsLoading: Ref<boolean>,
  options?: { cartKind?: ShopCartKindFilter },
) {
  const route = useRoute();
  const router = useRouter();
  const authStore = useAuthStore();
  const cartKind = options?.cartKind ?? 'all';

  const selectedShopId = ref<number | null>(null);

  const scopedActiveCarts = computed(() =>
    filterActiveCartsByKind(activeCarts.value, cartKind),
  );

  watch(
    [() => route.query.shopId, scopedActiveCarts, isCartsLoading],
    ([qShopId, carts, loading]) => {
      const scopedCarts = carts as ActiveCartItem[];
      const fromQuery = resolveCartShopId(authStore.tenantId, [], qShopId);
      if (fromQuery && scopedCarts.some((cart) => cart.shop_id === fromQuery)) {
        if (selectedShopId.value !== fromQuery) {
          selectedShopId.value = fromQuery;
        }
        return;
      }
      if (loading) {
        if (!selectedShopId.value) {
          const lastId = getLastVisitedShopId(authStore.tenantId);
          if (lastId) {
            const parsed = parseInt(lastId, 10);
            const matchesScoped = scopedCarts.some((cart) => cart.shop_id === parsed);
            if (!Number.isNaN(parsed) && matchesScoped) {
              selectedShopId.value = parsed;
            }
          }
        }
        return;
      }
      const resolved = resolveCartShopId(authStore.tenantId, scopedCarts);
      if (!resolved) {
        selectedShopId.value = null;
        return;
      }
      if (selectedShopId.value !== resolved) {
        selectedShopId.value = resolved;
        void router.replace(
          shopCartPath(route.params.tenantSlug ? String(route.params.tenantSlug) : null, resolved),
        );
      }
    },
    { immediate: true },
  );

  const showShopCartTabs = computed(
    () => !isCartsLoading.value && scopedActiveCarts.value.length > 1,
  );

  const showCartPicker = computed(() => false);

  const currentShopCartInfo = computed(() => {
    return scopedActiveCarts.value.find((c) => c.shop_id === selectedShopId.value) ?? null;
  });

  const tenantSlugParam = () =>
    route.params.tenantSlug ? String(route.params.tenantSlug) : null;

  const selectShopCart = (shopId: number) => {
    selectedShopId.value = shopId;
    void router.replace(shopCartPath(tenantSlugParam(), shopId));
  };

  const formatActiveCartTotal = (activeCart: ActiveCartItem) => {
    const currency = activeCart.currency_symbol || activeCart.currency_code || '';
    return `${currency}${Number(activeCart.cart_total).toFixed(2)}`;
  };

  const goBack = () => {
    const slug =
      currentShopCartInfo.value?.shop_slug || getLastVisitedShopSlug(authStore.tenantId);
    if (slug) {
      void router.push(shopCatalogPath(tenantSlugParam(), slug));
      return;
    }
    void router.push(shopCatalogEntryPath(tenantSlugParam()));
  };

  return {
    selectedShopId,
    scopedActiveCarts,
    showShopCartTabs,
    showCartPicker,
    currentShopCartInfo,
    selectShopCart,
    formatActiveCartTotal,
    goBack,
  };
}
