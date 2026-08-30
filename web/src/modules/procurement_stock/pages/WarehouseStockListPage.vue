<template>
  <q-page class="warehouse-stock-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Header -->
    <div class="warehouse-top-section bg-white border-bottom q-px-lg q-py-md shrink-0 shadow-xs">
      <div class="row items-center justify-between wrap q-gutter-y-sm">
        <div class="col-grow" style="min-width: 0">
          <div class="text-subtitle1 text-weight-bolder text-grey-9" style="font-size: 15px">
            Warehouse Stock
          </div>
          <div class="text-caption text-grey-7">
            {{
              isWarehouseReadOnly
                ? 'Parent company warehouse stock (view only).'
                : 'What is on the shelves, and whether it can be sold.'
            }}
          </div>
        </div>

        <div class="row items-center q-gutter-sm no-wrap">
          <q-input
            v-model="searchText"
            outlined
            dense
            clearable
            placeholder="Search product, code, barcode, shipment..."
            class="warehouse-search-input bg-white"
            style="min-width: 240px"
            @keyup.enter="onSearch"
            @clear="onSearch"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" size="16px" />
            </template>
          </q-input>

          <q-btn
            flat
            dense
            no-caps
            color="grey-8"
            class="rounded-sq-btn text-weight-bold q-px-sm border-grey"
            icon="ph ph-funnel"
            label="Filters"
            size="sm"
            @click="openFilterDrawer"
          >
            <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
              {{ activeFilterCount }}
            </q-badge>
          </q-btn>
        </div>
      </div>

      <q-banner v-if="stockStore.error" class="bg-negative text-white q-mt-sm q-py-xs">
        {{ stockStore.error }}
      </q-banner>

      <div v-if="shipmentIdFilter" class="row items-center q-mt-sm">
        <q-chip
          removable
          color="primary"
          text-color="white"
          dense
          @remove="clearShipmentFilter"
        >
          {{ shipmentChipLabel }}
        </q-chip>
      </div>
    </div>

    <!-- Filter Sidebar -->
    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <div class="q-gutter-y-md q-pa-sm">
        <q-select
          v-model="draftLocationFilter"
          :options="locationOptions"
          filled
          dense
          clearable
          emit-value
          map-options
          label="Location"
        />

        <q-select
          v-model="draftAvailabilityFilter"
          :options="availabilityOptions"
          filled
          dense
          clearable
          emit-value
          map-options
          label="Availability"
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

        <q-toggle v-model="draftIsSellableFilter" label="Sellable Only" left-label />

        <q-toggle v-model="draftHideZeroStockFilter" label="Hide Zero Stock" left-label />

        <div class="row justify-end q-gutter-x-sm q-mt-md">
          <q-btn flat no-caps label="Reset" color="grey-7" @click="onResetFilters" />
          <q-btn unelevated no-caps label="Apply Filters" color="primary" @click="onApplyDrawerFilters" />
        </div>
      </div>
    </FilterSidebar>

    <!-- Table -->
    <div
      class="warehouse-table-section col overflow-auto q-pa-none bg-white hide-native-scrollbar"
      style="overflow-x: auto; overflow-y: auto"
    >
      <div v-if="stockStore.loading && !stockStore.rows.length" class="row justify-center items-center q-py-xl">
        <q-spinner color="primary" size="3em" />
        <div class="text-grey-7 q-ml-md">Loading warehouse stock...</div>
      </div>

      <template v-else>
        <q-markup-table flat class="shipment-items-markup-table bg-white" style="min-width: 980px; width: 100%">
          <thead>
            <tr>
              <th class="text-center q-pa-none" style="width: 36px; min-width: 36px">SL</th>
              <th class="text-left" style="width: 82px; min-width: 82px">Image</th>
              <th class="text-left" style="min-width: 120px; width: 120px; white-space: normal">Name</th>
              <th class="text-left" style="min-width: 105px; width: 115px">Codes</th>
              <th class="text-left warehouse-col-shipment">Shipment</th>
              <th class="text-left warehouse-col-grade">Grade & Location</th>
              <th class="text-center bw-ops-col-tint--cost" style="min-width: 72px; width: 72px">Cost</th>
              <th class="text-center bw-ops-col-tint--qty" style="min-width: 56px; width: 56px">Qty</th>
              <th v-if="!isWarehouseReadOnly" class="text-center" style="min-width: 88px; width: 88px">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(row, index) in stockStore.rows"
              :key="row.id"
              class="warehouse-stock-row"
            >
              <td class="text-center text-weight-medium text-grey-7 q-pa-none" style="width: 36px; min-width: 36px">
                {{ rowSl(index) }}
              </td>

              <td class="shipment-image-col">
                <q-avatar square size="82px" class="avatar-soft-sq bg-grey-2 border-grey overflow-hidden" style="width: 0.85in; height: 0.85in">
                  <SmartImage
                    :src="row.image_url"
                    :alt="row.item_name"
                    style="object-fit: cover; width: 100%; height: 100%"
                  />
                </q-avatar>
              </td>

              <td style="width: 120px; min-width: 120px; max-width: 120px; white-space: normal !important; word-break: break-word">
                <div class="text-weight-bold text-grey-9" style="font-size: 13px; line-height: 1.35; word-break: break-word; white-space: normal">
                  {{ row.item_name }}
                </div>
              </td>

              <td class="font-mono text-caption">
                <div class="column q-gutter-y-2xs" style="line-height: 1.1">
                  <div v-if="row.product_code" class="row items-center justify-between no-wrap">
                    <div class="ellipsis">
                      <span class="text-grey-6 text-uppercase" style="font-size: 8px">C: </span>
                      <b class="text-dark" style="font-size: 10px">{{ row.product_code }}</b>
                    </div>
                    <q-btn
                      flat
                      dense
                      round
                      size="xs"
                      icon="ph ph-copy"
                      color="grey-7"
                      style="font-size: 9px; padding: 0"
                      @click.stop="copyText(row.product_code, 'Product Code')"
                    >
                      <q-tooltip>Copy Code</q-tooltip>
                    </q-btn>
                  </div>
                  <div v-if="row.barcode" class="row items-center justify-between no-wrap">
                    <div class="ellipsis">
                      <span class="text-grey-6 text-uppercase" style="font-size: 8px">B: </span>
                      <span class="text-grey-9" style="font-size: 10px">{{ row.barcode }}</span>
                    </div>
                    <q-btn
                      flat
                      dense
                      round
                      size="xs"
                      icon="ph ph-copy"
                      color="grey-7"
                      style="font-size: 9px; padding: 0"
                      @click.stop="copyText(row.barcode, 'Barcode')"
                    >
                      <q-tooltip>Copy Barcode</q-tooltip>
                    </q-btn>
                  </div>
                  <span v-if="!row.product_code && !row.barcode" class="text-grey-5">—</span>
                </div>
              </td>

              <td class="warehouse-col-shipment">
                <div class="text-weight-medium text-grey-9 ellipsis" style="font-size: 11px; max-width: 88px">
                  {{ row.shipment_name || '—' }}
                </div>
                <div v-if="row.shipment_status" class="text-caption text-grey-6 text-xxs ellipsis" style="max-width: 88px">
                  {{ formatGlobalShipmentStatus(row.shipment_status) }}
                </div>
              </td>

              <td class="warehouse-col-grade">
                <div class="column q-gutter-y-2xs" style="max-width: 100px">
                  <q-chip dense square color="grey-2" text-color="grey-9" class="text-weight-medium text-xxs q-ma-none ellipsis" style="max-width: 100px">
                    {{ gradeLabel(row) }}
                  </q-chip>
                  <div class="text-caption text-grey-7 row items-center q-gutter-x-xs no-wrap text-xxs">
                    <q-icon name="ph ph-map-pin" size="12px" color="grey-6" class="shrink-0" />
                    <span class="ellipsis" style="max-width: 84px">
                      {{ formatStockAvailability(row.availability) }}
                      ·
                      {{ row.location_name || (row.location_id ? `#${row.location_id}` : '—') }}
                    </span>
                  </div>
                </div>
              </td>

              <td class="text-center bw-ops-col-tint--cost font-mono" style="width: 72px; min-width: 72px">
                <div class="text-weight-bold text-primary" style="font-size: 12px">
                  {{ formatCost(getUnitCost(row)) }}
                </div>
                <div class="text-caption text-grey-7 text-weight-normal q-mt-2xs" style="font-size: 10px">
                  T: {{ formatCost(getUnitCost(row) * row.quantity) }}
                </div>
              </td>

              <td class="text-center bw-ops-col-tint--qty text-weight-bold text-grey-9 font-mono" style="width: 56px; min-width: 56px">
                {{ row.quantity }}
              </td>

              <td v-if="!isWarehouseReadOnly" class="text-center">
                <div class="row items-center justify-center q-gutter-x-xs no-wrap">
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-map-pin-line"
                    size="sm"
                    color="primary"
                    @click.stop="openLocationDialog(row)"
                  >
                    <q-tooltip>Transfer Location</q-tooltip>
                  </q-btn>
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-tag"
                    size="sm"
                    color="secondary"
                    @click.stop="openMoveGradeDialog(row)"
                  >
                    <q-tooltip>Re-Grade & Split</q-tooltip>
                  </q-btn>
                </div>
              </td>
            </tr>

            <tr v-if="stockStore.rows.length > 0" class="warehouse-totals-row">
              <td colspan="6" class="text-weight-bold text-grey-9">Total (page)</td>
              <td class="text-center bw-ops-col-tint--cost font-mono text-weight-bold text-primary">
                <div style="font-size: 12px">{{ formatCost(pageTotals.avgUnitCost) }} avg</div>
                <div class="text-caption text-grey-7 text-weight-normal" style="font-size: 10px">
                  T: {{ formatCost(pageTotals.totalCost) }}
                </div>
              </td>
              <td class="text-center bw-ops-col-tint--qty text-weight-bold text-grey-9 font-mono">
                {{ pageTotals.totalQty }}
              </td>
              <td v-if="!isWarehouseReadOnly" />
            </tr>

            <tr v-if="stockStore.rows.length === 0">
              <td :colspan="isWarehouseReadOnly ? 8 : 9" class="text-center q-py-xl">
                <q-icon name="ph ph-archive-box" size="48px" class="q-mb-sm text-grey-4" />
                <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-xs">
                  {{ stockStore.total === 0 ? 'No stock yet' : 'No stock matches filters' }}
                </div>
                <div v-if="stockStore.total === 0" class="text-caption text-grey-6 q-mb-md">
                  Receive a shipment first.
                </div>
                <q-btn
                  v-if="stockStore.total === 0 && !isWarehouseReadOnly"
                  color="primary"
                  unelevated
                  no-caps
                  dense
                  label="Go to shipments"
                  @click="goToShipments"
                />
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </template>
    </div>

    <!-- Pagination -->
    <div
      v-if="stockStore.total > 0"
      class="warehouse-footer bg-white border-top q-px-lg q-py-sm shrink-0 row items-center justify-between"
    >
      <div class="text-caption text-grey-7">
        Showing
        <span class="text-weight-bold text-grey-9">{{ pageRangeStart }}–{{ pageRangeEnd }}</span>
        of
        <span class="text-weight-bold text-grey-9">{{ stockStore.total }}</span>
      </div>
      <div class="row items-center q-gutter-sm">
        <q-select
          :model-value="stockStore.pageSize"
          :options="pageSizeOptions"
          dense
          outlined
          emit-value
          map-options
          options-dense
          hide-bottom-space
          style="width: 72px"
          @update:model-value="onPageSizeChange"
        />
        <q-btn
          flat
          round
          dense
          icon="ph ph-caret-left"
          :disable="stockStore.page <= 1 || stockStore.loading"
          @click="goToPage(stockStore.page - 1)"
        />
        <span class="text-caption text-weight-bold text-grey-8">
          Page {{ stockStore.page }} / {{ totalPages }}
        </span>
        <q-btn
          flat
          round
          dense
          icon="ph ph-caret-right"
          :disable="stockStore.page >= totalPages || stockStore.loading"
          @click="goToPage(stockStore.page + 1)"
        />
      </div>
    </div>

    <StockMoveLocationDialog
      v-if="!isWarehouseReadOnly"
      v-model="locationDialogOpen"
      :stock-row="selectedStockRow"
      :tenant-id="warehouseTenantId || 0"
      @updated="loadStock"
    />

    <StockMoveGradeDialog
      v-if="!isWarehouseReadOnly"
      v-model="moveGradeDialogOpen"
      :stock-row="selectedStockRow"
      :tenant-id="warehouseTenantId || 0"
      @updated="loadStock"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalStockStore } from '../stores/globalStockStore';
