<template>
  <q-page class="q-pa-md store-pricing-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold text-primary">Store Product Pricing</div>
            <div class="text-caption text-grey-8">Set regular and minimum sell prices for store products</div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Initial Loader -->
    <PageInitialLoader v-if="initialLoading" />

    <!-- Main Content -->
    <div v-else>

      <!-- Filters & Search Toolbar -->
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
            v-model="searchQuery"
            outlined
            dense
            class="soft-input toolbar-search"
            placeholder="Search by name, code or barcode..."
            clearable
            autofocus
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
                @click="
                  () => {
                    searchQuery = ''
                    showSearchInput = false
                  }
                "
              />
            </template>
          </q-input>

          <q-btn
            flat
            round
            dense
            icon="filter_alt"
            aria-label="Filters"
            @click="filterDrawerOpen = true"
          >
            <q-badge
              v-if="activeFilterCount > 0"
              color="primary"
              rounded
              floating
            >
              {{ activeFilterCount }}
            </q-badge>
          </q-btn>
        </div>

        <!-- Store selection dropdown -->
        <div class="row items-center q-gutter-sm">
          <div class="text-caption text-grey-8">Store:</div>
          <q-select
            v-model="selectedStoreId"
            :options="storeOptions"
            outlined
            dense
            emit-value
            map-options
            class="soft-input"
            style="min-width: 150px;"
          />
        </div>
      </div>

      <!-- Products Table with Row Expansion -->
      <q-table
        flat
        bordered
        :rows="rows"
        :columns="columns"
        row-key="product_id"
        :loading="loading"
        hide-bottom
        :pagination="{ rowsPerPage: 0 }"
        class="floating-surface shadow-1 pricing-q-table"
      >
        <template #header="props">
          <q-tr :props="props">
            <q-th auto-width />
            <q-th v-for="col in props.cols" :key="col.name" :props="props">
              {{ col.label }}
            </q-th>
          </q-tr>
        </template>

        <template #body="props">
          <q-tr :props="props">
            <q-td auto-width>
              <q-btn
                size="sm"
                flat
                round
                dense
                @click="props.expand = !props.expand"
                :icon="props.expand ? 'keyboard_arrow_up' : 'keyboard_arrow_down'"
              />
            </q-td>

            <!-- Image -->
            <q-td key="image" :props="props">
              <q-avatar rounded size="48px" class="bg-white overflow-hidden shadow-sm">
                <img
                  :src="props.row.image_url || fallbackImageUrl"
                  alt=""
                  style="object-fit: contain;"
                />
              </q-avatar>
            </q-td>

            <!-- Product Details -->
            <q-td key="name" :props="props" style="white-space: normal;">
              <div class="text-subtitle2 text-weight-bold text-primary" style="white-space: normal;">{{ props.row.name }}</div>
              <div class="text-caption text-grey-7">
                <span v-if="props.row.product_code" class="q-mr-sm">Code: {{ props.row.product_code }}</span>
                <span v-if="props.row.barcode">Barcode: {{ props.row.barcode }}</span>
              </div>
              <div v-if="props.row.note" class="text-caption text-grey-6 text-italic q-mt-xs" style="white-space: normal;">
                Note: {{ props.row.note }}
              </div>
            </q-td>

            <!-- Original Stock -->
            <q-td key="original_stock" :props="props">
              <div class="text-subtitle2 text-weight-medium text-grey-8">
                {{ getOriginalStock(props.row) }}
              </div>
            </q-td>

            <!-- Display Stock Override -->
            <q-td key="stock_override" :props="props">
              <div style="min-width: 120px; max-width: 150px;" v-if="tempPrices[props.row.product_id]">
                <q-input
                  v-model.number="tempPrices[props.row.product_id]!.stock_override"
                  type="number"
                  outlined
                  dense
                  placeholder="No override"
                  class="soft-input compact-input"
                  hide-bottom-space
                  :rules="[
                    val => val === null || val === '' || val >= 0 || 'Must be >= 0',
                  ]"
                />
              </div>
            </q-td>

            <!-- Regular Price -->
            <q-td key="price_bdt" :props="props">
              <div style="min-width: 150px; max-width: 200px;" v-if="tempPrices[props.row.product_id]">
                <q-input
                  v-model.number="tempPrices[props.row.product_id]!.price_bdt"
                  type="number"
                  outlined
                  dense
                  prefix="৳"
                  class="soft-input compact-input"
                  hide-bottom-space
                  :rules="[
                    val => val === null || val === '' || val >= 0 || 'Must be >= 0',
                    val => val === null || val === '' || !tempPrices[props.row.product_id]?.minimum_sell_price_bdt || val <= tempPrices[props.row.product_id]!.minimum_sell_price_bdt! || 'Must be <= min sell price'
                  ]"
                />
              </div>
            </q-td>

            <!-- Min Sell Price -->
            <q-td key="minimum_sell_price_bdt" :props="props">
              <div style="min-width: 150px; max-width: 200px;" v-if="tempPrices[props.row.product_id]">
                <q-input
                  v-model.number="tempPrices[props.row.product_id]!.minimum_sell_price_bdt"
                  type="number"
                  outlined
                  dense
                  prefix="৳"
                  class="soft-input compact-input"
                  hide-bottom-space
                  :rules="[
                    val => val === null || val === '' || val >= 0 || 'Must be >= 0',
                    val => val === null || val === '' || val >= (tempPrices[props.row.product_id]?.price_bdt || 0) || 'Must be >= regular price'
                  ]"
                />
                <div class="text-caption text-grey-6 q-mt-xs">
                  Profit: {{ getSellingPriceProfitRate(props.row.product_id) != null ? getSellingPriceProfitRate(props.row.product_id)!.toFixed(2) + '%' : '-' }}
                </div>
              </div>
            </q-td>

            <!-- Actions -->
            <q-td key="actions" :props="props" class="text-center">
              <q-btn
                flat
                round
                dense
                color="primary"
                icon="o_save"
                :loading="savingByProductId[props.row.product_id] || false"
                :disable="!isPriceModified(props.row.product_id)"
                @click="savePrices(props.row.product_id)"
              >
                <q-tooltip>Save Prices</q-tooltip>
              </q-btn>
            </q-td>
          </q-tr>

          <!-- Expansion row -->
          <q-tr v-show="props.expand" :props="props" class="bg-grey-1">
            <q-td colspan="100%" class="q-pa-md">
              <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-sm">Shipment Details & Costs</div>
              <q-table
                flat
                bordered
                dense
                :rows="props.row.items"
                :columns="expandedColumns"
                row-key="id"
                hide-bottom
                :pagination="{ rowsPerPage: 0 }"
                class="bg-white rounded-borders shadow-sm"
              >
                <template #body-cell-shipment="expProps">
                  <q-td :props="expProps">
                    {{ expProps.row.shipment?.shipment?.name || '-' }}
                  </q-td>
                </template>
                <template #body-cell-note="expProps">
                  <q-td :props="expProps" style="white-space: normal; max-width: 250px;">
                    {{ expProps.row.note || '-' }}
                  </q-td>
                </template>
                <template #body-cell-cost="expProps">
                  <q-td :props="expProps">
                    {{ expProps.row.cost ? formatAmountBdt(expProps.row.cost) : 'N/A' }}
                  </q-td>
                </template>
                <template #body-cell-available="expProps">
                  <q-td :props="expProps">
                    {{ expProps.row.quantities?.available ?? 0 }}
                  </q-td>
                </template>
                <template #body-cell-profit_reg="expProps">
                  <q-td :props="expProps">
                    <span 
                      v-if="getRegularProfitRate(props.row.product_id, expProps.row.cost) != null"
                      :class="(getRegularProfitRate(props.row.product_id, expProps.row.cost) ?? 0) >= 0 ? 'text-positive text-weight-medium' : 'text-negative text-weight-medium'"
                    >
                      {{ getRegularProfitRate(props.row.product_id, expProps.row.cost)!.toFixed(2) + '%' }}
                    </span>
                    <span v-else class="text-grey-5">-</span>
                  </q-td>
                </template>
                <template #body-cell-profit_sell="expProps">
                  <q-td :props="expProps">
                    <span 
                      v-if="getMinSellProfitRate(props.row.product_id, expProps.row.cost) != null"
                      :class="(getMinSellProfitRate(props.row.product_id, expProps.row.cost) ?? 0) >= 0 ? 'text-positive text-weight-medium' : 'text-negative text-weight-medium'"
                    >
                      {{ getMinSellProfitRate(props.row.product_id, expProps.row.cost)!.toFixed(2) + '%' }}
                    </span>
                    <span v-else class="text-grey-5">-</span>
                  </q-td>
                </template>
              </q-table>
            </q-td>
          </q-tr>
        </template>

        <template #no-data>
          <div class="full-width text-center text-grey-7 q-py-md">
            No products found.
          </div>
        </template>
      </q-table>

      <!-- Pagination Widget -->
      <div v-if="totalPages > 1" class="row justify-center q-py-md">
        <q-pagination
          v-model="page"
          :max="totalPages"
          :max-pages="8"
          boundary-numbers
          direction-links
          @update:model-value="onPageChange"
        />
      </div>

      <!-- Filters Drawer -->
      <FilterSidebar v-model="filterDrawerOpen" title="Filters">
        <q-select
          v-model="selectedShipmentId"
          :options="shipmentOptions"
          outlined
          dense
          emit-value
          map-options
          class="soft-input q-mb-md"
          label="Shipment Filter"
        />
        <div class="row q-gutter-sm justify-end">
          <q-btn flat no-caps label="Reset" @click="onResetFilters" />
        </div>
      </FilterSidebar>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, watch, onBeforeUnmount, computed } from 'vue'
