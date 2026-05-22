<template>
  <q-page class="q-pa-md products-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Products</div>
            <div class="text-caption text-grey-8">Browse product previews and open details</div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <div class="row items-center justify-between q-mb-md">
      <div class="row items-center q-gutter-sm toolbar-left">
        <q-btn
          v-if="!showSearchInput"
          flat
          round
          dense
          icon="search"
          aria-label="Show search"
          @click="showSearchInput = true"
        />
        <q-input
          v-else
          v-model="search"
          filled
          dense
          clearable
          class="soft-input toolbar-search"
          label="Search"
          @keyup.enter="onApplyFilters"
          @clear="onApplyFilters"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
          <template #append>
            <q-btn flat round dense icon="close" aria-label="Hide search" @click="onCloseSearch" />
          </template>
        </q-input>

        <q-btn flat round dense icon="filter_alt" aria-label="Filters" @click="filterDrawerOpen = true">
          <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
            {{ activeFilterCount }}
          </q-badge>
        </q-btn>
      </div>
    </div>

    <PageInitialLoader v-if="productStore.loading" />

    <div v-else-if="productStore.error" class="text-negative">
      error: {{ productStore.error }}
    </div>

    <q-banner v-else-if="!productStore.items.length" class="bg-grey-2 text-grey-8">
      No products found.
    </q-banner>

    <div v-else class="row q-col-gutter-md products-card-grid">
      <div v-for="product in productStore.items" :key="product.id" class="products-card-item">
        <q-card flat class="floating-surface shadow-1 product-card">
          <div class="product-image-wrap cursor-pointer" @click="openDetails(product.id)">
            <SmartImage
              :src="product.image_url"
              :alt="product.name ?? 'Product image'"
              imgClass="product-image"
              fallbackClass="product-image-fallback"
            />
          </div>

          <q-card-section class="q-pt-sm q-pb-sm">
            <div class="text-subtitle2 text-weight-medium product-name cursor-pointer" @click="openDetails(product.id)">
              {{ product.name ?? '-' }}
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <div v-if="totalPages > 1" class="row justify-center q-mt-md">
      <q-pagination
        v-model="page"
        :max="totalPages"
        :max-pages="8"
        boundary-numbers
        direction-links
        @update:model-value="onPageChange"
      />
    </div>

    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-select
        v-model="searchField"
        :options="searchFieldOptions"
        filled
        dense
        emit-value
        map-options
        class="soft-input q-mb-sm"
        label="Search By"
      />
      <q-select
        v-model="brand"
        :options="brandOptions"
        filled
        dense
        emit-value
        map-options
        clearable
        class="soft-input q-mb-sm"
        label="Brand"
      />
      <q-select
        v-model="category"
        :options="categoryOptions"
        filled
        dense
        emit-value
        map-options
        clearable
        class="soft-input q-mb-sm"
        label="Category"
      />
      <q-select
        v-model="vendorCode"
        :options="vendorOptions"
        filled
        dense
        emit-value
        map-options
        clearable
        class="soft-input q-mb-sm"
        label="Vendor"
      />
      <q-select
        v-model="marketCode"
        :options="marketOptions"
        filled
        dense
        emit-value
        map-options
        clearable
        class="soft-input q-mb-sm"
        label="Market"
      />
      <q-select
        v-model="availability"
        :options="availabilityOptions"
        filled
        dense
        emit-value
        map-options
        class="soft-input q-mb-md"
        label="Availability"
      />
      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" @click="onResetFilters" />
        <q-btn flat no-caps label="Apply" @click="onApplyDrawerFilters" />
      </div>
    </FilterSidebar>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import SmartImage from 'src/components/SmartImage.vue'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useMarketStore } from 'src/modules/market/stores/marketStore'
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { productService } from '../services/productService'
import { useProductStore } from '../stores/productStore'

const router = useRouter()
const authStore = useAuthStore()
const productStore = useProductStore()
const vendorStore = useVendorStore()
const marketStore = useMarketStore()