import { useStockLocationStore } from '../stores/stockLocationStore';
import {
  globalShipmentRepository,
  type GlobalShipment,
} from '../repositories/globalShipmentRepository';
import { getLeafLocations, toLocationSelectOptions } from '../utils/stockLocationOptions';
import {
  STOCK_AVAILABILITY_OPTIONS,
  formatStockAvailability,
  type StockAvailability,
} from '../constants/stockAvailability';
import { formatGlobalShipmentStatus } from '../constants/shipmentStatus';
import { tagRepository } from 'src/modules/tag/repositories/tagRepository';
import type { Tag } from 'src/modules/tag/types';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import StockMoveGradeDialog from '../components/StockMoveGradeDialog.vue';
import StockMoveLocationDialog from '../components/StockMoveLocationDialog.vue';
import { getSharedShipmentItemsCostingCache } from 'src/modules/global/composables/useShipmentItemsCostingCache';
import {
  isGlobalStockCostingInput,
  resolveGlobalStockUnitCostSync,
} from 'src/modules/global/utils/resolveGlobalStockUnitCost';
import type { GlobalStock } from '../repositories/globalStockRepository';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const stockStore = useGlobalStockStore();
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
const isSellableFilter = ref<boolean | null>(null);
const hideZeroStockFilter = ref<boolean>(true);
const shipmentIdFilter = ref<number | null>(
  route.query.shipment_id ? Number(route.query.shipment_id) : null,
);

