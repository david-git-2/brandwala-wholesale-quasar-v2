<template>
  <q-page class="bw-page">
    <section class="bw-page__stack" style="min-width: 0">
      <AppPageHeader
        eyebrow="Procurement & Stock"
        title="Warehouse"
        subtitle="What is on the shelves, and whether it can be sold."
      >
        <template #action>
          <q-btn
            flat
            color="grey-8"
            no-caps
            icon="ph ph-gear"
            label="Stock types"
            @click="openStockTypesConfig"
          />
        </template>
      </AppPageHeader>

      <q-banner v-if="stockStore.error" class="bw-status-banner bg-negative text-white q-mb-md">
        {{ stockStore.error }}
      </q-banner>

      <!-- Search & Filters Toolbar -->
      <div class="row items-center q-gutter-sm q-mb-md">
        <q-input
          v-model="searchText"
          filled
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
      <q-card v-else flat bordered class="q-pa-none overflow-hidden" style="min-width: 0">
        <q-table
          flat
          :rows="stockStore.rows"
          :columns="columns"
          row-key="id"
          :loading="stockStore.loading"
          v-model:pagination="pagination"
          :rows-per-page-options="[10, 20, 50]"
          table-style="min-width: 1200px;"
          @request="onTableRequest"
        >
          <template #body-cell-image="props">
            <q-td :props="props">
              <q-avatar rounded size="42px" class="bg-grey-2">
                <img
                  :src="props.row.image_url || 'https://placehold.co/56x56?text=No+Image'"
                  alt="Product Image"
                  style="object-fit: contain"
                />
              </q-avatar>
            </q-td>
          </template>

          <template #body-cell-product="props">
            <q-td :props="props">
              <div class="text-weight-bold text-grey-9">{{ props.row.item_name }}</div>
              <div class="text-caption text-grey-6 row q-gutter-x-sm">
                <span v-if="props.row.product_code">Code: {{ props.row.product_code }}</span>
                <span v-if="props.row.barcode">Barcode: {{ props.row.barcode }}</span>
              </div>
            </q-td>
          </template>

          <template #body-cell-usable="props">
            <q-td :props="props">
              <q-icon
                :name="props.row.is_usable ? 'check_circle' : 'cancel'"
                :color="props.row.is_usable ? 'green-6' : 'red-6'"
                size="20px"
              />
            </q-td>
          </template>

          <template #body-cell-availability="props">
            <q-td :props="props">
              <q-chip
                v-if="props.row.availability"
                dense
                square
                :label="formatStockAvailability(props.row.availability)"
                class="text-capitalize"
              />
              <span v-else class="text-grey-5">—</span>
            </q-td>
          </template>

          <template #body-cell-location="props">
            <q-td :props="props">
              {{ props.row.location_name || (props.row.location_id ? `#${props.row.location_id}` : '—') }}
            </q-td>
          </template>

          <template #body-cell-cost="props">
            <q-td :props="props" class="text-right text-secondary">
              <div>৳{{ formatCost(getUnitCost(props.row)) }}</div>
              <div class="text-caption text-grey-6 text-weight-normal" style="font-size: 10px">
                T: ৳{{ formatCost(getUnitCost(props.row) * props.row.quantity) }}
              </div>
            </q-td>
          </template>

          <template #body-cell-quantity="props">
            <q-td :props="props" class="text-weight-bold text-primary">
              {{ props.row.quantity }} pcs
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="text-center">
              <div class="row items-center justify-center q-gutter-x-xs no-wrap">
                <!-- Transfer location -->
                <q-btn
                  flat
                  round
                  dense
                  icon="ph ph-map-pin-line"
                  size="sm"
                  color="primary"
                  @click.stop="openTransferDialog(props.row)"
                >
                  <q-tooltip>Transfer location (Draft)</q-tooltip>
                </q-btn>

                <!-- Change availability -->
                <q-btn
                  flat
                  round
                  dense
                  icon="ph ph-tag"
                  size="sm"
                  color="secondary"
                  @click.stop="openAvailabilityDialog(props.row)"
                >
                  <q-tooltip>Change availability (Draft)</q-tooltip>
                </q-btn>
              </div>
            </q-td>
          </template>

          <template #bottom-row>
            <q-tr class="totals-row">
              <q-td class="totals-row__cell" />
              <!-- image -->
              <q-td class="totals-row__cell text-weight-bold text-grey-9">Total (Page)</q-td>
              <!-- product name -->
              <q-td class="totals-row__cell" />
              <!-- shipment -->
              <q-td class="totals-row__cell" />
              <!-- stock type -->
              <q-td class="totals-row__cell" />
              <!-- availability -->
              <q-td class="totals-row__cell" />
              <!-- location -->
              <q-td class="totals-row__cell" />
              <!-- usable -->
              <q-td
                class="totals-row__cell text-right stock-cost-col text-weight-bold text-secondary"
              >
                <div>৳{{ formatCost(pageTotals.avgUnitCost) }} (avg)</div>
                <div class="text-caption text-grey-7 text-weight-normal" style="font-size: 10px">
                  T: ৳{{ formatCost(pageTotals.totalCost) }}
                </div>
              </q-td>
              <!-- cost -->
              <q-td class="totals-row__cell text-right stock-qty-col text-weight-bold text-primary">
                {{ pageTotals.totalQty }} pcs
              </q-td>
              <!-- quantity -->
              <q-td class="totals-row__cell" />
              <!-- actions -->
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
    </section>

    <!-- Preset Stock Movement Form Dialog -->
    <StockMovementFormDialog
      v-model="movementDialogOpen"
      :tenant-id="authStore.tenantId"
      :initial-stock="movementPresetStock"
      :preset-movement-type="movementPresetType"
      :lock-fields="true"
      @created="onMovementDraftCreated"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar, type QTableColumn } from 'quasar';
