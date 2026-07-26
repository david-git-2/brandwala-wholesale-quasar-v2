<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header section -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Procurement & Stock</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Allocate Stock</h1>
        </div>
        <div class="col-auto row items-center q-gutter-x-sm">
          <q-btn
            v-if="isParentContext"
            color="primary"
            unelevated
            no-caps
            class="pill-btn"
            icon="ph ph-package"
            label="Bulk Allocate Shipment"
            @click="openBulkAllocateDialog"
          />
        </div>
      </section>

      <!-- Parent Context Validation Banner -->
      <q-banner
        v-if="!isParentContext"
        class="bg-orange-1 text-orange-10 rounded-borders bw-status-banner"
      >
        <template #avatar>
          <q-icon name="ph ph-warning" color="warning" />
        </template>
        Allocate Stock is restricted to parent tenant administrators. Please switch to the parent
        tenant context.
      </q-banner>

      <!-- Main Content (Only visible for Parent Context) -->
      <template v-else>
        <!-- Toolbar Card -->
        <q-card flat bordered class="q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col row items-center q-gutter-sm">
              <q-input
                v-model="searchText"
                outlined
                dense
                class="soft-input col-grow col-sm-auto"
                style="min-width: 200px"
                label="Search ready stock pools..."
                clearable
                @keyup.enter="onSearch"
                @clear="onSearch"
              >
                <template #prepend>
                  <q-icon name="ph ph-magnifying-glass" />
                </template>
              </q-input>

              <q-btn flat round dense icon="ph ph-funnel" aria-label="Filters" @click="openFilterDrawer">
                <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
                  {{ activeFilterCount }}
                </q-badge>
              </q-btn>

              <q-separator vertical class="gt-xs q-mx-xs" />

              <!-- Quick Status Filter Chips -->
              <div class="row items-center q-gutter-x-xs">
                <q-chip
                  clickable
                  dense
                  :color="statusChipFilter === 'all' ? 'primary' : 'grey-3'"
                  :text-color="statusChipFilter === 'all' ? 'white' : 'grey-8'"
                  @click="setStatusChipFilter('all')"
                >
                  All Stocks
                </q-chip>
                <q-chip
                  clickable
                  dense
                  :color="statusChipFilter === 'unallocated' ? 'orange-9' : 'grey-3'"
                  :text-color="statusChipFilter === 'unallocated' ? 'white' : 'grey-8'"
                  @click="setStatusChipFilter('unallocated')"
                >
                  Unallocated
                </q-chip>
                <q-chip
                  clickable
                  dense
                  :color="statusChipFilter === 'partial' ? 'warning' : 'grey-3'"
                  :text-color="statusChipFilter === 'partial' ? 'white' : 'grey-8'"
                  @click="setStatusChipFilter('partial')"
                >
                  Partially Allocated
                </q-chip>
                <q-chip
                  clickable
                  dense
                  :color="statusChipFilter === 'full' ? 'positive' : 'grey-3'"
                  :text-color="statusChipFilter === 'full' ? 'white' : 'grey-8'"
                  @click="setStatusChipFilter('full')"
                >
                  Fully Allocated
                </q-chip>
              </div>
            </div>
          </div>
        </q-card>

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

        <!-- Allocatable Stock Pools Table Skeleton -->
        <q-markup-table
          v-if="isLoadingAllocatableStock && !allocatableStocks.length"
          flat
          bordered
          class="treasury-table-wrap"
        >
          <thead>
            <tr>
              <th style="width: 40px"><q-skeleton type="QBtn" size="xs" width="24px" height="24px" /></th>
              <th><q-skeleton type="text" width="120px" /></th>
              <th><q-skeleton type="text" width="100px" /></th>
              <th><q-skeleton type="text" width="80px" /></th>
              <th class="text-center"><q-skeleton type="text" width="60px" class="q-mx-auto" /></th>
              <th><q-skeleton type="text" width="110px" /></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="n in 6" :key="n">
              <td><q-skeleton type="QBtn" size="xs" width="24px" height="24px" /></td>
              <td>
                <div class="row items-center no-wrap q-gutter-x-md">
                  <q-skeleton type="QAvatar" size="48px" class="flex-shrink-0" />
                  <div class="col">
                    <q-skeleton type="text" width="70%" height="16px" />
                    <q-skeleton type="text" width="40%" height="12px" class="q-mt-xs" />
                  </div>
                </div>
              </td>
              <td><q-skeleton type="text" width="80px" height="14px" /></td>
              <td><q-skeleton type="QBadge" width="70px" height="20px" /></td>
              <td class="text-center"><q-skeleton type="text" width="40px" height="14px" class="q-mx-auto" /></td>
              <td>
                <div style="min-width: 140px">
                  <div class="row justify-between items-center q-mb-xs">
                    <q-skeleton type="text" width="60px" height="12px" />
                    <q-skeleton type="QBadge" width="36px" height="16px" />
                  </div>
                  <q-skeleton type="rect" height="8px" class="rounded-borders" />
                </div>
              </td>
            </tr>
          </tbody>
        </q-markup-table>

        <q-card v-else flat bordered class="q-pa-none">
          <q-table
            flat
            :rows="filteredRows"
            :columns="columns"
            row-key="id"
            :loading="isLoadingAllocatableStock"
            v-model:pagination="pagination"
            @request="onRequest"
            binary-state-sort
            class="allocation-sticky-header-table"
          >
            <!-- Header Slot -->
            <template #header="props">
              <q-tr :props="props">
                <q-th auto-width />
                <q-th v-for="col in props.cols" :key="col.name" :props="props">
                  {{ col.label }}
                </q-th>
              </q-tr>
            </template>

            <!-- Row Slot -->
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
                      props.expand ? onRowExpand(props.row.id) : null;
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
                        <q-icon v-else name="ph ph-archive-box" color="grey-6" size="36px" />
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
                  <template v-else-if="col.name === 'allocation_progress'">
                    <div style="min-width: 140px" class="q-py-xs">
                      <div class="row justify-between items-center text-caption q-mb-xs">
                        <span class="text-weight-medium text-grey-8">
                          {{ getRowDisplayAllocated(props.row.id, props.row.allocated_qty) }} / {{ props.row.pool_quantity }}
                        </span>
                        <q-badge
                          :color="getRatioColor(getRowDisplayAllocated(props.row.id, props.row.allocated_qty), props.row.pool_quantity)"
                          dense
                          style="font-size: 10px"
                        >
                          {{ getPercentage(getRowDisplayAllocated(props.row.id, props.row.allocated_qty), props.row.pool_quantity) }}%
                        </q-badge>
                      </div>
                      <q-linear-progress
                        :value="props.row.pool_quantity > 0 ? getRowDisplayAllocated(props.row.id, props.row.allocated_qty) / props.row.pool_quantity : 0"
                        :color="getRatioColor(getRowDisplayAllocated(props.row.id, props.row.allocated_qty), props.row.pool_quantity)"
                        track-color="grey-3"
                        rounded
                        size="8px"
                      />
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

                    <div v-if="loadingRowAllocations[props.row.id]" class="column q-gutter-y-sm q-py-sm">
                      <div v-for="n in 3" :key="n" class="row q-col-gutter-sm items-center q-py-xs">
                        <div class="col-4">
                          <q-skeleton type="text" width="120px" height="16px" />
                        </div>
                        <div class="col-4 row justify-center items-center q-gutter-x-xs">
                          <q-skeleton type="QInput" height="36px" style="width: 110px" />
                          <q-skeleton type="QBtn" width="40px" height="24px" />
                        </div>
                        <div class="col-4 row justify-end">
                          <q-skeleton type="QBtn" width="70px" height="32px" />
                        </div>
                      </div>
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
                        v-for="(child, idx) in rowAllocations[props.row.id]"
                        :key="child.child_tenant_id"
                        class="row q-col-gutter-sm items-center q-py-sm"
                      >
                        <div class="col-4 text-body2 text-grey-9 row items-center no-wrap">
                          <span
                            v-if="hasQtyChanged(props.row.id, child.child_tenant_id)"
                            class="q-mr-xs text-caption text-weight-bold text-amber-9"
                            title="Unsaved changes"
                          >
                            ●
                          </span>
                          {{ child.child_tenant_name }}
                        </div>
                        <div class="col-4 row justify-center items-center q-gutter-x-xs">
                          <q-input
                            v-model.number="draftQuantities[props.row.id]![child.child_tenant_id]"
                            type="number"
                            dense
                            filled
                            min="0"
                            :tabindex="idx + 1"
                            class="soft-input text-center"
                            :class="{ 'bg-amber-1 rounded-borders': hasQtyChanged(props.row.id, child.child_tenant_id) }"
                            style="max-width: 110px"
                            input-class="text-center"
                            @update:model-value="onQtyChange(props.row)"
                          />
                          <q-btn
                            unelevated
                            size="xs"
                            color="secondary"
                            label="Max"
                            no-caps
                            class="q-px-xs"
                            @click="applyMaxAllocation(props.row.id, child.child_tenant_id)"
                          >
                            <q-tooltip>Assign remaining pool quantity to this tenant</q-tooltip>
                          </q-btn>
                        </div>
                        <div class="col-4 row justify-end q-gutter-x-sm">
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

                        <div class="row items-center q-gutter-x-sm">
                          <div
                            v-if="isOverAllocated(props.row.id)"
                            class="text-caption text-negative text-weight-bold q-mr-sm"
                          >
                            <q-icon name="ph ph-warning" color="negative" /> Exceeds pool capacity!
                          </div>
                          <q-btn
                            unelevated
                            size="sm"
                            color="primary"
                            label="Save Row Allocations"
                            no-caps
                            icon="ph ph-floppy-disk"
                            :loading="rowSubmittingState[props.row.id]"
                            :disable="
                              isOverAllocated(props.row.id) ||
                              !hasRowChanges(props.row.id)
                            "
                            @click="saveRowAllocations(props.row)"
                          />
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
                <q-icon name="ph ph-package" size="48px" class="q-mb-sm text-grey-4" />
                <div>
                  No ready stock pools found for allocation. Ensure shipments are received and in
                  Ready Stock.
                </div>
              </div>
            </template>
          </q-table>
        </q-card>

        <!-- Bulk Allocate Shipment Dialog -->
        <q-dialog v-model="bulkDialogOpen" persistent>
          <q-card style="min-width: 400px; max-width: 500px" class="q-pa-sm">
            <q-card-section class="row items-center justify-between q-pb-none">
              <div class="text-h6 text-weight-bold text-grey-9">Bulk Allocate Shipment</div>
              <q-btn icon="ph ph-x" flat round dense v-close-popup />
            </q-card-section>

            <q-card-section class="q-pt-sm">
              <div class="text-caption text-grey-7 q-mb-md">
                Allocate all unallocated ready stocks within a selected shipment batch to a target child tenant in a single action.
              </div>

              <div class="q-gutter-y-md">
                <q-select
                  v-model="bulkSelectedShipmentId"
                  :options="shipmentOptions"
                  label="Select Shipment Batch"
                  filled
                  dense
                  emit-value
                  map-options
                  :rules="[(val) => !!val || 'Shipment selection is required']"
                />

                <q-select
                  v-model="bulkSelectedChildTenantId"
                  :options="childTenantOptions"
                  label="Select Target Child Tenant"
                  filled
                  dense
                  emit-value
                  map-options
                  :loading="isLoadingChildTenants"
                  :rules="[(val) => !!val || 'Child tenant selection is required']"
                />
              </div>
            </q-card-section>

            <q-card-actions align="right" class="q-pt-md">
              <q-btn flat label="Cancel" color="grey-7" no-caps v-close-popup />
              <q-btn
                unelevated
                label="Allocate All Stock"
                color="primary"
                no-caps
                :loading="bulkMutation.isPending.value"
                :disable="!bulkSelectedShipmentId || !bulkSelectedChildTenantId"
                @click="onConfirmBulkAllocate"
              />
            </q-card-actions>
          </q-card>
        </q-dialog>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useQuasar, type QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import {
  globalStockAllocationRepository,
  type AllocatableStock,
  type ChildAllocationSummary,
} from '../repositories/globalStockAllocationRepository';
import {
  useAllocatableStockListQuery,
  useChildTenantsQuery,
  useShipmentsQuery,
  useStockTypesQuery,
} from '../composables/useAllocatableStockQueries';
import {
  useSaveAllocationMutation,
  useBulkAllocateShipmentMutation,
} from '../composables/useStockAllocationMutations';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const $q = useQuasar();
const authStore = useAuthStore();
const tenantStore = useTenantStore();

