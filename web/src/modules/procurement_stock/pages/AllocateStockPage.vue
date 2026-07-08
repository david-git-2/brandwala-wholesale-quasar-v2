<template>
  <q-page class="q-pa-xs q-sm-pa-sm">
    <div class="q-gutter-y-sm">
      <!-- Compact Header Card -->
      <q-card flat bordered class="q-py-sm q-px-md bg-white">
        <div class="row items-center justify-between no-wrap">
          <div class="column">
            <span
              class="text-caption text-weight-bold text-primary text-uppercase tracking-wider"
              style="font-size: 10px"
              >Procurement & Stock</span
            >
            <div class="text-h6 text-weight-bold text-grey-9 q-mt-xs" style="line-height: 1.1">
              Allocate Stock
            </div>
            <div class="text-caption text-grey-6 q-mt-xs" style="font-size: 11px">
              Distribute physical stock pools to sister concerns (child tenants)
            </div>
          </div>
        </div>
      </q-card>

      <!-- Parent Context Validation Banner -->
      <q-banner
        v-if="!isParentContext"
        class="bg-orange-1 text-orange-10 rounded-borders q-mb-md bw-status-banner"
      >
        <template #avatar>
          <q-icon name="warning" color="warning" />
        </template>
        Allocate Stock is restricted to parent tenant administrators. Please switch to the parent
        tenant context.
      </q-banner>

      <!-- Main Content (Only visible for Parent Context) -->
      <template v-else>
        <!-- Search and Filter Toolbar -->
        <div class="row items-center q-gutter-sm q-mb-md">
          <q-input
            v-model="searchText"
            filled
            dense
            clearable
            class="col-grow"
            label="Search ready stock pools..."
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
              v-model="draftShipmentFilter"
              :options="shipmentOptions"
              label="Shipment Batch"
              filled
              dense
              clearable
              emit-value
              map-options
            />

            <q-select
              v-model="draftStockTypeFilter"
              :options="stockTypeOptions"
              label="Stock Type"
              filled
              dense
              clearable
              emit-value
              map-options
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

        <!-- Allocatable Stock Pools Table -->
        <q-card flat bordered class="q-pa-none">
          <q-table
            flat
            :rows="allocationStore.allocatableStocks"
            :columns="columns"
            row-key="id"
            :loading="allocationStore.loadingAllocatable"
            v-model:pagination="pagination"
            @request="onRequest"
            binary-state-sort
            class="allocation-sticky-header-table"
          >
            <!-- Header Slot with leading auto-width for Collapse actions -->
            <template #header="props">
              <q-tr :props="props">
                <q-th auto-width />
                <q-th v-for="col in props.cols" :key="col.name" :props="props">
                  {{ col.label }}
                </q-th>
              </q-tr>
            </template>

            <!-- Expanded Row Slot -->
            <template #body="props">
              <q-tr :props="props">
                <q-td auto-width>
                  <q-btn
                    size="sm"
                    color="primary"
                    round
                    dense
                    @click="
                      props.expand = !props.expand;
                      props.expand ? loadRowAllocations(props.row.id) : null;
                    "
                    :icon="props.expand ? 'remove' : 'add'"
                  />
                </q-td>
                <q-td v-for="col in props.cols" :key="col.name" :props="props">
                  <template v-if="col.name === 'product'">
                    <div class="row items-center q-gutter-x-md no-wrap q-py-xs">
                      <q-avatar rounded size="1in" class="bg-grey-2 flex-shrink-0">
                        <img
                          v-if="props.row.image_url"
                          :src="props.row.image_url"
                          alt="Product"
                          style="object-fit: cover; width: 100%; height: 100%"
                        />
                        <q-icon v-else name="inventory_2" color="grey-6" size="36px" />
                      </q-avatar>
                      <div>
                        <div
                          class="text-weight-bold text-grey-9 text-wrap"
                          style="line-height: 1.2; word-break: break-word"
                        >
                          {{ props.row.item_name }}
                        </div>
                        <div class="text-caption text-grey-6 row q-gutter-x-sm q-mt-xs">
                          <span v-if="props.row.product_code"
                            >Code: {{ props.row.product_code }}</span
                          >
                          <span v-if="props.row.barcode">Barcode: {{ props.row.barcode }}</span>
                        </div>
                      </div>
                    </div>
                  </template>
                  <template v-else>
                    {{ col.value }}
                  </template>
                </q-td>
              </q-tr>

              <!-- Expanded content details -->
              <q-tr v-if="props.expand" :props="props" class="bg-grey-1">
                <q-td colspan="100%">
                  <div class="q-pa-md q-mx-auto" style="max-width: 800px; width: 100%">
                    <div class="text-subtitle2 text-weight-bold text-primary q-mb-sm">
                      Child Tenant Allocations for {{ props.row.item_name }}
                    </div>

                    <div v-if="rowLoadingState[props.row.id]" class="row justify-center q-py-md">
                      <q-spinner color="primary" size="24px" />
                    </div>

                    <div v-else-if="rowAllocations[props.row.id]" class="column q-gutter-y-sm">
                      <!-- Active allocations per child tenant -->
                      <div
                        class="row q-col-gutter-sm items-center q-pb-xs border-bottom text-caption text-weight-bold text-grey-7"
                      >
                        <div class="col-4">Sister Concern</div>
                        <div class="col-4 text-center">Allocated Quantity</div>
                        <div class="col-4 text-right">Actions</div>
                      </div>

                      <div
                        v-for="child in rowAllocations[props.row.id]"
                        :key="child.child_tenant_id"
                        class="row q-col-gutter-sm items-center q-py-sm"
                      >
                        <div class="col-4 text-body2 text-grey-9">
                          {{ child.child_tenant_name }}
                        </div>
                        <div class="col-4 row justify-center">
                          <q-input
                            v-model.number="draftQuantities[props.row.id]![child.child_tenant_id]"
                            type="number"
                            dense
                            filled
                            min="0"
                            class="soft-input text-center"
                            style="max-width: 120px"
                            input-class="text-center"
                            @update:model-value="onQtyChange(props.row)"
                          />
                        </div>
                        <div class="col-4 row justify-end q-gutter-x-sm">
                          <q-btn
                            unelevated
                            size="sm"
                            color="primary"
                            label="Save"
                            no-caps
                            :loading="submittingMap[`${props.row.id}-${child.child_tenant_id}`]"
                            :disable="
                              isOverAllocated(props.row.id) ||
                              !hasQtyChanged(props.row.id, child.child_tenant_id)
                            "
                            @click="saveAllocation(props.row, child.child_tenant_id)"
                          />
                          <q-btn
                            outline
                            size="sm"
                            color="negative"
                            label="Remove"
                            no-caps
                            :loading="submittingMap[`${props.row.id}-${child.child_tenant_id}`]"
                            :disable="!hasExistingAllocation(props.row.id, child.child_tenant_id)"
                            @click="removeAllocation(props.row, child.child_tenant_id)"
                          />
                        </div>
                      </div>

                      <div
                        v-if="
                          !rowAllocations[props.row.id] ||
                          rowAllocations[props.row.id]!.length === 0
                        "
                        class="text-caption text-grey-6 text-center q-py-md"
                      >
                        No sister concerns (child tenants) found under this parent tenant.
                      </div>

                      <!-- Reconciliation and totals summary -->
                      <div class="row justify-between items-center q-mt-md q-pt-md border-top">
                        <div class="text-caption text-grey-8">
                          Pool Qty:
                          <span class="text-weight-bold">{{ props.row.pool_quantity }}</span>
                          &nbsp;|&nbsp; Allocated Total:
                          <span
                            class="text-weight-bold"
                            :class="
                              isOverAllocated(props.row.id) ? 'text-negative' : 'text-primary'
                            "
                            >{{ draftTotals[props.row.id] ?? 0 }}</span
                          >
                          &nbsp;|&nbsp; Remaining:
                          <span class="text-weight-bold">{{
                            props.row.pool_quantity - (draftTotals[props.row.id] ?? 0)
                          }}</span>
                        </div>
                        <div
                          v-if="isOverAllocated(props.row.id)"
                          class="text-caption text-negative text-weight-bold"
                        >
                          <q-icon name="warning" color="negative" /> Allocation exceeds pool
                          capacity! Save disabled.
                        </div>
                      </div>
                    </div>
                  </div>
                </q-td>
              </q-tr>
            </template>

            <!-- Empty State -->
            <template #no-data>
              <div class="full-width text-center text-grey-7 q-py-lg">
                <q-icon name="inventory" size="48px" class="q-mb-sm text-grey-4" />
                <div>
                  No ready stock pools found for allocation. Ensure shipments are received and in
                  Ready Stock.
                </div>
              </div>
            </template>
          </q-table>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';