import type { InventoryItemWithStock } from 'src/modules/inventory/types'

import { supabase } from 'src/boot/supabase'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useStoreStore } from 'src/modules/store/stores/storeStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { handleApiFailure, showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'
import { formatAmountBdt } from 'src/utils/currency'

// Fallback image url if product doesn't have an image
const fallbackImageUrl = 'https://placehold.co/48x48?text=No+Image'

const authStore = useAuthStore()
const storeStore = useStoreStore()
const shipmentStore = useShipmentStore()

interface PricingTableRow {
  product_id: number
  name: string
  image_url: string | null
  barcode: string | null
  product_code: string | null
  price_bdt: number | null
  minimum_sell_price_bdt: number | null
  stock_override: number | null
  note: string | null
  items: InventoryItemWithStock[]
}

// State
const initialLoading = ref(true)
const loading = ref(false)
const rows = ref<PricingTableRow[]>([])

const selectedStoreId = ref<number | null>(null)
const selectedShipmentId = ref<number | null>(null)
const searchQuery = ref('')
const showSearchInput = ref(false)
const filterDrawerOpen = ref(false)

const storeOptions = ref<Array<{ label: string; value: number }>>([])
const shipmentOptions = ref<Array<{ label: string; value: number | null }>>([])

// Pricing maps
const storePricingMap = ref<Record<number, { price_bdt: number | null; minimum_sell_price_bdt: number | null; stock_override?: number | null; id?: number }>>({})
const savingByProductId = ref<Record<number, boolean>>({})

