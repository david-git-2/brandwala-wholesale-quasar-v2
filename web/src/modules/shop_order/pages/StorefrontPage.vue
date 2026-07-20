<template>
  <q-page class="bw-page storefront-page">
    <!-- ACCESS DENIED STATE -->
    <div
      v-if="accessDenied"
      class="column items-center justify-center error-container text-center q-pa-xl"
    >
      <q-icon name="gpp_bad" size="80px" color="negative" class="q-mb-md" />
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
      <q-icon name="search_off" size="80px" color="warning" class="q-mb-md" />
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
    <div v-else class="bw-page__stack">
      <!-- Shop Header Hero -->
      <q-card flat bordered class="q-mb-lg">
        <q-card-section class="q-py-md q-px-lg">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col">
              <div>
                <h1 class="text-h6 text-weight-bold q-my-none">
                  {{ shopStorefrontStore.shopDetails?.name }}
                </h1>
                <div class="row items-center q-gutter-xs text-caption text-grey-7 q-mt-xs">
                  <q-badge
                    :color="getShopTypeColor(shopStorefrontStore.shopDetails?.shop_type)"
                    text-color="white"
                    class="q-mr-xs"
                  >
                    {{ getShopTypeLabel(shopStorefrontStore.shopDetails?.shop_type) }}
                  </q-badge>
                </div>
              </div>
            </div>
            <!-- Back to App Link / Indicator -->
            <div class="col-auto row items-center q-gutter-sm">
              <q-btn
                v-if="shopStorefrontStore.permissions?.can_add_to_cart"
                flat
                round
                dense
                icon="shopping_cart"
                color="primary"
                @click="goToCart"
              >
                <q-badge color="negative" floating v-if="shopCartStore.itemCount > 0">
                  {{ shopCartStore.itemCount }}
                </q-badge>
                <q-tooltip>{{ $t('shop.cart') }}</q-tooltip>
              </q-btn>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <!-- Toolbar & Search -->
      <div class="row items-center justify-between q-col-gutter-md q-mb-md">
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
              <q-icon name="search" />
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

        <!-- Filter toggles -->
        <div class="col-xs-12 col-sm-4 col-md-6 text-right row justify-end q-gutter-sm">
          <q-btn
            flat
            round
            dense
            color="primary"
            icon="filter_list"
            @click="filterDrawerOpen = true"
          >
            <q-badge v-if="activeFilterCount > 0" color="primary" floating rounded>
              {{ activeFilterCount }}
            </q-badge>
            <q-tooltip>{{ $t('shop.filters') }}</q-tooltip>
          </q-btn>
        </div>
      </div>

      <!-- Active Filters Chips -->
      <div
        v-if="hasActiveFilters"
        class="row items-center q-gutter-xs q-mb-md active-filters-section"
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
          v-if="shopStorefrontStore.catalogItems.length > 0"
          class="row q-col-gutter-md product-grid"
        >
          <div
            v-for="item in shopStorefrontStore.catalogItems"
            :key="item.product_id + '-' + (item.global_stock_allocation_id || '')"
            class="col-xs-12 col-sm-6 col-md-4 col-lg-3 product-grid-item"
          >
            <q-card flat bordered class="product-card">
              <div class="product-image-wrapper">
                <img
                  v-if="item.product_image_url && !brokenImages[itemKey(item)]"
                  :src="item.product_image_url"
                  :alt="item.product_name || 'Product'"
                  class="product-image"
                  loading="lazy"
                  @error="brokenImages[itemKey(item)] = true"
                />
                <div v-else class="product-image-fallback">
                  <q-icon name="image_not_supported" size="28px" color="grey-5" />
                </div>
              </div>

              <div class="product-body">
                <div class="product-meta text-caption text-uppercase tracking-wider">
                  {{ item.product_brand || 'Generic' }}
                </div>
                <div class="product-name text-subtitle2 text-weight-bold">
                  {{ item.product_name }}
                </div>

                <!-- Available Quantity placed after Name -->
                <div
                  v-if="
                    shopStorefrontStore.permissions?.can_view_quantity &&
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
                  <template v-if="shopStorefrontStore.permissions?.see_price">
                    <div class="text-subtitle1 text-weight-bold text-primary">
                      <span v-if="shopStorefrontStore.shopDetails?.shop_type === 'dropship'" class="text-caption text-grey-6 block text-weight-medium">{{ $t('shop.wholesale_price') }}</span>
                      {{ formatMoney(item.unit_price_amount, item.unit_price_currency_symbol) }}
                    </div>
                    <div
                      v-if="item.minimum_sell_price_amount != null"
                      class="text-body2 text-grey-9 text-weight-medium q-mt-xs"
                    >
                      <template v-if="shopStorefrontStore.shopDetails?.shop_type === 'dropship'">
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
                        icon="remove"
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
                        icon="add"
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
                      icon="shopping_cart"
                      :label="quasar.screen.lt.sm ? undefined : $t('shop.add')"
                      class="add-cart-btn"
                      :disabled="
                        !shopStorefrontStore.permissions?.can_add_to_cart ||
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
                      icon="remove_shopping_cart"
                      :label="quasar.screen.lt.sm ? undefined : $t('shop.remove')"
                      class="add-cart-btn"
                      :disabled="!shopStorefrontStore.permissions?.can_add_to_cart"
                      @click="onRemoveFromCart(item)"
                    />
                  </div>
                </div>
              </div>
            </q-card>
          </div>
        </div>

        <div
          v-else-if="!shopStorefrontStore.loading"
          class="column items-center justify-center empty-state q-pa-xl text-center"
        >
          <q-icon name="o_shopping_bag" size="64px" color="grey-5" class="q-mb-md" />
          <div class="text-h6 text-weight-bold text-grey-8">{{ $t('shop.no_products_found') }}</div>
          <p class="text-body2 text-grey-6 q-mt-sm">
            {{ $t('shop.no_products_desc') }}
          </p>
        </div>

        <template #loading>
          <div v-if="shopStorefrontStore.loading" class="row justify-center q-my-md">
            <q-spinner-dots color="primary" size="40px" />
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
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useShopStorefrontStore } from '../stores/shopStorefrontStore';
import { useProductStore } from 'src/modules/products/stores/productStore';
import { useShopCartStore } from '../stores/shopCartStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import { useQuasar, type QInfiniteScroll } from 'quasar';

