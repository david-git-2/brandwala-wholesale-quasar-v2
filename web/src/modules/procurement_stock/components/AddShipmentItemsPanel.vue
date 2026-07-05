<template>
  <div class="add-items-panel column no-wrap" :class="{ 'add-items-panel--drawer': layout === 'drawer' }">
    <!-- Top compact toolbar -->
    <div class="q-pa-md toolbar-section row items-center q-col-gutter-sm">
      <div class="col">
        <q-input
          v-model="browseSearch"
          :placeholder="`Search catalog by ${searchFieldLabel.toLowerCase()}...`"
          filled
          dense
          clearable
          debounce="400"
        >
          <template #prepend>
            <q-btn-dropdown
              flat
              dense
              :label="searchFieldLabel"
              class="text-caption text-weight-medium text-grey-8 search-field-dropdown"
              no-caps
            >
              <q-list dense>
                <q-item clickable v-close-popup @click="browseSearchField = 'name'">
                  <q-item-section>Name</q-item-section>
                </q-item>
                <q-item clickable v-close-popup @click="browseSearchField = 'barcode'">
                  <q-item-section>Barcode</q-item-section>
                </q-item>
                <q-item clickable v-close-popup @click="browseSearchField = 'product_code'">
                  <q-item-section>Product Code</q-item-section>
                </q-item>
              </q-list>
            </q-btn-dropdown>
          </template>
        </q-input>
      </div>
      <div class="col-auto">
        <q-btn flat round dense icon="filter_alt" color="grey-8" @click="openFilterSidebar">
          <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
            {{ activeFilterCount }}
          </q-badge>
        </q-btn>
      </div>
      <div class="col-auto">
        <q-btn
          unelevated
          no-caps
          color="primary"
          icon="add"
          label="New Product"
          class="new-product-btn"
          @click="showNewProductSidebar = true"
        />
      </div>
    </div>

    <!-- Catalog Browse list -->
    <div class="browse-section col column q-px-md q-pb-sm">
      <div class="text-subtitle2 text-weight-bold q-mb-xs">Catalog Products</div>
      <div class="col scroll browse-list-container relative-position">
        <q-inner-loading :showing="browseLoading" />
        <q-list dense bordered separator class="rounded-borders browse-list">
          <q-item v-for="product in browseList" :key="product.id">
            <q-item-section avatar>
              <q-avatar square class="bg-grey-2" style="width: 1in; height: 1in;">
                <SmartImage :src="product.image_url" style="width: 1in; height: 1in; object-fit: contain;" />
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-medium">{{ product.name }}</q-item-label>
              <q-item-label caption>
                {{ [product.product_code, product.barcode].filter(Boolean).join(' · ') || 'No code' }}
              </q-item-label>
              <q-item-label v-if="product.list_price_amount != null" caption class="text-secondary">
                £{{ product.list_price_amount.toFixed(2) }}
              </q-item-label>
            </q-item-section>
            <q-item-section side class="row no-wrap items-center q-gutter-x-xs">
              <q-input
                :model-value="browseQtyById[product.id]"
                type="number"
                outlined
                dense
                placeholder="Qty"
                style="width: 70px;"
                @update:model-value="(val) => setBrowseQty(product.id, val === '' ? null : Number(val))"
              />
              <q-btn
                unelevated
                dense
                no-caps
                color="secondary"
                icon="add"
                class="q-px-sm"
                label="Add"
                @click="addProductToCart(product, browseQtyById[product.id])"
              />
            </q-item-section>
          </q-item>
          <q-item v-if="!browseLoading && browseList.length === 0">
            <q-item-section class="text-grey-6 text-center q-pa-md">No products found</q-item-section>
          </q-item>
        </q-list>
        <div v-if="browseTotal > browseList.length" class="text-center q-mt-sm">
          <q-btn flat dense no-caps color="primary" label="Load more" :loading="browseLoading" @click="loadMoreBrowse" />
        </div>
      </div>
    </div>

    <q-separator />

    <!-- Cart -->
    <div class="cart-section col q-pa-md">
      <div class="row items-center justify-between q-mb-sm">
        <div class="text-subtitle1 text-weight-bold">
          Cart
          <q-badge v-if="cart.length" color="primary" :label="cart.length" class="q-ml-xs" />
        </div>
        <q-btn v-if="cart.length" flat dense no-caps color="negative" label="Clear" @click="confirmClearCart" />
      </div>

      <div v-if="cart.length === 0" class="text-center text-grey-6 q-py-lg">
        <q-icon name="shopping_cart" size="36px" color="grey-4" />
        <div class="q-mt-sm">Search catalog or add a new product</div>
      </div>

      <div v-else class="cart-scroll">
        <div v-for="item in cart" :key="item.key" class="cart-line q-mb-sm q-pa-sm rounded-borders">
          <div class="row items-start no-wrap q-col-gutter-sm">
            <div class="col-auto">
              <q-avatar square class="bg-grey-2" style="width: 1in; height: 1in;">
                <SmartImage :src="item.image_url" style="width: 1in; height: 1in; object-fit: contain;" />
              </q-avatar>
            </div>
            <div class="col" style="min-width: 0;">
              <div class="text-weight-medium ellipsis-2-lines">
                {{ item.name }}
                <q-badge v-if="item.isNewProduct" color="orange" label="New" class="q-ml-xs" />
              </div>
              <div class="text-caption text-grey-7">
                <span v-if="item.product_code || item.barcode">
                  {{ [item.product_code, item.barcode].filter(Boolean).join(' · ') }}
                </span>
                <span class="q-ml-sm text-weight-bold text-grey-6">
                  (Wt: {{ item.product_weight }}g / Pkg: {{ item.package_weight }}g)
                </span>
              </div>
            </div>
            <div class="col-auto">
              <q-btn flat round dense size="sm" color="negative" icon="close" @click="removeFromCart(item)" />
            </div>
          </div>
          <div class="row q-col-gutter-xs q-mt-xs">
            <div class="col-4">
              <q-input
                v-model.number="item.ordered_quantity"
                type="number"
                label="Qty"
                outlined
                dense
                min="1"
                @update:model-value="(v) => onCartQtyUpdated(item, Number(v))"
              />
            </div>
            <div class="col-4">
              <q-input v-model.number="item.purchase_price" type="number" step="0.01" label="Price £" outlined dense min="0" />
            </div>
            <div class="col-4">
              <q-select
                v-model="item.vendor_id"
                :options="vendorOptions"
                label="Vendor"
                outlined
                dense
                emit-value
                map-options
                options-dense
                clearable
              />
            </div>
          </div>
          <div class="text-caption text-grey-7 text-right q-mt-xs">£{{ formatMoney(lineSubtotal(item)) }}</div>
        </div>
      </div>
    </div>

    <!-- Footer -->
    <div class="panel-footer q-pa-md">
      <div v-if="cart.length" class="row justify-between text-body2 q-mb-xs">
        <span class="text-grey-7">{{ totalCartUnits }} units · {{ totalCartWeightKg.toFixed(2) }} kg</span>
        <span class="text-weight-bold text-primary">£{{ formatMoney(totalCartPriceGbp) }}</span>
      </div>
      <div class="row q-gutter-sm">
        <q-btn v-if="showCancel" flat no-caps color="grey-8" label="Cancel" class="col" @click="onCancel" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          icon="save"
          :label="cart.length ? `Save ${cart.length} item${cart.length === 1 ? '' : 's'}` : 'Save'"
          class="col"
          :loading="submitting"
          :disable="cart.length === 0"
          @click="onCommitCart"
        />
      </div>
    </div>

    <!-- Catalog Filters Sidebar -->
    <FilterSidebar
      v-model="filterDrawerOpen"
      title="Filters"
      :z-index="7000"
    >
      <div class="q-gutter-y-md q-pa-sm">
        <!-- Vendor Filter -->
        <q-select
          v-model="draftVendorId"
          :options="vendorOptions"
          label="Vendor"
          filled
          dense
          emit-value
          map-options
          clearable
          @update:model-value="onDraftVendorChange"
        />

        <!-- Brand Filter -->
        <q-select
          v-model="draftBrand"
          :options="brandOptions"
          label="Brand"
          filled
          dense
          use-input
          fill-input
          hide-selected
          clearable
          new-value-mode="add-unique"
          @filter="filterBrands"
        />

        <!-- Category Filter -->
        <q-select
          v-model="draftCategory"
          :options="categoryOptions"
          label="Category"
          filled
          dense
          use-input
          fill-input
          hide-selected
          clearable
          new-value-mode="add-unique"
          @filter="filterCategories"
        />

        <!-- Apply & Reset Actions -->
        <div class="row justify-end q-gutter-x-sm q-mt-md">
          <q-btn flat no-caps label="Reset" color="grey-7" @click="onResetFilters" />
          <q-btn unelevated no-caps label="Apply Filters" color="primary" @click="onApplyFilters" />
        </div>
      </div>
    </FilterSidebar>

    <!-- New Product Sidebar -->
    <NewShipmentProductSidebar
      v-model="showNewProductSidebar"
      :z-index="7100"
      @add="onNewProductAdd"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useQuasar } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import { productRepository } from 'src/modules/products/repositories/productRepository'
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository'
import { productService } from 'src/modules/products/services/productService'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import SmartImage from 'src/components/SmartImage.vue'
import NewShipmentProductSidebar from './NewShipmentProductSidebar.vue'

