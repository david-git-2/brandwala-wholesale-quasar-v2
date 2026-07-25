<template>
  <q-page class="q-pa-md storefront-page">
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
    <div v-else-if="initialLoading" class="storefront-loading">
      <q-card flat bordered class="q-mb-md q-pa-md">
        <q-skeleton type="text" width="180px" height="28px" />
        <q-skeleton type="text" width="280px" class="q-mt-xs" />
      </q-card>
      <div class="row q-col-gutter-md product-grid">
        <div v-for="n in 8" :key="n" class="col-xs-12 col-sm-6 col-md-4 col-lg-3 product-grid-item">
          <q-card flat bordered class="product-card product-card-sk">
            <div class="product-image-wrapper">
              <q-skeleton type="rect" class="full-width full-height" />
            </div>
            <div class="product-body">
              <q-skeleton type="text" width="80%" />
              <q-skeleton type="text" width="50%" class="q-mt-xs" />
              <q-skeleton type="text" width="30%" class="q-mt-md" />
            </div>
          </q-card>
        </div>
      </div>
    </div>

    <!-- STOREFRONT MAIN CONTENT -->
    <div v-else class="q-gutter-y-md">
      <!-- Shop Header Hero -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat dense icon="ph ph-arrow-left" color="grey-7" @click="goDashboard" />
            <div>
              <div class="text-overline text-primary">Wholesale Storefront</div>
              <h1 class="text-h5 text-weight-bold q-my-none">{{ shopName }}</h1>
            </div>
          </div>
        </div>
        <div v-if="quasar.screen.xs" class="col-auto row items-center q-gutter-sm">
          <q-btn
            flat
            round
            dense
            color="primary"
            icon="ph ph-funnel-simple"
            @click="filterDrawerOpen = true"
          >
            <q-badge v-if="activeFilterCount > 0" color="primary" floating rounded>
              {{ activeFilterCount }}
            </q-badge>
            <q-tooltip>{{ $t('shop.filters') }}</q-tooltip>
          </q-btn>
        </div>
      </section>

      <!-- Toolbar & Search Card -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <!-- Search bar -->
          <div class="col-xs-12 col-sm-8 col-md-6 row no-wrap q-gutter-sm">
            <q-input
              v-model="search"
              filled
              dense
              type="text"
              class="soft-input col"
              :placeholder="$t('shop.search_placeholder')"
              clearable
              @keydown.enter="onSearchClick"
              @clear="onSearchClick"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
            <q-btn
              unelevated
              no-caps
              color="primary"
              :label="$t('shop.search')"
              class="pill-btn"
              @click="onSearchClick"
            />
          </div>

          <!-- Filter toggles & Active category indicator badge -->
          <div
            v-if="!quasar.screen.xs || category"
            class="col-xs-12 col-sm-4 col-md-6 text-right row items-center justify-end q-gutter-sm"
          >
            <q-badge v-if="category" color="primary" outline class="q-pa-xs">
              Category: {{ category }}
            </q-badge>
            <q-btn
              v-if="!quasar.screen.xs"
              flat
              round
              dense
              color="primary"
              icon="ph ph-funnel-simple"
              @click="filterDrawerOpen = true"
            >
              <q-badge v-if="activeFilterCount > 0" color="primary" floating rounded>
                {{ activeFilterCount }}
              </q-badge>
              <q-tooltip>{{ $t('shop.filters') }}</q-tooltip>
            </q-btn>
          </div>
        </div>
      </q-card>

      <!-- Active Filters Chips -->
      <div
        v-if="hasActiveFilters"
        class="row items-center q-gutter-xs active-filters-section"
      >
        <span class="text-caption text-weight-medium text-grey-7 q-mr-xs">{{
          $t('shop.active_filters')
        }}</span>
        <q-chip
          v-if="search"
          removable
          outline
          color="primary"
          text-color="primary"
          size="sm"
          class="q-ma-xs"
          @remove="search = ''"
        >
          Search: "{{ search }}"
        </q-chip>
        <q-chip
          v-if="brand"
          removable
          outline
          color="primary"
          text-color="primary"
          size="sm"
          class="q-ma-xs"
          @remove="brand = null"
        >
          {{ $t('shop.brand_filter', { name: brand }) }}
        </q-chip>
        <q-chip
          v-if="category"
          removable
          outline
          color="primary"
          text-color="primary"
          size="sm"
          class="q-ma-xs"
          @remove="category = null"
        >
          {{ $t('shop.category_filter', { name: category }) }}
        </q-chip>
        <q-btn
          flat
          dense
          no-caps
          color="primary"
          :label="$t('shop.clear_all')"
          size="sm"
          class="q-px-sm q-ml-xs text-weight-bold"
          @click="onResetFilters"
        />
      </div>

      <!-- PRODUCT GRID WITH INFINITE SCROLL -->
      <q-infinite-scroll ref="infiniteScrollRef" :offset="250" @load="onLoadMore">
        <div
          v-if="catalogItems.length > 0"
          class="row q-col-gutter-md product-grid"
        >
          <div
            v-for="item in catalogItems"
            :key="item.product_id + '-' + (item.global_stock_allocation_id || '')"
            class="col-xs-12 col-sm-6 col-md-4 col-lg-3 product-grid-item"
          >
            <q-card flat bordered class="product-card">
              <div class="product-image-wrapper cursor-pointer" @click="openQuickView(item)">
                <img
                  v-if="item.product_image_url && !brokenImages[itemKey(item)]"
                  :src="item.product_image_url"
                  :alt="item.product_name || 'Product'"
                  class="product-image"
                  loading="lazy"
                  @error="brokenImages[itemKey(item)] = true"
                />
                <div v-else class="product-image-fallback">
                  <q-icon name="ph ph-image-square" size="28px" color="grey-5" />
                </div>
              </div>

              <div class="product-body">
                <div class="product-meta text-caption text-uppercase tracking-wider">
                  {{ item.product_brand || 'Generic' }}
                </div>
                <div class="product-name text-subtitle2 text-weight-bold cursor-pointer" @click="openQuickView(item)">
                  {{ item.product_name }}
                </div>

                <!-- Available Quantity placed after Name -->
                <div
                  v-if="
                    permissions?.can_view_quantity &&
                    item.available_units !== null &&
                    item.available_units !== undefined
                  "
                  class="text-caption q-mt-xs"
                  :class="
                    item.available_units > 0
                      ? 'text-positive'
                      : item.available_units === 0
                        ? 'text-negative'
                        : 'text-grey-6'
                  "
                >
                  {{ item.available_units }} {{ $t('shop.avail') }}
                </div>

                <!-- Pricing Section -->
                <div class="product-pricing q-mt-sm">
                  <template v-if="permissions?.see_price">
                    <div class="text-subtitle1 text-weight-bold text-primary">
                      <span v-if="shopDetails?.shop_type === 'dropship'" class="text-caption text-grey-6 block text-weight-medium">{{ $t('shop.wholesale_price') }}</span>
                      {{ formatMoney(item.unit_price_amount, item.unit_price_currency_symbol) }}
                    </div>
                    <div
                      v-if="item.minimum_sell_price_amount != null"
                      class="text-body2 text-grey-9 text-weight-medium q-mt-xs"
                    >
                      <template v-if="shopDetails?.shop_type === 'dropship'">
                        {{ $t('shop.min_sell_price') }}:
                        <span class="text-secondary text-weight-bold">
                          {{
                            formatMoney(
                              item.minimum_sell_price_amount,
                              item.minimum_sell_price_currency_symbol,
                            )
                          }}
                        </span>
                      </template>
                      <template v-else>
                        {{
                          $t('shop.min_price_hint', {
                            amount: formatMoney(
                              item.minimum_sell_price_amount,
                              item.minimum_sell_price_currency_symbol,
                            ),
                          })
                        }}
                      </template>
                    </div>
                  </template>
                </div>

                <!-- Separate Actions Row below everything -->
                <div class="product-actions q-mt-auto q-pt-sm">
                  <div class="row items-center no-wrap justify-between q-gutter-x-xs">
                    <!-- Qty adjuster shown only when NOT in cart -->
                    <div
                      v-if="!isInCart(item)"
                      class="row items-center no-wrap quantity-controls col-auto"
                      style="
                        border: 1.5px solid var(--bw-theme-border, rgba(34, 56, 101, 0.15));
                        border-radius: 8px;
                        padding: 2px;
                        background: rgba(0, 0, 0, 0.02);
                      "
                    >
                      <q-btn
                        flat
                        round
                        dense
                        size="xs"
                        icon="ph ph-minus"
                        color="grey-8"
                        style="min-width: 28px; min-height: 28px"
                        @click="decrementQty(item)"
                      />
                      <div
                        class="text-weight-bold text-center text-grey-9"
                        style="width: 28px; font-size: 13px; user-select: none"
                      >
                        {{ selectedQuantities[itemKey(item)] || getMinQty(item) }}
                      </div>
                      <q-btn
                        flat
                        round
                        dense
                        size="xs"
                        icon="ph ph-plus"
                        color="grey-8"
                        style="min-width: 28px; min-height: 28px"
                        @click="incrementQty(item)"
                      />
                    </div>
                    <div v-else class="col-auto"></div>

                    <q-btn
                      v-if="!isInCart(item)"
                      color="primary"
                      unelevated
                      no-caps
                      dense
                      icon="ph ph-shopping-cart"
                      :label="quasar.screen.lt.sm ? undefined : $t('shop.add')"
                      class="add-cart-btn"
                      :disabled="
                        !permissions?.can_add_to_cart ||
                        (item.available_units !== null && item.available_units <= 0)
                      "
                      @click="onAddToCart(item)"
                    />
                    <q-btn
                      v-else
                      color="negative"
                      unelevated
                      no-caps
                      dense
                      icon="ph ph-shopping-cart"
                      :label="quasar.screen.lt.sm ? undefined : $t('shop.remove')"
                      class="add-cart-btn"
                      :disabled="!permissions?.can_add_to_cart"
                      @click="onRemoveFromCart(item)"
                    />
                  </div>
                </div>
              </div>
            </q-card>
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
          <div
            v-if="isFetchingNextPage || (isLoading && catalogItems.length > 0)"
            class="row q-col-gutter-md product-grid q-mt-xs"
          >
            <div v-for="n in 4" :key="'sk-more-' + n" class="col-xs-12 col-sm-6 col-md-4 col-lg-3 product-grid-item">
              <q-card flat bordered class="product-card product-card-sk">
                <div class="product-image-wrapper">
                  <q-skeleton type="rect" class="full-width full-height" />
                </div>
                <div class="product-body">
                  <q-skeleton type="text" width="80%" />
                  <q-skeleton type="text" width="50%" class="q-mt-xs" />
                  <q-skeleton type="text" width="30%" class="q-mt-md" />
                </div>
              </q-card>
            </div>
          </div>
        </template>
      </q-infinite-scroll>

    </div>

    <!-- FILTER SIDEBAR DRAWERS -->
    <FilterSidebar v-model="filterDrawerOpen" :title="$t('shop.filters')">
      <div class="q-pa-md">
        <q-select
          v-model="brand"
          filled
          use-input
          dense
          hide-selected
          fill-input
          input-debounce="300"
          emit-value
          map-options
          :options="filteredBrandOptions"
          class="soft-input q-mb-sm"
          :label="$t('shop.brand')"
          @filter="filterBrands"
        />

        <q-select
          v-model="category"
          filled
          use-input
          dense
          hide-selected
          fill-input
          input-debounce="300"
          emit-value
          map-options
          :options="filteredCategoryOptions"
          class="soft-input q-mb-md"
          :label="$t('shop.category')"
          @filter="filterCategories"
        />

        <div class="row q-gutter-sm justify-end q-mt-md">
          <q-btn flat no-caps :label="$t('shop_admin.reset')" color="grey-7" @click="onResetFilters" />
          <q-btn
            unelevated
            no-caps
            :label="$t('shop.apply')"
            color="primary"
            class="pill-btn"
            @click="filterDrawerOpen = false"
          />
        </div>
      </div>
    </FilterSidebar>

    <!-- PRODUCT QUICK VIEW DRAWER / BOTTOM SHEET -->
    <ProductQuickView
      v-model="quickViewOpen"
      :product="selectedQuickViewProduct"
      :shop-details="shopDetails"
      :permissions="permissions"
      :cart-item="selectedQuickViewProduct ? cartItemFor(selectedQuickViewProduct) : null"
      :saving="cartSaving"
      @add-to-cart="onQuickViewAddToCart"
    />
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
import { useShopCartMutations } from '../composables/useShopCartMutations';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import ProductQuickView from '../components/ProductQuickView.vue';
import { useQuasar, type QInfiniteScroll } from 'quasar';

