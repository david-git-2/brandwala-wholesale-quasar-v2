<template>
  <q-page class="q-pa-md bw-page theme-shop storefront-page">
    <!-- ACCESS DENIED STATE -->
    <div
      v-if="accessDenied"
      class="column items-center justify-center error-container text-center q-pa-xl"
    >
      <q-icon name="ph ph-shield-warning" size="80px" color="negative" class="q-mb-md" />
      <div class="text-h5 text-weight-bold text-grey-9">{{ $t('shop.access_denied') }}</div>
      <p class="text-body1 text-grey-6 q-mt-sm q-mb-lg" style="max-width: 400px">
        {{ $t('shop.access_denied_desc') }}
      </p>
      <q-btn color="primary" no-caps :label="$t('shop.go_back')" class="pill-btn" @click="goBack" />
    </div>

    <!-- NOT FOUND STATE -->
    <div
      v-else-if="notFound"
      class="column items-center justify-center error-container text-center q-pa-xl"
    >
      <q-icon name="ph ph-magnifying-glass-minus" size="80px" color="warning" class="q-mb-md" />
      <div class="text-h5 text-weight-bold text-grey-9">{{ $t('shop.shop_not_found') }}</div>
      <p class="text-body1 text-grey-6 q-mt-sm q-mb-lg" style="max-width: 400px">
        {{ $t('shop.shop_not_found_desc') }}
      </p>
      <q-btn color="primary" no-caps :label="$t('shop.go_back')" class="pill-btn" @click="goBack" />
    </div>

    <!-- INITIAL LOADING SKELETON -->
    <StorefrontSkeletonGrid v-else-if="initialLoading" initial />

    <!-- STOREFRONT MAIN CONTENT -->
    <div v-else class="bw-page__stack">
      <StorefrontSearchToolbar
        :shop-name="shopName"
        :current-slug="shopSlug"
        :shops="shops"
        v-model:search="search"
        v-model:brand="brand"
        v-model:category="category"
        :active-filter-count="activeFilterCount"
        :has-active-filters="hasActiveFilters"
        @search="onSearchClick"
        @open-filter="filterDrawerOpen = true"
        @reset-filters="onResetFilters"
        @switch-shop="onSwitchShop"
      />

      <!-- PRODUCT GRID WITH INFINITE SCROLL -->
      <q-infinite-scroll ref="infiniteScrollRef" :offset="250" @load="onLoadMore">
        <div v-if="catalogItems.length > 0" class="row q-col-gutter-md product-grid">
          <div
            v-for="item in catalogItems"
            :key="item.product_id + '-' + (item.global_stock_id || '')"
            class="col-xs-12 col-sm-6 col-md-4 col-lg-3 product-grid-item"
          >
            <StorefrontProductCard
              :item="item"
              :permissions="permissions"
              :shop-type="shopDetails?.shop_type"
              :selected-qty="selectedQuantities[itemKey(item)]"
              :in-cart="isInCart(item)"
              :loading="isCartPendingForItem(item)"
              :is-image-broken="brokenImages[itemKey(item)]"
              :format-money="formatMoney"
              @open-detail="goToProductDetail"
              @image-error="brokenImages[itemKey(item)] = true"
              @increment="incrementQty"
              @decrement="decrementQty"
              @add-to-cart="onAddToCart"
              @remove-from-cart="onRemoveFromCart"
            />
          </div>
        </div>

        <div
          v-else-if="!isLoading && !isFetching"
          class="column items-center justify-center empty-state q-pa-xl text-center"
        >
          <q-icon name="ph ph-tote" size="64px" color="grey-5" class="q-mb-md" />
          <div class="text-h6 text-weight-bold text-grey-8">{{ $t('shop.no_products_found') }}</div>
          <p class="text-body2 text-grey-6 q-mt-sm">
            {{ $t('shop.no_products_desc') }}
          </p>
        </div>

        <template #loading>
          <StorefrontSkeletonGrid
            v-if="isFetchingNextPage || (isLoading && catalogItems.length > 0)"
          />
        </template>
      </q-infinite-scroll>
    </div>

    <!-- FILTER SIDEBAR DRAWERS -->
    <FilterSidebar v-model="filterDrawerOpen" :title="$t('shop.filters')">
      <StorefrontFilterDrawer
        v-model:brand="brand"
        v-model:category="category"
        :brand-options="filteredBrandOptions"
        :category-options="filteredCategoryOptions"
        @filter-brands="filterBrands"
        @filter-categories="filterCategories"
        @reset-filters="onResetFilters"
        @apply="filterDrawerOpen = false"
      />
    </FilterSidebar>
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useShopStorefrontInfiniteQuery } from '../composables/useShopStorefrontQuery';
import {
  useShopBrandOptionsQuery,
  useShopCategoryOptionsQuery,
} from '../composables/useShopLookupOptionsQuery';
import { useShopCartQuery } from '../composables/useShopCartQuery';
import { useCustomerShopPermissionsQuery } from '../composables/useCustomerShopPermissionsQuery';
import { useShopCartMutations } from '../composables/useShopCartMutations';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerShopsQuery } from '../composables/useShopQuery';
import { useStorefrontState } from '../composables/useStorefrontState';
import type { CustomerAccessibleShop } from '../repositories/shopOrderRepository';
import { rememberCatalogShop, shopCatalogPath, shopCatalogProductPath } from '../utils/catalogShop';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import StorefrontSearchToolbar from '../components/StorefrontSearchToolbar.vue';
import StorefrontFilterDrawer from '../components/StorefrontFilterDrawer.vue';
import StorefrontProductCard from '../components/StorefrontProductCard.vue';
import StorefrontSkeletonGrid from '../components/StorefrontSkeletonGrid.vue';
import type { QInfiniteScroll } from 'quasar';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const authStore = useAuthStore();
const sessionTenantId = computed(() => authStore.tenantId ?? 0);

