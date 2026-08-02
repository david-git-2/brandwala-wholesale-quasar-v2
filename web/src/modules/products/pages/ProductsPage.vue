<template>
  <q-page class="q-pa-md products-page">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <ProductHeader
        @open-bulk-import="bulkImportDialogOpen = true"
        @open-create-dialog="openCreateDialog"
      />

      <!-- Toolbar Card -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-auto row items-center q-gutter-sm toolbar-left">
            <q-btn
              v-if="!showSearchInput"
              flat
              round
              dense
              icon="ph ph-magnifying-glass"
              aria-label="Show search"
              @click="showSearchInput = true"
            />
            <q-input
              v-else
              v-model="search"
              outlined
              dense
              clearable
              class="soft-input toolbar-search"
              label="Search"
              @keyup.enter="onApplyFilters"
              @clear="onApplyFilters"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
              <template #append>
                <q-btn flat round dense icon="ph ph-x" aria-label="Hide search" @click="onCloseSearch" />
              </template>
            </q-input>

            <q-btn
              flat
              round
              dense
              icon="ph ph-funnel"
              aria-label="Filters"
              @click="filterDrawerOpen = true"
            >
              <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
                {{ activeFilterCount }}
              </q-badge>
            </q-btn>
          </div>
        </div>
      </q-card>

      <!-- Skeleton Loader -->
      <ProductSkeleton v-if="isProductsLoading" />

      <!-- Loaded Product Grid -->
      <ProductGrid
        v-else
        :products="productItems"
        :is-loading="false"
        :error="productsError"
        :page="page"
        :total-pages="totalPages"
        @update:page="onPageChange"
        @select-product="openDetails"
      />

      <ProductFilterDrawer
        v-model:open="filterDrawerOpen"
        v-model:search-field="searchField"
        v-model:brand="brand"
        v-model:category="category"
        v-model:vendor-code="vendorCode"
        v-model:market-code="marketCode"
        v-model:availability="availability"
        :search-field-options="searchFieldOptions"
        :brand-options="brandOptions"
        :category-options="categoryOptions"
        :vendor-options="vendorOptions"
        :market-options="marketOptions"
        :availability-options="availabilityOptions"
        @apply="onApplyDrawerFilters"
        @reset="onResetFilters"
        @vendor-change="onFilterVendorChange"
      />

      <!-- Add Product Dialog -->
      <ProductCreateDialog
        v-model="createDialogOpen"
        :currencies="currencies"
        @success="onApplyFilters"
      />

      <!-- Bulk Import Dialog -->
      <BulkImportDialog v-model="bulkImportDialogOpen" @success="onApplyFilters" />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import BulkImportDialog from '../components/BulkImportDialog.vue';
import ProductHeader from '../components/ProductHeader.vue';
import ProductGrid from '../components/ProductGrid.vue';
import ProductSkeleton from '../components/ProductSkeleton.vue';
import ProductFilterDrawer from '../components/ProductFilterDrawer.vue';
import ProductCreateDialog from '../components/ProductCreateDialog.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalMarketsQuery, useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import {
  useProductsListQuery,
  useProductBrandsQuery,
  useProductCategoriesQuery,
} from '../composables/useProductQuery';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const vendorStore = useVendorStore();
const { data: marketsData } = useGlobalMarketsQuery();
const { data: currenciesData } = useGlobalCurrenciesQuery();

const page = ref(1);
const pageSize = ref(20);
const showSearchInput = ref(false);
const filterDrawerOpen = ref(false);
const bulkImportDialogOpen = ref(false);
const createDialogOpen = ref(false);
const search = ref('');
const searchField = ref<'name' | 'barcode' | 'product_code' | 'id'>('name');
const brand = ref<string | null>(null);
const category = ref<string | null>(null);
const vendorCode = ref<string | null>(null);
const marketCode = ref<string | null>(null);
const availability = ref<'all' | 'available' | 'unavailable'>('all');

// --- Query parameters for products list ---
const queryParams = computed(() => ({
  page: page.value,
  pageSize: pageSize.value,
  search: search.value || null,
  searchField: searchField.value,
  brand: brand.value || null,
  category: category.value || null,
  vendorCode: vendorCode.value || null,
  marketCode: marketCode.value || null,
  isAvailable: availability.value === 'all' ? null : availability.value === 'available',
  tenantId: authStore.tenantId ?? null,
}));

// --- TanStack Query for product listing ---
const {
  data: productsResult,
  isLoading: isProductsLoading,
  error: productsError,
} = useProductsListQuery(queryParams);

const productItems = computed(() => productsResult.value?.data ?? []);
const totalProducts = computed(() => productsResult.value?.meta?.total ?? 0);
const totalPages = computed(() =>
  Math.max(1, Math.ceil(totalProducts.value / pageSize.value)),
);

