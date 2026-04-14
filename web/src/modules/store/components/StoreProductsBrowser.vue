<template>
  <q-page class="q-pa-md">
    <div class="text-h6 q-mb-md">Store Products</div>

    <div class="row q-col-gutter-md items-end q-mb-md">
      <div class="col-12 col-sm-4 col-md-3">
        <q-input v-model="search" outlined dense type="text" label="Search" />
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
        <q-btn color="negative" outline label="Reset" @click="onResetFilters" />
      </div>
    </div>

    <q-btn-toggle
      v-if="storeOptions.length"
      v-model="selectedStoreId"
      no-caps
      unelevated
      toggle-color="primary"
      :options="storeOptions"
      @update:model-value="onStoreSelectionChange"
    />

    <ProductCardGrid
      :items="productCardItems"
      :show-price="props.mode === 'admin' || customerCanSeePrice"
      :show-cart="props.mode === 'customer'"
      :show-info="props.mode === 'admin'"
      :store-id="selectedStoreId"
      :cart-item-by-product-id="cartItemByProductId"
      :cart-quantity-by-product-id="cartQuantityByProductId"
      @add-to-cart="onAddToCart"
      @remove-from-cart="onRemoveFromCart"
      @update-cart-qty="onUpdateCartQty"
    />

    <div v-if="totalPages > 1" class="row justify-center q-mt-md">
      <q-pagination
        :model-value="storeStore.productsPage"
        :max="totalPages"
        :max-pages="8"
        boundary-numbers
        direction-links
        @update:model-value="onPageChange"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useCartStore } from 'src/modules/cart/stores/cartStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { storeService } from '../services/storeService'
import { useStoreStore } from '../stores/storeStore'
import ProductCardGrid from './ProductCardGrid.vue'

const props = withDefaults(
  defineProps<{
    mode?: 'admin' | 'customer'
  }>(),
  {
    mode: 'admin',
  },
)

const tenantStore = useTenantStore()
const storeStore = useStoreStore()
const authStore = useAuthStore()
const cartStore = useCartStore()

type FilterOption = {
  label: string
  value: string | null
}

type ProductCardItem = {
  id: number
  name: string
  brand?: string | null
  barcode?: string | null
  category?: string | null
  image_url?: string | null
  languages?: string | null
  price_gbp?: number | null
  tenant_id?: number
  created_at?: string
  updated_at?: string
  expire_date?: string | null
  market_code?: string | null
  tariff_code?: string | null
  vendor_code?: string | null
  is_available?: boolean
  product_code?: string | null
  package_weight?: number | null
  product_weight?: number | null
  available_units?: number | null
  country_of_origin?: string | null
  minimum_order_quantity?: number | null
  batch_code_manufacture_date?: string | null
}

const allBrandOption: FilterOption = {
  label: 'All brands',
  value: null,
}

const allCategoryOption: FilterOption = {
  label: 'All categories',
  value: null,
}

const selectedStoreId = ref<number | null>(null)
const storeOptions = ref<Array<{ label: string; value: number }>>([])
const search = ref('')
const category = ref<string | null>(null)
const brand = ref<string | null>(null)
let searchDebounceTimer: ReturnType<typeof setTimeout> | undefined
const suppressFilterWatch = ref(false)

const brandNames = ref<string[]>([])
const categoryNames = ref<string[]>([])
const filteredBrandNames = ref<string[]>([])
const filteredCategoryNames = ref<string[]>([])

const filteredBrandOptions = computed<FilterOption[]>(() => [
  allBrandOption,
  ...filteredBrandNames.value.map((item) => ({ label: item, value: item })),
])

const filteredCategoryOptions = computed<FilterOption[]>(() => [
  allCategoryOption,
  ...filteredCategoryNames.value.map((item) => ({ label: item, value: item })),
])

const totalPages = computed(() =>
  Math.max(1, Math.ceil(storeStore.productsTotal / storeStore.productsPageSize)),
)
const productCardItems = computed<ProductCardItem[]>(() =>
  storeStore.productItems
    .filter(
      (item): item is Record<string, unknown> & { id: number; name: string } =>
        typeof item['id'] === 'number' && typeof item['name'] === 'string',
    )
    .map((item) => ({
      ...item,
      id: item.id,
      name: item.name,
    })),
)
const customerCanSeePrice = computed(() => {
  if (storeStore.productsCanSeePrice) {
    return true
  }

  return storeStore.productItems.some((item) => {
    const price = item['price_gbp']
    return price !== null && price !== undefined
  })
})
const cartItemByProductId = computed<Record<number, number>>(() => {
  const map: Record<number, number> = {}

  cartStore.items.forEach((item) => {
    if (item.product_id != null) {
      map[item.product_id] = item.id
    }
  })

  return map
})
const cartQuantityByProductId = computed<Record<number, number>>(() => {
  const map: Record<number, number> = {}

  cartStore.items.forEach((item) => {
    if (item.product_id != null) {
      map[item.product_id] = item.quantity
    }
  })

  return map
})

const loadProducts = async (storeId: number, page = 1) => {
  const limit = storeStore.productsPageSize || 20
  const offset = Math.max(0, (page - 1) * limit)

  await storeStore.fetchStoreProducts({
    store_id: storeId,
    search: search.value || null,
    category: category.value || null,
    brand: brand.value || null,
    sort_by: 'id',
    sort_dir: 'asc',
    limit,
    offset,
  })
}

