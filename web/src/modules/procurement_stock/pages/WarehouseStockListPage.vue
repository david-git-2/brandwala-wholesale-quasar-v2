<template>
  <q-page class="bw-page">
    <section class="bw-page__stack" style="min-width: 0;">
      <AppPageHeader
        eyebrow="Procurement & Stock"
        title="Warehouse Stock"
        subtitle="View physical stock pools and configure stock types"
      >
        <template #action>
          <q-btn
            outline
            color="secondary"
            no-caps
            icon="settings"
            label="Stock Types Config"
            @click="openStockTypesConfig"
          />
          <q-btn
            unelevated
            color="primary"
            no-caps
            icon="call_split"
            label="Allocate Stock"
            :to="allocateStockRoute"
          />
        </template>
      </AppPageHeader>

      <q-banner v-if="stockStore.error" class="bw-status-banner bg-negative text-white q-mb-md">
        {{ stockStore.error }}
      </q-banner>

      <!-- Search & Filters Toolbar -->
      <div class="row items-center q-gutter-sm q-mb-md">
        <q-input
          v-model="searchText"
          filled
          dense
          clearable
          class="col-grow"
          placeholder="Search by product name, code, barcode or shipment..."
          @keyup.enter="onSearch"
          @clear="onSearch"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
        </q-input>

        <q-btn flat round dense icon="filter_alt" @click="openFilterDrawer">
          <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
            {{ activeFilterCount }}
          </q-badge>
        </q-btn>
      </div>

      <!-- Filter Sidebar -->
      <FilterSidebar v-model="filterDrawerOpen" title="Filters">
        <div class="q-gutter-y-md q-pa-sm">
          <q-select
            v-model="draftStockTypeFilter"
            :options="stockTypeOptions"
            filled
            dense
            clearable
            emit-value
            map-options
            label="Stock Type"
          />

          <q-select
            v-model="draftShipmentStatusFilter"
            :options="shipmentStatusOptions"
            filled
            dense
            clearable
            emit-value
            map-options
            label="Shipment Status"
          />

          <q-toggle
            v-model="draftIsSellableFilter"
            label="Sellable Only"
            left-label
          />

          <q-toggle
            v-model="draftHideZeroStockFilter"
            label="Hide Zero Stock"
            left-label
          />

          <div class="row justify-end q-gutter-x-sm q-mt-md">
            <q-btn flat no-caps label="Reset" color="grey-7" @click="onResetFilters" />
            <q-btn unelevated no-caps label="Apply Filters" color="primary" @click="onApplyDrawerFilters" />
          </div>
        </div>
      </FilterSidebar>

      <PageInitialLoader v-if="stockStore.loading && !stockStore.rows.length" />

      <!-- Stock Table -->
      <q-card v-else flat bordered class="q-pa-none overflow-hidden" style="min-width: 0;">
        <q-table
          flat
          :rows="stockStore.rows"
          :columns="columns"
          row-key="id"
          :loading="stockStore.loading"
          v-model:pagination="pagination"
          :rows-per-page-options="[10, 20, 50]"
          table-style="min-width: 1200px;"
          @request="onTableRequest"
        >
          <template #body-cell-image="props">
            <q-td :props="props">
              <q-avatar rounded size="42px" class="bg-grey-2">
                <img
                  :src="props.row.image_url || 'https://placehold.co/56x56?text=No+Image'"
                  alt="Product Image"
                  style="object-fit: contain;"
                />
              </q-avatar>
            </q-td>
          </template>

          <template #body-cell-product="props">
            <q-td :props="props">
              <div class="text-weight-bold text-grey-9">{{ props.row.item_name }}</div>
              <div class="text-caption text-grey-6 row q-gutter-x-sm">
                <span v-if="props.row.product_code">Code: {{ props.row.product_code }}</span>
                <span v-if="props.row.barcode">Barcode: {{ props.row.barcode }}</span>
              </div>
            </q-td>
          </template>

          <template #body-cell-usable="props">
            <q-td :props="props">
              <q-icon
                :name="props.row.is_usable ? 'check_circle' : 'cancel'"
                :color="props.row.is_usable ? 'green-6' : 'red-6'"
                size="20px"
              />
            </q-td>
          </template>

          <template #body-cell-cost="props">
            <q-td :props="props" class="text-right text-secondary">
              <div>৳{{ formatCost(getUnitCost(props.row)) }}</div>
              <div class="text-caption text-grey-6 text-weight-normal" style="font-size: 10px;">
                T: ৳{{ formatCost(getUnitCost(props.row) * props.row.quantity) }}
              </div>
            </q-td>
          </template>

          <template #body-cell-quantity="props">
            <q-td :props="props" class="text-weight-bold text-primary">
              {{ props.row.quantity }} pcs
            </q-td>
          </template>

          <template #bottom-row>
            <q-tr class="totals-row">
              <q-td class="totals-row__cell" /> <!-- image -->
              <q-td class="totals-row__cell text-weight-bold text-grey-9">Total (Page)</q-td> <!-- product name -->
              <q-td class="totals-row__cell" /> <!-- shipment -->
              <q-td class="totals-row__cell" /> <!-- stock type -->
              <q-td class="totals-row__cell" /> <!-- usable -->
              <q-td class="totals-row__cell text-right stock-cost-col text-weight-bold text-secondary">
                <div>৳{{ formatCost(pageTotals.avgUnitCost) }} (avg)</div>
                <div class="text-caption text-grey-7 text-weight-normal" style="font-size: 10px;">
                  T: ৳{{ formatCost(pageTotals.totalCost) }}
                </div>
              </q-td> <!-- cost -->
              <q-td class="totals-row__cell text-right stock-qty-col text-weight-bold text-primary">
                {{ pageTotals.totalQty }} pcs
              </q-td> <!-- quantity -->
            </q-tr>
          </template>

          <template #no-data>
            <div class="full-width text-center text-grey-7 q-py-lg">
              <q-icon name="inventory_2" size="48px" class="q-mb-sm text-grey-4" />
              <div>No Warehouse Stock Found.</div>
            </div>
          </template>
        </q-table>
      </q-card>

    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useQuasar, type QTableColumn } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useGlobalStockStore } from '../stores/globalStockStore'
