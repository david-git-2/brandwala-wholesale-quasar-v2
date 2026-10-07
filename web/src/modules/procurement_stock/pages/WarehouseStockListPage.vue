<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-banner v-if="listErrorMessage" class="bw-status-banner bg-negative text-white flex-shrink-0" dense rounded>
        {{ listErrorMessage }}
      </q-banner>

      <ProcurementOpsListToolbar
        :search="searchText"
        search-placeholder="Search product, code, barcode, shipment..."
        :filter-count="activeFilterCount"
        @update:search="onSearchInput"
        @open-filters="openFilterDrawer"
      >
        <template #pills>
          <div class="row items-center q-gutter-x-sm no-wrap">
            <div class="row items-center q-gutter-x-xs quick-filter-toggle">
              <button
                v-for="pill in availabilityQuickPills"
                :key="pill.value"
                type="button"
                class="quick-filter-pill"
                :class="{ 'quick-filter-pill--active': quickAvailability === pill.value }"
                @click="setQuickAvailability(pill.value)"
              >
                {{ pill.label }}
              </button>
            </div>
            <q-select
              v-model="groupBy"
              :options="groupByOptions"
              dense
              outlined
              emit-value
              map-options
              label="Group by"
              class="warehouse-group-by-select"
              style="min-width: 140px"
            />
          </div>
        </template>
        <template #chips>
          <q-chip
            v-if="shipmentIdFilter"
            removable
            dense
            outline
            color="primary"
            @remove="clearShipmentFilter"
          >
            {{ shipmentChipLabel }}
          </q-chip>
          <q-chip
            v-if="locationFilterChipLabel"
            removable
            dense
            outline
            @remove="clearLocationFilter"
          >
            {{ locationFilterChipLabel }}
          </q-chip>
          <q-chip
            v-if="gradeFilterChipLabel"
            removable
            dense
            outline
            @remove="clearGradeFilter"
          >
            {{ gradeFilterChipLabel }}
          </q-chip>
          <q-chip
            v-if="shipmentStatusFilter"
            removable
            dense
            outline
            @remove="shipmentStatusFilter = null"
          >
            Shipment: {{ formatGlobalShipmentStatus(shipmentStatusFilter) }}
          </q-chip>
        </template>
      </ProcurementOpsListToolbar>

      <FilterSidebar v-model="filterDrawerOpen" title="Filters">
        <div class="column q-gutter-y-md">
          <div>
            <div class="text-caption text-weight-medium q-mb-xs">Location (any level)</div>
            <StockLocationHierarchyPicker
              v-model="draftLocationFilter"
              :locations="stockLocationStore.items"
              pick-any-node
            />
          </div>

          <q-select
            v-model="draftGradeTagIdFilter"
            :options="gradeTagOptions"
            filled
            dense
            clearable
            emit-value
            map-options
            label="Condition"
          />

          <q-select
            v-model="draftShipmentIdFilter"
            :options="shipmentSelectOptions"
            filled
            dense
            clearable
            use-input
            emit-value
            map-options
            fill-input
            hide-selected
            input-debounce="300"
            label="Shipment"
            :loading="shipmentsLoading"
            @filter="filterShipments"
          />

          <q-select
            v-model="draftShipmentStatusFilter"
            :options="shipmentStatusOptions"
            filled
            dense
            clearable
            emit-value
            map-options
            label="Shipment status"
          />

          <q-toggle v-model="draftHideZeroStockFilter" label="Hide Zero Stock" left-label />
        </div>

        <template #footer>
          <div class="row justify-end q-gutter-x-sm">
            <q-btn flat no-caps label="Reset" color="grey-7" @click="onResetFilters" />
            <q-btn unelevated no-caps label="Apply Filters" color="primary" @click="onApplyDrawerFilters" />
          </div>
        </template>
      </FilterSidebar>

      <WarehouseStockListSkeleton
        v-if="listIsLoading && !listHasRows"
        :read-only="isWarehouseReadOnly"
      />

      <div
        v-else-if="!listHasRows && (totalCount ?? 0) === 0 && activeFilterCount === 0 && quickAvailability === 'all' && !groupBy && !listIsFetching"
        class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block col warehouse-list-card"
      >
        <q-icon name="ph ph-archive-box" size="48px" class="q-mb-sm text-grey-4" />
        <div class="text-subtitle1 text-weight-bold text-slate-800 q-mb-2xs">No stock yet</div>
        <div class="text-caption text-grey-6 q-mb-md">Receive a shipment first.</div>
        <q-btn
          v-if="!isWarehouseReadOnly"
          color="primary"
          unelevated
          no-caps
          dense
          class="rounded-sq-btn text-weight-bold q-px-md"
          label="Go to shipments"
          icon="ph ph-truck"
          @click="goToShipments"
        />
      </div>

      <div
        v-else-if="!listHasRows"
        class="column items-center justify-center text-center text-grey-7 q-py-xl col warehouse-list-card"
      >
        <q-icon name="ph ph-funnel" size="36px" class="q-mb-xs text-grey-4" />
        <div class="text-subtitle2 text-weight-medium text-slate-800">No stock matches filters</div>
        <div class="text-caption text-grey-6 q-mt-xs">Try a different search or clear filters.</div>
      </div>

      <div v-else class="warehouse-list-card col column no-wrap">
        <WarehouseStockListHeaderRow :read-only="isWarehouseReadOnly" />
        <div ref="scrollContainerRef" class="warehouse-list-scroll col">
          <template v-if="!groupBy">
            <WarehouseStockListRow
              v-for="(row, index) in stockRows"
              :key="row.id"
              :row="row"
              :index="rowSl(index)"
              :read-only="isWarehouseReadOnly"
              :grade-label="gradeLabel(row)"
              :availability-label="formatStockAvailability(row.availability)"
              :shipment-status-label="formatGlobalShipmentStatus(row.shipment_status)"
              :outcome-label="row.outcome_reason ? formatOutcomeReason(row.outcome_reason) : ''"
              :unit-cost-label="formatCost(getUnitCost(row))"
              :line-total-label="formatCost(getUnitCost(row) * row.quantity)"
              @location="openLocationDialog"
              @condition="openMoveGradeDialog"
              @copy-code="(code) => copyText(code, 'Product Code')"
            />
          </template>
          <template v-else>
            <div v-for="group in stockGroups" :key="group.key" class="warehouse-group-block">
              <button
                type="button"
                class="warehouse-group-header row items-center no-wrap full-width"
                @click="toggleGroupExpand(group.key)"
              >
                <q-icon
                  :name="expandedGroupKey === group.key ? 'ph ph-caret-down' : 'ph ph-caret-right'"
                  size="18px"
                  class="q-mr-sm text-grey-7"
                />
                <span class="col text-left text-weight-medium ellipsis">{{ group.label }}</span>
                <span class="text-caption text-grey-7 q-mr-sm">{{ group.lot_count }} lots</span>
                <span class="text-weight-bold text-primary">{{ group.quantity }}</span>
              </button>
              <WarehouseStockGroupLotsPanel
                v-if="expandedGroupKey === group.key && warehouseTenantId"
                :tenant-id="warehouseTenantId"
                :group-by="groupBy"
                :group-key="group.key"
                :read-only="isWarehouseReadOnly"
                :search="searchText"
                :shipment-id="shipmentIdFilter ?? null"
                :shipment-status="shipmentStatusFilter ?? null"
                :location-id="locationFilter ?? null"
                :availability="availabilityFilter ?? null"
                :grade-tag-id="gradeTagIdFilter ?? null"
                :hide-zero-stock="hideZeroStockFilter"
                :grade-label="gradeLabel"
                :get-unit-cost="getUnitCost"
                :format-cost="formatCost"
                @location="openLocationDialog"
                @condition="openMoveGradeDialog"
                @copy-code="(code) => copyText(code, 'Product Code')"
              />
            </div>
          </template>

          <div
            v-if="listHasMore"
            ref="scrollSentinelRef"
            class="warehouse-list-sentinel"
            aria-hidden="true"
          />

          <div
            v-if="listIsFetchingNext || (listIsFetching && listHasRows)"
            class="row justify-center q-py-sm"
          >
            <q-spinner color="primary" size="24px" />
          </div>
        </div>
      </div>
    </div>

    <StockMoveLocationDialog
      v-if="!isWarehouseReadOnly"
      v-model="locationDialogOpen"
      :stock-row="selectedStockRow"
      :warehouse-stock-rows="stockRows"
      :warehouse-list-incomplete="hasMore || (totalCount != null && stockRows.length < totalCount)"
      :grade-label="selectedStockRow ? gradeLabel(selectedStockRow) : undefined"
      :tenant-id="warehouseTenantId || 0"
      @updated="() => void refreshStockList()"
    />

    <StockMoveGradeDialog
      v-if="!isWarehouseReadOnly"
      v-model="moveGradeDialogOpen"
      :stock-row="selectedStockRow"
      :grade-label="selectedStockRow ? gradeLabel(selectedStockRow) : undefined"
      :tenant-id="warehouseTenantId || 0"
      @updated="() => void refreshStockList()"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useStockLocationStore } from '../stores/stockLocationStore';