// --- Filter lookups via TanStack Query ---
const filterLookupParams = computed(() => ({
  vendorCode: vendorCode.value,
  tenantId: authStore.tenantId ?? null,
}));

const { data: filterBrandsData } = useProductBrandsQuery(filterLookupParams);
const { data: filterCategoriesData } = useProductCategoriesQuery(filterLookupParams);

const brands = computed(() => filterBrandsData.value ?? []);
const categories = computed(() => filterCategoriesData.value ?? []);

const currencies = computed(() =>
  (currenciesData.value ?? [])
    .filter((c) => c.is_active)
    .map((c) => ({ label: `${c.code} (${c.symbol})`, value: c.id })),
);

const searchFieldOptions = [
  { label: 'Name', value: 'name' as const },
  { label: 'Barcode', value: 'barcode' as const },
  { label: 'Product Code', value: 'product_code' as const },
  { label: 'Product ID', value: 'id' as const },
];

const availabilityOptions = [
  { label: 'All', value: 'all' as const },
  { label: 'Available', value: 'available' as const },
  { label: 'Unavailable', value: 'unavailable' as const },
];

const brandOptions = computed(() => brands.value.map((item) => ({ label: item, value: item })));
const categoryOptions = computed(() =>
  categories.value.map((item) => ({ label: item, value: item })),
);
const vendorOptions = computed(() =>
  vendorStore.items.map((item) => ({ label: `${item.name} (${item.code})`, value: item.code })),
);
const marketOptions = computed(() =>
  (marketsData.value ?? []).map((item) => ({ label: `${item.name} (${item.code})`, value: item.code })),
);

const activeFilterCount = computed(() => {
  let count = 0;
  if (searchField.value !== 'name') count += 1;
  if (brand.value) count += 1;
  if (category.value) count += 1;
  if (vendorCode.value) count += 1;
  if (marketCode.value) count += 1;
  if (availability.value !== 'all') count += 1;
  return count;
});

const updateUrlQuery = () => {
  void router.replace({
    query: {
      page: page.value > 1 ? String(page.value) : undefined,
      search: search.value || undefined,
      searchField: searchField.value !== 'name' ? searchField.value : undefined,
      brand: brand.value || undefined,
      category: category.value || undefined,
      vendorCode: vendorCode.value || undefined,
      marketCode: marketCode.value || undefined,
      availability: availability.value !== 'all' ? availability.value : undefined,
    },
  });
};

watch(queryParams, () => {
  updateUrlQuery();
});

const onApplyFilters = () => {
  page.value = 1;
};

const onFilterVendorChange = () => {
  brand.value = null;
  category.value = null;
};

const onResetFilters = () => {
  search.value = '';
  searchField.value = 'name';
  brand.value = null;
  category.value = null;
  vendorCode.value = null;
  marketCode.value = null;
  availability.value = 'all';
  page.value = 1;
};

const onApplyDrawerFilters = () => {
  filterDrawerOpen.value = false;
  onApplyFilters();
};

const onCloseSearch = () => {
  search.value = '';
  showSearchInput.value = false;
  onApplyFilters();
};

const onPageChange = (nextPage: number) => {
  page.value = nextPage;
};

const openDetails = async (productId: number) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : '';
  await router.push(`${tenantPrefix}/app/products/${productId}`);
};

const openCreateDialog = () => {
  createDialogOpen.value = true;
};

const initializeFiltersFromQuery = () => {
  const query = route.query;

  if (query.page) {
    const parsedPage = Number(query.page);
    if (!isNaN(parsedPage) && parsedPage > 0) {
      page.value = parsedPage;
    }
  }

  if (query.search) {
    search.value = String(query.search);
    showSearchInput.value = true;
  }

  if (query.searchField) {
    const val = String(query.searchField);
    if (val === 'name' || val === 'barcode' || val === 'product_code' || val === 'id') {
      searchField.value = val;
    }
  }

  if (query.brand) {
    brand.value = String(query.brand);
  }

  if (query.category) {
    category.value = String(query.category);
  }

  if (query.vendorCode) {
    vendorCode.value = String(query.vendorCode);
  }

  if (query.marketCode) {
    marketCode.value = String(query.marketCode);
  }

  if (query.availability) {
    const val = String(query.availability);
    if (val === 'all' || val === 'available' || val === 'unavailable') {
      availability.value = val;
    }
  }
};

onMounted(() => {
  initializeFiltersFromQuery();
  void vendorStore.fetchVendors(authStore.tenantId ?? null);
});
</script>

<style scoped>
.products-page {
  background: transparent;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.toolbar-left {
  min-width: 0;
}

.toolbar-search {
  width: min(320px, 75vw);
}

@media (max-width: 599px) {
  .products-page {
    padding: 4px !important;
  }
}
</style>
