import { computed } from 'vue';
import { useRoute } from 'vue-router';

import { getShopTypePathFromRoute } from '../utils/tenantRouteContext';
import type { ShopTypePathSegment } from 'src/modules/shop_order/utils/shopRouteTypes';

const SHOP_TYPE_LOADING_LABEL: Record<ShopTypePathSegment, string> = {
  catalog: 'catalog',
  stock: 'stock',
  dropship: 'dropship',
};

export const SHOP_TYPE_AUTH_GHOST_LABEL: Record<ShopTypePathSegment, string> = {
  catalog: 'Catalog shop',
  stock: 'Stock shop',
  dropship: 'Dropship shop',
};

export const SHOP_ENTRY_TYPE_ERROR =
  'This sign-in link is missing the shop type (catalog, stock, or dropship). Use the full link from your supplier.';

export function useShopEntryShopType() {
  const route = useRoute();

  const shopTypePath = computed(() => getShopTypePathFromRoute(route));
  const validShopType = computed(() => shopTypePath.value != null);

  const shopTypeError = computed(() => (validShopType.value ? null : SHOP_ENTRY_TYPE_ERROR));

  const loadingTagline = computed(() => {
    const seg = shopTypePath.value;
    if (!seg) {
      return 'Loading shop…';
    }
    return `Loading ${SHOP_TYPE_LOADING_LABEL[seg]} shop…`;
  });

  return {
    shopTypePath,
    validShopType,
    shopTypeError,
    loadingTagline,
  };
}