import { useWarehouseStockInfiniteQuery } from '../composables/useWarehouseStockInfiniteQuery';
import { useWarehouseStockGroupsQuery } from '../composables/useWarehouseStockGroupsQuery';
import {
  globalShipmentRepository,
  type GlobalShipment,
} from '../repositories/globalShipmentRepository';
import { formatStockAvailability, type StockAvailability } from '../constants/stockAvailability';
import { formatOutcomeReason } from '../constants/shipmentOutcomeLabels';
import { formatGlobalShipmentStatus } from '../constants/shipmentStatus';
import {
  WAREHOUSE_AVAILABILITY_QUICK_FILTERS,
  WAREHOUSE_STOCK_GROUP_BY_OPTIONS,
  type WarehouseStockGroupBy,
} from '../constants/warehouseStockList';
import { tagRepository } from 'src/modules/tag/repositories/tagRepository';
import type { Tag } from 'src/modules/tag/types';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import ProcurementOpsListToolbar from '../components/ProcurementOpsListToolbar.vue';
import StockLocationHierarchyPicker from '../components/StockLocationHierarchyPicker.vue';
import WarehouseStockListHeaderRow from '../components/WarehouseStockListHeaderRow.vue';
import WarehouseStockListRow from '../components/WarehouseStockListRow.vue';
import WarehouseStockListSkeleton from '../components/WarehouseStockListSkeleton.vue';
import WarehouseStockGroupLotsPanel from '../components/WarehouseStockGroupLotsPanel.vue';
import StockMoveGradeDialog from '../components/StockMoveGradeDialog.vue';
import StockMoveLocationDialog from '../components/StockMoveLocationDialog.vue';
import { getSharedShipmentItemsCostingCache } from 'src/modules/global/composables/useShipmentItemsCostingCache';
import {
  isGlobalStockCostingInput,
  resolveGlobalStockUnitCostSync,
} from 'src/modules/global/utils/resolveGlobalStockUnitCost';
import type { GlobalStock } from '../repositories/globalStockRepository';
import { formatLocationOption } from '../utils/stockLocationOptions';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const stockLocationStore = useStockLocationStore();
const costingCache = getSharedShipmentItemsCostingCache();

