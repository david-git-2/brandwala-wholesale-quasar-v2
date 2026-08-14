<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Procurement & Stock</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Inbound Shipments</h1>
          <div class="text-body2 text-grey-7 q-mt-xs">
            Incoming goods from vendors. Open a row to add items and receive them.
          </div>
        </div>
        <div class="col-auto">
          <q-btn
            v-if="shipmentStore.total > 0"
            color="primary"
            unelevated
            no-caps
            label="Add shipment"
            @click="openCreateShipment"
          />
        </div>
      </section>

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
            <q-icon name="ph ph-magnifying-glass" />
          </template>
        </q-input>

        <q-btn flat round dense icon="ph ph-funnel" @click="openFilterDrawer">
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
            <q-btn
              unelevated
              no-caps
              label="Apply Filters"
              color="primary"
              @click="onApplyDrawerFilters"
            />
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
                  <span
                    class="status-dot"
                    :style="{ backgroundColor: statusDotColor(props.row.status) }"
                  />
                  {{ formatShipmentStatusLabel(props.row.status) }}
                </q-chip>
              </q-td>
              <q-td key="progress" :props="props">
                <span class="text-caption text-grey-8">
                  {{ props.row.progress_tag?.name || '—' }}
                </span>
              </q-td>
              <q-td key="received_date" :props="props">
                {{ props.row.received_date || '-' }}
              </q-td>
            </q-tr>
          </template>

          <template #no-data>
            <div class="full-width text-center text-grey-7 q-py-lg">
              <q-icon name="ph ph-truck" size="48px" class="q-mb-sm text-grey-4" />
              <div class="text-subtitle1 text-weight-medium q-mb-xs">
                {{ shipmentStore.total === 0 ? 'No shipments yet' : 'No shipments match filters' }}
              </div>
              <div v-if="shipmentStore.total === 0" class="text-body2 q-mb-md">
                Add a shipment to start buying and receiving goods.
              </div>
              <q-btn
                v-if="shipmentStore.total === 0"
                color="primary"
                unelevated
                no-caps
                label="Add shipment"
                @click="openCreateShipment"
              />
            </div>
          </template>
        </q-table>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar, type QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { GlobalShipment } from '../repositories/globalShipmentRepository';
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import ShipmentFormDialog from '../components/ShipmentFormDialog.vue';

const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();
const router = useRouter();
const $q = useQuasar();

// Filter State
const searchText = ref('');
const filterDrawerOpen = ref(false);
const statusFilter = ref<string | null>(null);
const draftStatusFilter = ref<string | null>(null);

const statusOptions = [
  { label: 'All Statuses', value: '__all__' },
  { label: 'Draft', value: 'draft' },
  { label: 'In transit', value: 'in_transit' },
  { label: 'Received', value: 'received' },
  { label: 'Cancelled', value: 'cancelled' },
];

const columns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'tenant_shipment_id', align: 'left', sortable: false },
  { name: 'name', label: 'Shipment Name', field: 'name', align: 'left', sortable: false },
  { name: 'type', label: 'Type', field: 'type', align: 'left', sortable: false },
  { name: 'status', label: 'Status', field: 'status', align: 'left', sortable: false },
  {
    name: 'progress',
    label: 'Progress',
    field: (row: { progress_tag?: { name?: string } | null }) => row.progress_tag?.name ?? '—',
    align: 'left',
    sortable: false,
  },
  {
    name: 'received_date',
    label: 'Received Date',
    field: 'received_date',
    align: 'left',
    sortable: false,
  },
];

const pagination = computed({
  get: () => ({
    page: shipmentStore.page,
    rowsPerPage: shipmentStore.pageSize,
    rowsNumber: shipmentStore.total,
  }),
  set: (val) => {
    shipmentStore.page = val.page;
    shipmentStore.pageSize = val.rowsPerPage;
  },
});

const activeFilterCount = computed(() => {
  return statusFilter.value && statusFilter.value !== '__all__' ? 1 : 0;
});

const loadShipments = async () => {
  if (!authStore.tenantId) return;
  await shipmentStore.fetchShipments(authStore.tenantId, {
    page: shipmentStore.page,
    pageSize: shipmentStore.pageSize,
    search: searchText.value.trim() || null,
    status: statusFilter.value === '__all__' ? null : statusFilter.value,
  });
};