export interface ShipmentCartItem {
  key: string
  product_id: number | null
  isNewProduct: boolean
  vendor_id: number | null
  name: string
  ordered_quantity: number
  purchase_price: number
  product_weight: number
  package_weight: number
  barcode: string | null
  product_code: string | null
  image_url: string | null
  category: string | null
  brand: string | null
}

interface ProductItem {
  id: number
  name: string
  product_code: string | null
  barcode: string | null
  list_price_amount: number | null
  product_weight: number | null
  package_weight: number | null
  image_url: string | null
}

const props = withDefaults(defineProps<{
  shipmentId: number
  layout?: 'drawer' | 'page'
  showCancel?: boolean
}>(), {
  layout: 'drawer',
  showCancel: true,
})

const emit = defineEmits<{
  saved: []
  cancel: []
}>()

const $q = useQuasar()
const authStore = useAuthStore()
const vendorStore = useVendorStore()
const shipmentStore = useGlobalShipmentStore()

const submitting = ref(false)

// Catalog browse state
const browseSearch = ref('')
const browseSearchField = ref<'name' | 'barcode' | 'product_code'>('name')
const browseList = ref<ProductItem[]>([])
const browseLoading = ref(false)
const browsePage = ref(1)
const browseTotal = ref(0)
const browseQtyById = ref<Record<number, number | null>>({})