const quasar = useQuasar();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const shopStorefrontStore = useShopStorefrontStore();
const productStore = useProductStore();
const shopCartStore = useShopCartStore();
const authStore = useAuthStore();

const shopSlug = computed(() => (route.params.shopSlug as string) || '');

const initialLoading = ref(true);
const accessDenied = ref(false);
const notFound = ref(false);

const search = ref('');
const brand = ref<string | null>(null);
const category = ref<string | null>(null);
const filterDrawerOpen = ref(false);

const brandNames = ref<string[]>([]);
const categoryNames = ref<string[]>([]);
const filteredBrandNames = ref<string[]>([]);
const filteredCategoryNames = ref<string[]>([]);

const suppressFilterWatch = ref(false);
const selectedQuantities = reactive<Record<string, number>>({});
const infiniteScrollRef = ref<QInfiniteScroll | null>(null);

const allBrandOption = computed(() => ({ label: t('shop.all_brands'), value: null }));
const allCategoryOption = computed(() => ({ label: t('shop.all_categories'), value: null }));

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

const goBack = () => {
  router.back();
};

const formatMoney = (amount: unknown, symbol?: string | null) => {
  const n = Number(amount);
  if (!Number.isFinite(n)) return '—';
  return `${symbol || '£'}${n.toFixed(2)}`;
};

const brokenImages = reactive<Record<string, boolean>>({});
const itemKey = (item: { product_id: number; global_stock_allocation_id?: number | null }) =>
  `${item.product_id}-${item.global_stock_allocation_id || ''}`;

const getShopTypeLabel = (type?: string) => {
  if (type === 'vendor_catalog') return 'Vendor Catalog';
  if (type === 'fixed_price') return 'Fixed Price';
  if (type === 'dropship') return 'Dropship Portal';
  return type || 'Shop';
};

const getShopTypeColor = (type?: string) => {
  if (type === 'vendor_catalog') return 'indigo';
  if (type === 'fixed_price') return 'teal';
  if (type === 'dropship') return 'orange-8';
  return 'grey';
};

const loadBrands = async (vendorCode?: string | null, tenantId?: number | null) => {
  const result = await productStore.fetchBrandOptions({
    vendorCode: vendorCode ?? null,
    tenantId: tenantId ?? null,
  });
  if (result.success) {
    brandNames.value = productStore.brandOptions;
    filteredBrandNames.value = productStore.brandOptions;
  }
};

const loadCategories = async (vendorCode?: string | null, tenantId?: number | null) => {
  const result = await productStore.fetchCategoryOptions({
    vendorCode: vendorCode ?? null,
    tenantId: tenantId ?? null,
  });
  if (result.success) {
    categoryNames.value = productStore.categoryOptions;
    filteredCategoryNames.value = productStore.categoryOptions;
  }
};

