<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-banner v-if="shipmentStore.error" class="bw-status-banner bg-negative text-white flex-shrink-0" dense rounded>
        {{ shipmentStore.error }}
      </q-banner>

      <!-- Toolbar: Quick Filters & Search -->
      <q-card flat class="floating-surface shadow-1 q-pa-xs flex-shrink-0">
        <div class="row items-center justify-between q-col-gutter-xs">
          <!-- Quick Filter Tabs -->
          <div class="col-12 col-md-auto">
            <div class="row items-center q-gutter-x-xs quick-filter-toggle">
              <q-btn
                v-for="tab in filterTabs"
                :key="tab.value"
                dense
                unelevated
                no-caps
                :color="quickFilter === tab.value ? 'primary' : 'transparent'"
                :text-color="quickFilter === tab.value ? 'white' : 'grey-8'"
                class="quick-filter-btn text-xs"
                @click="setQuickFilter(tab.value)"
              >
                <span>{{ tab.label }}</span>
                <q-badge
                  v-if="tab.count !== undefined"
                  :color="quickFilter === tab.value ? 'white' : 'grey-3'"
                  :text-color="quickFilter === tab.value ? 'primary' : 'grey-9'"
                  class="q-ml-xs text-weight-bolder"
                  rounded
                >
                  {{ tab.count }}
                </q-badge>
              </q-btn>
            </div>
          </div>

          <!-- Search & Filter Actions -->
          <div class="col-12 col-md-grow row items-center justify-end q-gutter-x-xs">
            <q-input
              v-model="searchText"
              outlined
              rounded
              dense
              clearable
              style="min-width: 200px"
              class="col-grow col-sm-auto dense-search-input"
              placeholder="Search by name or ID..."
              @keyup.enter="onSearch"
              @clear="onSearch"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" />
              </template>
            </q-input>

            <q-btn flat round dense icon="ph ph-funnel" @click="openFilterDrawer">
              <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
                {{ activeFilterCount }}
              </q-badge>
              <q-tooltip>More Filters</q-tooltip>
            </q-btn>

            <q-btn
              color="primary"
              unelevated
              no-caps
              dense
              class="rounded-sq-btn text-weight-bold q-px-sm"
              label="Add shipment"
              icon="ph ph-plus"
              @click="openCreateShipment"
            />
          </div>
        </div>
      </q-card>

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

      <!-- Skeleton Table Loader -->
      <q-markup-table
        v-if="shipmentStore.loading && !shipmentStore.rows.length"
        flat
        bordered
        class="shipment-table treasury-table-wrap col"
      >
        <thead>
          <tr>
            <th><q-skeleton type="text" width="60px" /></th>
            <th><q-skeleton type="text" width="120px" /></th>
            <th><q-skeleton type="text" width="80px" /></th>
            <th><q-skeleton type="text" width="100px" /></th>
            <th><q-skeleton type="text" width="70px" /></th>
            <th class="text-right"><q-skeleton type="text" width="40px" class="q-ml-auto" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="n in 6" :key="n">
            <td><q-skeleton type="text" width="60px" height="14px" /></td>
            <td><q-skeleton type="text" width="80%" height="14px" /></td>
            <td><q-skeleton type="QBadge" width="60px" height="16px" /></td>
            <td><q-skeleton type="text" width="70%" height="14px" /></td>
            <td><q-skeleton type="QBadge" width="65px" height="18px" /></td>
            <td class="text-right">
              <q-skeleton type="QBtn" size="sm" width="24px" height="24px" class="q-ml-auto" />
            </td>
          </tr>
        </tbody>
      </q-markup-table>

      <!-- Empty State -->
      <div
        v-else-if="!shipmentStore.rows.length && activeFilterCount === 0 && quickFilter === 'all'"
        class="column items-center justify-center q-pa-lg text-grey-6 empty-state-block floating-surface shadow-1 col"
      >
        <q-icon name="ph ph-truck" size="48px" class="q-mb-xs text-grey-4" />
        <div class="text-subtitle2 text-weight-medium q-mb-xs">No shipments yet</div>
        <div class="text-caption text-grey-6 q-mb-sm">Add a shipment to start buying and receiving goods.</div>
        <q-btn
          color="primary"
          unelevated
          no-caps
          dense
          class="rounded-sq-btn text-weight-bold q-px-md"
          label="Add shipment"
          icon="ph ph-plus"
          @click="openCreateShipment"
        />
      </div>

      <!-- No Matching Filters -->
      <div v-else-if="!shipmentStore.rows.length" class="column items-center justify-center text-center text-grey-7 q-py-lg floating-surface shadow-1 rounded-borders col">
        <q-icon name="ph ph-funnel" size="36px" class="q-mb-xs text-grey-4" />
        <div class="text-subtitle2 text-weight-medium">No shipments match filters</div>
        <div class="text-caption text-grey-6 q-mt-xs">Try clearing search or filters to view all shipments.</div>
      </div>

      <!-- Table View with Internal Scroll -->
      <div v-else class="treasury-table-wrap col">
        <q-card flat class="floating-surface shadow-1 q-pa-none full-height column no-wrap">
          <q-table
            flat
            :rows="shipmentStore.rows"
            :columns="columns"
            row-key="id"
            :loading="shipmentStore.loading"
            v-model:pagination="pagination"
            :rows-per-page-options="[10, 20, 50]"
            @request="onTableRequest"
            class="shipment-table cursor-pointer col"
            @row-click="onRowClick"
          >
            <template #body="props">
              <q-tr
                :props="props"
                :style="statusRowStyle(props.row.status)"
                class="shipment-row cursor-pointer"
                @click="onRowClick($event, props.row)"
              >
                <!-- ID Slot -->
                <q-td key="id" :props="props">
                  <span class="text-weight-bold text-primary cursor-pointer hover-underline">
                    #{{ props.row.tenant_shipment_id || props.row.id }}
                  </span>
                </q-td>

                <!-- Shipment Name Slot -->
                <q-td key="name" :props="props">
                  <div class="text-weight-bold line-clamp-1">
                    {{ props.row.name ?? '-' }}
                  </div>
                  <div class="text-caption text-grey-6 text-xxs row items-center">
                    <q-icon name="ph ph-calendar-blank" size="10px" class="q-mr-xs" />
                    {{ formatDate(props.row.created_at) }}
                  </div>
                </q-td>

                <!-- Type Slot -->
                <q-td key="type" :props="props">
                  <q-chip
                    square
                    dense
                    :color="getTypeChipStyle(props.row.type).color"
                    :text-color="getTypeChipStyle(props.row.type).textColor"
                    class="text-weight-bold text-capitalize text-xxs q-ma-none soft-chip"
                  >
                    {{ props.row.type }}
                  </q-chip>
                </q-td>

                <!-- Vendor Slot -->
                <q-td key="vendor" :props="props">
                  <div class="row items-center no-wrap">
                    <q-avatar
                      square
                      size="26px"
                      :color="$q.dark.isActive ? 'grey-9' : 'grey-3'"
                      :text-color="$q.dark.isActive ? 'grey-3' : 'grey-9'"
                      class="q-mr-xs text-weight-bold text-xxs avatar-soft-sq"
                    >
                      {{ getInitials(getVendorName(props.row.vendor_id)) }}
                    </q-avatar>
                    <div>
                      <div class="text-weight-bold text-xs line-clamp-1">
                        {{ getVendorName(props.row.vendor_id) }}
                      </div>
                    </div>
                  </div>
                </q-td>

                <!-- Status Slot -->
                <q-td key="status" :props="props">
                  <div
                    class="shipment-status-badge row inline items-center no-wrap"
                    :style="statusBadgeStyle(props.row.status)"
                  >
                    <q-icon
                      :name="getStatusIcon(props.row.status)"
                      size="13px"
                      class="q-mr-xs"
                    />
                    <span class="text-weight-bolder text-uppercase text-xxs" style="letter-spacing: 0.04em">
                      {{ formatShipmentStatusLabel(props.row.status) }}
                    </span>
                  </div>
                </q-td>

                <!-- Actions Slot -->
                <q-td key="actions" :props="props" class="text-right" @click.stop>
                  <q-btn flat round dense icon="ph ph-dots-three-vertical" size="sm" color="grey-7">
                    <q-menu anchor="bottom end" self="top end">
                      <q-list dense style="min-width: 130px">
                        <q-item clickable v-close-popup @click="viewDetails(props.row.id)">
                          <q-item-section avatar min-width="20px">
                            <q-icon name="ph ph-eye" size="14px" color="primary" />
                          </q-item-section>
                          <q-item-section class="text-weight-medium text-xs">View Details</q-item-section>
                        </q-item>
                        <q-item clickable v-close-popup @click="openEditShipment(props.row)">
                          <q-item-section avatar min-width="20px">
                            <q-icon name="ph ph-pencil-simple" size="14px" color="grey-8" />
                          </q-item-section>
                          <q-item-section class="text-weight-medium text-xs">Edit Details</q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </q-btn>
                </q-td>
              </q-tr>
            </template>
          </q-table>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar, type QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { GlobalShipment } from '../repositories/globalShipmentRepository';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import ShipmentFormDialog from '../components/ShipmentFormDialog.vue';