import type { Database } from 'src/types/database.types';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalStockStore } from '../stores/globalStockStore';
import { useGlobalStockTypeStore } from '../stores/globalStockTypeStore';
import { useStockLocationStore } from '../stores/stockLocationStore';
import { getLeafLocations, toLocationSelectOptions } from '../utils/stockLocationOptions';
import {
  STOCK_AVAILABILITY_OPTIONS,
  formatStockAvailability,
  type StockAvailability,
} from '../constants/stockAvailability';
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import StockTypeConfigPanel from '../components/StockTypeConfigPanel.vue';
import StockMovementFormDialog from '../components/StockMovementFormDialog.vue';
import { createShipmentItemsCostingCache } from 'src/modules/global/composables/useShipmentItemsCostingCache';
import {
  isGlobalStockCostingInput,
  resolveGlobalStockUnitCostSync,
} from 'src/modules/global/utils/resolveGlobalStockUnitCost';
import { showSuccessNotification } from 'src/utils/appFeedback';
import type { GlobalStock } from '../repositories/globalStockRepository';

type StockMovementType = Database['public']['Enums']['stock_movement_type'];

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const stockStore = useGlobalStockStore();
const stockTypeStore = useGlobalStockTypeStore();
const stockLocationStore = useStockLocationStore();
const $q = useQuasar();
const costingCache = createShipmentItemsCostingCache();

// Filter State
const searchText = ref('');
const filterDrawerOpen = ref(false);
const locationFilter = ref<number | null>(null);
const availabilityFilter = ref<StockAvailability | null>(null);
const isSellableFilter = ref<boolean | null>(null);
const shipmentStatusFilter = ref<string | null>(null);
const hideZeroStockFilter = ref<boolean>(true);

const draftLocationFilter = ref<number | null>(null);
const draftAvailabilityFilter = ref<StockAvailability | null>(null);
const draftIsSellableFilter = ref<boolean | null>(null);
const draftShipmentStatusFilter = ref<string | null>(null);
const draftHideZeroStockFilter = ref<boolean>(true);

// Movement Dialog Preset State
const movementDialogOpen = ref(false);
const movementPresetStock = ref<GlobalStock | null>(null);
const movementPresetType = ref<StockMovementType>('location_transfer');

const columns: QTableColumn[] = [
  { name: 'image', label: 'Image', field: 'image_url', align: 'left', sortable: false },
  { name: 'product', label: 'Product Details', field: 'item_name', align: 'left', sortable: false },
  { name: 'shipment', label: 'Shipment', field: 'shipment_name', align: 'left', sortable: false },
  {
    name: 'stock_type',
    label: 'Stock Type',
    field: 'stock_type_description',
    align: 'left',
    sortable: false,
  },
  { name: 'usable', label: 'Usable', field: 'is_usable', align: 'center', sortable: false },
  {
    name: 'availability',
    label: 'Availability',
    field: 'availability',
    align: 'left',
    sortable: false,
  },
  {
    name: 'location',
    label: 'Location',
    field: 'location_name',
    align: 'left',
    sortable: false,
  },
  {
    name: 'cost',
    label: 'Cost (Est. BDT)',
    field: 'id',
    align: 'right',
    sortable: false,
    classes: 'stock-cost-col',
    headerClasses: 'stock-cost-col',
  },
  {
    name: 'quantity',
    label: 'Quantity',
    field: 'quantity',
    align: 'right',
    sortable: false,
    classes: 'stock-qty-col',
    headerClasses: 'stock-qty-col',
  },
  {
    name: 'actions',
    label: 'Actions',
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

const openStockTypesConfig = () => {
  $q.dialog({
    component: StockTypeConfigPanel,
  }).onOk(() => {
    void loadStock();
  });
};

const openTransferDialog = (row: GlobalStock) => {
  movementPresetStock.value = row;
  movementPresetType.value = 'location_transfer';
  movementDialogOpen.value = true;
};

const openAvailabilityDialog = (row: GlobalStock) => {
  movementPresetStock.value = row;
  movementPresetType.value = 'availability_transfer';
  movementDialogOpen.value = true;
};

const onMovementDraftCreated = () => {
  showSuccessNotification('Draft created — post from Movements page');
  void loadStock();
};

onMounted(async () => {
  if (authStore.tenantId) {
    await Promise.all([
      stockTypeStore.fetchStockTypes(authStore.tenantId),
      stockLocationStore.fetchLocations(authStore.tenantId),
    ]);
  }
  void loadStock();
});
</script>

<style scoped>
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
