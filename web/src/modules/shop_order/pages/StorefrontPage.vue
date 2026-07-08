<template>
  <q-page class="q-pa-md storefront-page">
    <!-- ACCESS DENIED STATE -->
    <div
      v-if="accessDenied"
      class="column items-center justify-center error-container text-center q-pa-xl"
    >
      <q-icon name="gpp_bad" size="80px" color="negative" class="q-mb-md" />
      <div class="text-h5 text-weight-bold text-grey-9">Access Denied</div>
      <p class="text-body1 text-grey-6 q-mt-sm q-mb-lg" style="max-width: 400px">
        You do not have permission to access this shop. Please contact your administrator.
      </p>
      <q-btn color="primary" no-caps label="Go Back" class="pill-btn" @click="goBack" />
    </div>

    <!-- NOT FOUND STATE -->
    <div
      v-else-if="notFound"
      class="column items-center justify-center error-container text-center q-pa-xl"
    >
      <q-icon name="search_off" size="80px" color="warning" class="q-mb-md" />
      <div class="text-h5 text-weight-bold text-grey-9">Shop Not Found</div>
      <p class="text-body1 text-grey-6 q-mt-sm q-mb-lg" style="max-width: 400px">
        The shop you are trying to browse could not be found or is inactive.
      </p>
      <q-btn color="primary" no-caps label="Go Back" class="pill-btn" @click="goBack" />
    </div>

    <!-- INITIAL LOADING SKELETON -->
    <div v-else-if="initialLoading" class="storefront-loading">
      <q-card flat class="q-mb-md floating-surface hero-surface shadow-1 q-pa-md">
        <q-skeleton type="text" width="180px" height="28px" />
        <q-skeleton type="text" width="280px" class="q-mt-xs" />
      </q-card>
      <div class="row q-col-gutter-md">
        <div v-for="n in 8" :key="n" class="col-xs-12 col-sm-6 col-md-4 col-lg-3">
          <q-card flat bordered class="product-card-sk">
            <q-skeleton type="rect" height="200px" />
            <q-card-section>
              <q-skeleton type="text" width="80%" />
              <q-skeleton type="text" width="50%" class="q-mt-xs" />
              <q-skeleton type="text" width="30%" class="q-mt-md" />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>

    <!-- STOREFRONT MAIN CONTENT -->
    <div v-else>
      <!-- Shop Header Hero -->
      <q-card flat class="q-mb-lg floating-surface hero-surface shadow-1">
        <q-card-section class="q-py-md q-px-lg">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col">
              <div class="row items-center q-gutter-sm">
                <q-icon name="storefront" size="32px" color="primary" />
                <div>
                  <h1 class="text-h5 text-weight-bold q-my-none">
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
                    <span>•</span>
                    <span
                      >Order Mode:
                      {{ getOrderModeLabel(shopStorefrontStore.shopDetails?.order_mode) }}</span
                    >
                  </div>
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
                <q-tooltip>View Cart</q-tooltip>
              </q-btn>
              <q-btn flat round dense icon="arrow_back" color="grey-7" @click="goBack">
                <q-tooltip>Go Back</q-tooltip>
              </q-btn>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <!-- Toolbar & Search -->
      <div class="row items-center justify-between q-col-gutter-md q-mb-md">
        <!-- Search bar -->
        <div class="col-xs-12 col-sm-6 col-md-4">
          <q-input
            v-model="search"
            filled
            dense
            type="text"
            class="soft-input full-width"
            placeholder="Search products..."
            clearable
          >
            <template #prepend>
              <q-icon name="search" />
            </template>
          </q-input>
        </div>

        <!-- Filter toggles -->
        <div class="col-xs-12 col-sm-6 col-md-8 text-right row justify-end q-gutter-sm">
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
            <q-tooltip>Filters</q-tooltip>
          </q-btn>
        </div>
      </div>

      <!-- Active Filters Chips -->
      <div
        v-if="hasActiveFilters"
        class="row items-center q-gutter-xs q-mb-md active-filters-section"
      >
        <span class="text-caption text-weight-medium text-grey-7 q-mr-xs">Active Filters:</span>
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
          Brand: {{ brand }}
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
          Category: {{ category }}
        </q-chip>
        <q-btn
          flat
          dense
          no-caps
          color="primary"
          label="Clear All"
          size="sm"
          class="q-px-sm q-ml-xs text-weight-bold"
          @click="onResetFilters"
        />
      </div>

      <!-- PRODUCT GRID WITH INFINITE SCROLL -->
      <q-infinite-scroll ref="infiniteScrollRef" :offset="250" @load="onLoadMore">
        <div v-if="shopStorefrontStore.catalogItems.length > 0" class="row q-col-gutter-md">
          <div
            v-for="item in shopStorefrontStore.catalogItems"
            :key="item.product_id + '-' + (item.global_stock_allocation_id || '')"
            class="col-xs-12 col-sm-6 col-md-4 col-lg-3"
          >
            <q-card flat bordered class="product-card full-height column justify-between">
              <!-- Product Image -->
              <div class="product-image-wrapper relative-position">
                <q-img
                  :src="item.product_image_url || 'https://placehold.co/300x200?text=No+Image'"
                  :ratio="4 / 3"
                  class="product-image"
                  fit="contain"
                >
                  <template #error>
                    <div class="absolute-full flex flex-center bg-grey-3 text-grey-7">
                      No Image Available
                    </div>
                  </template>
                </q-img>
              </div>

              <!-- Product Info -->
              <q-card-section class="col q-pa-sm">
                <div class="text-caption text-grey-6 text-uppercase tracking-wider">
                  {{ item.product_brand || 'Generic' }}
                </div>
                <div class="product-name text-subtitle2 text-weight-bold text-grey-9 q-mt-xs">
                  {{ item.product_name }}
                </div>
                <div class="text-caption text-grey-7 q-mt-xs">
                  Code: {{ item.product_code || 'N/A' }}
                </div>
                <div class="text-caption text-grey-5">
                  Category: {{ item.product_category || 'N/A' }}
                </div>
              </q-card-section>

              <!-- Stock & Price section -->
              <q-card-section class="q-pa-sm q-pt-none border-top">
                <div class="row items-center justify-between q-mt-sm">
                  <!-- Price display -->
                  <div>
                    <div v-if="shopStorefrontStore.permissions?.see_price" class="column">
                      <div class="text-caption text-grey-6">Price</div>
                      <div class="text-subtitle1 text-weight-bold text-primary">
                        {{ item.unit_price_currency_symbol || '£'
                        }}{{ Number(item.unit_price_amount).toFixed(2) }}
                      </div>
                      <div v-if="item.minimum_sell_price_amount" class="text-caption text-grey-6">
                        Min Sell: {{ item.minimum_sell_price_currency_symbol || '£'
                        }}{{ Number(item.minimum_sell_price_amount).toFixed(2) }}
                      </div>
                    </div>
                    <div v-else class="text-caption text-grey-5 italic q-py-xs">Price hidden</div>
                  </div>

                  <!-- Quantity display -->
                  <div class="text-right">
                    <div
                      v-if="shopStorefrontStore.permissions?.can_view_quantity"
                      class="column items-end"
                    >
                      <div class="text-caption text-grey-6">Available</div>
                      <div
                        class="text-body2 text-weight-medium"
                        :class="item.available_units > 0 ? 'text-positive' : 'text-negative'"
                      >
                        {{
                          item.available_units !== null ? `${item.available_units} units` : 'N/A'
                        }}
                      </div>
                    </div>
                  </div>
                </div>
              </q-card-section>

              <!-- Action buttons -->
              <q-card-actions align="right" class="q-pa-sm q-pt-none">
                <q-btn
                  color="primary"
                  unelevated
                  no-caps
                  icon="shopping_cart"
                  label="Add to Cart"
                  class="full-width pill-btn"
                  :disabled="
                    !shopStorefrontStore.permissions?.can_add_to_cart ||
                    (item.available_units !== null && item.available_units <= 0)
                  "
                  @click="onAddToCart(item)"
                />
              </q-card-actions>
            </q-card>
          </div>
        </div>

        <div
          v-else-if="!shopStorefrontStore.loading"
          class="column items-center justify-center empty-state q-pa-xl text-center"
        >
          <q-icon name="o_shopping_bag" size="64px" color="grey-5" class="q-mb-md" />
          <div class="text-h6 text-weight-bold text-grey-8">No Products Found</div>
          <p class="text-body2 text-grey-6 q-mt-sm">
            There are no products matching the current criteria.
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
    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
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
          label="Brand"
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
          label="Category"
          @filter="filterCategories"
        />

        <div class="row q-gutter-sm justify-end q-mt-md">
          <q-btn flat no-caps label="Reset" color="grey-7" @click="onResetFilters" />
          <q-btn
            unelevated
            no-caps
            label="Apply"
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
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShopStorefrontStore } from '../stores/shopStorefrontStore';
import { useProductStore } from 'src/modules/products/stores/productStore';
import { useShopCartStore } from '../stores/shopCartStore';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import type { QInfiniteScroll } from 'quasar';

