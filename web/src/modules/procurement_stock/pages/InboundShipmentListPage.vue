<template>
  <q-page class="bw-page q-pa-xs">
    <section class="bw-page__stack">
      <!-- Compact Header Design -->
      <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
        <q-card-section class="q-py-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-12 col-sm">
              <div class="text-h6 text-weight-bold text-grey-9">Inbound Shipments</div>
              <div class="text-caption text-grey-7">Manage inbound supplier shipment batches, costing, and statuses</div>
            </div>
            <div class="col-12 col-sm-auto row justify-start justify-sm-end q-mt-xs q-mt-sm-none">
              <q-btn
                color="primary"
                no-caps
                size="sm"
                class="pill-btn slim-btn"
                icon="add"
                label="Add Shipment"
                @click="openCreateShipment"
              />
            </div>
          </div>
        </q-card-section>
      </q-card>

      <q-banner v-if="shipmentStore.error" class="bw-status-banner bg-negative text-white q-mb-md">
        {{ shipmentStore.error }}
      </q-banner>

      <!-- Search & Filters Toolbar -->
      <div class="row items-center q-gutter-sm q-mb-md">
        <q-input
          v-model="searchText"
          filled
          dense
          clearable
          class="col-grow"
          placeholder="Search by shipment name or ID..."
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
            v-model="draftStatusFilter"
            :options="statusOptions"
            filled
            dense
            clearable
            emit-value
            map-options
            label="Filter by Status"
          />

          <div class="row justify-end q-gutter-x-sm q-mt-md">
            <q-btn flat no-caps label="Reset" color="grey-7" @click="onResetFilters" />
            <q-btn unelevated no-caps label="Apply Filters" color="primary" @click="onApplyDrawerFilters" />
          </div>
        </div>
      </FilterSidebar>

      <PageInitialLoader v-if="shipmentStore.loading && !shipmentStore.rows.length" />

      <!-- Shipments Table -->
      <q-card v-else flat class="floating-surface shadow-1 q-pa-none">
        <q-table
          flat
          :rows="shipmentStore.rows"
          :columns="columns"
          row-key="id"
          :loading="shipmentStore.loading"
          v-model:pagination="pagination"
          :rows-per-page-options="[10, 20, 50]"
          @request="onTableRequest"
          class="shipment-list-table cursor-pointer"
        >
          <template #body="props">
            <q-tr
              :props="props"
              :style="statusSurfaceStyle(props.row.status)"
              @click="onRowClick($event, props.row)"
            >
              <q-td key="id" :props="props">
                #{{ props.row.tenant_shipment_id || props.row.id }}
              </q-td>
              <q-td key="name" :props="props">
                {{ props.row.name ?? '-' }}
              </q-td>
              <q-td key="type" :props="props" class="text-capitalize">
                {{ props.row.type }}
              </q-td>
              <q-td key="status" :props="props">
                <q-chip
                  dense
                  square
                  :style="statusChipStyle(props.row.status)"
                  class="shipment-status-chip"
                >
                  <span class="status-dot" :style="{ backgroundColor: statusDotColor(props.row.status) }" />
                  {{ props.row.status }}
                </q-chip>
              </q-td>
              <q-td key="received_date" :props="props">
                {{ props.row.received_date || '-' }}
              </q-td>
            </q-tr>
          </template>

          <template #no-data>
            <div class="full-width text-center text-grey-7 q-py-lg">
              <q-icon name="local_shipping" size="48px" class="q-mb-sm text-grey-4" />
              <div>No Inbound Shipments Found.</div>
            </div>
          </template>
        </q-table>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar, type QTableColumn } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import type { GlobalShipment } from '../repositories/globalShipmentRepository'
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import ShipmentFormDialog from '../components/ShipmentFormDialog.vue'

const authStore = useAuthStore()
const shipmentStore = useGlobalShipmentStore()
const router = useRouter()
const $q = useQuasar()

// Filter State
const searchText = ref('')
const filterDrawerOpen = ref(false)
const statusFilter = ref<string | null>(null)
const draftStatusFilter = ref<string | null>(null)