const {
  search,
  brand,
  category,
  activeFilterCount,
  hasActiveFilters,
  syncUrlQuery,
  itemKey,
  formatMoney,
} = useStorefrontState();

const shopSlug = computed(() => (route.params.shopSlug as string) || '');

const queryParams = computed(() => ({
  shopSlug: shopSlug.value,
  search: search.value || null,
  category: category.value || null,
  brand: brand.value || null,
  pageSize: 24,
}));

const {
  catalogItems,
  shopDetails,
  isLoading,
  isFetching,
  isFetchingNextPage,
  hasNextPage,
  fetchNextPage,
  isError,
  error,
} = useShopStorefrontInfiniteQuery(queryParams);

const filterDrawerOpen = ref(false);

const lookupParams = computed(() => ({
  vendorCode: shopDetails.value?.vendor_code ?? null,
  tenantId: shopDetails.value?.tenant_id ?? authStore.tenantId ?? null,
  enabled: filterDrawerOpen.value,
}));

const { brands: brandNames } = useShopBrandOptionsQuery(lookupParams);
const { categories: categoryNames } = useShopCategoryOptionsQuery(lookupParams);

const activeShopId = computed(() => shopDetails.value?.id ?? null);
const { data: permissions } = useCustomerShopPermissionsQuery(activeShopId);
const { items: cartItems } = useShopCartQuery(activeShopId);
const { addItemMutation, updateQtyMutation, removeItemMutation } = useShopCartMutations();

const cartSaving = computed(
  () =>
    addItemMutation.isPending.value ||
    updateQtyMutation.isPending.value ||
    removeItemMutation.isPending.value,
);

const shopsQuery = useCustomerShopsQuery(computed(() => authStore.tenantId ?? null));
const shops = computed(() => shopsQuery.data.value ?? []);
const shopName = computed(() => shopDetails.value?.name || t('navigation.catalog'));
const initialLoading = computed(() => isLoading.value && catalogItems.value.length === 0);
const accessDenied = computed(() => isError.value && error.value?.message?.includes('access denied'));
const notFound = computed(() => isError.value && !accessDenied.value);

const brandSearchVal = ref('');
const categorySearchVal = ref('');
const selectedQuantities = reactive<Record<string, number>>({});
const brokenImages = reactive<Record<string, boolean>>({});
const infiniteScrollRef = ref<QInfiniteScroll | null>(null);

const allBrandOption = computed(() => ({ label: t('shop.all_brands'), value: null }));
const allCategoryOption = computed(() => ({ label: t('shop.all_categories'), value: null }));

const filteredBrandNames = computed(() => {
  if (!brandSearchVal.value) return brandNames.value;
  const needle = brandSearchVal.value.toLowerCase();
  return brandNames.value.filter((b) => b.toLowerCase().includes(needle));
});

const filteredCategoryNames = computed(() => {
  if (!categorySearchVal.value) return categoryNames.value;
  const needle = categorySearchVal.value.toLowerCase();
  return categoryNames.value.filter((c) => c.toLowerCase().includes(needle));
});

const filteredBrandOptions = computed(() => [
  allBrandOption.value,
  ...filteredBrandNames.value.map((item) => ({ label: item, value: item })),
]);

const filteredCategoryOptions = computed(() => [
  allCategoryOption.value,
  ...filteredCategoryNames.value.map((item) => ({ label: item, value: item })),
]);

const onSwitchShop = (shop: { id: number; slug: string; name: string } | CustomerAccessibleShop) => {
  if (!shop.slug || shop.slug === shopSlug.value) return;
  if (sessionTenantId.value) {
    rememberCatalogShop(sessionTenantId.value, shop);
  }
  const tenantSlug =
    typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : authStore.tenantSlug;
  void router.push(shopCatalogPath(tenantSlug, shop.slug));
};