const searchFieldLabel = computed(() => {
  if (browseSearchField.value === 'name') return 'Name'
  if (browseSearchField.value === 'barcode') return 'Barcode'
  if (browseSearchField.value === 'product_code') return 'Product Code'
  return 'Name'
})

// Cart state
const cart = ref<ShipmentCartItem[]>([])
const cartStorageKey = computed(() => `shipment_cart_${props.shipmentId}`)

// Filters State
const filterDrawerOpen = ref(false)
const filterVendorId = ref<number | null>(null)
const filterBrand = ref<string>('')
const filterCategory = ref<string>('')

const draftVendorId = ref<number | null>(null)
const draftBrand = ref<string>('')
const draftCategory = ref<string>('')

// Brand & Category selections
const allBrands = ref<string[]>([])
const allCategories = ref<string[]>([])
const brandOptions = ref<string[]>([])
const categoryOptions = ref<string[]>([])

// New Product Sidebar State
const showNewProductSidebar = ref(false)

const vendorOptions = computed(() =>
  vendorStore.items.map((v) => ({ label: v.name, value: v.id })),
)

const activeFilterCount = computed(() => {
  let count = 0
  if (filterVendorId.value) count++
  if (filterBrand.value) count++
  if (filterCategory.value) count++
  return count
})

const totalCartUnits = computed(() =>
  cart.value.reduce((sum, item) => sum + (item.ordered_quantity || 0), 0),
)

const totalCartWeightKg = computed(() => {
  let sum = 0
  for (const item of cart.value) {
    sum += ((item.product_weight || 0) + (item.package_weight || 0)) * item.ordered_quantity
  }
  return sum / 1000
})

const totalCartPriceGbp = computed(() =>
  cart.value.reduce((sum, item) => sum + (item.purchase_price || 0) * item.ordered_quantity, 0),
)

