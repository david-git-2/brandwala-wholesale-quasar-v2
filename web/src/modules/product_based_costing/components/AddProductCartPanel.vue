<template>
  <div
    class="add-product-cart-panel column no-wrap col"
    :class="{ 'add-product-cart-panel--drawer': layout === 'drawer' }"
  >
    <div class="add-product-cart-page__top bg-white border-bottom q-px-sm q-py-xs shrink-0">
      <div class="row items-center no-wrap q-col-gutter-x-sm">
        <q-input
          v-model="browseSearch"
          :placeholder="$t('product_based_costing.search_name_barcode_code')"
          outlined
          dense
          hide-bottom-space
          clearable
          clear-value=""
          debounce="300"
          class="add-product-cart-page__search min-width-0 col"
          @clear="onClearSearch"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" size="14px" />
          </template>
        </q-input>
        <q-badge
          v-if="itemsOnFileCount > 0"
          color="primary"
          class="q-mr-xs shrink-0"
          :label="String(itemsOnFileCount)"
        />
        <q-btn
          flat
          dense
          no-caps
          icon="ph ph-funnel"
          color="grey-7"
          size="sm"
          class="add-product-cart-page__filter-btn shrink-0"
          :label="$t('product_based_costing.filters')"
          @click="openFilterSidebar"
        >
          <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
            {{ activeFilterCount }}
          </q-badge>
        </q-btn>
      </div>
    </div>

    <div
      ref="scrollContainerRef"
      class="add-product-cart-page__body col q-px-sm q-py-sm scroll min-height-0"
      @scroll="onScrollLoad"
    >
      <AddProductCartSkeleton v-if="showInitialSkeleton" />

      <q-banner v-else-if="!isLoading && products.length === 0" class="bg-grey-2 text-grey-8 rounded-borders">
        {{ $t('product_based_costing.no_products_found') }}
      </q-banner>

      <div v-else class="add-product-cart-page__grid">
        <AddProductCartCard
          v-for="product in products"
          :key="product.id"
          :product="product"
          :is-on-file="isAlreadyOnFile(product)"
          :loading="actionProductId === product.id"
          :disabled="createMutation.isPending.value || deleteMutation.isPending.value"
          @add="onAddToCart"
          @remove="onRemoveFromFile"
        />
      </div>

      <div v-if="isFetchingMore" class="row justify-center q-py-md">
        <q-spinner color="primary" size="28px" />
      </div>
    </div>

    <FilterSidebar
      v-model="filterDrawerOpen"
      :title="$t('product_based_costing.filters')"
      :z-index="filterSidebarZIndex"
    >
      <div class="column q-gutter-y-md">
        <q-select
          v-model="draftVendorId"
          :options="vendorOptions"
          :label="$t('product_based_costing.vendor')"
          filled
          dense
          emit-value
          map-options
          clearable
          popup-content-class="add-product-cart-filter-menu"
          @update:model-value="onDraftVendorSelect"
        />

        <q-select
          v-model="draftBrand"
          :options="brandOptions"
          :label="$t('product_based_costing.table_col_brand')"
          filled
          dense
          use-input
          fill-input
          hide-selected
          clearable
          new-value-mode="add-unique"
          popup-content-class="add-product-cart-filter-menu"
          @filter="filterBrands"
        />

        <q-select
          v-model="draftCategory"
          :options="categoryOptions"
          :label="$t('product_based_costing.category')"
          filled
          dense
          use-input
          fill-input
          hide-selected
          clearable
          new-value-mode="add-unique"
          popup-content-class="add-product-cart-filter-menu"
          @filter="filterCategories"
        />
      </div>

      <template #footer>
        <div class="row justify-end q-gutter-x-sm">
          <q-btn
            flat
            no-caps
            :label="$t('product_based_costing.reset')"
            color="grey-7"
            @click="onResetFilters"
          />
          <q-btn
            unelevated
            no-caps
            :label="$t('product_based_costing.apply_filters')"
            color="primary"
            @click="onApplyFilters"
          />
        </div>
      </template>
    </FilterSidebar>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import AddProductCartCard from './AddProductCartCard.vue';