// Context Verification
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

// State & Filters
const searchText = ref('');
const filterDrawerOpen = ref(false);
const shipmentFilter = ref<number | null>(null);
const stockTypeFilter = ref<number | null>(null);
const draftShipmentFilter = ref<number | null>(null);
const draftStockTypeFilter = ref<number | null>(null);

type StatusChipType = 'all' | 'unallocated' | 'partial' | 'full';
const statusChipFilter = ref<StatusChipType>('all');

// Table Pagination
const pagination = ref({
  sortBy: 'id',
  descending: true,
  page: 1,
  rowsPerPage: 20,
  rowsNumber: 0,
});

// TanStack Query Params
const allocatableQueryParams = computed(() => ({
  tenantId: isParentContext.value ? contextTenantId.value : null,
  page: pagination.value.page,
  pageSize: pagination.value.rowsPerPage,
  search: searchText.value,
  shipmentId: shipmentFilter.value,
  stockTypeId: stockTypeFilter.value,
}));

// TanStack Queries
const {
  data: allocatableData,
  isLoading: isLoadingAllocatableStock,
} = useAllocatableStockListQuery(allocatableQueryParams);

const allocatableStocks = computed(() => allocatableData.value?.data || []);

watch(allocatableData, (newData) => {
  if (newData?.meta?.total !== undefined) {
    pagination.value.rowsNumber = newData.meta.total;
  }
});