const formatMoney = (val: number) => val.toFixed(2)
const lineSubtotal = (item: ShipmentCartItem) => (item.purchase_price || 0) * item.ordered_quantity

const getDefaultVendorId = () => filterVendorId.value

const getVendorCode = (vendorId: number | null): string | null => {
  if (!vendorId) return null
  return vendorStore.items.find((v) => v.id === vendorId)?.code ?? null
}

const saveCartToStorage = () => {
  const key = cartStorageKey.value
  if (cart.value.length === 0) {
    sessionStorage.removeItem(key)
  } else {
    sessionStorage.setItem(key, JSON.stringify(cart.value))
  }
}

const loadCartFromStorage = () => {
  try {
    const raw = sessionStorage.getItem(cartStorageKey.value)
    if (!raw) return
    const parsed = JSON.parse(raw) as ShipmentCartItem[]
    if (Array.isArray(parsed)) cart.value = parsed
  } catch {
    sessionStorage.removeItem(cartStorageKey.value)
  }
}

watch(cart, saveCartToStorage, { deep: true })

const buildCatalogCartItem = (product: ProductItem, qty: number): ShipmentCartItem => ({
  key: `catalog_${product.id}`,
  product_id: product.id,
  isNewProduct: false,
  vendor_id: getDefaultVendorId(),
  name: product.name,
  ordered_quantity: qty,
  purchase_price: product.list_price_amount || 0,
  product_weight: product.product_weight ?? 0,
  package_weight: product.package_weight ?? 0,
  barcode: product.barcode,
  product_code: product.product_code,
  image_url: product.image_url,
  category: null,
  brand: null,
})

const setBrowseQty = (productId: number, qty: number | null) => {
  if (qty === null || isNaN(qty) || qty < 1) {
    browseQtyById.value[productId] = null
  } else {
    browseQtyById.value[productId] = qty
  }
}

const addProductToCart = (product: ProductItem, qty: number | null | undefined) => {
  if (!qty || isNaN(qty) || qty < 1) {
    $q.notify({
      type: 'warning',
      message: 'Quantity is required to add product to cart.'
    })
    return
  }

  const key = `catalog_${product.id}`
  const existing = cart.value.find((c) => c.key === key)
  if (existing) {
    existing.ordered_quantity += qty
    // Refresh weights from the latest catalog product record
    existing.product_weight = product.product_weight ?? 0
    existing.package_weight = product.package_weight ?? 0
    
    // Move existing item to top of the cart since it's the last added/modified
    const idx = cart.value.indexOf(existing)
    if (idx > -1) {
      cart.value.splice(idx, 1)
      cart.value.unshift(existing)
    }
  } else {
    // Unshift to put last added item first
    cart.value.unshift(buildCatalogCartItem(product, qty))
  }
  // Reset row qty
  browseQtyById.value[product.id] = null

  // Clear search query
  browseSearch.value = ''
}

const loadBrowse = async (append = false) => {
  if (!browseSearch.value.trim() && !filterBrand.value && !filterCategory.value && !filterVendorId.value) {
    browseList.value = []
    browseTotal.value = 0
    return
  }

  browseLoading.value = true
  try {
    const vendorCode = filterVendorId.value
      ? vendorStore.items.find((v) => v.id === filterVendorId.value)?.code
      : undefined

    const res = await productRepository.listProducts({
      page: browsePage.value,
      pageSize: 15,
      search: browseSearch.value.trim() || undefined,
      searchField: browseSearchField.value,
      vendorCode,
      brand: filterBrand.value || undefined,
      category: filterCategory.value || undefined,
      tenantId: authStore.tenantId,
    })
    const items = res.data as ProductItem[]
    browseList.value = append ? [...browseList.value, ...items] : items
    browseTotal.value = res.meta.total
  } finally {
    browseLoading.value = false
  }
}

const loadMoreBrowse = () => {
  browsePage.value += 1
  void loadBrowse(true)
}

// Watcher to auto-detect search field type (e.g. numeric barcode vs name)
watch(browseSearch, (newVal) => {
  const query = (newVal || '').trim()
  if (query) {
    if (/^\d{6,}$/.test(query)) {
      browseSearchField.value = 'barcode'
    } else if (/^[A-Za-z0-9\-_]{3,}$/.test(query) && /\d/.test(query) && /[A-Za-z]/.test(query)) {
      browseSearchField.value = 'product_code'
    }
  }

  browsePage.value = 1
  void loadBrowse()
})

