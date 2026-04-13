<template>
  <q-page class="q-pa-md">
<q-btn color="primary" flat icon="arrow_back" label="back to list " @click="router.push({ name: 'product-based-costing-file-details-page' })" />
   <div class="row q-col-gutter-md items-end q-mb-md">
      <div class="col-12 col-sm-4 col-md-3">
        <q-input
          v-model="search"
          outlined
          dense
          type="text"
          label="Search"
        />
      </div>

      <div class="col-12 col-sm-4 col-md-3">
        <q-select
          v-model="brand"
          outlined
          use-input
          dense
          hide-selected
          fill-input
          input-debounce="300"
          emit-value
          map-options
          :options="filteredBrandOptions"
          label="Brand"

          @filter="filterBrands"
        />
      </div>

      <div class="col-12 col-sm-4 col-md-3">
        <q-select
          v-model="category"
          outlined
          use-input
          dense
          hide-selected
          fill-input
          input-debounce="300"
          emit-value
          map-options
          :options="filteredCategoryOptions"
          label="Category"

          @filter="filterCategories"
        />
      </div>

      <div class="col-12 col-sm-4 col-md-3">
        <q-btn
          color="negative"
          outline
          label="Reset"
          @click="onResetFilters"
        />
      </div>
    </div>

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

    <div class="flex flex-center q-ma-md q-pa-md" style="border-radius: 8px;">
      <q-btn
        v-if="productStore.page < productStore.total / productStore.pageSize"
        color="primary"
        :loading="isLoadingMore"
        label="Load More"
        @click="onPaginationClick"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import ProductCard from '../components/ProductCard.vue'
import { productService } from 'src/modules/products/services/productService'
import { useProductStore } from 'src/modules/products/stores/productStore'
import { useRoute, useRouter } from 'vue-router'
import { useProductBasedCostingStore } from '../../product_based_costing/stores/productBasedCostingStore'
const costingFileStore = useProductBasedCostingStore()
const route = useRoute()
const router = useRouter()

const productStore = useProductStore()

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
const category = ref<string | null>(null)
const brand = ref<string | null>(null)
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

const loadProducts = async () => {
  await productStore.fetchProducts({
    page: 1,
    search: search.value,
    category: category.value,
    brand: brand.value,
    vendorCode: "PC",
  })
}

const loadBrands = async () => {
  brandLoading.value = true

  try {
    const result = await productService.listBrands()

    if (result.success) {
      brandNames.value = result.data ?? []
      filteredBrandNames.value = result.data ?? []
    }
  } finally {
    brandLoading.value = false
  }
}

const loadCategories = async () => {
  categoryLoading.value = true

  try {
    const result = await productService.listCategories()

    if (result.success) {
      categoryNames.value = result.data ?? []
      filteredCategoryNames.value = result.data ?? []
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

const isLoadingMore = ref(false)

const onPaginationClick = async () => {
  isLoadingMore.value = true
  try {
    await productStore.fetchProducts({
      page: productStore.page + 1,
      search: search.value,
      category: category.value,
      brand: brand.value,
      vendorCode: 'PC',
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
      vendorCode: 'PC',
    })
  } finally {
    suppressFilterWatch.value = false
  }
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
  void Promise.all([loadBrands(), loadCategories(), loadProducts(), loadCostingFileItems()])
})

onBeforeUnmount(() => {
  if (searchDebounceTimer) {
    clearTimeout(searchDebounceTimer)
  }
})
</script>

<style scoped>
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