import { useGlobalStockTypeStore } from '../stores/globalStockTypeStore'
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import StockTypeConfigPanel from '../components/StockTypeConfigPanel.vue'
import { calculateLineLandedCostBdt } from '../utils/landedCost'

const authStore = useAuthStore()
const stockStore = useGlobalStockStore()
const stockTypeStore = useGlobalStockTypeStore()
const $q = useQuasar()

// Filter State
const searchText = ref('')
const filterDrawerOpen = ref(false)
const stockTypeFilter = ref<number | null>(null)
const isSellableFilter = ref<boolean | null>(null)
const shipmentStatusFilter = ref<string | null>(null)
const hideZeroStockFilter = ref<boolean>(true)

const draftStockTypeFilter = ref<number | null>(null)
const draftIsSellableFilter = ref<boolean | null>(null)
const draftShipmentStatusFilter = ref<string | null>(null)
const draftHideZeroStockFilter = ref<boolean>(true)

const columns: QTableColumn[] = [
  { name: 'image', label: 'Image', field: 'image_url', align: 'left', sortable: false },
  { name: 'product', label: 'Product Details', field: 'item_name', align: 'left', sortable: false },
  { name: 'shipment', label: 'Shipment', field: 'shipment_name', align: 'left', sortable: false },
  { name: 'stock_type', label: 'Stock Type', field: 'stock_type_description', align: 'left', sortable: false },
  { name: 'usable', label: 'Usable', field: 'is_usable', align: 'center', sortable: false },
  { name: 'cost', label: 'Cost (Est. BDT)', field: 'id', align: 'right', sortable: false, classes: 'stock-cost-col', headerClasses: 'stock-cost-col' },
  { name: 'quantity', label: 'Quantity', field: 'quantity', align: 'right', sortable: false, classes: 'stock-qty-col', headerClasses: 'stock-qty-col' },
]

const pagination = computed({
  get: () => ({
    page: stockStore.page,
    rowsPerPage: stockStore.pageSize,
    rowsNumber: stockStore.total,
  }),
  set: (val) => {
    stockStore.page = val.page
    stockStore.pageSize = val.rowsPerPage
  }
})