import AddProductCartSkeleton from './AddProductCartSkeleton.vue';
import { useProductBasedCostingItemsQuery } from '../composables/useProductBasedCostingItemsQuery';
import { useProductBasedCostingFileDetailQuery } from '../composables/useProductBasedCostingFileDetailQuery';
import {
  useCreateProductBasedCostingItemMutation,
  useDeleteProductBasedCostingItemMutation,
} from '../composables/useProductBasedCostingItemMutations';
import { useProductsInfiniteListQuery } from 'src/modules/products/composables/useProductQuery';
import { productService } from 'src/modules/products/services/productService';
import type { Product } from 'src/modules/products/types';
import type { ProductBasedCostingItem } from '../types';

const props = withDefaults(
  defineProps<{
    fileId: number;
    layout?: 'drawer' | 'page';
    filterSidebarZIndex?: number;
  }>(),
  {
    layout: 'page',
    filterSidebarZIndex: 7000,
  },
);

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const createMutation = useCreateProductBasedCostingItemMutation();
const deleteMutation = useDeleteProductBasedCostingItemMutation();

const PAGE_SIZE = 24;

const fileIdRef = computed(() => props.fileId);
const { data: fileItems } = useProductBasedCostingItemsQuery(fileIdRef);
const { data: fileDetail } = useProductBasedCostingFileDetailQuery(fileIdRef);
const itemsOnFileCount = computed(() => fileItems.value?.length ?? 0);

const browseSearch = ref('');
const browseSearchQuery = computed(() => (browseSearch.value ?? '').trim());
const browseSearchField = ref<'name' | 'barcode' | 'product_code'>('name');

const filterDrawerOpen = ref(false);
const filterVendorId = ref<number | null>(null);
const filterBrand = ref('');
const filterCategory = ref('');

const draftVendorId = ref<number | null>(null);
const draftBrand = ref('');
const draftCategory = ref('');

const allBrands = ref<string[]>([]);
const allCategories = ref<string[]>([]);
const brandOptions = ref<string[]>([]);
const categoryOptions = ref<string[]>([]);

const actionProductId = ref<number | null>(null);
const scrollContainerRef = ref<HTMLElement | null>(null);

const vendorOptions = computed(() =>
  vendorStore.items.map((v) => ({ label: v.name, value: v.id })),
);

const vendorCode = computed(() => {
  if (!filterVendorId.value) return undefined;
  return vendorStore.items.find((v) => v.id === filterVendorId.value)?.code ?? undefined;
});

const activeFilterCount = computed(() => {
  let count = 0;
  if (filterVendorId.value) count++;
  if (filterBrand.value) count++;
  if (filterCategory.value) count++;
  return count;
});

const listQueryParams = computed(() => ({
  pageSize: PAGE_SIZE,
  search: browseSearchQuery.value || null,
  searchField: browseSearchField.value,
  category: filterCategory.value || null,
  brand: filterBrand.value || null,
  tenantId: authStore.tenantId ?? null,
  vendorCode: vendorCode.value ?? null,
  isAvailable: true,
}));

const {
  products,
  hasMore,
  isLoading,
  isFetching,
  isFetchingNextPage,
  fetchNextPage,
} = useProductsInfiniteListQuery(listQueryParams);

watch(browseSearch, (newVal) => {
  const query = (newVal || '').trim();
  if (query) {
    let detectedField: 'name' | 'barcode' | 'product_code' | null = null;
    if (/^\d{6,}$/.test(query)) {
      detectedField = 'barcode';
    } else if (/^[A-Za-z0-9\-_]{3,}$/.test(query) && /\d/.test(query) && /[A-Za-z]/.test(query)) {
      detectedField = 'product_code';
    }

    if (detectedField && browseSearchField.value !== detectedField) {
      browseSearchField.value = detectedField;
      return;
    }
  }

  resetScrollPosition();
});

watch(browseSearchField, () => {
  resetScrollPosition();
});

watch([filterBrand, filterCategory, filterVendorId], () => {
  resetScrollPosition();
});

