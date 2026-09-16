<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <!-- Status/Error Banner -->
      <q-banner v-if="shipmentStore.error" class="bw-status-banner bg-negative text-white flex-shrink-0" dense rounded>
        {{ shipmentStore.error }}
      </q-banner>

      <!-- Compact List Toolbar -->
      <q-card flat bordered class="q-pa-xs flex-shrink-0 list-toolbar-card">
        <div class="row items-center justify-between q-col-gutter-xs">
          <!-- Quick Filter Tabs -->
          <div class="col-12 col-md-auto">
            <div class="row items-center q-gutter-x-xs quick-filter-toggle">
              <button
                v-for="tab in filterTabs"
                :key="tab.value"
                type="button"
                class="quick-filter-pill"
                :class="{ 'quick-filter-pill--active': quickFilter === tab.value }"
                @click="setQuickFilter(tab.value)"
              >
                <span>{{ tab.label }}</span>
                <span
                  v-if="tab.count !== undefined"
                  class="pill-badge"
                  :class="{ 'pill-badge--active': quickFilter === tab.value }"
                >
                  {{ tab.count }}
                </span>
              </button>
            </div>
          </div>

          <!-- Search & Header Actions -->
          <div class="col-12 col-md-grow row items-center justify-end q-gutter-x-xs">
            <q-input
              v-model="searchText"
              outlined
              dense
              debounce="300"
              clearable
              style="min-width: 220px"
              class="col-grow col-sm-auto dense-search-input"
              placeholder="Search by shipment name or ID..."
              @update:model-value="onSearch"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" class="text-slate-400" />
              </template>
            </q-input>

            <q-btn flat round dense icon="ph ph-funnel" class="text-slate-500" @click="openFilterDrawer">
              <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
                {{ activeFilterCount }}
              </q-badge>
              <q-tooltip>Filter options</q-tooltip>
            </q-btn>

            <q-btn
              outline
              dense
              no-caps
              color="grey-8"
              class="rounded-sq-btn text-weight-medium q-px-sm"
              label="Archived"
              icon="ph ph-archive-box"
              @click="openArchivedShipmentsModal"
            >
              <span v-if="shipmentStore.archivedTotal > 0" class="archived-counter-badge q-ml-xs">
                {{ shipmentStore.archivedTotal }}
              </span>
            </q-btn>

            <q-btn
              color="primary"
              unelevated
              no-caps
              dense
              class="rounded-sq-btn text-weight-bold q-px-sm"
              label="New Shipment"
              icon="ph ph-plus"
              @click="openCreateShipment"
            />
          </div>
        </div>
      </q-card>

      <!-- Filter Sidebar Drawer -->
      <FilterSidebar v-model="filterDrawerOpen" title="Filter Shipments">
        <div class="q-gutter-y-md q-pa-sm">
          <q-select
            v-model="draftStatusFilter"
            :options="statusOptions"
            outlined
            dense
            clearable
            emit-value
            map-options
            label="Shipment Status"
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

      <!-- Skeleton Loading State -->
      <div v-if="shipmentStore.loading && !shipmentStore.rows.length" class="shipment-list-card col">
        <div class="shipment-list-scroll">
          <div v-for="n in 8" :key="n" class="shipment-list-item shipment-list-item--skeleton">
            <div class="shipment-info">
              <q-skeleton type="text" width="220px" height="18px" class="q-mb-xs" />
              <q-skeleton type="text" width="320px" height="13px" />
            </div>
            <div class="shipment-aside">
              <q-skeleton type="QBadge" width="75px" height="22px" class="rounded-borders" />
              <q-skeleton type="QBtn" size="xs" width="16px" height="16px" />
            </div>
          </div>
        </div>
      </div>

      <!-- Zero State (First Time) -->
      <div
        v-else-if="!shipmentStore.rows.length && activeFilterCount === 0 && quickFilter === 'all'"
        class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block col"
      >
        <q-icon name="ph ph-truck" size="48px" class="q-mb-sm text-grey-4" />
        <div class="text-subtitle1 text-weight-bold text-slate-800 q-mb-2xs">No Inbound Shipments</div>
        <div class="text-caption text-grey-6 q-mb-md">Add a shipment to start procuring, receiving, and tracking stock batches.</div>
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

      <!-- No Filter Matches -->
      <div v-else-if="!shipmentStore.rows.length" class="column items-center justify-center text-center text-grey-7 q-py-xl col shipment-list-card">
        <q-icon name="ph ph-funnel" size="36px" class="q-mb-xs text-grey-4" />
        <div class="text-subtitle2 text-weight-medium text-slate-800">No shipments found</div>
        <div class="text-caption text-grey-6 q-mt-xs">Try searching with a different keyword or clear status filters.</div>
      </div>

      <!-- Clean Linear-Style List Container -->
      <div v-else class="shipment-list-card col">
        <!-- Scrollable List of Rows -->
        <div class="shipment-list-scroll">
          <div
            v-for="shipment in shipmentStore.rows"
            :key="shipment.id"
            class="shipment-list-item"
            @click="viewDetails(shipment.id)"
          >
            <!-- Left Side: Title & Inline Metadata -->
            <div class="shipment-info">
              <div class="shipment-title-line">
                <span class="shipment-name">{{ shipment.name || `Shipment #${shipment.id}` }}</span>
              </div>
              <div class="shipment-meta-line">
                <span class="meta-item meta-vendor">{{ shipment.vendor_name || getVendorName(shipment.vendor_id) }}</span>
                <span class="meta-dot">·</span>
                <span class="meta-item meta-type">{{ formatTypeLabel(shipment.type) }}</span>
                <span class="meta-dot">·</span>
                <span class="meta-item meta-date">{{ formatDate(shipment.created_at) }}</span>
                <span v-if="shipment.cargo_company_id" class="meta-dot">·</span>
                <span v-if="shipment.cargo_company_id" class="meta-item meta-cargo">Cargo #{{ shipment.cargo_company_id }}</span>
              </div>
            </div>

            <!-- Right Side: Status Tag & Arrow CTA -->
            <div class="shipment-aside">
              <span class="status-pill" :class="`status-pill--${getStatusSlug(shipment.status)}`">
                <q-icon :name="getStatusIcon(shipment.status)" size="12px" class="status-icon" />
                {{ formatShipmentStatusLabel(shipment.status) }}
              </span>

              <q-icon name="ph ph-caret-right" size="15px" class="shipment-chevron" />
            </div>
          </div>

          <!-- Load More Button inside list -->
          <div v-if="hasMore" class="row justify-center q-py-sm">
            <q-btn
              flat
              dense
              no-caps
              :loading="loadingMore"
              class="load-more-btn text-weight-medium text-slate-700 q-px-md"
              label="Load more"
              icon="ph ph-arrow-down"
              @click="loadMoreShipments"
            />
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import ShipmentFormDialog from '../components/ShipmentFormDialog.vue';
import ArchivedShipmentsModal from '../components/ArchivedShipmentsModal.vue';
import { formatGlobalShipmentStatus } from '../constants/shipmentStatus';