const draftLocationFilter = ref<number | null>(null);
const draftAvailabilityFilter = ref<StockAvailability | null>(null);
const draftIsSellableFilter = ref<boolean | null>(null);
const draftShipmentIdFilter = ref<number | null>(null);
const draftHideZeroStockFilter = ref<boolean>(true);
const shipmentSelectOptions = ref<Array<{ label: string; value: number }>>([]);
const shipmentsLoading = ref(false);

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

const totalPages = computed(() =>
  Math.max(1, Math.ceil(stockStore.total / stockStore.pageSize)),
);

const pageRangeStart = computed(() => {
  if (stockStore.total === 0) return 0;
  return (stockStore.page - 1) * stockStore.pageSize + 1;
});

const pageRangeEnd = computed(() =>
  Math.min(stockStore.page * stockStore.pageSize, stockStore.total),
);

const rowSl = (index: number) => (stockStore.page - 1) * stockStore.pageSize + index + 1;

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
    stockStore.page = 1;
    void loadStock();
  },
);

const clearShipmentFilter = () => {
  shipmentIdFilter.value = null;
  draftShipmentIdFilter.value = null;
  void router.replace({ query: { ...route.query, shipment_id: undefined } });
  stockStore.page = 1;
  void loadStock();
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
  if (availabilityFilter.value !== null) count++;
  if (isSellableFilter.value !== null) count++;
  if (!hideZeroStockFilter.value) count++;
  if (shipmentIdFilter.value !== null) count++;
  return count;
});