const statusOptions = [
  { label: 'All Statuses', value: '__all__' },
  { label: 'Draft', value: 'Draft' },
  { label: 'Order Placed', value: 'Order Placed' },
  { label: 'Proforma Generated', value: 'Proforma Generated' },
  { label: 'Payment Done', value: 'Payment Done' },
  { label: 'Delivery Date Received', value: 'Delivery Date Received' },
  { label: 'UK Warehouse Delivery Received', value: 'Uk Warehouse Delivery Received' },
  { label: 'Air Shipment Date Set', value: 'Air Shipment Date Set' },
  { label: 'Airport Arrival', value: 'Airport Arrival' },
  { label: 'Airport Released', value: 'Airport Released' },
  { label: 'Warehouse Received', value: 'Warehouse Received' },
  { label: 'Ready Stock', value: 'Ready Stock' },
]

const columns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'tenant_shipment_id', align: 'left', sortable: false },
  { name: 'name', label: 'Shipment Name', field: 'name', align: 'left', sortable: false },
  { name: 'type', label: 'Type', field: 'type', align: 'left', sortable: false },
  { name: 'status', label: 'Status', field: 'status', align: 'left', sortable: false },
  { name: 'received_date', label: 'Received Date', field: 'received_date', align: 'left', sortable: false },
]

const pagination = computed({
  get: () => ({
    page: shipmentStore.page,
    rowsPerPage: shipmentStore.pageSize,
    rowsNumber: shipmentStore.total,
  }),
  set: (val) => {
    shipmentStore.page = val.page
    shipmentStore.pageSize = val.rowsPerPage
  }
})

const activeFilterCount = computed(() => {
  return statusFilter.value && statusFilter.value !== '__all__' ? 1 : 0
})

const loadShipments = async () => {
  if (!authStore.tenantId) return
  await shipmentStore.fetchShipments(authStore.tenantId, {
    page: shipmentStore.page,
    pageSize: shipmentStore.pageSize,
    search: searchText.value.trim() || null,
    status: statusFilter.value === '__all__' ? null : statusFilter.value,
  })
}

const onTableRequest = async (props: { pagination: { page: number; rowsPerPage: number } }) => {
  shipmentStore.page = props.pagination.page
  shipmentStore.pageSize = props.pagination.rowsPerPage
  await loadShipments()
}

const onSearch = () => {
  shipmentStore.page = 1
  void loadShipments()
}

// Filter Actions
const openFilterDrawer = () => {
  draftStatusFilter.value = statusFilter.value
  filterDrawerOpen.value = true
}

const onApplyDrawerFilters = () => {
  statusFilter.value = draftStatusFilter.value
  filterDrawerOpen.value = false
  shipmentStore.page = 1
  void loadShipments()
}

const onResetFilters = () => {
  draftStatusFilter.value = null
  statusFilter.value = null
  filterDrawerOpen.value = false
  shipmentStore.page = 1
  void loadShipments()
}

const onRowClick = (_evt: Event, row: GlobalShipment) => {
  viewDetails(row.id)
}

const viewDetails = (id: number) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  void router.push(`${tenantPrefix}/app/procurement/shipment/${id}`)
}

const openCreateShipment = () => {
  $q.dialog({
    component: ShipmentFormDialog,
  }).onOk(() => {
    void loadShipments()
  })
}

// Legacy Visual Styling Map
type ShipmentStatusVisual = {
  rowBackground: string
  rowAccent: string
  chipBackground: string
  chipText: string
  chipBorder: string
  chipShadow: string
  dot: string
}

const defaultStatusVisual: ShipmentStatusVisual = {
  rowBackground: '#f8f9fb',
  rowAccent: '#8ea0b8',
  chipBackground: '#dbe5f3',
  chipText: '#3b4b66',
  chipBorder: '#b9c8dd',
  chipShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
  dot: '#66758c',
}