const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();
const vendorStore = useVendorStore();
const router = useRouter();
const route = useRoute();
const $q = useQuasar();

// Filter & Search State
const searchText = ref(typeof route.query.search === 'string' ? route.query.search : '');
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

const draftCount = computed(() => shipmentStore.rows.filter((r) => r.status === 'draft').length);
const inTransitCount = computed(() => shipmentStore.rows.filter((r) => r.status === 'in_transit').length);
const receivedCount = computed(() => shipmentStore.rows.filter((r) => r.status === 'received').length);

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

const formatDate = (dateStr: string | null | undefined): string => {
  if (!dateStr) return '—';
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  } catch {
    return dateStr.split('T')[0] ?? '—';
  }
};

const formatTypeLabel = (type: string | null | undefined): string => {
  if (!type) return 'Standard';
  return type.charAt(0).toUpperCase() + type.slice(1);
};

const formatShipmentStatusLabel = formatGlobalShipmentStatus;

const getStatusSlug = (status: string | null | undefined): string => {
  const s = (status ?? '').toLowerCase().trim();
  if (s === 'received') return 'received';
  if (s === 'in_transit') return 'transit';
  if (s === 'draft') return 'draft';
  if (s === 'cancelled') return 'cancelled';
  return 'default';
};

const getStatusIcon = (status: string | null | undefined): string => {
  const s = (status ?? '').toLowerCase().trim();
  if (s === 'received') return 'ph ph-check-circle';
  if (s === 'in_transit') return 'ph ph-truck';
  if (s === 'draft') return 'ph ph-file-dashed';
  if (s === 'cancelled') return 'ph ph-x-circle';
  return 'ph ph-circle';
};

const loadingMore = ref(false);

const activeFilterCount = computed(() => {
  return statusFilter.value && statusFilter.value !== '__all__' ? 1 : 0;
});

