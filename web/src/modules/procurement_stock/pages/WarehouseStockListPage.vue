<template>
  <q-page class="bw-page page-fixed-layout q-pa-md">
    <section class="bw-page__stack" style="min-width: 0; flex: 1 1 0%; display: flex; flex-direction: column; overflow: hidden;">
      <AppPageHeader
        dense
        eyebrow="Procurement & Stock"
        title="Warehouse"
        subtitle="What is on the shelves, and whether it can be sold."
        class="q-mb-sm"
      />

      <q-banner v-if="stockStore.error" class="bw-status-banner bg-negative text-white q-mb-md">
        {{ stockStore.error }}
      </q-banner>

      <!-- Active Shipment Filter Chip if filtered by shipment_id -->
      <div v-if="shipmentIdFilter" class="row items-center q-mb-sm">
        <q-chip
          removable
          color="primary"
          text-color="white"
          dense
          @remove="clearShipmentFilter"
        >
          Shipment Filter: #{{ shipmentIdFilter }}
        </q-chip>
      </div>

      <!-- Search & Filters Toolbar -->
      <div class="row items-center q-gutter-sm q-mb-md">
        <q-input
          v-model="searchText"
          outlined
          rounded
          dense
          clearable
          class="col-grow"
          placeholder="Search by product name, code, barcode or shipment..."
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
            v-model="draftShipmentStatusFilter"
            :options="shipmentStatusOptions"
            filled
            dense
            clearable
            emit-value
            map-options
            label="Shipment Status"
          />

          <q-toggle v-model="draftIsSellableFilter" label="Sellable Only" left-label />

          <q-toggle v-model="draftHideZeroStockFilter" label="Hide Zero Stock" left-label />

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

      <PageInitialLoader v-if="stockStore.loading && !stockStore.rows.length" />

      <!-- Stock Table -->
      <div v-else class="table-fixed-wrap">
        <q-card flat bordered class="q-pa-none overflow-hidden full-height" style="min-width: 0; display: flex; flex-direction: column;">
          <q-table
            flat
            :rows="stockStore.rows"
            :columns="columns"
            row-key="id"
            :loading="stockStore.loading"
            v-model:pagination="pagination"
            :rows-per-page-options="[10, 20, 50]"
            table-style="min-width: 1100px;"
            @request="onTableRequest"
          >
            <!-- Stock ID (1st column) -->
            <template #body-cell-stock_id="props">
              <q-td :props="props" class="text-weight-bold text-grey-9">
                {{ props.row.id }}
              </q-td>
            </template>

            <!-- Image (1 inch thumbnail) -->
            <template #body-cell-image="props">
              <q-td :props="props">
                <div class="q-pa-xs border rounded-borders bg-white inline-block">
                  <SmartImage
                    :src="props.row.image_url"
                    :alt="props.row.item_name"
                    style="width: 80px; height: 80px; object-fit: cover; border-radius: 6px"
                  />
                </div>
              </q-td>
            </template>

            <!-- Product Details (Multiline Name) -->
            <template #body-cell-product="props">
              <q-td :props="props" style="white-space: normal; word-break: break-word; min-width: 220px">
                <div class="text-weight-bold text-grey-9">{{ props.row.item_name }}</div>
              </q-td>
            </template>

            <!-- Code / Barcode (Separate Column with Copy Button) -->
            <template #body-cell-code="props">
              <q-td :props="props">
                <div v-if="props.row.product_code || props.row.barcode" class="column q-gutter-y-2xs">
                  <div v-if="props.row.product_code" class="row items-center q-gutter-x-xs no-wrap">
                    <span class="text-weight-medium text-grey-9">{{ props.row.product_code }}</span>
                    <q-btn
                      flat
                      round
                      dense
                      icon="ph ph-copy"
                      size="xs"
                      color="grey-7"
                      @click.stop="copyText(props.row.product_code)"
                    >
                      <q-tooltip>Copy code</q-tooltip>
                    </q-btn>
                  </div>
                  <div v-if="props.row.barcode" class="row items-center q-gutter-x-xs no-wrap text-caption text-grey-6">
                    <span>BC: {{ props.row.barcode }}</span>
                    <q-btn
                      flat
                      round
                      dense
                      icon="ph ph-copy"
                      size="xs"
                      color="grey-6"
                      @click.stop="copyText(props.row.barcode)"
                    >
                      <q-tooltip>Copy barcode</q-tooltip>
                    </q-btn>
                  </div>
                </div>
                <span v-else class="text-grey-5">—</span>
              </q-td>
            </template>

            <!-- Combined Stock Type & Location -->
            <template #body-cell-stock_type="props">
              <q-td :props="props">
                <div class="column q-gutter-y-xs">
                  <div>
                    <q-chip
                      dense
                      square
                      color="grey-2"
                      text-color="grey-9"
                      class="text-weight-medium text-capitalize"
                    >
                      {{ props.row.stock_type_description || props.row.availability || 'Standard' }}
                    </q-chip>
                  </div>
                  <div class="text-caption text-grey-7 row items-center q-gutter-x-xs no-wrap">
                    <q-icon name="ph ph-map-pin" size="14px" color="grey-6" />
                    <span>{{ props.row.location_name || (props.row.location_id ? `#${props.row.location_id}` : '—') }}</span>
                  </div>
                </div>
              </q-td>
            </template>

            <!-- Cost -->
            <template #body-cell-cost="props">
              <q-td :props="props" class="text-center text-secondary">
                <div>৳{{ formatCost(getUnitCost(props.row)) }}</div>
                <div class="text-caption text-grey-6 text-weight-normal" style="font-size: 10px">
                  T: ৳{{ formatCost(getUnitCost(props.row) * props.row.quantity) }}
                </div>
              </q-td>
            </template>

            <!-- Quantity -->
            <template #body-cell-quantity="props">
              <q-td :props="props" class="text-center text-weight-bold text-primary">
                {{ props.row.quantity }}
              </q-td>
            </template>

            <!-- Icon Action Buttons Cell -->
            <template #body-cell-actions="props">
              <q-td :props="props" class="text-center">
                <div class="row items-center justify-center q-gutter-x-xs no-wrap">
                  <!-- Location Transfer icon button -->
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-map-pin-line"
                    size="sm"
                    color="primary"
                    @click.stop="openLocationDialog(props.row)"
                  >
                    <q-tooltip>Transfer Location</q-tooltip>
                  </q-btn>

                  <!-- Re-Grade & Split icon button -->
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-tag"
                    size="sm"
                    color="secondary"
                    @click.stop="openMoveGradeDialog(props.row)"
                  >
                    <q-tooltip>Re-Grade & Split Condition</q-tooltip>
                  </q-btn>
                </div>
              </q-td>
            </template>

            <template #bottom-row>
              <q-tr class="totals-row">
                <q-td class="totals-row__cell text-weight-bold text-grey-9">Total (Page)</q-td>
                <q-td class="totals-row__cell" />
                <q-td class="totals-row__cell" />
                <q-td class="totals-row__cell" />
                <q-td class="totals-row__cell" />
                <q-td class="totals-row__cell" />
                <q-td
                  class="totals-row__cell text-center stock-cost-col text-weight-bold text-secondary"
                >
                  <div>৳{{ formatCost(pageTotals.avgUnitCost) }} (avg)</div>
                  <div class="text-caption text-grey-7 text-weight-normal" style="font-size: 10px">
                    T: ৳{{ formatCost(pageTotals.totalCost) }}
                  </div>
                </q-td>
                <q-td class="totals-row__cell text-center stock-qty-col text-weight-bold text-primary">
                  {{ pageTotals.totalQty }}
                </q-td>
                <q-td class="totals-row__cell" />
              </q-tr>
            </template>

            <template #no-data>
              <div class="full-width text-center text-grey-7 q-py-lg">
                <q-icon name="ph ph-archive-box" size="48px" class="q-mb-sm text-grey-4" />
                <div class="text-subtitle1 text-weight-medium q-mb-xs">
                  {{ stockStore.total === 0 ? 'No stock yet' : 'No stock matches filters' }}
                </div>
                <div v-if="stockStore.total === 0" class="text-body2 q-mb-md">
                  Receive a shipment first.
                </div>
                <q-btn
                  v-if="stockStore.total === 0"
                  color="primary"
                  unelevated
                  no-caps
                  label="Go to shipments"
                  @click="goToShipments"
                />
              </div>
            </template>
          </q-table>
        </q-card>
      </div>
    </section>

    <!-- Location Transfer Dialog -->
    <StockMoveLocationDialog
      v-model="locationDialogOpen"
      :stock-row="selectedStockRow"
      :tenant-id="authStore.tenantId || 0"
      @updated="loadStock"
    />

    <!-- Unified Move & Re-Grade Dialog -->
    <StockMoveGradeDialog
      v-model="moveGradeDialogOpen"
      :stock-row="selectedStockRow"
      :tenant-id="authStore.tenantId || 0"
      @updated="loadStock"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { copyToClipboard, type QTableColumn } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalStockStore } from '../stores/globalStockStore';