const loadBrands = async (storeId: number) => {
  const result = await storeService.getStoreProductBrands(storeId)

  if (result.success) {
    brandNames.value = result.data ?? []
    filteredBrandNames.value = result.data ?? []
  }
}

const loadCategories = async (storeId: number) => {
  const result = await storeService.getStoreProductCategories(storeId)

  if (result.success) {
    categoryNames.value = result.data ?? []
    filteredCategoryNames.value = result.data ?? []
  }
}

const onStoreSelectionChange = async (storeId: number | string | null) => {
  if (!storeId) {
    return
  }

  const numericStoreId = Number(storeId)
  const selectedStore = storeStore.items.find((store) => store.id === numericStoreId)
  if (props.mode === 'customer') {
    storeStore.productsCanSeePrice = Boolean(selectedStore?.see_price)
  }

  suppressFilterWatch.value = true

  try {
    brand.value = null
    category.value = null
    await Promise.all([loadBrands(numericStoreId), loadCategories(numericStoreId)])
  } finally {
    suppressFilterWatch.value = false
  }

  await loadProducts(numericStoreId, 1)

  if (props.mode === 'customer') {
    const tenantId = authStore.tenantId
    if (tenantId) {
      await cartStore.fetchItemsForContext({
        tenant_id: tenantId,
        store_id: numericStoreId,
        customer_group_id: authStore.customerGroupId ?? null,
      })
    }
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
      item.toLowerCase().includes(needle),
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
      item.toLowerCase().includes(needle),
    )
  })
}

const scheduleSearchLoad = () => {
  if (suppressFilterWatch.value || !selectedStoreId.value) {
    return
  }

  if (searchDebounceTimer) {
    clearTimeout(searchDebounceTimer)
  }

  searchDebounceTimer = setTimeout(() => {
    void loadProducts(selectedStoreId.value!, 1)
  }, 400)
}

watch(search, () => {
  scheduleSearchLoad()
})

watch([category, brand], () => {
  if (suppressFilterWatch.value || !selectedStoreId.value) {
    return
  }

  void loadProducts(selectedStoreId.value, 1)
})

const onPageChange = async (page: number) => {
  if (!selectedStoreId.value) {
    return
  }

  await loadProducts(selectedStoreId.value, page)
}

const onResetFilters = async () => {
  if (!selectedStoreId.value) {
    return
  }

  suppressFilterWatch.value = true

  try {
    search.value = ''
    brand.value = null
    category.value = null
    filteredBrandNames.value = [...brandNames.value]
    filteredCategoryNames.value = [...categoryNames.value]
    await loadProducts(selectedStoreId.value, 1)
  } finally {
    suppressFilterWatch.value = false
  }
}

const onAddToCart = async (payload: {
  store_id: number | null
  item: ProductCardItem
  quantity: number
  minimum_quantity: number
}) => {
  if (props.mode !== 'customer') {
    return
  }

  const tenantId = authStore.tenantId
  if (!tenantId) {
    return
  }

  const selectedStore = storeStore.items.find((store) => store.id === (payload.store_id ?? -1))

  await cartStore.addItemToCart({
    tenant_id: tenantId,
    store_id: payload.store_id,
    customer_group_id: authStore.customerGroupId ?? null,
    can_see_price: Boolean(selectedStore?.see_price),
    product_id: payload.item.id,
    name: payload.item.name,
    image_url: payload.item.image_url ?? null,
    price_gbp: payload.item.price_gbp ?? null,
    quantity: payload.quantity,
    minimum_quantity: payload.minimum_quantity,
  })
}

const onRemoveFromCart = async (payload: { cart_item_id: number }) => {
  if (props.mode !== 'customer') {
    return
  }

  await cartStore.deleteCartItem({
    id: payload.cart_item_id,
  })
}

const onUpdateCartQty = async (payload: {
  cart_item_id: number
  quantity: number
  minimum_quantity: number
}) => {
  if (props.mode !== 'customer') {
    return
  }

  await cartStore.updateCartItem({
    id: payload.cart_item_id,
    quantity: payload.quantity,
    minimum_quantity: payload.minimum_quantity,
  })
}

onMounted(async () => {
  if (props.mode === 'customer') {
    await storeStore.fetchStoresForCustomer()
  } else {
    const tenantId = tenantStore.selectedTenant?.id ?? 0
    await storeStore.fetchStoresAdmin(tenantId)
  }

  storeOptions.value = storeStore.items.map((store) => ({
    label: store.name,
    value: store.id,
  }))

  const firstStore = storeStore.items[0]

  if (!firstStore) {
    return
  }

  selectedStoreId.value = firstStore.id
  if (props.mode === 'customer') {
    storeStore.productsCanSeePrice = Boolean(firstStore.see_price)
  }
  await Promise.all([loadBrands(firstStore.id), loadCategories(firstStore.id)])
  await loadProducts(firstStore.id, 1)

  if (props.mode === 'customer') {
    const tenantId = authStore.tenantId
    if (tenantId) {
      await cartStore.fetchItemsForContext({
        tenant_id: tenantId,
        store_id: firstStore.id,
        customer_group_id: authStore.customerGroupId ?? null,
      })
    }
  }
})

onBeforeUnmount(() => {
  if (searchDebounceTimer) {
    clearTimeout(searchDebounceTimer)
  }
})
</script>