const hasMore = computed(() => {
  return shipmentStore.rows.length < shipmentStore.total;
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

const loadMoreShipments = async () => {
  if (loadingMore.value || !hasMore.value || !authStore.tenantId) return;
  loadingMore.value = true;
  try {
    const nextPage = shipmentStore.page + 1;
    await shipmentStore.fetchShipments(authStore.tenantId, {
      page: nextPage,
      pageSize: shipmentStore.pageSize,
      search: searchText.value.trim() || null,
      status: statusFilter.value === '__all__' ? null : statusFilter.value,
      append: true,
    });
  } finally {
    loadingMore.value = false;
  }
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

const openArchivedShipmentsModal = () => {
  $q.dialog({
    component: ArchivedShipmentsModal,
  });
};

onMounted(() => {
  void loadVendorData();
  void loadShipments();
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
  background: var(--bw-neutral-canvas, #F8FAFC);
}

.list-toolbar-card {
  background: var(--bw-neutral-surface, #FFFFFF);
  border-radius: var(--bw-radius-sm, 8px);
  border: 1px solid var(--bw-neutral-border, #E2E8F0);
}

.rounded-sq-btn {
  border-radius: var(--bw-radius-sm, 8px);
}

.quick-filter-toggle {
  display: flex;
  align-items: center;
  background: #F1F5F9;
  border-radius: var(--bw-radius-sm, 8px);
  padding: 2px;
  gap: 2px;
}

.quick-filter-pill {
  border: none;
  background: transparent;
  padding: 4px 10px;
  font-size: 12px;
  font-weight: 500;
  color: #64748B;
  border-radius: 6px;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  transition: all 0.15s ease;
}

.quick-filter-pill:hover {
  color: #0F172A;
}

.quick-filter-pill--active {
  background: var(--bw-neutral-surface, #FFFFFF);
  color: #0F172A;
  font-weight: 600;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}

.pill-badge {
  font-size: 10.5px;
  font-weight: 700;
  padding: 0 5px;
  border-radius: 4px;
  background: #E2E8F0;
  color: #475569;
}

.pill-badge--active {
  background: #0F172A;
  color: #FFFFFF;
}

.archived-counter-badge {
  font-size: 10.5px;
  font-weight: 600;
  background: #F1F5F9;
  color: #475569;
  padding: 1px 6px;
  border-radius: 4px;
}

/* Linear-Style List Container */
.shipment-list-card {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: var(--bw-neutral-surface, #FFFFFF);
  border: 1px solid var(--bw-neutral-border, #E2E8F0);
  border-radius: var(--bw-radius-sm, 8px);
  overflow: hidden;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
}

.shipment-list-scroll {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
}

/* Individual Compact Row (~48-52px) */
.shipment-list-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.65rem 1rem;
  border-bottom: 1px solid var(--bw-neutral-border, #F1F5F9);
  cursor: pointer;
  transition: all 0.15s ease;
  min-height: 50px;
}

.shipment-list-item:hover {
  background: #F8FAFC;
}

.shipment-list-item:hover .shipment-name {
  color: #0F172A;
}

.shipment-list-item:hover .shipment-chevron {
  color: #0F172A;
  transform: translateX(2px);
}

.shipment-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.shipment-title-line {
  display: flex;
  align-items: center;
  gap: 6px;
}

.shipment-name {
  font-size: 13px;
  font-weight: 600;
  color: #1E293B;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  letter-spacing: -0.01em;
}

.shipment-meta-line {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11.5px;
  color: #64748B;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.meta-item {
  font-weight: 400;
}

.meta-vendor {
  color: #475569;
  font-weight: 500;
}

.meta-dot {
  color: #94A3B8;
  font-weight: 700;
}

.shipment-aside {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-shrink: 0;
  margin-left: 1rem;
}

/* Status Pill */
.status-pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11.5px;
  font-weight: 500;
  padding: 2.5px 8px;
  border-radius: 999px;
  white-space: nowrap;
}

.status-icon {
  flex-shrink: 0;
}

.status-pill--received {
  background: #DCFCE7;
  color: #166534;
}

.status-pill--transit {
  background: #FFEDD5;
  color: #9A3412;
}

.status-pill--draft {
  background: #FEF3C7;
  color: #92400E;
}

.status-pill--cancelled {
  background: #FEE2E2;
  color: #991B1B;
}

.status-pill--default {
  background: #F1F5F9;
  color: #475569;
}

.shipment-chevron {
  color: #94A3B8;
  transition: all 0.15s ease;
}

/* Skeleton Loading Item */
.shipment-list-item--skeleton {
  cursor: default;
}

.shipment-list-item--skeleton:hover {
  background: transparent;
}

/* Load More */
.load-more-btn {
  background: #F1F5F9;
  border-radius: var(--bw-radius-sm, 8px);
  font-size: 12px;
  transition: all 0.15s ease;
}

.load-more-btn:hover {
  background: #E2E8F0;
  color: #0F172A;
}

.text-slate-400 { color: #94A3B8; }
.text-slate-500 { color: #64748B; }
.text-slate-700 { color: #334155; }
.text-slate-800 { color: #1E293B; }
.text-slate-900 { color: #0F172A; }
</style>