import { useStockLocationStore } from '../stores/stockLocationStore';
import { getLeafLocations, toLocationSelectOptions } from '../utils/stockLocationOptions';
import {
  STOCK_AVAILABILITY_OPTIONS,
  type StockAvailability,
} from '../constants/stockAvailability';
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import StockMoveGradeDialog from '../components/StockMoveGradeDialog.vue';
import StockMoveLocationDialog from '../components/StockMoveLocationDialog.vue';
import { createShipmentItemsCostingCache } from 'src/modules/global/composables/useShipmentItemsCostingCache';
import {
  isGlobalStockCostingInput,
  resolveGlobalStockUnitCostSync,
} from 'src/modules/global/utils/resolveGlobalStockUnitCost';
import { showSuccessNotification } from 'src/utils/appFeedback';
import type { GlobalStock } from '../repositories/globalStockRepository';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const stockStore = useGlobalStockStore();
const stockLocationStore = useStockLocationStore();
const costingCache = createShipmentItemsCostingCache();

// Filter State
const searchText = ref('');
const filterDrawerOpen = ref(false);
const locationFilter = ref<number | null>(null);
const availabilityFilter = ref<StockAvailability | null>(null);
const isSellableFilter = ref<boolean | null>(null);
const shipmentStatusFilter = ref<string | null>(null);
const hideZeroStockFilter = ref<boolean>(true);
const shipmentIdFilter = ref<number | null>(
  route.query.shipment_id ? Number(route.query.shipment_id) : null,
);