const showInitialSkeleton = computed(
  () => isLoading.value && products.value.length === 0,
);
const isFetchingMore = computed(() => isFetchingNextPage.value);

watch(
  [products, hasMore, isFetching],
  () => {
    void nextTick(() => {
      onScrollLoad();
    });
  },
);

const getFileItems = (): ProductBasedCostingItem[] => fileItems.value ?? [];

const matchesProductOnFile = (item: ProductBasedCostingItem, product: Product) => {
  if (item.product_id != null && item.product_id === product.id) return true;

  const itemCode = item.product_code?.trim();
  const productCode = product.product_code?.trim();
  if (itemCode && productCode) {
    return itemCode === productCode;
  }

  const itemBarcode = item.barcode?.trim();
  const productBarcode = product.barcode?.trim();
  if (itemBarcode && productBarcode && itemBarcode === productBarcode) {
    return !itemCode && !productCode;
  }

  return false;
};

const isAlreadyOnFile = (product: Product) => {
  return getFileItems().some((item) => matchesProductOnFile(item, product));
};

const getFileItemForProduct = (product: Product): ProductBasedCostingItem | undefined => {
  return getFileItems().find((item) => matchesProductOnFile(item, product));
};

const getVendorCode = (vendorId: number | null): string | null => {
  if (!vendorId) return null;
  return vendorStore.items.find((v) => v.id === vendorId)?.code ?? null;
};

const openFilterSidebar = () => {
  draftVendorId.value = filterVendorId.value;
  draftBrand.value = filterBrand.value;
  draftCategory.value = filterCategory.value;
  filterDrawerOpen.value = true;
  void onDraftVendorChange(filterVendorId.value, { preserveSelections: true });
};

const onDraftVendorSelect = (vendorId: number | null) => {
  void onDraftVendorChange(vendorId);
};

const syncBrandCategoryOptions = () => {
  brandOptions.value = [...allBrands.value];
  categoryOptions.value = [...allCategories.value];
};

const onDraftVendorChange = async (
  vendorId: number | null,
  options?: { preserveSelections?: boolean },
) => {
  const preserveSelections = options?.preserveSelections ?? false;
  const savedBrand = preserveSelections ? draftBrand.value : '';
  const savedCategory = preserveSelections ? draftCategory.value : '';

  if (!preserveSelections) {
    draftBrand.value = '';
    draftCategory.value = '';
  }

  allBrands.value = [];
  allCategories.value = [];
  brandOptions.value = [];
  categoryOptions.value = [];

  if (!vendorId) return;

  const code = getVendorCode(vendorId);
  const tenantId = authStore.tenantId;
  if (typeof tenantId !== 'number') return;

  const [brandsRes, catsRes] = await Promise.all([
    productService.listBrands({ vendorCode: code, tenantId }),
    productService.listCategories({ vendorCode: code, tenantId }),
  ]);

  if (brandsRes.success && brandsRes.data) {
    allBrands.value = brandsRes.data;
  }
  if (catsRes.success && catsRes.data) {
    allCategories.value = catsRes.data;
  }

  syncBrandCategoryOptions();

  if (preserveSelections) {
    draftBrand.value = savedBrand;
    draftCategory.value = savedCategory;
  }
};

const filterBrands = (val: string, update: (callback: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim();
    brandOptions.value = needle
      ? allBrands.value.filter((v) => v.toLowerCase().includes(needle))
      : allBrands.value;
  });
};

const filterCategories = (val: string, update: (callback: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim();
    categoryOptions.value = needle
      ? allCategories.value.filter((v) => v.toLowerCase().includes(needle))
      : allCategories.value;
  });
};

const onApplyFilters = () => {
  filterVendorId.value = draftVendorId.value;
  filterBrand.value = draftBrand.value;
  filterCategory.value = draftCategory.value;
  filterDrawerOpen.value = false;
  resetScrollPosition();
};

const onResetFilters = () => {
  draftVendorId.value = null;
  draftBrand.value = '';
  draftCategory.value = '';
  filterVendorId.value = null;
  filterBrand.value = '';
  filterCategory.value = '';
  filterDrawerOpen.value = false;
  resetScrollPosition();
};