const filterBrands = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    if (val === '') {
      filteredBrandNames.value = [...brandNames.value];
      return;
    }
    const needle = val.toLowerCase();
    filteredBrandNames.value = brandNames.value.filter((item) =>
      item.toLowerCase().includes(needle),
    );
  });
};

const filterCategories = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    if (val === '') {
      filteredCategoryNames.value = [...categoryNames.value];
      return;
    }
    const needle = val.toLowerCase();
    filteredCategoryNames.value = categoryNames.value.filter((item) =>
      item.toLowerCase().includes(needle),
    );
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

const onLoadMore = async (index: number, done: (stop?: boolean) => void) => {
  if (!shopSlug.value || accessDenied.value || notFound.value) {
    done(true);
    return;
  }

  const limit = shopStorefrontStore.pageSize;
  const offset = (index - 1) * limit;

  const result = await shopStorefrontStore.fetchCatalog(shopSlug.value, {
    search: search.value || null,
    category: category.value || null,
    brand: brand.value || null,
    limit,
    offset,
    append: index > 1,
  });

  if (result.success && 'data' in result) {
    const loadedCount = result.data?.data?.length ?? 0;
    const total = shopStorefrontStore.totalItems;
    const currentTotal = shopStorefrontStore.catalogItems.length;
    const hasMore = loadedCount > 0 && currentTotal < total;
    done(!hasMore);
  } else {
    done(true);
  }
};

const onResetFilters = () => {
  suppressFilterWatch.value = true;
  try {
    search.value = '';
    brand.value = null;
    category.value = null;
    filteredBrandNames.value = [...brandNames.value];
    filteredCategoryNames.value = [...categoryNames.value];
    shopStorefrontStore.catalogItems = [];
    resetInfiniteScroll();
  } finally {
    suppressFilterWatch.value = false;
  }
};

const getMinQty = (item: any) => {
  if (shopStorefrontStore.shopDetails?.shop_type === 'dropship') {
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

const onAddToCart = async (item: any) => {
  if (!shopStorefrontStore.shopDetails) return;
  const key = itemKey(item);
  const qty = selectedQuantities[key] || getMinQty(item);
  const result = await shopCartStore.addItem(
    shopStorefrontStore.shopDetails.id,
    item.product_id,
    item.global_stock_allocation_id,
    qty,
  );
  if (result.success) {
    delete selectedQuantities[key];
  }
};

const goToCart = () => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push(`${tenantSlug}/shop/cart`);
};

const cartItemFor = (catalogItem: any) => {
  return shopCartStore.items.find(
    (cartItem) =>
      cartItem.product_id === catalogItem.product_id &&
      cartItem.global_stock_allocation_id === catalogItem.global_stock_allocation_id,
  );
};

const isInCart = (catalogItem: any) => {
  return !!cartItemFor(catalogItem);
};

const onRemoveFromCart = async (catalogItem: any) => {
  const cartItem = cartItemFor(catalogItem);
  if (!cartItem) return;
  await shopCartStore.removeItem(cartItem.id);
};

const onSearchClick = () => {
  shopStorefrontStore.catalogItems = [];
  resetInfiniteScroll();
};

watch([category, brand], () => {
  if (suppressFilterWatch.value) return;
  shopStorefrontStore.catalogItems = [];
  resetInfiniteScroll();
});

onMounted(async () => {
  try {
    const result = await shopStorefrontStore.fetchCatalog(shopSlug.value, {
      limit: shopStorefrontStore.pageSize,
      offset: 0,
    });

    if (!result.success) {
      if (result.error?.includes('access denied')) {
        accessDenied.value = true;
      } else {
        notFound.value = true;
      }
      return;
    }

    // Fetch active cart for this shop
    if (shopStorefrontStore.shopDetails) {
      localStorage.setItem('last_visited_shop_id', String(shopStorefrontStore.shopDetails.id));
      localStorage.setItem('last_visited_shop_slug', shopStorefrontStore.shopDetails.slug);
      await shopCartStore.fetchCart(shopStorefrontStore.shopDetails.id);
    }

    const vendorCode = shopStorefrontStore.shopDetails?.vendor_code;
    const tenantId = shopStorefrontStore.shopDetails?.tenant_id || authStore.tenantId;
    await Promise.all([loadBrands(vendorCode, tenantId), loadCategories(vendorCode, tenantId)]);
  } catch {
    notFound.value = true;
  } finally {
    initialLoading.value = false;
  }
});
</script>

<style scoped>
.storefront-page {
  background: transparent;
}
.hero-surface {
  border-radius: 16px;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 82%, transparent);
}

/* —— Desktop / tablet: vertical cards —— */
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
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.35;
  min-height: 2.7em;
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
    -webkit-line-clamp: 2;
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