const quasar = useQuasar();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const authStore = useAuthStore();

const shopSlug = computed(() => (route.params.shopSlug as string) || '');
const search = ref('');
const brand = ref<string | null>(null);
const category = ref<string | null>(null);

// Apply route params on init
const applyRouteQueryParams = () => {
  const qVal = (route.query.q || route.query.search) as string | undefined;
  if (qVal) search.value = String(qVal);
  if (route.query.category) category.value = String(route.query.category);
  if (route.query.brand) brand.value = String(route.query.brand);
};
applyRouteQueryParams();

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
  permissions,
  isLoading,
  isFetching,
  isFetchingNextPage,
  hasNextPage,
  fetchNextPage,
  isError,
  error,
} = useShopStorefrontInfiniteQuery(queryParams);

const filterDrawerOpen = ref(false);
const quickViewOpen = ref(false);
const selectedQuickViewProduct = ref<any>(null);

const lookupParams = computed(() => ({
  vendorCode: shopDetails.value?.vendor_code ?? null,
  tenantId: shopDetails.value?.tenant_id ?? authStore.tenantId ?? null,
  enabled: filterDrawerOpen.value,
}));

const { brands: brandNames } = useShopBrandOptionsQuery(lookupParams);
const { categories: categoryNames } = useShopCategoryOptionsQuery(lookupParams);