const page = ref(1)
const showSearchInput = ref(false)
const filterDrawerOpen = ref(false)
const search = ref('')
const searchField = ref<'name' | 'barcode' | 'product_code' | 'id'>('name')
const brand = ref<string | null>(null)
const category = ref<string | null>(null)
const vendorCode = ref<string | null>(null)
const marketCode = ref<string | null>(null)
const availability = ref<'all' | 'available' | 'unavailable'>('all')
const brands = ref<string[]>([])
const categories = ref<string[]>([])

const searchFieldOptions = [
  { label: 'Name', value: 'name' },
  { label: 'Barcode', value: 'barcode' },
  { label: 'Product Code', value: 'product_code' },
  { label: 'Product ID', value: 'id' },
]

const availabilityOptions = [
  { label: 'All', value: 'all' },
  { label: 'Available', value: 'available' },
  { label: 'Unavailable', value: 'unavailable' },
]

const brandOptions = computed(() => brands.value.map((item) => ({ label: item, value: item })))
const categoryOptions = computed(() => categories.value.map((item) => ({ label: item, value: item })))
const vendorOptions = computed(() => vendorStore.items.map((item) => ({ label: `${item.name} (${item.code})`, value: item.code })))
const marketOptions = computed(() => marketStore.items.map((item) => ({ label: `${item.name} (${item.code})`, value: item.code })))
const totalPages = computed(() => Math.max(1, Math.ceil(productStore.total / productStore.pageSize)))
const activeFilterCount = computed(() => {
  let count = 0
  if (searchField.value !== 'name') count += 1
  if (brand.value) count += 1
  if (category.value) count += 1
  if (vendorCode.value) count += 1
  if (marketCode.value) count += 1
  if (availability.value !== 'all') count += 1
  return count
})

const loadProducts = async () => {
  await productStore.fetchProducts({
    page: page.value,
    pageSize: productStore.pageSize,
    search: search.value,
    searchField: searchField.value,
    brand: brand.value,
    category: category.value,
    vendorCode: vendorCode.value,
    marketCode: marketCode.value,
    isAvailable:
      availability.value === 'all'
        ? null
        : availability.value === 'available',
    tenantId: authStore.tenantId ?? null,
  })
}

const onApplyFilters = async () => {
  page.value = 1
  await loadProducts()
}

const onResetFilters = async () => {
  search.value = ''
  searchField.value = 'name'
  brand.value = null
  category.value = null
  vendorCode.value = null
  marketCode.value = null
  availability.value = 'all'
  page.value = 1
  await loadProducts()
}

const onApplyDrawerFilters = async () => {
  filterDrawerOpen.value = false
  await onApplyFilters()
}

const onCloseSearch = async () => {
  search.value = ''
  showSearchInput.value = false
  await onApplyFilters()
}

const onPageChange = async (nextPage: number) => {
  page.value = nextPage
  await loadProducts()
}

const openDetails = async (productId: number) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/products/${productId}`)
}

onMounted(async () => {
  const [brandResult, categoryResult] = await Promise.all([
    productService.listBrands({ tenantId: authStore.tenantId ?? null }),
    productService.listCategories({ tenantId: authStore.tenantId ?? null }),
    vendorStore.fetchVendors(authStore.tenantId ?? null),
    marketStore.fetchMarkets(),
  ])

  if (brandResult.success) {
    brands.value = brandResult.data ?? []
  }
  if (categoryResult.success) {
    categories.value = categoryResult.data ?? []
  }

  await loadProducts()
})
</script>

<style scoped>
.products-page {
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

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.product-card {
  width: 200px;
  height: 100%;
  min-height: 260px;
}

.products-card-grid {
  justify-content: center;
  row-gap: 16px;
  column-gap: 16px;
}

.products-card-item {
  width: 200px;
  max-width: 200px;
  flex: 0 0 200px;
}

.product-image-wrap {
  height: 190px;
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
  background: #fff;
}

.product-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
}

.product-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #eef2f6;
}

.product-name {
  min-height: 38px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.toolbar-left {
  min-width: 0;
}

.toolbar-search {
  width: min(320px, 75vw);
}
</style>