// Form temporary inputs
const tempPrices = ref<Record<number, { price_bdt: number | null; minimum_sell_price_bdt: number | null; stock_override?: number | null }>>({})

// Pagination state
const page = ref(1)
const pageSize = ref(10)
const totalPages = ref(1)

const activeFilterCount = computed(() => (selectedShipmentId.value ? 1 : 0))

// Columns definitions
const columns = [
  { name: 'image', label: 'Image', field: 'image_url', align: 'left' as const },
  { name: 'name', label: 'Product Details', field: 'name', align: 'left' as const, style: 'min-width: 220px; white-space: normal;' },
  { name: 'original_stock', label: 'Original Stock', field: (row: PricingTableRow) => getOriginalStock(row), align: 'left' as const },
  { name: 'stock_override', label: 'Display Stock Override', field: 'stock_override', align: 'left' as const },
  { name: 'price_bdt', label: 'Regular Price (BDT)', field: 'price_bdt', align: 'left' as const },
  { name: 'minimum_sell_price_bdt', label: 'Min Sell Price (BDT)', field: 'minimum_sell_price_bdt', align: 'left' as const },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' as const }
]

const expandedColumns = [
  { name: 'shipment', label: 'Shipment', field: 'shipment', align: 'left' as const },
  { name: 'note', label: 'Note', field: 'note', align: 'left' as const },
  { name: 'cost', label: 'Cost (BDT)', field: 'cost', align: 'right' as const },
  { name: 'available', label: 'Available Stock', field: 'available', align: 'right' as const },
  { name: 'profit_reg', label: 'Regular Price Profit', field: 'profit_reg', align: 'right' as const },
  { name: 'profit_sell', label: 'Sell Price Profit', field: 'profit_sell', align: 'right' as const }
]

