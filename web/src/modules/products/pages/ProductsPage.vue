<template>
  <q-page class="q-pa-md products-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Products</div>
            <div class="text-caption text-grey-8">Browse product previews and open details</div>
          </div>
          <div class="col-auto">
            <q-btn
              outline
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              label="Add Product"
              icon="add"
              @click="openCreateDialog"
            />
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
            <q-chip
              dense
              square
              :color="product.is_available ? 'green-1' : 'red-1'"
              :text-color="product.is_available ? 'green-9' : 'red-9'"
              size="xs"
              class="status-badge text-weight-bold q-ma-none"
            >
              {{ product.is_available ? 'Available' : 'Not Available' }}
            </q-chip>
            <SmartImage
              :src="product.image_url"
              :alt="product.name ?? 'Product image'"
              imgClass="product-image"
              fallbackClass="product-image-fallback"
            />
          </div>

          <q-card-section class="q-pt-sm q-pb-sm">
            <div class="product-name cursor-pointer" @click="openDetails(product.id)">
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
        :max-pages="$q.screen.xs ? 4 : 8"
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

    <!-- Add Product Dialog -->
    <q-dialog v-model="createDialogOpen" persistent>
      <q-card style="width: 960px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-none">
          <div class="text-h6 text-weight-bold text-primary">Add Product</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-separator class="q-my-md" />

        <q-card-section class="q-pa-none">
          <q-form ref="createFormRef">
            <div class="row q-col-gutter-lg">
              <!-- Left Column (Image & Identification) -->
              <div class="col-12 col-md-5 q-gutter-y-md">
                <div class="image-preview-container border rounded-borders q-pa-sm bg-grey-1 text-center" style="border: 1px dashed #cfd8dc; border-radius: 8px; min-height: 200px;">
                  <div v-if="createForm.image_url" style="display: flex; align-items: center; justify-content: center; height: 200px;">
                    <SmartImage :src="createForm.image_url" style="max-height: 200px; max-width: 100%; object-fit: contain; margin: 0 auto;" />
                  </div>
                  <div v-else class="flex flex-center text-grey-6" style="height: 200px;">
                    <div class="column items-center">
                      <q-icon name="image" size="48px" />
                      <div class="text-caption q-mt-sm">No Image Preview</div>
                    </div>
                  </div>
                </div>

                <q-input
                  v-model="createForm.image_url"
                  label="Image URL"
                  outlined
                  dense
                  class="soft-input"
                >
                  <template #prepend>
                    <q-icon name="image" />
                  </template>
                </q-input>

                <q-input
                  v-model="createForm.name"
                  label="Name *"
                  type="textarea"
                  autogrow
                  outlined
                  dense
                  class="soft-input"
                  :rules="[val => !!val || 'Name is required']"
                >
                  <template #prepend>
                    <q-icon name="inventory_2" />
                  </template>
                </q-input>

                <q-input
                  v-model="createForm.barcode"
                  label="Barcode"
                  outlined
                  dense
                  class="soft-input"
                >
                  <template #prepend>
                    <q-icon name="qr_code" />
                  </template>
                </q-input>

                <q-input
                  v-model="createForm.product_code"
                  label="Product Code"
                  outlined
                  dense
                  class="soft-input"
                >
                  <template #prepend>
                    <q-icon name="badge" />
                  </template>
                </q-input>
              </div>

              <!-- Right Column (Metadata, Parameters & Options) -->
              <div class="col-12 col-md-7 q-gutter-y-md">
                <div class="row q-col-gutter-sm">
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="createForm.vendor_code"
                      :options="dialogVendorOptions"
                      emit-value
                      map-options
                      label="Vendor"
                      outlined
                      dense
                      clearable
                      class="soft-input"
                      @update:model-value="onVendorOrMarketChange"
                    >
                      <template #prepend>
                        <q-icon name="storefront" />
                      </template>
                    </q-select>
                  </div>
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="createForm.market_code"
                      :options="dialogMarketOptions"
                      emit-value
                      map-options
                      label="Market"
                      outlined
                      dense
                      clearable
                      class="soft-input"
                      @update:model-value="onVendorOrMarketChange"
                    >
                      <template #prepend>
                        <q-icon name="public" />
                      </template>
                    </q-select>
                  </div>
                </div>

                <div class="row q-col-gutter-sm">
                  <div class="col-12 col-sm-6">
                    <div class="row items-center q-col-gutter-sm no-wrap">
                      <div class="col">
                        <q-select
                          v-model="createForm.brand"
                          :options="dialogBrandOptions"
                          use-input
                          fill-input
                          hide-selected
                          input-debounce="0"
                          clearable
                          emit-value
                          map-options
                          label="Brand"
                          outlined
                          dense
                          :disable="!canPickBrandCategory"
                          @filter="filterBrandOptions"
                          @input-value="onBrandInputValue"
                          class="soft-input"
                        >
                          <template #prepend>
                            <q-icon name="sell" />
                          </template>
                        </q-select>
                      </div>
                      <div class="col-auto">
                        <q-btn
                          color="primary"
                          no-caps
                          outline
                          label="Add"
                          :disable="!canAddBrand"
                          @click="addBrandOption"
                          style="height: 40px;"
                          class="pill-btn"
                        />
                      </div>
                    </div>
                  </div>

                  <div class="col-12 col-sm-6">
                    <div class="row items-center q-col-gutter-sm no-wrap">
                      <div class="col">
                        <q-select
                          v-model="createForm.category"
                          :options="dialogCategoryOptions"
                          use-input
                          fill-input
                          hide-selected
                          input-debounce="0"
                          clearable
                          emit-value
                          map-options
                          label="Category"
                          outlined
                          dense
                          :disable="!canPickBrandCategory"
                          @filter="filterCategoryOptions"
                          @input-value="onCategoryInputValue"
                          class="soft-input"
                        >
                          <template #prepend>
                            <q-icon name="category" />
                          </template>
                        </q-select>
                      </div>
                      <div class="col-auto">
                        <q-btn
                          color="primary"
                          no-caps
                          outline
                          label="Add"
                          :disable="!canAddCategory"
                          @click="addCategoryOption"
                          style="height: 40px;"
                          class="pill-btn"
                        />
                      </div>
                    </div>
                  </div>
                </div>

                <div class="row q-col-gutter-sm">
                  <div class="col-12">
                    <q-input
                      v-model.number="createForm.price_gbp"
                      label="Price GBP"
                      type="number"
                      step="0.01"
                      outlined
                      dense
                      class="soft-input"
                    >
                      <template #prepend>
                        <q-icon name="currency_pound" />
                      </template>
                    </q-input>
                  </div>
                </div>

                <div class="row q-col-gutter-sm">
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model.number="createForm.product_weight"
                      label="Product Weight"
                      type="number"
                      outlined
                      dense
                      class="soft-input"
                    >
                      <template #prepend>
                        <q-icon name="scale" />
                      </template>
                    </q-input>
                  </div>
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model.number="createForm.package_weight"
                      label="Package Weight"
                      type="number"
                      outlined
                      dense
                      class="soft-input"
                    >
                      <template #prepend>
                        <q-icon name="fitness_center" />
                      </template>
                    </q-input>
                  </div>
                </div>

                <div class="row items-center q-pl-xs">
                  <q-toggle
                    v-model="createForm.is_available"
                    label="Is Available"
                    color="primary"
                  />
                </div>
              </div>
            </div>
          </q-form>
        </q-card-section>

        <q-separator class="q-my-md" />

        <q-card-actions align="right" class="q-pa-none">
          <q-btn flat label="Cancel" no-caps class="pill-btn slim-btn" v-close-popup :disable="productStore.saving" />
          <q-btn color="primary" label="Save Product" no-caps class="pill-btn slim-btn" :loading="productStore.saving" @click="onCreateProduct" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import type { QForm } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useMarketStore } from 'src/modules/market/stores/marketStore'
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { productService } from '../services/productService'
import { useProductStore } from '../stores/productStore'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'