const onClearSearch = () => {
  browseSearch.value = '';
  resetScrollPosition();
};

const loadMore = () => {
  if (!hasMore.value || isFetching.value) return;
  void fetchNextPage();
};

const onScrollLoad = () => {
  const el = scrollContainerRef.value;
  if (!el || !hasMore.value || isFetching.value) return;

  const thresholdPx = 240;
  if (el.scrollTop + el.clientHeight >= el.scrollHeight - thresholdPx) {
    loadMore();
  }
};

const resetScrollPosition = () => {
  if (scrollContainerRef.value) {
    scrollContainerRef.value.scrollTop = 0;
  }
};

const onAddToCart = async (product: Product) => {
  if (isAlreadyOnFile(product) || !props.fileId) return;

  actionProductId.value = product.id;
  try {
    await createMutation.mutateAsync({
      silentSuccessNotification: true,
      name: product.name || '',
      brand: product.brand || null,
      image_url: product.image_url || '',
      quantity: 1,
      barcode: product.barcode || '',
      product_code: product.product_code || '',
      vendor_code: product.vendor_code || null,
      market_code: product.market_code || null,
      price_gbp: product.list_price_amount || 0,
      product_weight: product.product_weight || 0,
      web_link: '',
      package_weight: product.package_weight || 0,
      product_based_costing_file_id: props.fileId,
      product_id: product.id,
      input_type: 'product_list',
    });
  } finally {
    actionProductId.value = null;
  }
};

const onRemoveFromFile = async (product: Product) => {
  const fileItem = getFileItemForProduct(product);
  if (!fileItem?.id) return;

  actionProductId.value = product.id;
  try {
    await deleteMutation.mutateAsync({
      id: fileItem.id,
      fileId: props.fileId,
      silentSuccessNotification: true,
    });
  } finally {
    actionProductId.value = null;
  }
};

const syncFilterVendorFromFile = () => {
  if (filterVendorId.value != null) return;
  const code = fileDetail.value?.vendor_code?.trim();
  if (!code) return;
  const vendor = vendorStore.items.find((v) => v.code === code);
  if (!vendor) return;
  filterVendorId.value = vendor.id;
  draftVendorId.value = vendor.id;
};

watch(
  [fileDetail, () => vendorStore.items.length],
  () => {
    syncFilterVendorFromFile();
  },
  { immediate: true },
);

onMounted(() => {
  void ensureVendorsLoaded();
});

watch(
  () => authStore.tenantId,
  () => {
    void ensureVendorsLoaded();
  },
);

async function ensureVendorsLoaded() {
  const tenantId = authStore.tenantId;
  if (typeof tenantId !== 'number') return;
  if (vendorStore.items.length > 0) {
    syncFilterVendorFromFile();
    return;
  }
  await vendorStore.fetchVendors(tenantId);
  syncFilterVendorFromFile();
}
</script>

<style scoped>
.add-product-cart-panel {
  min-height: 0;
}

.add-product-cart-panel--drawer {
  background: var(--tf-theme-base, var(--tf-disabled-bg));
}

.add-product-cart-panel--drawer .add-product-cart-page__search {
  max-width: none;
}

.border-bottom {
  border-bottom: 1px solid var(--tf-neutral-border);
}

.add-product-cart-page__search {
  flex: 1 1 auto;
  max-width: 220px;
}

.add-product-cart-page__search :deep(.q-field__control) {
  min-height: 30px;
  height: 30px;
}

.add-product-cart-page__search :deep(.q-field__marginal) {
  height: 30px;
}

.add-product-cart-page__search :deep(.q-field__native) {
  font-size: 12px;
}

.add-product-cart-page__filter-btn {
  font-size: 12px;
  font-weight: 600;
  padding: 0 6px;
}

.add-product-cart-page__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 1rem;
}

@media (max-width: 599px) {
  .add-product-cart-page__search {
    max-width: none;
  }

  .add-product-cart-page__grid {
    grid-template-columns: 1fr;
  }
}
</style>

<style>
.add-product-cart-filter-menu {
  z-index: 7200 !important;
}
</style>