// Methods
const getOriginalStock = (row: PricingTableRow) => {
  return row.items?.reduce((sum: number, item: InventoryItemWithStock) => sum + (item.quantities?.available ?? 0), 0) ?? 0
}

const isPriceModified = (productId: number) => {
  const temp = tempPrices.value[productId]
  const saved = storePricingMap.value[productId]
  if (!temp) return false

  const tempPrice = temp.price_bdt ?? null
  const tempMinSell = temp.minimum_sell_price_bdt ?? null
  const tempStockOverride = temp.stock_override ?? null

  const savedPrice = saved?.price_bdt ?? null
  const savedMinSell = saved?.minimum_sell_price_bdt ?? null
  const savedStockOverride = saved?.stock_override ?? null

  return tempPrice !== savedPrice || tempMinSell !== savedMinSell || tempStockOverride !== savedStockOverride
}


// Profit margin calculators
const getRegularProfitRate = (productId: number, cost: number | null) => {
  if (cost == null || cost <= 0) return null
  const pricing = tempPrices.value[productId]
  const price = typeof pricing?.price_bdt === 'number' ? pricing.price_bdt : null
  if (price == null) return null
  return ((price - cost) / cost) * 100
}

const getSellingPriceProfitRate = (productId: number) => {
  const pricing = tempPrices.value[productId]
  const price = typeof pricing?.price_bdt === 'number' ? pricing.price_bdt : null
  const minSell = typeof pricing?.minimum_sell_price_bdt === 'number' ? pricing.minimum_sell_price_bdt : null
  if (minSell == null || price == null || price <= 0) return null
  return ((minSell - price) / price) * 100
}

const getMinSellProfitRate = (productId: number, cost: number | null) => {
  if (cost == null || cost <= 0) return null
  const pricing = tempPrices.value[productId]
  const minSell = typeof pricing?.minimum_sell_price_bdt === 'number' ? pricing.minimum_sell_price_bdt : null
  if (minSell == null) return null
  return ((minSell - cost) / cost) * 100
}

// Load paginated data securely via Postgres RPC
const loadData = async () => {
  if (!authStore.tenantId || !selectedStoreId.value) return
  loading.value = true

  try {
    const { data: rpcResult, error: rpcError } = await supabase.rpc('list_store_product_pricing', {
      p_tenant_id: authStore.tenantId,
      p_store_id: selectedStoreId.value,
      p_page: page.value,
      p_page_size: pageSize.value,
      p_search: searchQuery.value.trim() || null,
      p_shipment_id: selectedShipmentId.value || null
    } )

    if (rpcError) throw rpcError

    const parsedResult = rpcResult as {
      data: Array<{
        product_id: number
        name: string
        image_url: string | null
        barcode: string | null
        product_code: string | null
        price_bdt: number | null
        minimum_sell_price_bdt: number | null
        stock_override: number | null
        note: string | null
        items: InventoryItemWithStock[]
      }>
      meta: {
        total: number
        page: number
        page_size: number
        total_pages: number
      }
    } | null

    const pageData = parsedResult?.data ?? []
    totalPages.value = parsedResult?.meta?.total_pages ?? 1

    const productIds: number[] = []

    // Pre-populate tempPrices and storePricingMap
    pageData.forEach(row => {
      const id = row.product_id
      productIds.push(id)

      storePricingMap.value[id] = {
        price_bdt: row.price_bdt,
        minimum_sell_price_bdt: row.minimum_sell_price_bdt,
        stock_override: row.stock_override
      }
      
      if (!tempPrices.value[id]) {
        tempPrices.value[id] = {
          price_bdt: row.price_bdt,
          minimum_sell_price_bdt: row.minimum_sell_price_bdt,
          stock_override: row.stock_override
        }
      }
    })

    rows.value = pageData
  } catch (error) {
    console.error('[pricing] Error loading pricing data:', error)
    handleApiFailure(
      { success: false, error: error instanceof Error ? error.message : String(error) },
      'Failed to load pricing details.',
    )
  } finally {
    loading.value = false
  }
}