const isWarehouseReadOnly = computed(() => authStore.selectedTenant?.parent_id != null);
const warehouseTenantId = computed(
  () => authStore.selectedTenant?.parent_id ?? authStore.tenantId ?? null,
);

const searchText = ref('');
const filterDrawerOpen = ref(false);
const locationFilter = ref<number | null>(null);
const availabilityFilter = ref<StockAvailability | null>(null);
const gradeTagIdFilter = ref<number | null>(null);
const shipmentStatusFilter = ref<string | null>(null);
const hideZeroStockFilter = ref<boolean>(true);
const shipmentIdFilter = ref<number | null>(
  route.query.shipment_id ? Number(route.query.shipment_id) : null,
);
const groupBy = ref<WarehouseStockGroupBy | null>(null);
const expandedGroupKey = ref<string | null>(null);
const quickAvailability = ref<'all' | StockAvailability>('all');

const draftLocationFilter = ref<number | null>(null);
const draftGradeTagIdFilter = ref<number | null>(null);
const draftShipmentStatusFilter = ref<string | null>(null);
const draftShipmentIdFilter = ref<number | null>(null);
const draftHideZeroStockFilter = ref<boolean>(true);
const shipmentSelectOptions = ref<Array<{ label: string; value: number }>>([]);
const shipmentsLoading = ref(false);

const flatListEnabled = computed(() => groupBy.value == null);

const {
  stockRows,
  totalCount,
  hasMore,
  isLoading,
  isFetching,
  isFetchingNextPage,
  fetchNextPage,
  refetch,
  error: stockListError,
} = useWarehouseStockInfiniteQuery({
  tenantId: warehouseTenantId,
  search: searchText,
  shipmentId: shipmentIdFilter,
  shipmentStatus: shipmentStatusFilter,
  locationId: locationFilter,
  availability: availabilityFilter,
  gradeTagId: gradeTagIdFilter,
  hideZeroStock: hideZeroStockFilter,
  enabled: flatListEnabled,
});

