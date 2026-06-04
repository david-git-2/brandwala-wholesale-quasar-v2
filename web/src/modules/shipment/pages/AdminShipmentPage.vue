<template>
  <q-page class="q-pa-md shipment-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Shipment Management</div>
            <div class="text-caption text-grey-8">Manage shipments and open details</div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              label="Create Shipment"
              @click="openCreate"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <CreateShipmentDialog v-model="showDialog" :initialData="selectedShipment" @submit="onSubmit" />

    <PageInitialLoader v-if="shipmentStore.loading" />

    <div v-else-if="shipmentStore.error">
      error: {{ shipmentStore.error }}
    </div>

    <div v-else>
      <div class="row items-center justify-between q-mb-sm">
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
            v-model="searchText"
            outlined
            dense
            class="soft-input toolbar-search"
            label="Search"
            clearable
            autofocus
            @clear="onApplyFilters"
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
                @click="onCloseSearch"
              />
            </template>
          </q-input>

          <q-btn
            flat
            round
            dense
            icon="filter_alt"
            aria-label="Filters"
            @click="openFilterDrawer"
          >
            <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
              {{ activeFilterCount }}
            </q-badge>
          </q-btn>
        </div>

        <q-btn-toggle
          v-model="viewMode"
          dense
          unelevated
          no-caps
          toggle-color="primary"
          color="white"
          text-color="primary"
          :options="[
            { icon: 'table_rows', value: 'table' },
            { icon: 'grid_view', value: 'card' },
          ]"
        />
      </div>

      <q-card v-if="viewMode === 'table'" flat class="floating-surface shadow-1">
        <q-table
          flat
          :rows="filteredShipments"
          :columns="tableColumns"
          row-key="id"
          :pagination="tablePagination"
          :rows-per-page-options="[10, 20, 50]"
          class="shipment-list-table"
        >
          <template #body="slotProps">
            <q-tr
              :props="slotProps"
              class="cursor-pointer"
              :style="statusSurfaceStyle(slotProps.row.status)"
              @click="onSelectShipment(slotProps.row)"
            >
              <q-td key="id" :props="slotProps">#{{ slotProps.row.tenant_shipment_id }}</q-td>
              <q-td key="name" :props="slotProps">{{ slotProps.row.name ?? '-' }}</q-td>
              <q-td key="status" :props="slotProps">
                <q-chip dense square :style="statusChipStyle(slotProps.row.status)" class="shipment-status-chip">
                  <span class="status-dot" :style="{ backgroundColor: statusDotColor(slotProps.row.status) }" />
                  {{ slotProps.row.status }}
                </q-chip>
              </q-td>
              <q-td key="actions" :props="slotProps" class="text-right">
                <q-btn flat round dense icon="more_vert" aria-label="Shipment actions" @click.stop>
                  <q-menu auto-close>
                    <q-list dense style="min-width: 120px">
                      <q-item clickable v-ripple @click="onShipmentEdit(slotProps.row)">
                        <q-item-section>Edit</q-item-section>
                      </q-item>
                      <q-item clickable v-ripple @click="onShipmentCopy(slotProps.row)">
                        <q-item-section>Copy</q-item-section>
                      </q-item>
                      <q-item clickable v-ripple @click="onShipmentDelete(slotProps.row)">
                        <q-item-section class="text-negative">Delete</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </q-td>
            </q-tr>
          </template>
        </q-table>
      </q-card>

      <div v-else class="row q-col-gutter-md">
        <div v-for="shipment in pagedCardShipments" :key="shipment.id" class="col-12 col-sm-6">
          <q-card
            flat
            class="floating-surface shadow-1 cursor-pointer"
            :style="statusSurfaceStyle(shipment.status)"
            @click="onSelectShipment(shipment)"
          >
            <q-card-section>
              <div class="row items-center justify-between q-gutter-sm">
                <div class="text-subtitle1 text-weight-medium">#{{ shipment.tenant_shipment_id }} {{ shipment.name }}</div>
                <q-chip dense square :style="statusChipStyle(shipment.status)" class="shipment-status-chip">
                  <span class="status-dot" :style="{ backgroundColor: statusDotColor(shipment.status) }" />
                  {{ shipment.status }}
                </q-chip>
              </div>
            </q-card-section>
            <q-card-actions align="right">
              <q-btn flat round dense icon="more_vert" aria-label="Shipment actions" @click.stop>
                <q-menu auto-close>
                  <q-list dense style="min-width: 120px">
                    <q-item clickable v-ripple @click="onShipmentEdit(shipment)">
                      <q-item-section>Edit</q-item-section>
                    </q-item>
                    <q-item clickable v-ripple @click="onShipmentCopy(shipment)">
                      <q-item-section>Copy</q-item-section>
                    </q-item>
                    <q-item clickable v-ripple @click="onShipmentDelete(shipment)">
                      <q-item-section class="text-negative">Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </q-card-actions>
          </q-card>
        </div>
      </div>

      <div v-if="viewMode === 'card' && totalCardPages > 1" class="row justify-center q-mt-md">
        <q-pagination
          v-model="cardPage"
          :max="totalCardPages"
          :max-pages="8"
          boundary-numbers
          direction-links
        />
      </div>
    </div>

    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-select
        v-model="draftStatusFilter"
        :options="statusFilterOptions"
        outlined
        dense
        class="soft-input q-mb-md"
        emit-value
        map-options
        label="Status"
        @update:model-value="onDrawerStatusChange"
      />
      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" @click="onResetFilters" />
      </div>
    </FilterSidebar>

    <q-dialog v-model="showDeleteDialog" persistent>
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Delete Shipment</q-card-section>
        <q-card-section>
          Are you sure you want to delete
          <strong>{{ pendingDeleteShipment?.name ?? 'this shipment' }}</strong
          >?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="closeDeleteDialog" />
          <q-btn color="negative" label="Delete" :loading="shipmentStore.saving" @click="confirmDeleteShipment" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useQuasar, type QTableColumn } from 'quasar'