// Save prices
const savePrices = async (productId: number) => {
  if (!authStore.tenantId || !selectedStoreId.value) return

  const prices = tempPrices.value[productId]
  if (!prices) return

  const priceBdt = !prices.price_bdt && prices.price_bdt !== 0 ? null : Number(prices.price_bdt)
  const minSellBdt = !prices.minimum_sell_price_bdt && prices.minimum_sell_price_bdt !== 0 ? null : Number(prices.minimum_sell_price_bdt)
  const stockOverride = !prices.stock_override && prices.stock_override !== 0 ? null : Number(prices.stock_override)

  if (priceBdt === null || isNaN(priceBdt) || priceBdt < 0) {
    showWarningDialog('Please enter a valid regular price (greater than or equal to 0).')
    return
  }
  if (minSellBdt === null || isNaN(minSellBdt) || minSellBdt < 0) {
    showWarningDialog('Please enter a valid min sell price (greater than or equal to 0).')
    return
  }
  if (minSellBdt < priceBdt) {
    showWarningDialog('Minimum sell price must be greater than or equal to the regular price.')
    return
  }
  if (stockOverride !== null && (isNaN(stockOverride) || stockOverride < 0)) {
    showWarningDialog('Please enter a valid display stock override (greater than or equal to 0).')
    return
  }

  savingByProductId.value = { ...savingByProductId.value, [productId]: true }

  try {
    // Upsert prices and stock override in store_product_prices
    const { data, error: priceError } = await supabase
      .from('store_product_prices')
      .upsert(
        {
          tenant_id: authStore.tenantId,
          store_id: selectedStoreId.value,
          inventory_item_id: productId, // Since productId is actually inventory_item_id in row key mapping
          price_bdt: priceBdt,
          minimum_sell_price_bdt: minSellBdt,
          stock_override: stockOverride,
          is_active: true,
        },
        { onConflict: 'tenant_id,store_id,inventory_item_id' },
      )
      .select('*')
      .single()

    if (priceError) throw priceError

    showSuccessNotification('Pricing and stock override updated successfully.')

    // Update store pricing map
    storePricingMap.value[productId] = {
      price_bdt: priceBdt,
      minimum_sell_price_bdt: minSellBdt,
      stock_override: stockOverride,
      id: data?.id,
    }
  } catch (error) {
    console.error('[pricing] Error saving prices and stock override:', error)
    handleApiFailure(
      { success: false, error: error instanceof Error ? error.message : String(error) },
      'Failed to save product pricing.',
    )
  } finally {
    savingByProductId.value = { ...savingByProductId.value, [productId]: false }
  }
}

// Watchers for reactive updates
let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null

watch(searchQuery, () => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer)
  searchDebounceTimer = setTimeout(() => {
    page.value = 1
    void loadData()
  }, 400)
})

watch(selectedShipmentId, () => {
  page.value = 1
  void loadData()
})

watch(selectedStoreId, () => {
  page.value = 1
  void loadData()
})

const onResetFilters = () => {
  selectedShipmentId.value = null
  searchQuery.value = ''
  filterDrawerOpen.value = false
}

const onPageChange = async (nextPage: number) => {
  page.value = nextPage
  await loadData()
}

// Initial setup
onMounted(async () => {
  try {
    if (!authStore.tenantId) return

    // 1. Load shipments lookup options
    await shipmentStore.fetchShipments(authStore.tenantId)
    shipmentOptions.value = [
      { label: 'All Shipments', value: null },
      ...shipmentStore.shipments
        .filter((s) => s.inventory_added)
        .map((s) => ({
          label: `#${s.tenant_shipment_id ?? s.id} ${s.name}`,
          value: s.id
        }))
    ]

    // 2. Load stores list
    await storeStore.fetchStoresAdmin(authStore.tenantId)
    storeOptions.value = storeStore.items.map((store) => ({
      label: store.name,
      value: store.id,
    }))

    if (storeStore.items.length > 0 && storeStore.items[0]) {
      selectedStoreId.value = storeStore.items[0].id
    }

    // 3. Load first page of data
    await loadData()
  } finally {
    initialLoading.value = false
  }
})

onBeforeUnmount(() => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer)
})
</script>

<style scoped>
.store-pricing-page {
  background: transparent;
}

.hero-surface {
  border-radius: 16px;
}

.pricing-q-table {
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.86);
  backdrop-filter: blur(6px);
  border: 1px solid rgba(34, 56, 101, 0.08);
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.compact-input :deep(.q-field__control) {
  height: 40px;
  font-size: 0.85rem;
}

.shadow-sm {
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

.toolbar-left {
  min-width: 0;
}

.toolbar-search {
  width: min(320px, 75vw);
}
</style>