watch(browseSearchField, () => {
  browsePage.value = 1
  void loadBrowse()
})

const onCartQtyUpdated = (item: ShipmentCartItem, val: number) => {
  if (val <= 0) cart.value = cart.value.filter((c) => c.key !== item.key)
}

const removeFromCart = (item: ShipmentCartItem) => {
  cart.value = cart.value.filter((c) => c.key !== item.key)
}

const confirmClearCart = () => {
  $q.dialog({ title: 'Clear cart?', message: 'Remove all items?', cancel: true })
    .onOk(() => { cart.value = [] })
}

const onNewProductAdd = (newProduct: Omit<ShipmentCartItem, 'key'>) => {
  // Unshift to put last added item first
  cart.value.unshift({
    ...newProduct,
    key: `new_${Date.now()}`,
  })
}

const openFilterSidebar = () => {
  draftVendorId.value = filterVendorId.value
  draftBrand.value = filterBrand.value
  draftCategory.value = filterCategory.value
  void onDraftVendorChange(filterVendorId.value)
  filterDrawerOpen.value = true
}

const onDraftVendorChange = async (vendorId: number | null) => {
  draftBrand.value = ''
  draftCategory.value = ''
  allBrands.value = []
  allCategories.value = []

  if (!vendorId) return

  const vendorCode = getVendorCode(vendorId)
  const tenantId = authStore.tenantId

  const [brandsRes, catsRes] = await Promise.all([
    productService.listBrands({ vendorCode, tenantId }),
    productService.listCategories({ vendorCode, tenantId }),
  ])

  if (brandsRes.success && brandsRes.data) {
    allBrands.value = brandsRes.data
  }
  if (catsRes.success && catsRes.data) {
    allCategories.value = catsRes.data
  }
}

const filterBrands = (val: string, update: (callback: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim()
    brandOptions.value = needle
      ? allBrands.value.filter((v) => v.toLowerCase().includes(needle))
      : allBrands.value
  })
}

const filterCategories = (val: string, update: (callback: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim()
    categoryOptions.value = needle
      ? allCategories.value.filter((v) => v.toLowerCase().includes(needle))
      : allCategories.value
  })
}

const onApplyFilters = () => {
  filterVendorId.value = draftVendorId.value
  filterBrand.value = draftBrand.value
  filterCategory.value = draftCategory.value
  filterDrawerOpen.value = false
  browsePage.value = 1
  void loadBrowse()
}

const onResetFilters = () => {
  draftVendorId.value = null
  draftBrand.value = ''
  draftCategory.value = ''
  filterVendorId.value = null
  filterBrand.value = ''
  filterCategory.value = ''
  filterDrawerOpen.value = false
  browsePage.value = 1
  void loadBrowse()
}

const findExistingProductId = async (item: ShipmentCartItem): Promise<number | null> => {
  if (!authStore.tenantId) return null
  const barcode = item.barcode?.trim()
  if (barcode) {
    const res = await productRepository.listProducts({
      page: 1, pageSize: 1, search: barcode, searchField: 'barcode', tenantId: authStore.tenantId,
    })
    const [first] = res.data
    if (first) return first.id
  }
  const productCode = item.product_code?.trim()
  if (productCode) {
    const res = await productRepository.listProducts({
      page: 1, pageSize: 1, search: productCode, searchField: 'product_code', tenantId: authStore.tenantId,
    })
    const [first] = res.data
    if (first) return first.id
  }
  return null
}

const registerProduct = async (item: ShipmentCartItem): Promise<number> => {
  const existingId = await findExistingProductId(item)
  if (existingId) return existingId

  const created = await productRepository.createProduct({
    tenant_id: authStore.tenantId ?? null,
    name: item.name,
    product_code: item.product_code,
    barcode: item.barcode,
    list_price_amount: item.purchase_price,
    list_price_currency_id: gbpCurrencyId.value,
    product_weight: item.product_weight,
    package_weight: item.package_weight,
    image_url: item.image_url,
    category: item.category,
    brand: item.brand,
    vendor_code: getVendorCode(item.vendor_id),
    country_of_origin: null,
    available_units: null,
    tariff_code: null,
    languages: null,
    batch_code_manufacture_date: null,
    expire_date: null,
    minimum_order_quantity: null,
    market_code: null,
    is_available: true,
  })
  return created.id
}