const activeShopId = computed(() => shopDetails.value?.id ?? null);
const { items: cartItems } = useShopCartQuery(activeShopId);
const { addItemMutation, updateQtyMutation, removeItemMutation } = useShopCartMutations();

const cartSaving = computed(
  () =>
    addItemMutation.isPending.value ||
    updateQtyMutation.isPending.value ||
    removeItemMutation.isPending.value,
);

const shopName = computed(() => shopDetails.value?.name || 'Wholesale Storefront');
const initialLoading = computed(() => isLoading.value && catalogItems.value.length === 0);
const accessDenied = computed(() => isError.value && error.value?.message?.includes('access denied'));
const notFound = computed(() => isError.value && !accessDenied.value);


const brandSearchVal = ref('');
const categorySearchVal = ref('');

const selectedQuantities = reactive<Record<string, number>>({});
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

const activeFilterCount = computed(() => {
  let count = 0;
  if (brand.value) count += 1;
  if (category.value) count += 1;
  return count;
});

const hasActiveFilters = computed(() => {
  return Boolean(search.value || brand.value || category.value);
});

const goDashboard = () => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push(`${tenantSlug}/shop`);
};

const goBack = () => {
  router.back();
};

const syncUrlQuery = () => {
  const query: Record<string, string> = {};
  if (search.value) query.search = search.value;
  if (category.value) query.category = category.value;
  if (brand.value) query.brand = brand.value;
  void router.replace({ query });
};