import { useQuasar, type QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useGlobalShipmentStore } from 'src/modules/procurement_stock/stores/globalShipmentStore';
import { useGlobalStockTypeStore } from 'src/modules/procurement_stock/stores/globalStockTypeStore';
import { useGlobalStockAllocationStore } from 'src/modules/procurement_stock/stores/globalStockAllocationStore';
import {
  globalStockAllocationRepository,
  type AllocatableStock,
} from '../repositories/globalStockAllocationRepository';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const $q = useQuasar();
const authStore = useAuthStore();
const tenantStore = useTenantStore();
const shipmentStore = useGlobalShipmentStore();
const stockTypeStore = useGlobalStockTypeStore();
const allocationStore = useGlobalStockAllocationStore();

// State
const searchText = ref('');

// Filter State
const filterDrawerOpen = ref(false);
const shipmentFilter = ref<number | null>(null);
const stockTypeFilter = ref<number | null>(null);
const draftShipmentFilter = ref<number | null>(null);
const draftStockTypeFilter = ref<number | null>(null);

// Allocation editing states
const rowAllocations = ref<Record<number, any[]>>({});
const rowLoadingState = ref<Record<number, boolean>>({});
const savedQuantities = ref<Record<number, Record<number, number>>>({}); // Map of stockId -> childTenantId -> qty
const draftQuantities = ref<Record<number, Record<number, number>>>({}); // Map of stockId -> childTenantId -> qty
const draftTotals = ref<Record<number, number>>({});
const submittingMap = ref<Record<string, boolean>>({});