const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();
const vendorStore = useVendorStore();
const router = useRouter();
const route = useRoute();
const $q = useQuasar();

// Filter & Quick Tab State
const searchText = ref(
  typeof route.query.search === 'string' ? route.query.search : '',
);
const filterDrawerOpen = ref(false);
const quickFilter = ref<string>('all');
const statusFilter = ref<string | null>(null);
const draftStatusFilter = ref<string | null>(null);

const statusOptions = [
  { label: 'All Statuses', value: '__all__' },
  { label: 'Draft', value: 'draft' },
  { label: 'In transit', value: 'in_transit' },
  { label: 'Received', value: 'received' },
  { label: 'Cancelled', value: 'cancelled' },
];

const draftCount = computed(
  () => shipmentStore.rows.filter((r) => r.status === 'draft').length,
);
const inTransitCount = computed(
  () => shipmentStore.rows.filter((r) => r.status === 'in_transit').length,
);
const receivedCount = computed(
  () => shipmentStore.rows.filter((r) => r.status === 'received').length,
);

const filterTabs = computed(() => [
  { label: 'All', value: 'all', count: shipmentStore.total },
  { label: 'Draft', value: 'draft', count: draftCount.value },
  { label: 'In Transit', value: 'in_transit', count: inTransitCount.value },
  { label: 'Received', value: 'received', count: receivedCount.value },
  { label: 'Cancelled', value: 'cancelled' },
]);