const formatMoney = (amount: unknown, symbol?: string | null) => {
  const n = Number(amount);
  if (!Number.isFinite(n)) return '—';
  return `${symbol || '£'}${n.toFixed(2)}`;
};

const brokenImages = reactive<Record<string, boolean>>({});
const itemKey = (item: { product_id: number; global_stock_allocation_id?: number | null }) =>
  `${item.product_id}-${item.global_stock_allocation_id || ''}`;

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
  if (shopDetails.value?.shop_type === 'dropship') {
    return 1;
  }
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

const openQuickView = (item: any) => {
  selectedQuickViewProduct.value = item;
  quickViewOpen.value = true;
};

const onQuickViewAddToCart = async (payload: { product: any; quantity: number }) => {
  if (!shopDetails.value) return;
  const existing = cartItemFor(payload.product);
  if (existing) {
    await updateQtyMutation.mutateAsync({
      cartItemId: existing.id,
      quantity: payload.quantity,
      shopId: shopDetails.value.id,
    });
  } else {
    await addItemMutation.mutateAsync({
      shopId: shopDetails.value.id,
      productId: payload.product.product_id,
      globalStockAllocationId: payload.product.global_stock_allocation_id,
      quantity: payload.quantity,
    });
  }
};

const onAddToCart = async (item: any) => {
  if (!shopDetails.value) return;
  const key = itemKey(item);
  const qty = selectedQuantities[key] || getMinQty(item);
  await addItemMutation.mutateAsync({
    shopId: shopDetails.value.id,
    productId: item.product_id,
    globalStockAllocationId: item.global_stock_allocation_id,
    quantity: qty,
  });
  delete selectedQuantities[key];
};