const shipmentStatusVisualMap: Record<string, ShipmentStatusVisual> = {
  draft: {
    rowBackground: '#fffbf2',
    rowAccent: '#d8a54a',
    chipBackground: '#efd399',
    chipText: '#6a4a14',
    chipBorder: '#d8b672',
    chipShadow: '0 1px 2px rgba(106, 74, 20, 0.18)',
    dot: '#9a6a24',
  },
  'order placed': {
    rowBackground: '#f3f7ff',
    rowAccent: '#6f93d8',
    chipBackground: '#c8d8f8',
    chipText: '#27487a',
    chipBorder: '#a9c4f3',
    chipShadow: '0 1px 2px rgba(39, 72, 122, 0.18)',
    dot: '#3f67b3',
  },
  'proforma generated': {
    rowBackground: '#f8f4ff',
    rowAccent: '#9a74d4',
    chipBackground: '#dccdfa',
    chipText: '#4e2d86',
    chipBorder: '#c6b1f1',
    chipShadow: '0 1px 2px rgba(78, 45, 134, 0.18)',
    dot: '#6f4ab2',
  },
  'payment done': {
    rowBackground: '#f2fbf7',
    rowAccent: '#51b595',
    chipBackground: '#bfeadc',
    chipText: '#1c5f4b',
    chipBorder: '#9edcc8',
    chipShadow: '0 1px 2px rgba(28, 95, 75, 0.18)',
    dot: '#2f8f72',
  },
  'delivery date received': {
    rowBackground: '#eefbff',
    rowAccent: '#5cbfd6',
    chipBackground: '#bde9f4',
    chipText: '#1e5f71',
    chipBorder: '#9fd8e7',
    chipShadow: '0 1px 2px rgba(30, 95, 113, 0.18)',
    dot: '#308ca6',
  },
  'uk warehouse delivery received': {
    rowBackground: '#eef4ff',
    rowAccent: '#5b82d6',
    chipBackground: '#c4d5fa',
    chipText: '#274a8d',
    chipBorder: '#a9c2f2',
    chipShadow: '0 1px 2px rgba(39, 74, 141, 0.18)',
    dot: '#3f67b3',
  },
  'air shipment date set': {
    rowBackground: '#fff7ee',
    rowAccent: '#df9549',
    chipBackground: '#f7d6af',
    chipText: '#7a4516',
    chipBorder: '#ecc08f',
    chipShadow: '0 1px 2px rgba(122, 69, 22, 0.18)',
    dot: '#b86d23',
  },
  'airport arrival': {
    rowBackground: '#fff3ef',
    rowAccent: '#df7f63',
    chipBackground: '#f4c8ba',
    chipText: '#7f3420',
    chipBorder: '#e7ab98',
    chipShadow: '0 1px 2px rgba(127, 52, 32, 0.18)',
    dot: '#b65336',
  },
  'airport released': {
    rowBackground: '#f8f4f1',
    rowAccent: '#9a7c66',
    chipBackground: '#decebf',
    chipText: '#5d4635',
    chipBorder: '#cdb9a8',
    chipShadow: '0 1px 2px rgba(93, 70, 53, 0.18)',
    dot: '#7a5e48',
  },
  'warehouse received': {
    rowBackground: '#f2fbf6',
    rowAccent: '#59aa7d',
    chipBackground: '#c3e8d2',
    chipText: '#1f5d3c',
    chipBorder: '#9fd4b7',
    chipShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
    dot: '#2f8b5d',
  },
  'ready stock': {
    rowBackground: '#edf9f2',
    rowAccent: '#449a69',
    chipBackground: '#b9e3ca',
    chipText: '#194f35',
    chipBorder: '#95cfaf',
    chipShadow: '0 1px 2px rgba(25, 79, 53, 0.18)',
    dot: '#25784d',
  },
}

const getStatusVisual = (status: string | null | undefined): ShipmentStatusVisual => {
  const key = (status ?? '').trim().toLowerCase()
  return shipmentStatusVisualMap[key] ?? defaultStatusVisual
}

const statusSurfaceStyle = (status: string | null | undefined) => {
  const style = getStatusVisual(status)
  return {
    backgroundColor: style.rowBackground,
    boxShadow: `inset 6px 0 0 ${style.rowAccent}`,
  }
}

const statusChipStyle = (status: string | null | undefined) => {
  const style = getStatusVisual(status)
  return {
    backgroundColor: style.chipBackground,
    color: style.chipText,
    border: `1px solid ${style.chipBorder}`,
    boxShadow: style.chipShadow,
  }
}

const statusDotColor = (status: string | null | undefined) => {
  return getStatusVisual(status).dot
}


onMounted(() => {
  void loadShipments()
})
</script>

<style scoped>
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.shipment-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>