const setQuickFilter = (val: string) => {
  quickFilter.value = val;
  statusFilter.value = val === 'all' ? null : val;
  shipmentStore.page = 1;
  void loadShipments();
};

// Vendor Lookup
const getVendorName = (vendorId: number | null | undefined): string => {
  if (!vendorId) return '—';
  const found = vendorStore.items.find((v) => v.id === vendorId);
  return found ? found.name : `Vendor #${vendorId}`;
};

const loadVendorData = async () => {
  if (!authStore.tenantId) return;
  try {
    await vendorStore.fetchVendors(authStore.tenantId);
  } catch (err) {
    console.error('Failed to load vendors', err);
  }
};

// Avatar & styling helpers
const getInitials = (name: string | null | undefined): string => {
  if (!name || name === '—') return 'VS';
  const parts = name.trim().split(/\s+/);
  const p0 = parts[0];
  const p1 = parts[1];
  if (p0 && p1 && p0[0] && p1[0]) {
    return (p0[0] + p1[0]).toUpperCase();
  }
  return name.slice(0, 2).toUpperCase();
};

const getTypeChipStyle = (type: string | null | undefined) => {
  if ($q.dark.isActive) {
    switch (type) {
      case 'international':
        return { color: 'purple-10', textColor: 'purple-2' };
      case 'local':
        return { color: 'teal-10', textColor: 'teal-2' };
      case 'transfer':
        return { color: 'indigo-10', textColor: 'indigo-2' };
      default:
        return { color: 'grey-9', textColor: 'grey-2' };
    }
  }
  switch (type) {
    case 'international':
      return { color: 'purple-1', textColor: 'purple-9' };
    case 'local':
      return { color: 'teal-1', textColor: 'teal-9' };
    case 'transfer':
      return { color: 'indigo-1', textColor: 'indigo-9' };
    default:
      return { color: 'grey-2', textColor: 'grey-9' };
  }
};

const formatDate = (dateStr: string | null | undefined): string => {
  if (!dateStr) return '—';
  return dateStr.split('T')[0] ?? '—';
};