const router = useRouter()
const $q = useQuasar()
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

const createDialogOpen = ref(false)
const createFormRef = ref<QForm | null>(null)

const createForm = reactive({
  name: '',
  product_code: '',
  barcode: '',
  brand: null as string | null,
  category: null as string | null,
  price_gbp: null as number | null,
  image_url: '',
  vendor_code: null as string | null,
  market_code: 'GB',
  is_available: true,
  product_weight: null as number | null,
  package_weight: null as number | null,
})

const brandNames = ref<string[]>([])
const categoryNames = ref<string[]>([])
const filteredBrandNames = ref<string[]>([])
const filteredCategoryNames = ref<string[]>([])
const brandInputValue = ref('')
const categoryInputValue = ref('')

const dialogBrandOptions = computed(() => {
  const seen = new Set<string>()
  const options = filteredBrandNames.value
    .map((item) => (item ?? '').trim())
    .filter((item) => item.length > 0)
    .filter((item) => item.toLowerCase() !== 'other')
    .filter((item) => {
      const key = item.toLowerCase()
      if (seen.has(key)) return false
      seen.add(key)
      return true
    })
    .map((item) => ({
      label: item,
      value: item,
    }))

  return [{ label: 'Other', value: null as string | null }, ...options]
})

const dialogCategoryOptions = computed(() => {
  const seen = new Set<string>()
  const options = filteredCategoryNames.value
    .map((item) => (item ?? '').trim())
    .filter((item) => item.length > 0)
    .filter((item) => item.toLowerCase() !== 'other')
    .filter((item) => {
      const key = item.toLowerCase()
      if (seen.has(key)) return false
      seen.add(key)
      return true
    })
    .map((item) => ({
      label: item,
      value: item,
    }))

  return [{ label: 'Other', value: null as string | null }, ...options]
})

const dialogVendorOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...vendorStore.items.map((vendor) => ({
    label: `${vendor.name} (${vendor.code})`,
    value: vendor.code,
  })),
])

const dialogMarketOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...marketStore.items.map((market) => ({
    label: `${market.name} (${market.code})`,
    value: market.code,
  })),
])

const canPickBrandCategory = computed(
  () => Boolean(createForm.vendor_code) && Boolean(createForm.market_code),
)

const normalized = (value: string | null | undefined) => (value ?? '').trim()

const normalizeKey = (value: string | null | undefined) =>
  normalized(value).toLowerCase()

const lastTypedBrand = ref('')
const lastTypedCategory = ref('')

const canAddBrand = computed(() => {
  if (!canPickBrandCategory.value || !createForm.vendor_code) return false
  const candidate = normalized(lastTypedBrand.value || brandInputValue.value || createForm.brand)
  if (!candidate || candidate.toLowerCase() === 'other') return false
  return !brandNames.value.some((item) => normalizeKey(item) === normalizeKey(candidate))
})

const canAddCategory = computed(() => {
  if (!canPickBrandCategory.value || !createForm.vendor_code) return false
  const candidate = normalized(lastTypedCategory.value || categoryInputValue.value || createForm.category)
  if (!candidate || candidate.toLowerCase() === 'other') return false
  return !categoryNames.value.some((item) => normalizeKey(item) === normalizeKey(candidate))
})

const loadBrandCategoryOptions = async () => {
  if (!createForm.vendor_code || !createForm.market_code) {
    brandNames.value = []
    categoryNames.value = []
    filteredBrandNames.value = []
    filteredCategoryNames.value = []
    return
  }

  const [brandResult, categoryResult] = await Promise.all([
    productService.listBrands({ vendorCode: createForm.vendor_code, tenantId: authStore.tenantId ?? null }),
    productService.listCategories({ vendorCode: createForm.vendor_code, tenantId: authStore.tenantId ?? null }),
  ])

  if (brandResult.success) {
    brandNames.value = brandResult.data ?? []
    filteredBrandNames.value = [...brandNames.value]
  } else {
    handleApiFailure(brandResult, brandResult.error ?? 'Failed to load brands.')
  }

  if (categoryResult.success) {
    categoryNames.value = categoryResult.data ?? []
    filteredCategoryNames.value = [...categoryNames.value]
  } else {
    handleApiFailure(categoryResult, categoryResult.error ?? 'Failed to load categories.')
  }
}

const filterBrandOptions = (val: string, update: (callback: () => void) => void) => {
  const needle = normalizeKey(val)
  update(() => {
    if (!needle) {
      filteredBrandNames.value = [...brandNames.value]
      return
    }
    filteredBrandNames.value = brandNames.value.filter(
      (item) => normalizeKey(item).includes(needle),
    )
  })
}

const filterCategoryOptions = (val: string, update: (callback: () => void) => void) => {
  const needle = normalizeKey(val)
  update(() => {
    if (!needle) {
      filteredCategoryNames.value = [...categoryNames.value]
      return
    }
    filteredCategoryNames.value = categoryNames.value.filter(
      (item) => normalizeKey(item).includes(needle),
    )
  })
}

const onBrandInputValue = (value: string) => {
  const cleaned = (value || '').trim()
  if (cleaned && cleaned.toLowerCase() !== 'other') {
    lastTypedBrand.value = cleaned
  }
  brandInputValue.value = value
}

const onCategoryInputValue = (value: string) => {
  const cleaned = (value || '').trim()
  if (cleaned && cleaned.toLowerCase() !== 'other') {
    lastTypedCategory.value = cleaned
  }
  categoryInputValue.value = value
}

const addBrandOption = async () => {
  const name = normalized(lastTypedBrand.value || brandInputValue.value || createForm.brand)
  if (!name || name.toLowerCase() === 'other' || !createForm.vendor_code) return

  const selectedVendor = vendorStore.items.find((v) => v.code === createForm.vendor_code)
  const result = await productService.createProductBrand({
    name,
    value: name.toLowerCase(),
    vendor_code: createForm.vendor_code,
    vendor_id: selectedVendor ? selectedVendor.id : null,
    tenant_id: authStore.tenantId ?? null,
  })

  if (!result.success) {
    handleApiFailure(result, result.error ?? 'Failed to add brand.')
    return
  }

  showSuccessNotification('Brand added successfully.')
  await loadBrandCategoryOptions()
  createForm.brand = result.data?.name || name.toUpperCase()
  brandInputValue.value = ''
  lastTypedBrand.value = ''
}

