<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <!-- Status/Error Banner -->
      <q-banner v-if="shipmentStore.error" class="tf-status-banner bg-negative text-white flex-shrink-0" dense rounded>
        {{ shipmentStore.error }}
      </q-banner>

      <ProcurementOpsListToolbar
        :search="searchText"
        search-placeholder="Search by shipment name or ID..."
        :filter-count="activeFilterCount"
        icon-search
        inline-pills
        @update:search="onSearchTextUpdate"
        @open-filters="openFilterDrawer"
      >
        <template #pills>
          <TfDrawerSectionTabs
            v-model="quickFilter"
            :tabs="quickFilterSectionTabs"
            ariaLabel="Filter shipments by status"
            @update:model-value="setQuickFilter"
          />
        </template>
        <template #pills-secondary>
          <TfDrawerSectionTabs
            v-model="vendorQuickFilter"
            :tabs="vendorSectionTabs"
            ariaLabel="Filter shipments by vendor"
            count-visibility="positive"
            @update:model-value="setVendorQuickFilter"
          />
        </template>
        <template #trailing>
          <q-btn
            flat
            round
            dense
            color="grey-8"
            icon="ph ph-archive-box"
            class="flex-shrink-0"
            aria-label="Archived shipments"
            @click="openArchivedShipmentsModal"
          >
            <q-badge
              v-if="shipmentStore.archivedTotal > 0"
              color="grey-7"
              text-color="white"
              rounded
              floating
            >
              {{ shipmentStore.archivedTotal }}
            </q-badge>
            <q-tooltip>Archived</q-tooltip>
          </q-btn>
          <q-btn
            color="primary"
            unelevated
            no-caps
            dense
            class="rounded-sq-btn text-weight-bold q-px-sm flex-shrink-0"
            label="New Shipment"
            @click="openCreateShipment"
          />
        </template>
      </ProcurementOpsListToolbar>

      <!-- Filter Sidebar Drawer -->
      <FilterSidebar v-model="filterDrawerOpen" title="Filter Shipments">
        <div class="column q-gutter-y-md">
          <q-select
            v-model="draftCargoCompanyFilter"
            :options="cargoCompanyOptions"
            outlined
            dense
            clearable
            emit-value
            map-options
            label="Cargo company"
            :loading="cargoCompanyStore.loading && !cargoCompanyOptions.length"
          />
        </div>

        <template #footer>
          <div class="row justify-end q-gutter-x-sm">
            <q-btn flat no-caps label="Reset" color="grey-7" @click="onResetFilters" />
            <q-btn
              unelevated
              no-caps
              label="Apply Filters"
              color="primary"
              @click="onApplyDrawerFilters"
            />
          </div>
        </template>
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
        v-else-if="
          !shipmentStore.rows.length &&
          activeFilterCount === 0 &&
          quickFilter === 'all' &&
          vendorQuickFilter === 'all'
        "
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
        <div ref="scrollContainerRef" class="shipment-list-scroll">
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

          <div
            v-if="hasMore"
            ref="scrollSentinelRef"
            class="shipment-list-sentinel row justify-center q-py-sm"
            aria-hidden="true"
          >
            <q-spinner-dots v-if="loadingMore" color="primary" size="28px" />
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { useCargoCompanyStore } from '../stores/cargoCompanyStore';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import ProcurementOpsListToolbar from '../components/ProcurementOpsListToolbar.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import ShipmentFormDialog from '../components/ShipmentFormDialog.vue';
import ArchivedShipmentsModal from '../components/ArchivedShipmentsModal.vue';
import { formatGlobalShipmentStatus } from '../constants/shipmentStatus';

const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();
const cargoCompanyStore = useCargoCompanyStore();
const vendorStore = useVendorStore();
const router = useRouter();
const route = useRoute();
const $q = useQuasar();

// Filter & Search State
const searchText = ref(typeof route.query.search === 'string' ? route.query.search : '');
const filterDrawerOpen = ref(false);
const quickFilter = ref<string>('all');
const statusFilter = ref<string | null>(null);
const vendorQuickFilter = ref('all');
const vendorFilter = ref<number | null>(null);
const cargoCompanyFilter = ref<number | null>(null);
const draftCargoCompanyFilter = ref<number | null>(null);
const cargoCompanyOptions = computed(() => cargoCompanyStore.selectOptions);