const resolveProductId = async (item: ShipmentCartItem) => {
  if (item.product_id && !item.isNewProduct) {
    return { productId: item.product_id, registered: false }
  }
  const existingId = await findExistingProductId(item)
  if (existingId) return { productId: existingId, registered: false }
  const productId = await registerProduct(item)
  return { productId, registered: true }
}

const onCommitCart = async () => {
  if (cart.value.length === 0) return

  submitting.value = true
  let savedCount = 0
  let registeredCount = 0

  try {
    for (const item of cart.value) {
      const { productId, registered } = await resolveProductId(item)
      if (registered) registeredCount++

      await shipmentStore.addShipmentItem({
        shipment_id: props.shipmentId,
        product_id: productId,
        vendor_id: item.vendor_id,
        name: item.name,
        ordered_quantity: item.ordered_quantity,
        purchase_price: item.purchase_price,
        product_weight: item.product_weight,
        package_weight: item.package_weight,
        barcode: item.barcode,
        product_code: item.product_code,
        image_url: item.image_url,
        add_method: 'manual',
        source_child_tenant_id: null,
        source_type: null,
        source_id: null,
      })
      savedCount++
    }

    sessionStorage.removeItem(cartStorageKey.value)
    cart.value = []

    let msg = `Added ${savedCount} item${savedCount === 1 ? '' : 's'}.`
    if (registeredCount > 0) msg += ` ${registeredCount} new product${registeredCount === 1 ? '' : 's'} registered.`
    $q.notify({ type: 'positive', message: msg })
    emit('saved')
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    $q.notify({ type: 'negative', message: savedCount > 0 ? `${msg} (${savedCount} saved)` : msg })
  } finally {
    submitting.value = false
  }
}

const onCancel = () => {
  if (cart.value.length === 0) {
    emit('cancel')
    return
  }
  $q.dialog({
    title: 'Discard cart?',
    message: 'Unsaved items will be lost.',
    cancel: true,
  }).onOk(() => {
    sessionStorage.removeItem(cartStorageKey.value)
    cart.value = []
    emit('cancel')
  })
}

const gbpCurrencyId = ref<number | null>(null)

onMounted(async () => {
  loadCartFromStorage()
  if (authStore.tenantId) void vendorStore.fetchVendors(authStore.tenantId)
  void loadBrowse()
  try {
    const currencyData = await globalReferenceRepository.listCurrencies()
    gbpCurrencyId.value = currencyData.find(c => c.code === 'GBP')?.id ?? null
  } catch (e) {
    console.error('Error fetching currencies:', e)
  }
})
</script>

<style scoped>
.add-items-panel {
  flex: 1;
  min-height: 0;
  background: transparent;
}

.add-items-panel--drawer {
  width: 100%;
}

.add-items-panel:not(.add-items-panel--drawer) {
  min-height: 70vh;
}

.toolbar-section {
  background: rgba(248, 250, 252, 0.5);
  border-bottom: 1px solid rgba(226, 232, 240, 0.8);
}

.new-product-btn {
  height: 40px;
}

.browse-section {
  min-height: 0;
}

.browse-list-container {
  overflow-y: auto;
  min-height: 150px;
}

.browse-list {
  border: 1px solid #e2e8f0;
}

.cart-section {
  min-height: 0;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.cart-scroll {
  overflow-y: auto;
  flex: 1;
}

.cart-line {
  background: rgba(248, 250, 252, 0.6);
  border: 1px solid rgba(226, 232, 240, 0.8);
}

.panel-footer {
  border-top: 1px solid rgba(226, 232, 240, 0.8);
  background: rgba(248, 250, 252, 0.5);
}

.ellipsis-2-lines {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.search-field-dropdown {
  border-right: 1px solid rgba(0, 0, 0, 0.12);
  border-radius: 0;
  margin-right: 8px;
  padding-right: 8px;
}

:deep(input[type="number"]::-webkit-outer-spin-button),
:deep(input[type="number"]::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

:deep(input[type="number"]) {
  -moz-appearance: textfield;
}
</style>