const { data: childTenants, isLoading: isLoadingChildTenants } = useChildTenantsQuery(
  effectiveParentTenantId,
);
const { data: shipments } = useShipmentsQuery(contextTenantId);
const { data: stockTypes } = useStockTypesQuery(contextTenantId);

// TanStack Mutations
const saveAllocationMutation = useSaveAllocationMutation();
const bulkMutation = useBulkAllocateShipmentMutation();

// Allocation Editing Local UI States
const rowAllocations = ref<Record<number, ChildAllocationSummary[]>>({});
const loadingRowAllocations = ref<Record<number, boolean>>({});
const rowSubmittingState = ref<Record<number, boolean>>({});
const savedQuantities = ref<Record<number, Record<number, number>>>({});
const draftQuantities = ref<Record<number, Record<number, number>>>({});
const draftTotals = ref<Record<number, number>>({});
const submittingMap = ref<Record<string, boolean>>({});

// Bulk Allocation Dialog State
const bulkDialogOpen = ref(false);
const bulkSelectedShipmentId = ref<number | null>(null);
const bulkSelectedChildTenantId = ref<number | null>(null);

// Columns Definition
const columns: QTableColumn[] = [
  { name: 'product', label: 'Product Details', field: 'item_name', align: 'left', sortable: true },
  { name: 'shipment', label: 'Shipment Batch', field: 'shipment_name', align: 'left', sortable: true },
  { name: 'stock_type', label: 'Stock Type', field: 'stock_type_description', align: 'left', sortable: true },
  { name: 'pool_quantity', label: 'Pool Qty', field: 'pool_quantity', align: 'center', sortable: true },
  { name: 'allocation_progress', label: 'Allocation Status', field: 'allocated_qty', align: 'left', sortable: true },
];

