<template>
  <q-page class="q-pa-md costing-cart-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Product Cart</div>
            <div class="text-caption text-grey-8">Pick products for this costing file</div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat class="q-mb-md floating-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row q-col-gutter-md items-end justify-between">
          <div class="col-12 col-sm-6 col-md-5">
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
              outlined
              dense
              type="text"
              class="soft-input"
              label="Search"
              clearable
              autofocus
              @clear="onSearchHide"
            >
              <template #prepend>
                <q-icon name="search" />
              </template>
              <template #append>
                <q-btn
                  flat
                  round
                  dense
                  icon="close"
                  aria-label="Hide search"
                  @click="onSearchHide"
                />
              </template>
            </q-input>
          </div>

          <div class="col-auto row items-center q-gutter-sm">
            <q-btn
              flat
              round
              dense
              icon="filter_alt"
              aria-label="Filters"
              @click="filterDrawerOpen = true"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <div v-if="brandLoading || categoryLoading" class="text-caption text-grey-7 q-mb-md">
      Loading filter options...
    </div>

    <div class="product-container">
      <div
        v-for="item in productStore.items"
        :key="item.id"
        class="product-item"
      >
        <ProductCard :product="item" />
      </div>
    </div>

    <div class="flex flex-center q-ma-md q-pa-md">
      <q-btn
        v-if="productStore.page < productStore.total / productStore.pageSize"
        color="primary"
        :loading="isLoadingMore"
        no-caps
        class="pill-btn slim-btn"
        label="Load More"
        @click="onPaginationClick"
      />
    </div>

    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-select
        v-model="vendorCode"
        outlined
        dense
        class="soft-input q-mb-md"
        emit-value
        map-options
        :options="vendorOptions"
        label="Vendor"
      />

      <q-select
        v-model="brand"
        outlined
        use-input
        dense
        class="soft-input q-mb-md"
        input-debounce="300"
        emit-value
        map-options
        :options="filteredBrandOptions"
        label="Brand"
        @filter="filterBrands"
      />

      <q-select
        v-model="category"
        outlined
        use-input
        dense
        class="soft-input q-mb-md"
        input-debounce="300"
        emit-value
        map-options
        :options="filteredCategoryOptions"
        label="Category"
        @filter="filterCategories"
      />

      <div class="row q-gutter-sm justify-end">
        <q-btn
          color="negative"
          outline
          no-caps
          class="pill-btn slim-btn"
          label="Reset"
          @click="onResetFilters"
        />
      </div>
    </FilterSidebar>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import ProductCard from '../components/ProductCard.vue'
import { useProductStore } from 'src/modules/products/stores/productStore'
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useRoute } from 'vue-router'
import { useProductBasedCostingStore } from '../../product_based_costing/stores/productBasedCostingStore'
import FilterSidebar from 'src/components/FilterSidebar.vue'
const costingFileStore = useProductBasedCostingStore()
const route = useRoute()
const authStore = useAuthStore()

const productStore = useProductStore()
const vendorStore = useVendorStore()

type FilterOption = {
  label: string
  value: string | null
}

const allBrandOption: FilterOption = {
  label: 'All brands',
  value: null,
}

const allCategoryOption: FilterOption = {
  label: 'All categories',
  value: null,
}

const search = ref('')
const showSearchInput = ref(false)
const category = ref<string | null>(null)
const brand = ref<string | null>(null)
const vendorCode = ref<string | null>('PC')
const filterDrawerOpen = ref(false)
let searchDebounceTimer: ReturnType<typeof setTimeout> | undefined
const suppressFilterWatch = ref(false)

const brandNames = ref<string[]>([])
const categoryNames = ref<string[]>([])

const filteredBrandNames = ref<string[]>([])
const filteredCategoryNames = ref<string[]>([])

const brandLoading = ref(false)
const categoryLoading = ref(false)

const filteredBrandOptions = computed<FilterOption[]>(() => [
  allBrandOption,
  ...filteredBrandNames.value.map((item) => ({
    label: item,
    value: item,
  })),
])

const filteredCategoryOptions = computed<FilterOption[]>(() => [
  allCategoryOption,
  ...filteredCategoryNames.value.map((item) => ({
    label: item,
    value: item,
  })),
])