// Table Pagination
const pagination = ref({
  sortBy: 'id',
  descending: true,
  page: 1,
  rowsPerPage: 20,
  rowsNumber: 0,
});

// Column definitions
const columns: QTableColumn[] = [
  { name: 'product', label: 'Product Details', field: 'item_name', align: 'left', sortable: true },
  {
    name: 'shipment',
    label: 'Shipment Batch',
    field: 'shipment_name',
    align: 'left',
    sortable: true,
  },
  {
    name: 'stock_type',
    label: 'Stock Type',
    field: 'stock_type_description',
    align: 'left',
    sortable: true,
  },
  {
    name: 'pool_quantity',
    label: 'Pool Qty',
    field: 'pool_quantity',
    align: 'center',
    sortable: true,
  },
  {
    name: 'allocated_qty',
    label: 'Allocated',
    field: 'allocated_qty',
    align: 'center',
    sortable: true,
  },
  {
    name: 'unallocated_qty',
    label: 'Unallocated',
    field: 'unallocated_qty',
    align: 'center',
    sortable: true,
  },
];

// Computed properties for Context Verification
const contextTenantId = computed(() => tenantStore.selectedTenantId ?? authStore.tenantId ?? null);
const effectiveParentTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null;
  if (!current) return authStore.tenantId;
  return current.parent_id ?? current.id;
});
const isParentContext = computed(() => {
  return (
    contextTenantId.value !== null &&
    effectiveParentTenantId.value !== null &&
    contextTenantId.value === effectiveParentTenantId.value
  );
});