const {
  groups: stockGroups,
  hasMore: groupsHasMore,
  isFetching: groupsIsFetching,
  isFetchingNextPage: groupsIsFetchingNextPage,
  fetchNextPage: fetchNextGroupsPage,
  refetch: refetchGroups,
  isLoading: groupsIsLoading,
} = useWarehouseStockGroupsQuery({
  tenantId: warehouseTenantId,
  groupBy: computed(() => groupBy.value),
  search: searchText,
  shipmentId: shipmentIdFilter,
  shipmentStatus: shipmentStatusFilter,
  locationId: locationFilter,
  availability: availabilityFilter,
  gradeTagId: gradeTagIdFilter,
  hideZeroStock: hideZeroStockFilter,
  enabled: computed(() => groupBy.value != null),
});

const listHasMore = computed(() => (groupBy.value ? groupsHasMore.value : hasMore.value));
const listIsFetching = computed(() => (groupBy.value ? groupsIsFetching.value : isFetching.value));
const listIsFetchingNext = computed(() =>
  groupBy.value ? groupsIsFetchingNextPage.value : isFetchingNextPage.value,
);
const listIsLoading = computed(() => (groupBy.value ? groupsIsLoading.value : isLoading.value));
const listHasRows = computed(() =>
  groupBy.value ? stockGroups.value.length > 0 : stockRows.value.length > 0,
);

const listErrorMessage = computed(() =>
  stockListError.value ? (stockListError.value as Error).message : null,
);

const moveGradeDialogOpen = ref(false);
const locationDialogOpen = ref(false);
const selectedStockRow = ref<GlobalStock | null>(null);
const gradeTags = ref<Tag[]>([]);

const gradeNameById = computed(() => {
  const map = new Map<number, string>();
  for (const tag of gradeTags.value) {
    map.set(tag.id, tag.name);
  }
  return map;
});

const gradeLabel = (row: GlobalStock): string =>
  row.grade_name || gradeNameById.value.get(row.grade_tag_id ?? 0) || 'Standard';

const availabilityQuickPills = WAREHOUSE_AVAILABILITY_QUICK_FILTERS;
const groupByOptions = WAREHOUSE_STOCK_GROUP_BY_OPTIONS;

const shipmentStatusOptions = [
  { label: 'Draft', value: 'draft' },
  { label: 'In transit', value: 'in_transit' },
  { label: 'Received', value: 'received' },
  { label: 'Cancelled', value: 'cancelled' },
];

const gradeTagOptions = computed(() =>
  gradeTags.value.map((t) => ({ label: t.name, value: t.id })),
);

const locationFilterChipLabel = computed(() => {
  const id = locationFilter.value;
  if (id == null) return '';
  const loc = stockLocationStore.items.find((l) => l.id === id);
  return loc ? `Location: ${formatLocationOption(loc)}` : `Location #${id}`;
});

const gradeFilterChipLabel = computed(() => {
  const id = gradeTagIdFilter.value;
  if (id == null) return '';
  const name = gradeNameById.value.get(id);
  return name ? `Condition: ${name}` : `Condition #${id}`;
});

const setQuickAvailability = (value: 'all' | StockAvailability) => {
  quickAvailability.value = value;
  availabilityFilter.value = value === 'all' ? null : value;
  resetScrollPosition();
};

const onSearchInput = (val: string | null | undefined) => {
  searchText.value = val ?? '';
  onSearch();
};

const toggleGroupExpand = (key: string) => {
  expandedGroupKey.value = expandedGroupKey.value === key ? null : key;
};

const clearLocationFilter = () => {
  locationFilter.value = null;
  resetScrollPosition();
};

const clearGradeFilter = () => {
  gradeTagIdFilter.value = null;
  resetScrollPosition();
};

watch(groupBy, () => {
  expandedGroupKey.value = null;
  resetScrollPosition();
});

const shipmentOptionLabel = (shipment: GlobalShipment): string => {
  const num =
    (shipment as GlobalShipment & { tenant_shipment_id?: number | null }).tenant_shipment_id ??
    shipment.id;
  return `${shipment.name} (${formatGlobalShipmentStatus(shipment.status)})`;
};

const shipmentChipLabel = computed(() => {
  const id = shipmentIdFilter.value;
  if (id == null) return '';
  const match = shipmentSelectOptions.value.find((opt) => opt.value === id);
  return match?.label ?? `Shipment #${id}`;
});

const scrollContainerRef = ref<HTMLElement | null>(null);
const scrollSentinelRef = ref<HTMLElement | null>(null);
let scrollObserver: IntersectionObserver | null = null;

