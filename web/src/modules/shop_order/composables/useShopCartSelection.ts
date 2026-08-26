import { computed, ref, watch, type Ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { ActiveCartItem } from '../repositories/shopCartRepository';
import {
  getLastVisitedShopSlug,
  resolveCartShopId,
  shopCartPath,
  shopCatalogEntryPath,
  shopCatalogPath,
} from '../utils/catalogShop';

export function useShopCartSelection(
  activeCarts: Ref<ActiveCartItem[]>,
  isCartsLoading: Ref<boolean>,
) {
  const route = useRoute();
  const router = useRouter();
  const authStore = useAuthStore();

  const selectedShopId = ref<number | null>(null);

  watch(
    [() => route.query.shopId, activeCarts, isCartsLoading],
    ([qShopId, carts, loading]) => {
      const fromQuery = resolveCartShopId(authStore.tenantId, [], qShopId);
      if (fromQuery) {
        selectedShopId.value = fromQuery;
        return;
      }
      if (loading) {
        selectedShopId.value = null;
        return;
      }
      const resolved = resolveCartShopId(authStore.tenantId, carts);
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

  const showCartPicker = computed(() => {
    return (
      !route.query.shopId &&
      !selectedShopId.value &&
      !isCartsLoading.value &&
      activeCarts.value.length > 1
    );
  });

  const currentShopCartInfo = computed(() => {
    return activeCarts.value.find((c) => c.shop_id === selectedShopId.value) ?? null;
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
    showCartPicker,
    currentShopCartInfo,
    selectShopCart,
    formatActiveCartTotal,
    goBack,
  };
}
