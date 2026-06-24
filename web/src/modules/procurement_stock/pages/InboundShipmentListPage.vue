<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <AppPageHeader
        eyebrow="Procurement & Stock"
        title="Inbound Shipments"
        subtitle="Manage inbound supplier shipment batches, costing, and statuses"
      >
        <template #action>
          <q-btn
            color="primary"
            icon="add"
            label="Create Shipment"
            unelevated
            no-caps
            @click="openCreateShipment"
          />
        </template>
      </AppPageHeader>

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
      <q-card v-else flat bordered class="q-pa-none">
        <q-table
          flat
          :rows="shipmentStore.rows"
          :columns="columns"
          row-key="id"
          :loading="shipmentStore.loading"
          v-model:pagination="pagination"
          :rows-per-page-options="[10, 20, 50]"
          @request="onTableRequest"
          @row-click="onRowClick"
          class="cursor-pointer"
        >
          <template #body-cell-id="props">
            <q-td :props="props">
              #{{ props.row.tenant_shipment_id || props.row.id }}
            </q-td>
          </template>

          <template #body-cell-type="props">
            <q-td :props="props" class="text-capitalize">
              {{ props.row.type }}
            </q-td>
          </template>

          <template #body-cell-status="props">
            <q-td :props="props">
              <q-chip
                square
                dense
                :color="statusChipColor(props.row.status)"
                text-color="white"
                class="text-weight-bold"
              >
                {{ props.row.status }}
              </q-chip>
            </q-td>
          </template>

          <template #body-cell-created_at="props">
            <q-td :props="props">
              {{ formatDate(props.row.created_at) }}
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" @click.stop>
              <q-btn
                flat
                round
                dense
                color="primary"
                icon="visibility"
                @click="viewDetails(props.row.id)"
              />
            </q-td>
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
import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
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
  { name: 'created_at', label: 'Created At', field: 'created_at', align: 'left', sortable: false },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center', sortable: false },
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

const onTableRequest = async (props: any) => {
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

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
}

const statusChipColor = (status: string) => {
  switch (status) {
    case 'Draft': return 'grey-7'
    case 'Order Placed': return 'blue-6'
    case 'Payment Done': return 'indigo-6'
    case 'Warehouse Received': return 'orange-8'
    case 'Ready Stock': return 'green-7'
    default: return 'primary'
  }
}

const openCreateShipment = () => {
  $q.dialog({
    component: ShipmentFormDialog,
  }).onOk(() => {
    void loadShipments()
  })
}

onMounted(() => {
  void loadShipments()
})
</script>