const locationOptions = computed(() =>
  toLocationSelectOptions(getLeafLocations(stockLocationStore.items)),
);

const availabilityOptions = STOCK_AVAILABILITY_OPTIONS;

const pageSizeOptions = [
  { label: '10', value: 10 },
  { label: '20', value: 20 },
  { label: '50', value: 50 },
];

const getUnitCost = (row: GlobalStock): number => {
  if (!isGlobalStockCostingInput(row)) return 0;
  return resolveGlobalStockUnitCostSync(row, costingCache.getSync(row.shipment_id));
};

const formatCost = (val: number): string =>
  val.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const pageTotals = computed(() => {
  let totalQty = 0;
  let totalCost = 0;
  for (const row of stockStore.rows) {
    const qty = row.quantity || 0;
    const unitCost = getUnitCost(row);
    totalQty += qty;
    totalCost += unitCost * qty;
  }
  return {
    totalQty,
    totalCost,
    avgUnitCost: totalQty > 0 ? totalCost / totalQty : 0,
  };
});

const loadStock = async () => {
  if (!warehouseTenantId.value) return;
  await stockStore.fetchStocks(warehouseTenantId.value, {
    page: stockStore.page,
    pageSize: stockStore.pageSize,
    search: searchText.value.trim() || null,
    availability: availabilityFilter.value,
    isSellable: isSellableFilter.value,
    hideZeroStock: hideZeroStockFilter.value,
    locationId: locationFilter.value,
    shipmentId: shipmentIdFilter.value,
  });
  await costingCache.prefetchShipmentItems(stockStore.rows.map((row) => row.shipment_id));
};