const addCategoryOption = async () => {
  const name = normalized(lastTypedCategory.value || categoryInputValue.value || createForm.category)
  if (!name || name.toLowerCase() === 'other' || !createForm.vendor_code) return

  const selectedVendor = vendorStore.items.find((v) => v.code === createForm.vendor_code)
  const result = await productService.createProductCategory({
    name,
    value: name.toLowerCase(),
    vendor_code: createForm.vendor_code,
    vendor_id: selectedVendor ? selectedVendor.id : null,
    tenant_id: authStore.tenantId ?? null,
  })

  if (!result.success) {
    handleApiFailure(result, result.error ?? 'Failed to add category.')
    return
  }

  showSuccessNotification('Category added successfully.')
  await loadBrandCategoryOptions()
  createForm.category = result.data?.name || name
  categoryInputValue.value = ''
  lastTypedCategory.value = ''
}

const onVendorOrMarketChange = async () => {
  createForm.brand = null
  createForm.category = null
  await loadBrandCategoryOptions()
}

const openCreateDialog = () => {
  createForm.name = ''
  createForm.product_code = ''
  createForm.barcode = ''
  createForm.brand = null
  createForm.category = null
  createForm.price_gbp = null
  createForm.image_url = ''
  createForm.vendor_code = null
  createForm.market_code = 'GB'
  createForm.is_available = true
  createForm.product_weight = null
  createForm.package_weight = null

  brandNames.value = []
  categoryNames.value = []
  filteredBrandNames.value = []
  filteredCategoryNames.value = []
  brandInputValue.value = ''
  categoryInputValue.value = ''
  lastTypedBrand.value = ''
  lastTypedCategory.value = ''

  void loadBrandCategoryOptions()

  createDialogOpen.value = true
}

const cleanNumber = (val: number | string | null | undefined): number | null => {
  if (val === '' || val == null) return null
  const parsed = Number(val)
  return Number.isFinite(parsed) ? parsed : null
}

const onCreateProduct = async () => {
  if (createFormRef.value) {
    const isValid = await createFormRef.value.validate()
    if (!isValid) return
  }

  try {
    const result = await productStore.createProduct({
      tenant_id: authStore.tenantId ?? null,
      name: createForm.name.trim(),
      product_code: createForm.product_code.trim() || null,
      barcode: createForm.barcode.trim() || null,
      brand: createForm.brand?.trim() || null,
      category: createForm.category?.trim() || null,
      price_gbp: cleanNumber(createForm.price_gbp),
      image_url: createForm.image_url.trim() || null,
      vendor_code: createForm.vendor_code?.trim() || null,
      market_code: createForm.market_code?.trim() || null,
      is_available: createForm.is_available,
      product_weight: cleanNumber(createForm.product_weight),
      package_weight: cleanNumber(createForm.package_weight),
      available_units: null,
      expire_date: null,
      minimum_order_quantity: null,
      tariff_code: null,
      languages: null,
      batch_code_manufacture_date: null,
    })

    if (result && result.success) {
      createDialogOpen.value = false
    }
  } catch (err) {
    console.error('Error creating product:', err)
  }
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
  position: relative;
  height: 190px;
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
  background: #fff;
}

.status-badge {
  position: absolute;
  top: 8px;
  left: 8px;
  z-index: 2;
  font-weight: 700;
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
  min-height: 52px;
  font-size: 13px;
  font-weight: 400;
  line-height: 1.3;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
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

  .products-card-grid {
    margin-left: 0 !important;
    margin-right: 0 !important;
    margin-top: 0 !important;
    row-gap: 0px !important;
  }

  .products-card-grid > .products-card-item {
    width: 100%;
    max-width: 100%;
    flex: 0 0 100%;
    padding: 0 !important;
  }

  .product-card {
    width: 100%;
    min-height: unset;
    height: auto;
    display: flex;
    flex-direction: row;
    align-items: center;
    border-radius: 0;
    border: none;
    border-bottom: 1px solid rgba(34, 56, 101, 0.08);
    background: #fff;
    padding: 12px 8px;
    margin-bottom: 0px;
  }

  .product-image-wrap {
    width: 1.2in;
    height: 1.2in;
    flex: 0 0 1.2in;
    border-bottom: none;
    border-right: none;
    border-radius: 4px;
    overflow: hidden;
  }

  .product-image-fallback {
    border-radius: 4px;
  }

  .product-card :deep(.q-card__section) {
    flex: 1;
    padding: 0 0 0 12px !important;
    display: flex;
    align-items: center;
  }

  .product-name {
    min-height: unset;
    font-size: 13px;
    line-height: 1.35;
    -webkit-line-clamp: 3;
    margin: 0;
  }
}
</style>