const onTableRequest = async (props: { pagination: { page: number; rowsPerPage: number } }) => {
  shipmentStore.page = props.pagination.page;
  shipmentStore.pageSize = props.pagination.rowsPerPage;
  await loadShipments();
};

const onSearch = () => {
  shipmentStore.page = 1;
  void loadShipments();
};

// Filter Actions
const openFilterDrawer = () => {
  draftStatusFilter.value = statusFilter.value;
  filterDrawerOpen.value = true;
};

const onApplyDrawerFilters = () => {
  statusFilter.value = draftStatusFilter.value;
  filterDrawerOpen.value = false;
  shipmentStore.page = 1;
  void loadShipments();
};

const onResetFilters = () => {
  draftStatusFilter.value = null;
  statusFilter.value = null;
  filterDrawerOpen.value = false;
  shipmentStore.page = 1;
  void loadShipments();
};

const onRowClick = (_evt: Event, row: GlobalShipment) => {
  viewDetails(row.id);
};

const viewDetails = (id: number) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : '';
  void router.push(`${tenantPrefix}/app/procurement/shipment/${id}`);
};

const openCreateShipment = () => {
  $q.dialog({
    component: ShipmentFormDialog,
  }).onOk(() => {
    void loadShipments();
  });
};

// Legacy Visual Styling Map
type ShipmentStatusVisual = {
  rowBackground: string;
  rowAccent: string;
  chipBackground: string;
  chipText: string;
  chipBorder: string;
  chipShadow: string;
  dot: string;
};

const defaultStatusVisual: ShipmentStatusVisual = {
  rowBackground: '#f8f9fb',
  rowAccent: '#8ea0b8',
  chipBackground: '#dbe5f3',
  chipText: '#3b4b66',
  chipBorder: '#b9c8dd',
  chipShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
  dot: '#66758c',
};

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
  in_transit: {
    rowBackground: '#fff7ee',
    rowAccent: '#df9549',
    chipBackground: '#f7d6af',
    chipText: '#7a4516',
    chipBorder: '#ecc08f',
    chipShadow: '0 1px 2px rgba(122, 69, 22, 0.18)',
    dot: '#b86d23',
  },
  received: {
    rowBackground: '#edf9f2',
    rowAccent: '#449a69',
    chipBackground: '#b9e3ca',
    chipText: '#194f35',
    chipBorder: '#95cfaf',
    chipShadow: '0 1px 2px rgba(25, 79, 53, 0.18)',
    dot: '#25784d',
  },
  cancelled: {
    rowBackground: '#fef2f2',
    rowAccent: '#dc2626',
    chipBackground: '#fecaca',
    chipText: '#7f1d1d',
    chipBorder: '#fca5a5',
    chipShadow: '0 1px 2px rgba(127, 29, 29, 0.18)',
    dot: '#b91c1c',
  },
};

const formatShipmentStatusLabel = (status: string | null | undefined): string => {
  switch ((status ?? '').trim()) {
    case 'draft':
      return 'Draft';
    case 'in_transit':
      return 'In transit';
    case 'received':
      return 'Received';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status || '—';
  }
};

const getStatusVisual = (status: string | null | undefined): ShipmentStatusVisual => {
  const key = (status ?? '').trim().toLowerCase();
  return shipmentStatusVisualMap[key] ?? defaultStatusVisual;
};

const statusSurfaceStyle = (status: string | null | undefined) => {
  const style = getStatusVisual(status);
  return {
    backgroundColor: style.rowBackground,
    boxShadow: `inset 6px 0 0 ${style.rowAccent}`,
  };
};

const statusChipStyle = (status: string | null | undefined) => {
  const style = getStatusVisual(status);
  return {
    backgroundColor: style.chipBackground,
    color: style.chipText,
    border: `1px solid ${style.chipBorder}`,
    boxShadow: style.chipShadow,
  };
};

const statusDotColor = (status: string | null | undefined) => {
  return getStatusVisual(status).dot;
};

onMounted(() => {
  void loadShipments();
});
</script>

<style scoped>
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