const rowSl = (index: number) => index + 1;

const disconnectScrollObserver = () => {
  scrollObserver?.disconnect();
  scrollObserver = null;
};

const tryFetchNextPage = () => {
  if (groupBy.value) {
    if (!groupsHasMore.value || groupsIsFetchingNextPage.value) return;
    void fetchNextGroupsPage();
    return;
  }
  if (!hasMore.value || isFetchingNextPage.value) return;
  void fetchNextPage();
};

const setupScrollObserver = () => {
  disconnectScrollObserver();
  const root = scrollContainerRef.value;
  const target = scrollSentinelRef.value;
  if (!root || !target) return;

  scrollObserver = new IntersectionObserver(
    (entries) => {
      if (!entries[0]?.isIntersecting) return;
      tryFetchNextPage();
    },
    { root, rootMargin: '160px 0px', threshold: 0 },
  );
  scrollObserver.observe(target);
};

const loadShipmentOptions = async (search?: string) => {
  if (!warehouseTenantId.value) return;
  shipmentsLoading.value = true;
  try {
    const result = await globalShipmentRepository.listPaginated(
      warehouseTenantId.value,
      1,
      50,
      search?.trim() || undefined,
    );
    const options = result.data.map((shipment) => ({
      label: shipmentOptionLabel(shipment),
      value: shipment.id,
    }));
    const selectedId = draftShipmentIdFilter.value ?? shipmentIdFilter.value;
    if (selectedId != null && !options.some((opt) => opt.value === selectedId)) {
      const existing = shipmentSelectOptions.value.find((opt) => opt.value === selectedId);
      if (existing) options.unshift(existing);
    }
    shipmentSelectOptions.value = options;
  } finally {
    shipmentsLoading.value = false;
  }
};

const filterShipments = (val: string, update: (callback: () => void) => void) => {
  void loadShipmentOptions(val).then(() => {
    update(() => undefined);
  });
};

watch(
  () => route.query.shipment_id,
  (newVal) => {
    shipmentIdFilter.value = newVal ? Number(newVal) : null;
    resetScrollPosition();
  },
);

const clearShipmentFilter = () => {
  shipmentIdFilter.value = null;
  draftShipmentIdFilter.value = null;
  void router.replace({ query: { ...route.query, shipment_id: undefined } });
  resetScrollPosition();
};

const writeShipmentQuery = (id: number | null): boolean => {
  const next = id == null ? undefined : String(id);
  const current = route.query.shipment_id;
  const currentStr = Array.isArray(current) ? current[0] : current;
  if ((currentStr ?? undefined) === next) return false;
  void router.replace({ query: { ...route.query, shipment_id: next } });
  return true;
};

const copyText = (text: string | null, label: string) => {
  if (!text) return;
  void navigator.clipboard.writeText(String(text));
  $q.notify({
    message: `Copied ${label} to clipboard`,
    color: 'positive',
    icon: 'ph ph-copy',
    timeout: 1000,
  });
};

const openLocationDialog = (row: GlobalStock) => {
  selectedStockRow.value = row;
  locationDialogOpen.value = true;
};

const openMoveGradeDialog = (row: GlobalStock) => {
  selectedStockRow.value = row;
  moveGradeDialogOpen.value = true;
};

const activeFilterCount = computed(() => {
  let count = 0;
  if (locationFilter.value !== null) count++;
  if (gradeTagIdFilter.value !== null) count++;
  if (shipmentStatusFilter.value !== null) count++;
  if (!hideZeroStockFilter.value) count++;
  if (shipmentIdFilter.value !== null) count++;
  return count;
});

const getUnitCost = (row: GlobalStock): number => {
  if (!isGlobalStockCostingInput(row)) return 0;
  return resolveGlobalStockUnitCostSync(row, costingCache.getSync(row.shipment_id));
};

const formatCost = (val: number): string =>
  val.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const resetScrollPosition = () => {
  if (scrollContainerRef.value) {
    scrollContainerRef.value.scrollTop = 0;
  }
};

const refreshStockList = async () => {
  resetScrollPosition();
  await Promise.all([refetch(), groupBy.value ? refetchGroups() : Promise.resolve()]);
};

const onSearch = () => {
  resetScrollPosition();
};

watch(
  stockRows,
  (rows) => {
    if (!rows.length) return;
    void costingCache.prefetchShipmentItems(rows.map((row) => row.shipment_id));
  },
  { immediate: true },
);