// Active Filter Count
const activeFilterCount = computed(() => {
  let count = 0;
  if (shipmentFilter.value !== null) count++;
  if (stockTypeFilter.value !== null) count++;
  return count;
});

// Select options
const shipmentOptions = computed(() => {
  return shipmentStore.rows
    .filter((s) => s.status === 'Ready Stock')
    .map((s) => ({ label: s.name, value: s.id }));
});

const stockTypeOptions = computed(() => {
  return stockTypeStore.items
    .filter((t) => t.is_sellable)
    .map((t) => ({ label: t.description, value: t.id }));
});

// Handlers

// Loads allocations for child tenants of a specific stock pool
const loadRowAllocations = async (stockId: number) => {
  rowLoadingState.value[stockId] = true;
  try {
    const data = await globalStockAllocationRepository.listChildAllocationSummary(stockId);
    rowAllocations.value[stockId] = data;

    // Initialize maps
    const saved = savedQuantities.value[stockId] ?? {};
    const draft = draftQuantities.value[stockId] ?? {};
    savedQuantities.value[stockId] = saved;
    draftQuantities.value[stockId] = draft;

    // Pre-fill child concerns
    data.forEach((item) => {
      saved[item.child_tenant_id] = item.allocated_qty;
      draft[item.child_tenant_id] = item.allocated_qty;
    });

    recalculateDraftTotal(stockId);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Failed to load allocations.');
  } finally {
    rowLoadingState.value[stockId] = false;
  }
};

const recalculateDraftTotal = (stockId: number) => {
  const stockDrafts = draftQuantities.value[stockId] || {};
  const allocs = rowAllocations.value[stockId] || [];
  draftTotals.value[stockId] = allocs.reduce((sum, item) => {
    const val = Number(stockDrafts[item.child_tenant_id]);
    return sum + (Number.isFinite(val) ? Math.max(0, val) : 0);
  }, 0);
};

const onQtyChange = (row: AllocatableStock) => {
  recalculateDraftTotal(row.id);
};

const isOverAllocated = (stockId: number) => {
  const pool = allocationStore.allocatableStocks.find((s) => s.id === stockId);
  if (!pool) return false;
  return (draftTotals.value[stockId] || 0) > pool.pool_quantity;
};

const hasQtyChanged = (stockId: number, childId: number) => {
  const saved = savedQuantities.value[stockId]?.[childId] ?? 0;
  const draft = draftQuantities.value[stockId]?.[childId] ?? 0;
  return Number(saved) !== Number(draft);
};

const hasExistingAllocation = (stockId: number, childId: number) => {
  const saved = savedQuantities.value[stockId]?.[childId] ?? 0;
  return Number(saved) > 0;
};

const saveAllocation = async (row: AllocatableStock, childId: number) => {
  const stockId = row.id;
  const qty = Number(draftQuantities.value[stockId]?.[childId] || 0);
  const key = `${stockId}-${childId}`;
  const currentTenantId = contextTenantId.value;

  if (!currentTenantId) {
    showErrorNotification('Parent tenant context is missing.');
    return;
  }

  submittingMap.value[key] = true;
  try {
    await globalStockAllocationRepository.upsertGlobalStockAllocation(
      currentTenantId,
      childId,
      stockId,
      qty,
    );
    showSuccessNotification('Allocation updated successfully.');
    await loadRowAllocations(stockId);
    await fetchAllocatableData();
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Failed to update allocation.');
  } finally {
    submittingMap.value[key] = false;
  }
};