const cartItemFor = (catalogItem: any) => {
  return cartItems.value.find(
    (cartItem) =>
      cartItem.product_id === catalogItem.product_id &&
      cartItem.global_stock_allocation_id === catalogItem.global_stock_allocation_id,
  );
};

const isInCart = (catalogItem: any) => {
  return !!cartItemFor(catalogItem);
};

const onRemoveFromCart = async (catalogItem: any) => {
  if (!shopDetails.value) return;
  const cartItem = cartItemFor(catalogItem);
  if (!cartItem) return;
  await removeItemMutation.mutateAsync({
    cartItemId: cartItem.id,
    shopId: shopDetails.value.id,
  });
};

const onSearchClick = () => {
  syncUrlQuery();
  resetInfiniteScroll();
};

watch([category, brand], () => {
  syncUrlQuery();
  resetInfiniteScroll();
});

watch(
  () => route.query,
  () => {
    applyRouteQueryParams();
  },
);

watch(shopDetails, (newDetails) => {
  if (newDetails?.id) {
    localStorage.setItem('last_visited_shop_id', String(newDetails.id));
    localStorage.setItem('last_visited_shop_slug', newDetails.slug);
  }
});
</script>


<style scoped>
.storefront-page {
  background: transparent;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 82%, transparent);
}

/* —— Desktop / tablet: vertical cards —— */
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

.product-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  border-radius: 16px;
  background: var(--bw-theme-surface, #ffffff);
  border-color: var(--bw-theme-border, rgba(34, 56, 101, 0.12));
  color: var(--bw-theme-ink, #1f2937);
  overflow: hidden;
  transition:
    transform 0.25s ease,
    box-shadow 0.25s ease;
}
.product-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--bw-theme-shadow, 0 10px 20px rgba(34, 56, 101, 0.06));
}
.product-image-wrapper {
  position: relative;
  height: 160px;
  flex: 0 0 160px;
  background: color-mix(
    in srgb,
    var(--bw-theme-base, #fafafa) 90%,
    var(--bw-theme-surface, #fff) 10%
  );
  border-bottom: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.05));
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8px;
}
.product-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
  border-radius: 8px;
}
.product-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: color-mix(
    in srgb,
    var(--bw-theme-base, #eef2f6) 88%,
    var(--bw-theme-surface, #fff) 12%
  );
  border-radius: 8px;
}
.product-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding: 10px 12px 12px;
}
.product-meta {
  letter-spacing: 0.05em;
  margin-bottom: 2px;
  color: var(--bw-theme-muted, #6b7280);
}
.product-name {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.35;
  min-height: 4.05em;
  margin-bottom: 4px;
  color: var(--bw-theme-ink, #1f2937);
}
.product-codes {
  margin-bottom: 8px;
  color: var(--bw-theme-muted, #6b7280);
}
.product-codes__secondary {
  opacity: 0.75;
}
.product-actions {
  margin-top: auto;
  padding-top: 8px;
  border-top: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.06));
}
.product-pricing {
  min-width: 0;
}
.add-cart-btn {
  flex: 1 1 auto;
  border-radius: 8px;
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

/* —— Small screen: side-image list rows —— */
@media (max-width: 599px) {
  .product-grid {
    margin-left: 0 !important;
    margin-right: 0 !important;
    row-gap: 0 !important;
  }
  .product-grid-item {
    padding: 0 !important;
  }
  .product-card {
    flex-direction: row;
    align-items: stretch;
    height: auto;
    min-height: unset;
    border-radius: 0;
    border: none !important;
    border-bottom: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.08)) !important;
    box-shadow: none;
  }
  .product-card:hover {
    transform: none;
    box-shadow: none;
  }
  .product-image-wrapper {
    width: 96px;
    height: 96px;
    flex: 0 0 96px;
    align-self: center;
    margin: 10px 0 10px 10px;
    padding: 4px;
    border-bottom: none;
    border-radius: 8px;
    overflow: hidden;
  }
  .product-image,
  .product-image-fallback {
    border-radius: 6px;
  }
  .product-body {
    padding: 10px 12px 10px 10px;
  }
  .product-name {
    min-height: unset;
    -webkit-line-clamp: 3;
    line-clamp: 3;
    font-size: 14px;
  }
  .product-actions {
    border-top: none;
    padding-top: 4px;
  }
  .add-cart-btn {
    min-width: 36px;
    padding-left: 4px;
    padding-right: 4px;
  }
}
</style>