const route = useRoute();
const router = useRouter();
const shopStorefrontStore = useShopStorefrontStore();
const productStore = useProductStore();
const shopCartStore = useShopCartStore();

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

let searchDebounceTimer: ReturnType<typeof setTimeout> | undefined;
const suppressFilterWatch = ref(false);
const infiniteScrollRef = ref<QInfiniteScroll | null>(null);

const allBrandOption = { label: 'All brands', value: null };
const allCategoryOption = { label: 'All categories', value: null };

const filteredBrandOptions = computed(() => [
  allBrandOption,
  ...filteredBrandNames.value.map((item) => ({ label: item, value: item })),
]);

const filteredCategoryOptions = computed(() => [
  allCategoryOption,
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

const getOrderModeLabel = (mode?: string) => {
  if (mode === 'procurement_intent') return 'Procurement Intent';
  if (mode === 'checkout_fixed') return 'Fixed Checkout';
  if (mode === 'checkout_wholesale') return 'Wholesale Checkout';
  return mode || 'N/A';
};

const loadBrands = async (vendorCode?: string | null) => {
  const result = await productStore.fetchBrandOptions({
    vendorCode: vendorCode ?? null,
  });
  if (result.success) {
    brandNames.value = productStore.brandOptions;
    filteredBrandNames.value = productStore.brandOptions;
  }
};

const loadCategories = async (vendorCode?: string | null) => {
  const result = await productStore.fetchCategoryOptions({
    vendorCode: vendorCode ?? null,
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

const onAddToCart = async (item: any) => {
  if (!shopStorefrontStore.shopDetails) return;
  const result = await shopCartStore.addItem(
    shopStorefrontStore.shopDetails.id,
    item.product_id,
    item.global_stock_allocation_id,
    1,
  );
  if (result.success) {
    if (item.available_units !== null) {
      item.available_units = Math.max(0, item.available_units - 1);
    }
  }
};

const goToCart = () => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push(`${tenantSlug}/shop/cart`);
};

watch(search, () => {
  if (suppressFilterWatch.value) return;
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
  searchDebounceTimer = setTimeout(() => {
    shopStorefrontStore.catalogItems = [];
    resetInfiniteScroll();
  }, 400);
});

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
    await Promise.all([loadBrands(vendorCode), loadCategories(vendorCode)]);
  } catch {
    notFound.value = true;
  } finally {
    initialLoading.value = false;
  }
});

onBeforeUnmount(() => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
});
</script>