import { useRouter } from 'vue-router'
import CreateShipmentDialog from '../components/ShipmentDialog.vue'
import { useShipmentStore } from '../stores/shipmentStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import type { Shipment } from '../types'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'

const shipmentStore = useShipmentStore()
const tenantStore = useTenantStore()
const authStore = useAuthStore()
const router = useRouter()
const $q = useQuasar()

const showDialog = ref(false)
const selectedShipment = ref<{ id?: number; name?: string; is_gbp?: boolean } | null>(null)
const showDeleteDialog = ref(false)
const pendingDeleteShipment = ref<Shipment | null>(null)

const showSearchInput = ref(false)
const searchText = ref('')
const viewMode = ref<'table' | 'card'>('table')
const filterDrawerOpen = ref(false)
const statusFilter = ref<string>('__all__')
const draftStatusFilter = ref<string>('__all__')
const cardPage = ref(1)
const cardRowsPerPage = 12

const tablePagination = ref({
  page: 1,
  rowsPerPage: 20,
})

const tableColumns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'tenant_shipment_id', align: 'left' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' },
]

const statusFilterOptions = [
  { label: 'All', value: '__all__' },
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
  { label: 'Added to Inventory', value: 'Added to Inventory' },
]

const activeFilterCount = computed(() => (statusFilter.value !== '__all__' ? 1 : 0))

const filteredShipments = computed(() => {
  const search = searchText.value.trim().toLowerCase()
  return shipmentStore.shipments.filter((shipment) => {
    const matchesSearch =
      search.length === 0 ||
      String(shipment.tenant_shipment_id).includes(search) ||
      shipment.name.toLowerCase().includes(search)
    const matchesStatus = statusFilter.value === '__all__' || shipment.status === statusFilter.value
    return matchesSearch && matchesStatus
  })
})

const totalCardPages = computed(() => Math.max(1, Math.ceil(filteredShipments.value.length / cardRowsPerPage)))

const pagedCardShipments = computed(() => {
  const start = (cardPage.value - 1) * cardRowsPerPage
  return filteredShipments.value.slice(start, start + cardRowsPerPage)
})

watch(filteredShipments, () => {
  if (cardPage.value > totalCardPages.value) {
    cardPage.value = totalCardPages.value
  }
})

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
  'added to inventory': {
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

const openCreate = () => {
  selectedShipment.value = null
  showDialog.value = true
}

const onSubmit = async (data: { name: string; is_gbp: boolean }) => {
  if (selectedShipment.value?.id) {
    await shipmentStore.updateShipment({
      id: selectedShipment.value.id,
      patch: { name: data.name },
    })
  } else {
    await shipmentStore.createShipment({
      name: data.name,
      is_gbp: data.is_gbp,
      tenant_id: tenantStore.selectedTenant?.id ?? 1,
    })
  }
}

const onShipmentEdit = (shipment: Shipment) => {
  selectedShipment.value = {
    id: shipment.id,
    name: shipment.name,
    is_gbp: shipment.is_gbp,
  }
  showDialog.value = true
}

const onShipmentDelete = (shipment: Shipment) => {
  pendingDeleteShipment.value = shipment
  showDeleteDialog.value = true
}

const onShipmentCopy = async (shipment: Shipment) => {
  await shipmentStore.copyShipment({ id: shipment.id })
}

const closeDeleteDialog = () => {
  pendingDeleteShipment.value = null
  showDeleteDialog.value = false
}

const confirmDeleteShipment = async () => {
  if (!pendingDeleteShipment.value) return
  const result = await shipmentStore.deleteShipment({ id: pendingDeleteShipment.value.id })
  if (result.success) {
    closeDeleteDialog()
    $q.notify({ type: 'positive', message: 'Shipment deleted successfully.' })
  }
}

const onSelectShipment = async (shipment: Shipment) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment/${shipment.id}`)
}

const onApplyFilters = () => {
  cardPage.value = 1
}

const onCloseSearch = () => {
  searchText.value = ''
  showSearchInput.value = false
  onApplyFilters()
}

const openFilterDrawer = () => {
  draftStatusFilter.value = statusFilter.value
  filterDrawerOpen.value = true
}

const onDrawerStatusChange = () => {
  statusFilter.value = draftStatusFilter.value
  cardPage.value = 1
}

const onResetFilters = () => {
  searchText.value = ''
  statusFilter.value = '__all__'
  draftStatusFilter.value = '__all__'
  cardPage.value = 1
  filterDrawerOpen.value = false
}

onMounted(async () => {
  await shipmentStore.fetchShipments(tenantStore.selectedTenant?.id ?? 1)
})
</script>

<style scoped>
.shipment-list-page {
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

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.shipment-list-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
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

.toolbar-left {
  min-width: 0;
}

.toolbar-search {
  width: min(320px, 75vw);
}
</style>