const draftLocationFilter = ref<number | null>(null);
const draftAvailabilityFilter = ref<StockAvailability | null>(null);
const draftIsSellableFilter = ref<boolean | null>(null);
const draftShipmentStatusFilter = ref<string | null>(null);
const draftHideZeroStockFilter = ref<boolean>(true);

// Dialog state
const moveGradeDialogOpen = ref<boolean>(false);
const locationDialogOpen = ref<boolean>(false);
const selectedStockRow = ref<GlobalStock | null>(null);

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
  void router.replace({ query: { ...route.query, shipment_id: undefined } });
  stockStore.page = 1;
  void loadStock();
};

const copyText = async (text: string | null) => {
  if (!text) return;
  try {
    await copyToClipboard(text);
    showSuccessNotification('Copied to clipboard');
  } catch (err) {
    console.error('Failed to copy', err);
  }
};

const openLocationDialog = (row: GlobalStock) => {
  selectedStockRow.value = row;
  locationDialogOpen.value = true;
};

const openMoveGradeDialog = (row: GlobalStock) => {
  selectedStockRow.value = row;
  moveGradeDialogOpen.value = true;
};

const columns: QTableColumn[] = [
  { name: 'stock_id', label: 'Stock ID', field: 'id', align: 'left', sortable: true },
  { name: 'image', label: 'Image', field: 'image_url', align: 'left', sortable: false },
  { name: 'product', label: 'Product Name', field: 'item_name', align: 'left', sortable: false },
  { name: 'code', label: 'Code / Barcode', field: 'product_code', align: 'left', sortable: false },
  { name: 'shipment', label: 'Shipment', field: 'shipment_name', align: 'left', sortable: false },
  {
    name: 'stock_type',
    label: 'Stock Type & Location',
    field: 'stock_type_description',
    align: 'left',
    sortable: false,
  },
  {
    name: 'cost',
    label: 'Cost (Est. BDT)',
    field: 'id',
    align: 'center',
    sortable: false,
    classes: 'stock-cost-col',
    headerClasses: 'stock-cost-col',
  },
  {
    name: 'quantity',
    label: 'Quantity',
    field: 'quantity',
    align: 'center',
    sortable: false,
    classes: 'stock-qty-col',
    headerClasses: 'stock-qty-col',
  },
  {
    name: 'actions',
    label: 'Action',
    field: 'id',
    align: 'center',
    sortable: false,
  },
];

const pagination = computed({
  get: () => ({
    page: stockStore.page,
    rowsPerPage: stockStore.pageSize,
    rowsNumber: stockStore.total,
  }),
  set: (val) => {
    stockStore.page = val.page;
    stockStore.pageSize = val.rowsPerPage;
  },
});

const activeFilterCount = computed(() => {
  let count = 0;
  if (locationFilter.value !== null) count++;
  if (availabilityFilter.value !== null) count++;
  if (isSellableFilter.value !== null) count++;
  if (shipmentStatusFilter.value !== null) count++;
  if (!hideZeroStockFilter.value) count++;
  if (shipmentIdFilter.value !== null) count++;
  return count;
});