// Computed Options
const childTenantOptions = computed(() => {
  return (childTenants.value || []).map((t: { name: string; id: number }) => ({
    label: t.name,
    value: t.id,
  }));
});

const shipmentOptions = computed(() => {
  return (shipments.value || [])
    .filter((s: { status: string }) => s.status === 'Ready Stock')
    .map((s: { name: string; id: number }) => ({ label: s.name, value: s.id }));
});

const stockTypeOptions = computed(() => {
  return (stockTypes.value || [])
    .filter((t: { is_sellable: boolean }) => t.is_sellable)
    .map((t: { description: string; id: number }) => ({ label: t.description, value: t.id }));
});

// Filtered Rows for Status Chips
const filteredRows = computed(() => {
  const stocks = allocatableStocks.value;
  if (statusChipFilter.value === 'all') return stocks;

  return stocks.filter((stock) => {
    const allocated = stock.allocated_qty;
    const total = stock.pool_quantity;
    if (statusChipFilter.value === 'unallocated') return allocated === 0;
    if (statusChipFilter.value === 'partial') return allocated > 0 && allocated < total;
    if (statusChipFilter.value === 'full') return allocated >= total && total > 0;
    return true;
  });
});

// Active Filter Count
const activeFilterCount = computed(() => {
  let count = 0;
  if (shipmentFilter.value !== null) count++;
  if (stockTypeFilter.value !== null) count++;
  return count;
});

// UI Helpers
const getRowDisplayAllocated = (stockId: number, fallbackQty: number) => {
  if (draftTotals.value[stockId] !== undefined) {
    return draftTotals.value[stockId]!;
  }
  return fallbackQty;
};

const getPercentage = (allocated: number, total: number) => {
  if (!total || total <= 0) return 0;
  return Math.min(100, Math.round((allocated / total) * 100));
};

const getRatioColor = (allocated: number, total: number) => {
  if (allocated > total) return 'negative';
  if (allocated === total && total > 0) return 'positive';
  if (allocated > 0) return 'warning';
  return 'grey-5';
};