<style scoped>
.storefront-page {
  background: transparent;
}
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}
.hero-surface {
  border-radius: 16px;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
.product-card {
  border-radius: 16px;
  background: #ffffff;
  transition:
    transform 0.25s ease,
    box-shadow 0.25s ease;
  overflow: hidden;
}
.product-card:hover {
  transform: translateY(-4px);
  box-shadow:
    0 10px 20px rgba(34, 56, 101, 0.06),
    0 2px 6px rgba(34, 56, 101, 0.04);
}
.product-image-wrapper {
  background: #fafafa;
  border-bottom: 1px solid rgba(34, 56, 101, 0.05);
  padding: 8px;
}
.product-image {
  border-radius: 8px;
}
.product-name {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  height: 40px;
  line-height: 20px;
}
.tracking-wider {
  letter-spacing: 0.05em;
}
.border-top {
  border-top: 1px solid rgba(34, 56, 101, 0.06);
}
.empty-state {
  min-height: 320px;
  background: rgba(255, 255, 255, 0.6);
  border-radius: 16px;
  border: 1px dashed rgba(34, 56, 101, 0.12);
  backdrop-filter: blur(4px);
}
.error-container {
  min-height: 450px;
  background: rgba(255, 255, 255, 0.8);
  border-radius: 20px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.02);
}
</style>