const removeAllocation = (row: AllocatableStock, childId: number) => {
  const stockId = row.id;
  const key = `${stockId}-${childId}`;
  const currentTenantId = contextTenantId.value;

  if (!currentTenantId) {
    showErrorNotification('Parent tenant context is missing.');
    return;
  }

  $q.dialog({
    title: 'Confirm Removal',
    message: 'Are you sure you want to remove this child concern allocation?',
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      submittingMap.value[key] = true;
      try {
        await globalStockAllocationRepository.upsertGlobalStockAllocation(
          currentTenantId,
          childId,
          stockId,
          0,
        );
        showSuccessNotification('Allocation removed successfully.');
        await loadRowAllocations(stockId);
        await fetchAllocatableData();
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        showErrorNotification(msg || 'Failed to remove allocation.');
      } finally {
        submittingMap.value[key] = false;
      }
    })();
  });
};

// Pagination & Fetching
const fetchAllocatableData = async () => {
  if (!isParentContext.value || !authStore.tenantId) return;

  await allocationStore.fetchAllocatableStocks(authStore.tenantId, {
    page: pagination.value.page,
    pageSize: pagination.value.rowsPerPage,
    search: searchText.value,
    shipmentId: shipmentFilter.value,
    stockTypeId: stockTypeFilter.value,
  });

  pagination.value.rowsNumber = allocationStore.allocatableTotal;
};

const onRequest = (props: {
  pagination: {
    page: number;
    rowsPerPage: number;
    sortBy: string;
    descending: boolean;
  };
}) => {
  pagination.value.page = props.pagination.page;
  pagination.value.rowsPerPage = props.pagination.rowsPerPage;
  pagination.value.sortBy = props.pagination.sortBy;
  pagination.value.descending = props.pagination.descending;
  void fetchAllocatableData();
};

const onSearch = () => {
  pagination.value.page = 1;
  void fetchAllocatableData();
};

// Filter Actions
const openFilterDrawer = () => {
  draftShipmentFilter.value = shipmentFilter.value;
  draftStockTypeFilter.value = stockTypeFilter.value;
  filterDrawerOpen.value = true;
};

const onApplyDrawerFilters = () => {
  shipmentFilter.value = draftShipmentFilter.value;
  stockTypeFilter.value = draftStockTypeFilter.value;
  filterDrawerOpen.value = false;
  pagination.value.page = 1;
  void fetchAllocatableData();
};

const onResetFilters = () => {
  draftShipmentFilter.value = null;
  draftStockTypeFilter.value = null;
  shipmentFilter.value = null;
  stockTypeFilter.value = null;
  filterDrawerOpen.value = false;
  pagination.value.page = 1;
  void fetchAllocatableData();
};

// Lifecycle
onMounted(async () => {
  const currentTenantId = contextTenantId.value;
  if (isParentContext.value && currentTenantId) {
    await Promise.all([
      shipmentStore.fetchShipments(currentTenantId),
      stockTypeStore.fetchStockTypes(currentTenantId),
      fetchAllocatableData(),
    ]);
  }
});

// Watch context change
watch(
  () => [contextTenantId.value, isParentContext.value] as const,
  async ([newTenantId, parentCtx]) => {
    if (parentCtx && newTenantId) {
      await Promise.all([
        shipmentStore.fetchShipments(newTenantId),
        stockTypeStore.fetchStockTypes(newTenantId),
        fetchAllocatableData(),
      ]);
    }
  },
);
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.12);
}
.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.12);
}

.allocation-sticky-header-table {
  height: clamp(400px, calc(100vh - 250px), 70vh);
  max-width: 100%;
}

.allocation-sticky-header-table :deep(.q-table__container) {
  max-height: 100%;
}

.allocation-sticky-header-table :deep(.q-table__middle) {
  max-height: 100%;
  overflow: auto;
}

.allocation-sticky-header-table :deep(table) {
  min-width: 1200px;
}

.allocation-sticky-header-table :deep(thead tr th) {
  position: sticky;
  z-index: 1;
  background-color: #fff;
}

.allocation-sticky-header-table :deep(thead tr:first-child th) {
  top: 0;
}
</style>