const locationOptions = computed(() =>
  toLocationSelectOptions(getLeafLocations(stockLocationStore.items)),
);

const availabilityOptions = STOCK_AVAILABILITY_OPTIONS;

const shipmentStatusOptions = [
  { label: 'All', value: '__all__' },
  { label: 'In transit', value: 'in_transit' },
  { label: 'Received', value: 'received' },
];

const getUnitCost = (row: GlobalStock): number => {
  if (!isGlobalStockCostingInput(row)) return 0;
  return resolveGlobalStockUnitCostSync(row, costingCache.getSync(row.shipment_id));
};

const formatCost = (val: number): string => {
  return val.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};

const pageTotals = computed(() => {
  let totalQty = 0;
  let totalCost = 0;
  const rows = stockStore.rows;
  for (const row of rows) {
    const qty = row.quantity || 0;
    const unitCost = getUnitCost(row);
    totalQty += qty;
    totalCost += unitCost * qty;
  }
  const avgUnitCost = totalQty > 0 ? totalCost / totalQty : 0;
  return {
    totalQty,
    totalCost,
    avgUnitCost,
  };
});

const loadStock = async () => {
  if (!authStore.tenantId) return;
  await stockStore.fetchStocks(authStore.tenantId, {
    page: stockStore.page,
    pageSize: stockStore.pageSize,
    search: searchText.value.trim() || null,
    availability: availabilityFilter.value,
    isSellable: isSellableFilter.value,
    shipmentStatus: shipmentStatusFilter.value === '__all__' ? null : shipmentStatusFilter.value,
    hideZeroStock: hideZeroStockFilter.value,
    locationId: locationFilter.value,
    shipmentId: shipmentIdFilter.value,
  });
  await costingCache.prefetchShipmentItems(stockStore.rows.map((row) => row.shipment_id));
};

const onTableRequest = async (props: any) => {
  stockStore.page = props.pagination.page;
  stockStore.pageSize = props.pagination.rowsPerPage;
  await loadStock();
};

const onSearch = () => {
  stockStore.page = 1;
  void loadStock();
};

// Filter Actions
const openFilterDrawer = () => {
  draftLocationFilter.value = locationFilter.value;
  draftAvailabilityFilter.value = availabilityFilter.value;
  draftIsSellableFilter.value = isSellableFilter.value;
  draftShipmentStatusFilter.value = shipmentStatusFilter.value;
  draftHideZeroStockFilter.value = hideZeroStockFilter.value;
  filterDrawerOpen.value = true;
};

const onApplyDrawerFilters = () => {
  locationFilter.value = draftLocationFilter.value;
  availabilityFilter.value = draftAvailabilityFilter.value;
  isSellableFilter.value = draftIsSellableFilter.value;
  shipmentStatusFilter.value = draftShipmentStatusFilter.value;
  hideZeroStockFilter.value = draftHideZeroStockFilter.value;
  filterDrawerOpen.value = false;
  stockStore.page = 1;
  void loadStock();
};

const onResetFilters = () => {
  draftLocationFilter.value = null;
  draftAvailabilityFilter.value = null;
  draftIsSellableFilter.value = null;
  draftShipmentStatusFilter.value = null;
  draftHideZeroStockFilter.value = true;
  locationFilter.value = null;
  availabilityFilter.value = null;
  isSellableFilter.value = null;
  shipmentStatusFilter.value = null;
  hideZeroStockFilter.value = true;
  filterDrawerOpen.value = false;
  stockStore.page = 1;
  void loadStock();
};

const goToShipments = () => {
  void router.push({
    name: 'app-procurement-shipment-list',
    params: { tenantSlug: route.params.tenantSlug },
  });
};

onMounted(async () => {
  if (authStore.tenantId) {
    await stockLocationStore.fetchLocations(authStore.tenantId);
  }
  void loadStock();
});
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.table-fixed-wrap {
  flex: 1 1 0%;
  display: flex;
  flex-direction: column;
  min-height: 0;
  overflow: hidden;
}

:deep(.q-table__card) {
  display: flex;
  flex-direction: column;
  height: 100%;
}

:deep(.q-table__container) {
  display: flex;
  flex-direction: column;
  height: 100%;
}

:deep(.q-table__middle) {
  flex: 1 1 0%;
  overflow-y: auto;
}

:deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background-color: #f8fafc !important;
}

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