watch(
  [scrollContainerRef, scrollSentinelRef, listHasMore, listHasRows, groupBy],
  () => {
    if (!listHasRows.value) {
      disconnectScrollObserver();
      return;
    }
    setupScrollObserver();
  },
  { flush: 'post' },
);

watch(listIsFetchingNext, (fetching, wasFetching) => {
  if (!wasFetching || fetching || !listHasMore.value) return;
  requestAnimationFrame(() => {
    if (!listHasMore.value || listIsFetchingNext.value) return;
    const root = scrollContainerRef.value;
    const target = scrollSentinelRef.value;
    if (!root || !target) return;
    const rootRect = root.getBoundingClientRect();
    const targetRect = target.getBoundingClientRect();
    if (targetRect.top <= rootRect.bottom + 160) {
      tryFetchNextPage();
    }
  });
});

onBeforeUnmount(() => {
  disconnectScrollObserver();
});

const openFilterDrawer = () => {
  draftLocationFilter.value = locationFilter.value;
  draftGradeTagIdFilter.value = gradeTagIdFilter.value;
  draftShipmentStatusFilter.value = shipmentStatusFilter.value;
  draftShipmentIdFilter.value = shipmentIdFilter.value;
  draftHideZeroStockFilter.value = hideZeroStockFilter.value;
  filterDrawerOpen.value = true;
  void loadShipmentOptions();
};

const onApplyDrawerFilters = () => {
  locationFilter.value = draftLocationFilter.value;
  gradeTagIdFilter.value = draftGradeTagIdFilter.value;
  shipmentStatusFilter.value = draftShipmentStatusFilter.value;
  hideZeroStockFilter.value = draftHideZeroStockFilter.value;
  shipmentIdFilter.value = draftShipmentIdFilter.value;
  filterDrawerOpen.value = false;
  resetScrollPosition();
  writeShipmentQuery(draftShipmentIdFilter.value);
};

const onResetFilters = () => {
  draftLocationFilter.value = null;
  draftGradeTagIdFilter.value = null;
  draftShipmentStatusFilter.value = null;
  draftShipmentIdFilter.value = null;
  draftHideZeroStockFilter.value = true;
  locationFilter.value = null;
  gradeTagIdFilter.value = null;
  shipmentStatusFilter.value = null;
  hideZeroStockFilter.value = true;
  shipmentIdFilter.value = null;
  filterDrawerOpen.value = false;
  resetScrollPosition();
  writeShipmentQuery(null);
};

const goToShipments = () => {
  void router.push({
    name: 'app-procurement-shipment-list',
    params: { tenantSlug: route.params.tenantSlug },
  });
};

onMounted(async () => {
  if (warehouseTenantId.value) {
    await stockLocationStore.fetchLocations(warehouseTenantId.value);
  }
  try {
    gradeTags.value = await tagRepository.listTagsForCategory({
      moduleKey: 'stock_grade',
      code: 'warehouse',
    });
  } catch {
    gradeTags.value = [];
  }
  if (shipmentIdFilter.value != null) {
    void loadShipmentOptions();
  }
});
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
  overflow: hidden;
}

.full-height {
  min-height: 0;
  height: 100%;
}

.border-grey {
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}
.shrink-0 {
  flex-shrink: 0;
}
.avatar-soft-sq {
  border-radius: 6px;
}
.font-mono {
  font-family: var(--bw-font-mono, monospace);
}
.rounded-sq-btn {
  border-radius: 8px;
}

.warehouse-list-card {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: var(--bw-neutral-surface, #ffffff);
  border: 1px solid var(--bw-neutral-border, #e2e8f0);
  border-radius: var(--bw-radius-sm, 8px);
  overflow: hidden;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
}

.warehouse-list-scroll {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
}

.warehouse-list-sentinel {
  height: 1px;
  width: 100%;
  flex-shrink: 0;
}

.warehouse-group-header {
  border: none;
  background: color-mix(in srgb, var(--bw-neutral-canvas, #fbfaf7) 70%, transparent);
  padding: 0.55rem 1rem;
  cursor: pointer;
  border-bottom: 1px solid var(--bw-neutral-border, #e2e8f0);
  color: var(--bw-neutral-ink, #1e293b);
}

.warehouse-group-header:hover {
  background: color-mix(in srgb, var(--bw-neutral-canvas, #fbfaf7) 90%, transparent);
}

.text-slate-400 {
  color: #94a3b8;
}
.text-slate-800 {
  color: #1e293b;
}
</style>