const vendorOptions = computed<FilterOption[]>(() => [
  { label: 'All vendors', value: null },
  ...vendorStore.items.map((item) => ({
    label: `${item.name ?? item.code} (${item.code})`,
    value: item.code ?? null,
  })),
])

const loadProducts = async () => {
  await productStore.fetchProducts({
    page: 1,
    search: search.value,
    category: category.value,
    brand: brand.value,
    vendorCode: vendorCode.value,
    isAvailable: true,
  })
}

const loadBrands = async () => {
  brandLoading.value = true

  try {
    const result = await productStore.fetchBrandOptions({
      vendorCode: vendorCode.value,
    })

    if (result.success) {
      brandNames.value = productStore.brandOptions
      filteredBrandNames.value = productStore.brandOptions
    }
  } finally {
    brandLoading.value = false
  }
}

const loadCategories = async () => {
  categoryLoading.value = true

  try {
    const result = await productStore.fetchCategoryOptions({
      vendorCode: vendorCode.value,
    })

    if (result.success) {
      categoryNames.value = productStore.categoryOptions
      filteredCategoryNames.value = productStore.categoryOptions
    }
  } finally {
    categoryLoading.value = false
  }
}

const filterBrands = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    if (val === '') {
      filteredBrandNames.value = [...brandNames.value]
      return
    }

    const needle = val.toLowerCase()
    filteredBrandNames.value = brandNames.value.filter((item) =>
      item.toLowerCase().includes(needle)
    )
  })
}

const filterCategories = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    if (val === '') {
      filteredCategoryNames.value = [...categoryNames.value]
      return
    }

    const needle = val.toLowerCase()
    filteredCategoryNames.value = categoryNames.value.filter((item) =>
      item.toLowerCase().includes(needle)
    )
  })
}

const scheduleSearchLoad = () => {
  if (suppressFilterWatch.value) {
    return
  }

  if (searchDebounceTimer) {
    clearTimeout(searchDebounceTimer)
  }

  searchDebounceTimer = setTimeout(() => {
    void loadProducts()
  }, 400)
}

watch(search, () => {
  scheduleSearchLoad()
})

watch([category, brand], () => {
  if (suppressFilterWatch.value) {
    return
  }

  void loadProducts()
})

watch(vendorCode, async () => {
  brand.value = null
  category.value = null
  filteredBrandNames.value = []
  filteredCategoryNames.value = []

  await Promise.all([loadBrands(), loadCategories()])
  await loadProducts()
})

const isLoadingMore = ref(false)

const onPaginationClick = async () => {
  isLoadingMore.value = true
  try {
    await productStore.fetchProducts({
      page: productStore.page + 1,
      search: search.value,
      category: category.value,
      brand: brand.value,
      vendorCode: vendorCode.value,
      isAvailable: true,
      append: true,
    })
  } finally {
    isLoadingMore.value = false
  }
}

const onResetFilters = async () => {
  suppressFilterWatch.value = true

  try {
    search.value = ''
    brand.value = null
    category.value = null

    filteredBrandNames.value = [...brandNames.value]
    filteredCategoryNames.value = [...categoryNames.value]

    await productStore.fetchProducts({
      page: 1,
      search: '',
      category: null,
      brand: null,
      vendorCode: vendorCode.value,
      isAvailable: true,
    })
  } finally {
    suppressFilterWatch.value = false
    filterDrawerOpen.value = false
  }
}

const onSearchHide = () => {
  search.value = ''
  showSearchInput.value = false
  void loadProducts()
}

const fileId = computed(() => {
  const parsed = Number(route.params.id)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null
})

const loadCostingFileItems = async () => {
  if (!fileId.value) {
    return
  }

  await costingFileStore.fetchProductBasedCostingItems(fileId.value)
}

onMounted(() => {
  void Promise.all([
    vendorStore.fetchVendors(authStore.tenantId ?? null),
    loadBrands(),
    loadCategories(),
    loadProducts(),
    loadCostingFileItems(),
  ])
})

onBeforeUnmount(() => {
  if (searchDebounceTimer) {
    clearTimeout(searchDebounceTimer)
  }
})
</script>

<style scoped>
.costing-cart-page {
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

.product-container {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 16px;
  width: 100%;
}

.product-item {
  width: 300px;
  flex: 0 0 260px;
}
</style>