const draftCount = computed(() => shipmentStore.rows.filter((r) => r.status === 'draft').length);
const inTransitCount = computed(() => shipmentStore.rows.filter((r) => r.status === 'in_transit').length);
const receivedCount = computed(() => shipmentStore.rows.filter((r) => r.status === 'received').length);

const filterTabs = computed(() => [
  { label: 'All', value: 'all', count: shipmentStore.rows.length },
  { label: 'Draft', value: 'draft', count: draftCount.value },
  { label: 'In Transit', value: 'in_transit', count: inTransitCount.value },
  { label: 'Received', value: 'received', count: receivedCount.value },
  { label: 'Cancelled', value: 'cancelled' },
]);

const quickFilterSectionTabs = computed(() =>
  filterTabs.value.map((tab) => ({
    name: tab.value,
    label: tab.label,
    count: tab.count,
  })),
);

const setQuickFilter = (val: string | number) => {
  const next = String(val);
  quickFilter.value = next;
  statusFilter.value = next === 'all' ? null : next;
  void loadShipments();
};

const vendorSectionTabs = computed(() => [
  { name: 'all', label: 'All' },
  ...vendorStore.items.map((v) => ({
    name: `vendor_${v.id}`,
    label: (v.code || `V${v.id}`).toUpperCase(),
  })),
]);

const setVendorQuickFilter = (val: string | number) => {
  const next = String(val);
  vendorQuickFilter.value = next;
  if (next === 'all') {
    vendorFilter.value = null;
  } else if (next.startsWith('vendor_')) {
    vendorFilter.value = Number(next.slice('vendor_'.length));
  }
  void loadShipments();
};

// Vendor Lookup
const getVendorName = (vendorId: number | null | undefined): string => {
  if (!vendorId) return '—';
  const found = vendorStore.items.find((v) => v.id === vendorId);
  return found ? found.name : `Vendor #${vendorId}`;
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

const activeFilterCount = computed(() => (cargoCompanyFilter.value != null ? 1 : 0));

const hasMore = computed(() => shipmentStore.hasMore);

const loadShipments = async () => {
  if (!authStore.tenantId) return;
  await shipmentStore.fetchShipments(authStore.tenantId, {
    pageSize: shipmentStore.pageSize,
    search: searchText.value.trim() || null,
    status: statusFilter.value === '__all__' ? null : statusFilter.value,
    vendorId: vendorFilter.value,
    cargoCompanyId: cargoCompanyFilter.value,
  });
};

const scrollContainerRef = ref<HTMLElement | null>(null);
const scrollSentinelRef = ref<HTMLElement | null>(null);
let scrollObserver: IntersectionObserver | null = null;

const disconnectScrollObserver = () => {
  scrollObserver?.disconnect();
  scrollObserver = null;
};

const loadMoreShipments = async () => {
  if (loadingMore.value || !hasMore.value || !authStore.tenantId) return;
  loadingMore.value = true;
  try {
    await shipmentStore.fetchShipments(authStore.tenantId, {
      pageSize: shipmentStore.pageSize,
      cursor: shipmentStore.nextCursor,
      search: searchText.value.trim() || null,
      status: statusFilter.value === '__all__' ? null : statusFilter.value,
      vendorId: vendorFilter.value,
      cargoCompanyId: cargoCompanyFilter.value,
      append: true,
    });
  } finally {
    loadingMore.value = false;
    void nextTick(() => setupScrollObserver());
  }
};

const setupScrollObserver = () => {
  disconnectScrollObserver();
  if (!hasMore.value) return;
  const root = scrollContainerRef.value;
  const target = scrollSentinelRef.value;
  if (!root || !target) return;

  scrollObserver = new IntersectionObserver(
    (entries) => {
      if (!entries[0]?.isIntersecting) return;
      void loadMoreShipments();
    },
    { root, rootMargin: '160px 0px', threshold: 0 },
  );
  scrollObserver.observe(target);
};

const onSearchTextUpdate = (val: string | null | undefined) => {
  searchText.value = val ?? '';
  onSearch();
};

const onSearch = () => {
  void loadShipments();
};

const openFilterDrawer = () => {
  draftCargoCompanyFilter.value = cargoCompanyFilter.value;
  filterDrawerOpen.value = true;
};

const onApplyDrawerFilters = () => {
  cargoCompanyFilter.value = draftCargoCompanyFilter.value;
  filterDrawerOpen.value = false;
  void loadShipments();
};

const onResetFilters = () => {
  draftCargoCompanyFilter.value = null;
  cargoCompanyFilter.value = null;
  filterDrawerOpen.value = false;
  void loadShipments();
};

const viewDetails = (id: number) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : '';
  void router.push(`${tenantPrefix}/app/procurement/shipment/${id}`);
};