const goToPage = async (page: number) => {
  stockStore.page = page;
  await loadStock();
};

const onPageSizeChange = async (size: number) => {
  stockStore.pageSize = size;
  stockStore.page = 1;
  await loadStock();
};

const onSearch = () => {
  stockStore.page = 1;
  void loadStock();
};

const openFilterDrawer = () => {
  draftLocationFilter.value = locationFilter.value;
  draftAvailabilityFilter.value = availabilityFilter.value;
  draftIsSellableFilter.value = isSellableFilter.value;
  draftShipmentIdFilter.value = shipmentIdFilter.value;
  draftHideZeroStockFilter.value = hideZeroStockFilter.value;
  filterDrawerOpen.value = true;
  void loadShipmentOptions();
};

const onApplyDrawerFilters = () => {
  locationFilter.value = draftLocationFilter.value;
  availabilityFilter.value = draftAvailabilityFilter.value;
  isSellableFilter.value = draftIsSellableFilter.value;
  hideZeroStockFilter.value = draftHideZeroStockFilter.value;
  shipmentIdFilter.value = draftShipmentIdFilter.value;
  filterDrawerOpen.value = false;
  stockStore.page = 1;
  const navigated = writeShipmentQuery(draftShipmentIdFilter.value);
  if (!navigated) void loadStock();
};

const onResetFilters = () => {
  draftLocationFilter.value = null;
  draftAvailabilityFilter.value = null;
  draftIsSellableFilter.value = null;
  draftShipmentIdFilter.value = null;
  draftHideZeroStockFilter.value = true;
  locationFilter.value = null;
  availabilityFilter.value = null;
  isSellableFilter.value = null;
  hideZeroStockFilter.value = true;
  shipmentIdFilter.value = null;
  filterDrawerOpen.value = false;
  stockStore.page = 1;
  const navigated = writeShipmentQuery(null);
  if (!navigated) void loadStock();
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
  void loadStock();
});
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
.border-top {
  border-top: 1px solid #e2e8f0;
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
.text-xxs {
  font-size: 11px;
}
.font-mono {
  font-family: monospace;
}
.rounded-sq-btn {
  border-radius: 8px;
}
.hide-native-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;
}
.hide-native-scrollbar::-webkit-scrollbar {
  display: none;
}

.warehouse-search-input :deep(.q-field__control) {
  min-height: 34px;
  height: 34px;
}

.shipment-items-markup-table th,
.shipment-items-markup-table td {
  padding: 4px 4px !important;
  height: 48px;
}

.shipment-items-markup-table th.bw-ops-col-tint--cost,
.shipment-items-markup-table td.bw-ops-col-tint--cost {
  background-color: #ffe8d1 !important;
  box-shadow: inset 2px 0 0 #ea580c;
}

.shipment-items-markup-table th.bw-ops-col-tint--qty,
.shipment-items-markup-table td.bw-ops-col-tint--qty {
  background-color: #d0e6ff !important;
  box-shadow: inset 2px 0 0 #2563eb;
}

.shipment-items-markup-table tr.warehouse-stock-row:hover td {
  filter: brightness(0.98);
}

.warehouse-totals-row td {
  background-color: #f8fafc !important;
  border-top: 1px solid #e2e8f0;
  font-weight: 600;
}

.warehouse-col-shipment {
  width: 88px;
  min-width: 88px;
  max-width: 88px;
}

.warehouse-col-grade {
  width: 100px;
  min-width: 100px;
  max-width: 100px;
}
</style>