const columns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'tenant_shipment_id', align: 'left', sortable: false },
  { name: 'name', label: 'Shipment Name', field: 'name', align: 'left', sortable: false },
  { name: 'type', label: 'Type', field: 'type', align: 'left', sortable: false },
  {
    name: 'vendor',
    label: 'Vendor',
    field: (row: GlobalShipment) => getVendorName(row.vendor_id),
    align: 'left',
    sortable: false,
  },
  { name: 'status', label: 'Status', field: 'status', align: 'left', sortable: false },
  { name: 'actions', label: 'Actions', field: 'id', align: 'right', sortable: false },
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

const openFilterDrawer = () => {
  draftStatusFilter.value = statusFilter.value;
  filterDrawerOpen.value = true;
};

const onApplyDrawerFilters = () => {
  statusFilter.value = draftStatusFilter.value;
  quickFilter.value = draftStatusFilter.value || 'all';
  filterDrawerOpen.value = false;
  shipmentStore.page = 1;
  void loadShipments();
};

const onResetFilters = () => {
  draftStatusFilter.value = null;
  statusFilter.value = null;
  quickFilter.value = 'all';
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

const openEditShipment = (shipment: GlobalShipment) => {
  $q.dialog({
    component: ShipmentFormDialog,
    componentProps: {
      shipment,
    },
  }).onOk(() => {
    void loadShipments();
  });
};

// Visual Styling Map for status badges & row hues
type ShipmentStatusVisual = {
  rowBackground: string;
  rowAccent: string;
  chipBackground: string;
  chipText: string;
  chipBorder: string;
  chipShadow: string;
  icon: string;
};

const defaultStatusVisual: ShipmentStatusVisual = {
  rowBackground: '#ffffff',
  rowAccent: '#cbd5e1',
  chipBackground: '#f1f5f9',
  chipText: '#334155',
  chipBorder: '#cbd5e1',
  chipShadow: '0 1px 3px rgba(51, 65, 85, 0.1)',
  icon: 'ph ph-info',
};

const defaultDarkStatusVisual: ShipmentStatusVisual = {
  rowBackground: 'transparent',
  rowAccent: '#475569',
  chipBackground: 'rgba(255, 255, 255, 0.08)',
  chipText: '#cbd5e1',
  chipBorder: 'rgba(255, 255, 255, 0.15)',
  chipShadow: 'none',
  icon: 'ph ph-info',
};

const shipmentStatusVisualMap: Record<string, ShipmentStatusVisual> = {
  draft: {
    rowBackground: '#fffdf5',
    rowAccent: '#f59e0b',
    chipBackground: '#fef3c7',
    chipText: '#78350f',
    chipBorder: '#f59e0b',
    chipShadow: '0 2px 4px rgba(217, 119, 6, 0.18)',
    icon: 'ph ph-note-pencil',
  },
  in_transit: {
    rowBackground: '#fffbf7',
    rowAccent: '#f97316',
    chipBackground: '#ffedd5',
    chipText: '#7c2d12',
    chipBorder: '#f97316',
    chipShadow: '0 2px 4px rgba(234, 88, 12, 0.18)',
    icon: 'ph ph-truck',
  },
  received: {
    rowBackground: '#f6fcf8',
    rowAccent: '#22c55e',
    chipBackground: '#dcfce7',
    chipText: '#14532d',
    chipBorder: '#22c55e',
    chipShadow: '0 2px 4px rgba(22, 163, 74, 0.18)',
    icon: 'ph ph-check-circle',
  },
  cancelled: {
    rowBackground: '#fef7f7',
    rowAccent: '#ef4444',
    chipBackground: '#fee2e2',
    chipText: '#7f1d1d',
    chipBorder: '#ef4444',
    chipShadow: '0 2px 4px rgba(220, 38, 38, 0.18)',
    icon: 'ph ph-x-circle',
  },
};

const darkStatusVisualMap: Record<string, ShipmentStatusVisual> = {
  draft: {
    rowBackground: 'transparent',
    rowAccent: '#f59e0b',
    chipBackground: 'rgba(245, 158, 11, 0.15)',
    chipText: '#fbbf24',
    chipBorder: 'rgba(245, 158, 11, 0.35)',
    chipShadow: 'none',
    icon: 'ph ph-note-pencil',
  },
  in_transit: {
    rowBackground: 'transparent',
    rowAccent: '#f97316',
    chipBackground: 'rgba(249, 115, 22, 0.15)',
    chipText: '#fb923c',
    chipBorder: 'rgba(249, 115, 22, 0.35)',
    chipShadow: 'none',
    icon: 'ph ph-truck',
  },
  received: {
    rowBackground: 'transparent',
    rowAccent: '#3ecf8e',
    chipBackground: 'rgba(62, 207, 142, 0.15)',
    chipText: '#3ecf8e',
    chipBorder: 'rgba(62, 207, 142, 0.35)',
    chipShadow: 'none',
    icon: 'ph ph-check-circle',
  },
  cancelled: {
    rowBackground: 'transparent',
    rowAccent: '#f87171',
    chipBackground: 'rgba(248, 113, 113, 0.15)',
    chipText: '#f87171',
    chipBorder: 'rgba(248, 113, 113, 0.35)',
    chipShadow: 'none',
    icon: 'ph ph-x-circle',
  },
};

const formatShipmentStatusLabel = (status: string | null | undefined): string => {
  switch ((status ?? '').trim().toLowerCase()) {
    case 'draft':
      return 'Draft';
    case 'in_transit':
      return 'In Transit';
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
  if ($q.dark.isActive) {
    return darkStatusVisualMap[key] ?? defaultDarkStatusVisual;
  }
  return shipmentStatusVisualMap[key] ?? defaultStatusVisual;
};

const statusRowStyle = (status: string | null | undefined) => {
  const visual = getStatusVisual(status);
  return {
    backgroundColor: visual.rowBackground,
    boxShadow: `inset 3px 0 0 ${visual.rowAccent}`,
  };
};

const statusBadgeStyle = (status: string | null | undefined) => {
  const style = getStatusVisual(status);
  return {
    backgroundColor: style.chipBackground,
    color: style.chipText,
    border: `1px solid ${style.chipBorder}`,
    boxShadow: style.chipShadow,
  };
};

const getStatusIcon = (status: string | null | undefined): string => {
  return getStatusVisual(status).icon;
};

onMounted(() => {
  void loadShipments();
  void loadVendorData();
});

watch(
  () => route.query.search,
  (value) => {
    const nextSearch = typeof value === 'string' ? value : '';
    if (searchText.value === nextSearch) {
      return;
    }
    searchText.value = nextSearch;
    shipmentStore.page = 1;
    void loadShipments();
  },
);
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
  overflow: hidden;
}

.rounded-sq-btn {
  border-radius: 8px;
}

.style-compact-overline {
  font-size: 10px;
  line-height: 1.2;
}

.quick-filter-toggle {
  background: rgba(0, 0, 0, 0.03);
  border-radius: 8px;
  padding: 2px;
}

.quick-filter-toggle :deep(.q-btn) {
  border-radius: 6px;
  font-weight: 600;
  padding: 2px 10px;
}

.treasury-table-wrap {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.shipment-table {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.shipment-table :deep(.q-table__container) {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  box-shadow: none;
  background: transparent;
}

.shipment-table :deep(.q-table__middle) {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
}

.shipment-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  font-weight: 700;
  color: #0f172a;
  background: #f8fafc;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  padding: 8px 12px;
  border-bottom: 1px solid #e2e8f0;
}

body.body--dark .shipment-table :deep(thead tr th) {
  background: #1c1c1c;
  color: #a1a1aa;
  border-bottom: 1px solid #2e2e2e;
}

.shipment-table :deep(tbody tr) {
  transition: background-color 0.15s ease;
}

.shipment-table :deep(tbody tr:hover) {
  background-color: #f1f5f9 !important;
}

body.body--dark .shipment-table :deep(tbody tr:hover) {
  background-color: #242424 !important;
}

.shipment-table :deep(tbody td) {
  padding: 6px 12px;
  border-bottom: 1px solid #f1f5f9;
  font-size: 12.5px;
}

body.body--dark .shipment-table :deep(tbody td) {
  border-bottom: 1px solid #262626;
  color: #ededed;
}

.hover-underline:hover {
  text-decoration: underline;
}

.shipment-status-badge {
  border-radius: 6px;
  padding: 3px 8px;
  display: inline-flex;
  align-items: center;
  font-weight: 700;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.shipment-status-badge:hover {
  transform: translateY(-1px);
}

.line-clamp-1 {
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 1;
  line-clamp: 1;
  -webkit-box-orient: vertical;
}

.text-xxs {
  font-size: 9px;
  line-height: 1;
}

.text-xs {
  font-size: 11px;
}
</style>