const openCreateShipment = () => {
  $q.dialog({
    component: ShipmentFormDialog,
  }).onOk((created: { id?: number } | undefined) => {
    if (created?.id) {
      viewDetails(created.id);
    }
  });
};

const openArchivedShipmentsModal = () => {
  $q.dialog({
    component: ArchivedShipmentsModal,
  });
};

const parentTenantId = computed(
  () => authStore.selectedTenant?.parent_id ?? authStore.tenantId,
);

onMounted(() => {
  if (authStore.tenantId && vendorStore.items.length === 0) {
    void vendorStore.fetchVendors(authStore.tenantId);
  }
  void cargoCompanyStore.ensureCompaniesLoaded(parentTenantId.value);
  void loadShipments().then(() => nextTick(() => setupScrollObserver()));
});

onUnmounted(() => {
  disconnectScrollObserver();
});

watch(
  () => [hasMore.value, shipmentStore.rows.length] as const,
  () => {
    void nextTick(() => setupScrollObserver());
  },
);

watch(
  () => route.query.search,
  (value) => {
    const nextSearch = typeof value === 'string' ? value : '';
    if (searchText.value === nextSearch) {
      return;
    }
    searchText.value = nextSearch;
    void loadShipments();
  },
);
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
  overflow: hidden;
  background: var(--tf-neutral-canvas, #F8FAFC);
}

.list-toolbar-card {
  background: var(--tf-neutral-surface, #FFFFFF);
  border-radius: var(--tf-radius-sm, 8px);
  border: 1px solid var(--tf-neutral-border, #E2E8F0);
}

.rounded-sq-btn {
  border-radius: var(--tf-radius-sm, 8px);
}

/* Linear-Style List Container */
.shipment-list-card {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: var(--tf-neutral-surface, #FFFFFF);
  border: 1px solid var(--tf-neutral-border, #E2E8F0);
  border-radius: var(--tf-radius-sm, 8px);
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
  border-bottom: 1px solid var(--tf-neutral-border, #F1F5F9);
  cursor: pointer;
  transition: all 0.15s ease;
  min-height: 50px;
}

.shipment-list-item:hover {
  background: var(--tf-hover-bg);
}

.shipment-list-item:hover .shipment-name {
  color: var(--tf-neutral-ink);
}

.shipment-list-item:hover .shipment-chevron {
  color: var(--tf-neutral-ink);
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
  color: var(--tf-neutral-ink);
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
  color: var(--tf-neutral-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.meta-item {
  font-weight: 400;
}

.meta-vendor {
  color: var(--tf-neutral-muted);
  font-weight: 500;
}

.meta-dot {
  color: var(--tf-neutral-chrome-text);
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
  background: var(--tf-success-soft);
  color: var(--tf-success);
}

.status-pill--transit {
  background: var(--tf-info-soft);
  color: var(--tf-info);
}

.status-pill--draft {
  background: var(--tf-warning-soft);
  color: var(--tf-warning);
}

.status-pill--cancelled {
  background: var(--tf-error-soft);
  color: var(--tf-error);
}

.status-pill--default {
  background: var(--tf-disabled-bg);
  color: var(--tf-neutral-muted);
}

.shipment-chevron {
  color: var(--tf-neutral-chrome-text);
  transition: all 0.15s ease;
}

/* Skeleton Loading Item */
.shipment-list-item--skeleton {
  cursor: default;
}

.shipment-list-item--skeleton:hover {
  background: transparent;
}

.shipment-list-sentinel {
  min-height: 40px;
}

.text-slate-400 { color: var(--tf-neutral-chrome-text); }
.text-slate-500 { color: var(--tf-neutral-muted); }
.text-slate-700 { color: var(--tf-neutral-ink); }
.text-slate-800 { color: var(--tf-neutral-ink); }
.text-slate-900 { color: var(--tf-neutral-ink); }
</style>