const activeFilterCount = computed(() => {
  let count = 0
  if (stockTypeFilter.value !== null) count++
  if (isSellableFilter.value !== null) count++
  if (shipmentStatusFilter.value !== null) count++
  if (!hideZeroStockFilter.value) count++
  return count
})

const stockTypeOptions = computed(() => {
  return stockTypeStore.items.map((t) => ({ label: t.description, value: t.id }))
})

const shipmentStatusOptions = [
  { label: 'All', value: '__all__' },
  { label: 'Warehouse Received', value: 'Warehouse Received' },
  { label: 'Ready Stock', value: 'Ready Stock' },
]

const getUnitCost = (row: any): number => {
  return calculateLineLandedCostBdt(row, {
    ...row,
    type: row.shipment_type,
  })
}

const formatCost = (val: number): string => {
  return val.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

const pageTotals = computed(() => {
  let totalQty = 0
  let totalCost = 0
  const rows = stockStore.rows
  for (const row of rows) {
    const qty = row.quantity || 0
    const unitCost = getUnitCost(row)
    totalQty += qty
    totalCost += unitCost * qty
  }
  const avgUnitCost = totalQty > 0 ? totalCost / totalQty : 0
  return {
    totalQty,
    totalCost,
    avgUnitCost,
  }
})

const allocateStockRoute = computed(() => {
  const slug = authStore.tenantSlug
  return slug ? `/${slug}/app/procurement/stock/allocate` : '/app/procurement/stock/allocate'
})

const loadStock = async () => {
  if (!authStore.tenantId) return
  await stockStore.fetchStocks(authStore.tenantId, {
    page: stockStore.page,
    pageSize: stockStore.pageSize,
    search: searchText.value.trim() || null,
    stockTypeId: stockTypeFilter.value,
    isSellable: isSellableFilter.value,
    shipmentStatus: shipmentStatusFilter.value === '__all__' ? null : shipmentStatusFilter.value,
    hideZeroStock: hideZeroStockFilter.value,
  })
}

const onTableRequest = async (props: any) => {
  stockStore.page = props.pagination.page
  stockStore.pageSize = props.pagination.rowsPerPage
  await loadStock()
}

const onSearch = () => {
  stockStore.page = 1
  void loadStock()
}

// Filter Actions
const openFilterDrawer = () => {
  draftStockTypeFilter.value = stockTypeFilter.value
  draftIsSellableFilter.value = isSellableFilter.value
  draftShipmentStatusFilter.value = shipmentStatusFilter.value
  draftHideZeroStockFilter.value = hideZeroStockFilter.value
  filterDrawerOpen.value = true
}

const onApplyDrawerFilters = () => {
  stockTypeFilter.value = draftStockTypeFilter.value
  isSellableFilter.value = draftIsSellableFilter.value
  shipmentStatusFilter.value = draftShipmentStatusFilter.value
  hideZeroStockFilter.value = draftHideZeroStockFilter.value
  filterDrawerOpen.value = false
  stockStore.page = 1
  void loadStock()
}

const onResetFilters = () => {
  draftStockTypeFilter.value = null
  draftIsSellableFilter.value = null
  draftShipmentStatusFilter.value = null
  draftHideZeroStockFilter.value = true
  stockTypeFilter.value = null
  isSellableFilter.value = null
  shipmentStatusFilter.value = null
  hideZeroStockFilter.value = true
  filterDrawerOpen.value = false
  stockStore.page = 1
  void loadStock()
}

const openStockTypesConfig = () => {
  $q.dialog({
    component: StockTypeConfigPanel,
  }).onOk(() => {
    void loadStock()
  })
}

onMounted(async () => {
  if (authStore.tenantId) {
    await stockTypeStore.fetchStockTypes(authStore.tenantId)
  }
  void loadStock()
})
</script>

<style scoped>
.stock-cost-col {
  background-color: #ffe8d1 !important;
}

.stock-qty-col {
  background-color: #d0e6ff !important;
}

.totals-row {
  font-weight: 600;
  background-color: rgba(0, 0, 0, 0.02);
}

.totals-row__cell {
  border-top: 1px solid rgba(0, 0, 0, 0.12);
  padding: 8px 16px;
}
</style>