const setStatusChipFilter = (filterType: StatusChipType) => {
  statusChipFilter.value = filterType;
  pagination.value.page = 1;
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
  const pool = allocatableStocks.value.find((s) => s.id === stockId);
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

const hasRowChanges = (stockId: number) => {
  const saved = savedQuantities.value[stockId] || {};
  const draft = draftQuantities.value[stockId] || {};
  const allocs = rowAllocations.value[stockId] || [];

  return allocs.some((child) => {
    const sVal = Number(saved[child.child_tenant_id] ?? 0);
    const dVal = Number(draft[child.child_tenant_id] ?? 0);
    return sVal !== dVal;
  });
};

const applyMaxAllocation = (stockId: number, childTenantId: number) => {
  const pool = allocatableStocks.value.find((s) => s.id === stockId);
  if (!pool) return;

  const currentDrafts = draftQuantities.value[stockId] || {};
  let otherDraftSum = 0;
  Object.keys(currentDrafts).forEach((keyIdStr) => {
    const cId = Number(keyIdStr);
    if (cId !== childTenantId) {
      otherDraftSum += Number(currentDrafts[cId] || 0);
    }
  });

  const availableRemaining = Math.max(0, pool.pool_quantity - otherDraftSum);
  if (!draftQuantities.value[stockId]) {
    draftQuantities.value[stockId] = {};
  }
  draftQuantities.value[stockId][childTenantId] = availableRemaining;
  recalculateDraftTotal(stockId);
};

const onRowExpand = async (stockId: number) => {
  loadingRowAllocations.value[stockId] = true;
  try {
    const data = await globalStockAllocationRepository.listChildAllocationSummary(stockId);
    rowAllocations.value[stockId] = data;

    const saved = savedQuantities.value[stockId] ?? {};
    const draft = draftQuantities.value[stockId] ?? {};
    savedQuantities.value[stockId] = saved;
    draftQuantities.value[stockId] = draft;

    data.forEach((item) => {
      saved[item.child_tenant_id] = item.allocated_qty;
      draft[item.child_tenant_id] = item.allocated_qty;
    });

    recalculateDraftTotal(stockId);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Failed to load allocations.');
  } finally {
    loadingRowAllocations.value[stockId] = false;
  }
};

const saveRowAllocations = async (row: AllocatableStock) => {
  const stockId = row.id;
  const currentTenantId = contextTenantId.value;
  if (!currentTenantId) {
    showErrorNotification('Parent tenant context is missing.');
    return;
  }

  const allocs = rowAllocations.value[stockId] || [];
  const changes = allocs.filter((child) => hasQtyChanged(stockId, child.child_tenant_id));

  if (changes.length === 0) return;

  rowSubmittingState.value[stockId] = true;
  try {
    for (const child of changes) {
      const qty = Number(draftQuantities.value[stockId]?.[child.child_tenant_id] || 0);
      await saveAllocationMutation.mutateAsync({
        parentTenantId: currentTenantId,
        childTenantId: child.child_tenant_id,
        stockId,
        quantity: qty,
      });
    }
    showSuccessNotification(`Allocations updated for ${row.item_name}.`);
    await onRowExpand(stockId);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Failed to save row allocations.');
  } finally {
    rowSubmittingState.value[stockId] = false;
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
        await saveAllocationMutation.mutateAsync({
          parentTenantId: currentTenantId,
          childTenantId: childId,
          stockId,
          quantity: 0,
        });
        showSuccessNotification('Allocation removed successfully.');
        await onRowExpand(stockId);
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        showErrorNotification(msg || 'Failed to remove allocation.');
      } finally {
        submittingMap.value[key] = false;
      }
    })();
  });
};

const openBulkAllocateDialog = () => {
  bulkSelectedShipmentId.value = shipmentFilter.value ?? null;
  bulkSelectedChildTenantId.value = null;
  bulkDialogOpen.value = true;
};

const onConfirmBulkAllocate = async () => {
  if (!bulkSelectedShipmentId.value || !bulkSelectedChildTenantId.value) return;
  const parentId = contextTenantId.value;
  if (!parentId) {
    showErrorNotification('Parent tenant context is missing.');
    return;
  }

  try {
    const updatedCount = await bulkMutation.mutateAsync({
      parentTenantId: parentId,
      shipmentId: bulkSelectedShipmentId.value,
      childTenantId: bulkSelectedChildTenantId.value,
    });
    showSuccessNotification(
      `Bulk allocation completed successfully (${updatedCount} products updated).`,
    );
    bulkDialogOpen.value = false;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    showErrorNotification(msg || 'Failed to bulk allocate shipment.');
  }
};

// Table pagination request
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
};

const onSearch = () => {
  pagination.value.page = 1;
};

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
};

const onResetFilters = () => {
  draftShipmentFilter.value = null;
  draftStockTypeFilter.value = null;
  shipmentFilter.value = null;
  stockTypeFilter.value = null;
  filterDrawerOpen.value = false;
  pagination.value.page = 1;
};
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