const goBack = () => {
  router.back();
};

const filterBrands = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    brandSearchVal.value = val;
  });
};

const filterCategories = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    categorySearchVal.value = val;
  });
};

const resetInfiniteScroll = () => {
  void nextTick(() => {
    if (infiniteScrollRef.value) {
      infiniteScrollRef.value.reset();
      infiniteScrollRef.value.resume();
    }
  });
};

const onLoadMore = async (_index: number, done: (stop?: boolean) => void) => {
  if (!hasNextPage.value || isFetchingNextPage.value) {
    done(!hasNextPage.value);
    return;
  }
  await fetchNextPage();
  done(!hasNextPage.value);
};

const onResetFilters = () => {
  search.value = '';
  brand.value = null;
  category.value = null;
  syncUrlQuery();
  resetInfiniteScroll();
};

const getMinQty = (item: any) => {
  if (shopDetails.value?.shop_type === 'dropship') return 1;
  return item.minimum_order_quantity || 1;
};

const decrementQty = (item: any) => {
  const key = itemKey(item);
  const min = getMinQty(item);
  const current = selectedQuantities[key] || min;
  if (current > min) {
    selectedQuantities[key] = current - min;
  }
};

const incrementQty = (item: any) => {
  const key = itemKey(item);
  const min = getMinQty(item);
  const current = selectedQuantities[key] || min;
  if (item.available_units === null || current + min <= item.available_units) {
    selectedQuantities[key] = current + min;
  }
};

const goToProductDetail = (item: any) => {
  void router.push(shopCatalogProductPath(authStore.tenantSlug, shopSlug.value, item.product_id));
};

const cartItemFor = (catalogItem: any) => {
  return cartItems.value.find(
    (cartItem) =>
      cartItem.product_id === catalogItem.product_id &&
      cartItem.global_stock_id === catalogItem.global_stock_id,
  );
};

const isInCart = (catalogItem: any) => {
  return !!cartItemFor(catalogItem);
};

const pendingCartItems = reactive(new Set<string>());

const isCartPendingForItem = (item: any) => {
  return pendingCartItems.has(itemKey(item));
};

const onAddToCart = async (item: any) => {
  if (!shopDetails.value) return;
  const key = itemKey(item);
  const qty = selectedQuantities[key] || getMinQty(item);
  pendingCartItems.add(key);
  try {
    await addItemMutation.mutateAsync({
      shopId: shopDetails.value.id,
      productId: item.product_id,
      globalStockAllocationId: item.global_stock_id ?? null,
      globalStockId: item.global_stock_id ?? null,
      quantity: qty,
    });
    delete selectedQuantities[key];
  } finally {
    pendingCartItems.delete(key);
  }
};

const onRemoveFromCart = async (catalogItem: any) => {
  if (!shopDetails.value) return;
  const cartItem = cartItemFor(catalogItem);
  if (!cartItem) return;
  const key = itemKey(catalogItem);
  pendingCartItems.add(key);
  try {
    await removeItemMutation.mutateAsync({
      cartItemId: cartItem.id,
      shopId: shopDetails.value.id,
    });
  } finally {
    pendingCartItems.delete(key);
  }
};

const onSearchClick = () => {
  syncUrlQuery();
  resetInfiniteScroll();
};

watch([category, brand], () => {
  syncUrlQuery();
  resetInfiniteScroll();
});

watch(shopDetails, (newDetails) => {
  const slug = newDetails?.slug || shopSlug.value;
  if (newDetails?.id && slug && sessionTenantId.value) {
    rememberCatalogShop(sessionTenantId.value, { id: newDetails.id, slug });
  }
});
</script>

<style scoped>
.storefront-page {
  background: transparent;
}

@media (min-width: 600px) {
  .product-grid {
    display: grid !important;
    grid-template-columns: repeat(auto-fill, minmax(220px, 250px));
    justify-content: center;
    gap: 16px;
    margin: 0 !important;
  }
  .product-grid-item {
    width: 100% !important;
    max-width: none !important;
    padding: 0 !important;
  }
}

.empty-state {
  min-height: 320px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 60%, transparent);
  border-radius: 16px;
  border: 1px dashed var(--bw-theme-border, rgba(34, 56, 101, 0.12));
  backdrop-filter: blur(4px);
  color: var(--bw-theme-ink, #1f2937);
}

.error-container {
  min-height: 450px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 80%, transparent);
  border-radius: 20px;
  border: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.08));
  box-shadow: var(--bw-theme-shadow, 0 8px 30px rgba(0, 0, 0, 0.02));
  color: var(--bw-theme-ink, #1f2937);
}

@media (max-width: 599px) {
  .product-grid {
    margin-left: 0 !important;
    margin-right: 0 !important;
    row-gap: 0 !important;
  }
  .product-grid-item {
    padding: 0 !important;
  }
}
</style>
